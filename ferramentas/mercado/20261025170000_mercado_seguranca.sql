-- Mercado, segunda etapa: itens conferidos contra as regras do jogo, banimento, limites diários,
-- anúncio idempotente (p_envio) e consultas de situação para o jogo se recuperar de queda de conexão.
-- Depois desta, aplicar tipos_mercado.sql (gerado por gerar_tipos.gd).
begin;

create table if not exists public.mercado_tipos (
 tipo text primary key,
 categoria text not null,
 empilhavel boolean not null,
 encantavel boolean not null default false,
 duas_maos boolean not null default false
);
create table if not exists public.mercado_banidos (
 codigo_hash text primary key,
 motivo text not null default '',
 criado_em timestamptz not null default now()
);
alter table public.mercado_tipos enable row level security;
alter table public.mercado_banidos enable row level security;
revoke all on public.mercado_tipos, public.mercado_banidos from public, anon, authenticated;

alter table public.mercado_config add column if not exists max_anuncios_dia int not null default 20;
alter table public.mercado_config add column if not exists max_compras_dia int not null default 30;
alter table public.mercado_anuncios add column if not exists envio text;
create unique index if not exists mercado_anuncios_envio on public.mercado_anuncios(vendedor_hash,envio) where envio is not null;
create index if not exists mercado_anuncios_comprador on public.mercado_anuncios(comprador_hash,vendido_em);

-- Refaz o item só com os campos conhecidos e dentro dos limites que o jogo consegue gerar; null = inválido.
-- Limites (raridades.gd): nível 1..5, até 6 afixos, valor de afixo até max*1,6, encantamento só em arma encantável, nível 1..3.
create or replace function public.mercado_normalizar_item(p_item jsonb) returns jsonb
language plpgsql stable security definer set search_path=public,pg_temp as $$
declare t public.mercado_tipos%rowtype; v_rar text; v_nivel int; v_qtd int; v_qual int; v_enc text; v_nivel_enc int;
 afixos jsonb:='{}'; chave text; valor numeric; limite numeric; permitidos text[];
begin
 if p_item is null or jsonb_typeof(p_item)<>'object' or octet_length(p_item::text)>2048 then return null; end if;
 select * into t from public.mercado_tipos where tipo=p_item->>'tipo';
 if not found then return null; end if;
 v_rar:=coalesce(p_item->>'raridade','comum');
 if v_rar not in ('comum','incomum','raro','epico','lendario') then return null; end if;
 begin
  v_nivel:=coalesce((p_item->>'nivel')::int,1);
  v_qtd:=coalesce((p_item->>'quantidade')::int,1);
  v_qual:=coalesce((p_item->>'qualidade')::int,0);
  v_nivel_enc:=coalesce((p_item->>'nivel_encantamento')::int,0);
 exception when others then return null;
 end;
 if t.empilhavel then
  if v_qtd not between 1 and 999 or (t.categoria='peixe' and v_qual not between 0 and 3) then return null; end if;
  return jsonb_build_object('id',t.tipo,'tipo',t.tipo,'categoria',t.categoria,'nivel',1,'raridade',v_rar,'duas_maos',false,
   'encantamento','','nivel_encantamento',0,'afixos','{}'::jsonb,'quantidade',v_qtd,'qualidade',case when t.categoria='peixe' then v_qual else 0 end);
 end if;
 if v_nivel not between 1 and 5 then return null; end if;
 v_enc:=coalesce(p_item->>'encantamento','');
 if v_enc<>'' and (not t.encantavel or v_enc not in ('fogo','gelo','raio','eletrico') or v_nivel_enc not between 1 and 3) then return null; end if;
 if v_enc='' then v_nivel_enc:=0; end if;
 -- Arma e escudo só recebem os afixos do próprio espaço; peças de armadura podem ter qualquer um (ascensão na bigorna)
 permitidos:=case t.categoria
  when 'arma' then array['critico','dano_critico','roubo_vida','velocidade','vitalidade']
  when 'escudo' then array['velocidade','vitalidade','defesa']
  else array['critico','dano_critico','roubo_vida','velocidade','vitalidade','defesa'] end;
 if p_item ? 'afixos' and jsonb_typeof(p_item->'afixos')<>'object' then return null; end if;
 for chave in select jsonb_object_keys(coalesce(p_item->'afixos','{}'::jsonb)) loop
  if not chave=any(permitidos) then return null; end if;
  if jsonb_typeof(p_item->'afixos'->chave)<>'number' then return null; end if;
  valor:=(p_item->'afixos'->>chave)::numeric;
  limite:=case chave when 'critico' then 0.065 when 'dano_critico' then 0.33 when 'roubo_vida' then 3
   when 'velocidade' then 10 when 'vitalidade' then 3 else 6 end;
  if valor<=0 or valor>limite then return null; end if;
  afixos:=afixos||jsonb_build_object(chave,valor);
 end loop;
 return jsonb_build_object('id',t.tipo,'tipo',t.tipo,'categoria',t.categoria,'nivel',v_nivel,'raridade',v_rar,'duas_maos',t.duas_maos,
  'encantamento',v_enc,'nivel_encantamento',v_nivel_enc,'afixos',afixos,'quantidade',1,'qualidade',0);
end $$;

drop function if exists public.mercado_anunciar(text,text,jsonb,int,int);
-- p_envio: código único gerado pelo jogo por anúncio. Repetir o mesmo envio devolve o anúncio já criado.
create or replace function public.mercado_anunciar(p_codigo text,p_apelido text,p_item jsonb,p_preco int,p_horas int,p_envio text)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare h text; c public.mercado_config%rowtype; nome text; item jsonb; novo bigint;
begin
 h:=public.mercado_hash(p_codigo);
 if p_envio is null or p_envio !~ '^[a-f0-9]{16,64}$' then return jsonb_build_object('erro','envio_invalido'); end if;
 select id into novo from public.mercado_anuncios where vendedor_hash=h and envio=p_envio;
 if found then return jsonb_build_object('ok',true,'id',novo,'repetido',true); end if;
 select * into c from public.mercado_config where id=1;
 if not c.ligado then return jsonb_build_object('erro','mercado_fechado'); end if;
 if exists(select 1 from public.mercado_banidos where codigo_hash=h) then return jsonb_build_object('erro','banido'); end if;
 item:=public.mercado_normalizar_item(p_item);
 if item is null then return jsonb_build_object('erro','item_invalido'); end if;
 if item->>'tipo'=any(c.tipos_bloqueados) then return jsonb_build_object('erro','item_bloqueado'); end if;
 if p_preco is null or p_preco not between c.preco_min and c.preco_max then return jsonb_build_object('erro','preco_invalido'); end if;
 if p_horas is null or not (p_horas=any(c.horas_permitidas)) then return jsonb_build_object('erro','prazo_invalido'); end if;
 perform pg_advisory_xact_lock(hashtext('mercado:'||h));
 perform public.mercado_expirar(h);
 if (select count(*) from public.mercado_anuncios where vendedor_hash=h and estado='aberto')>=c.max_anuncios then
  return jsonb_build_object('erro','limite_anuncios'); end if;
 if (select count(*) from public.mercado_anuncios where vendedor_hash=h and criado_em>now()-interval '1 day')>=c.max_anuncios_dia then
  return jsonb_build_object('erro','limite_diario'); end if;
 nome:=left(btrim(regexp_replace(coalesce(p_apelido,''),'[[:cntrl:]]','','g')),16);
 if nome='' or public.apelido_proibido(nome) then nome:='sem apelido'; end if;
 insert into public.mercado_anuncios(vendedor_hash,vendedor_apelido,item,tipo,categoria,raridade,nivel,preco,expira_em,envio)
  values(h,nome,item,item->>'tipo',item->>'categoria',item->>'raridade',(item->>'nivel')::int,p_preco,now()+make_interval(hours=>p_horas),p_envio)
  returning id into novo;
 return jsonb_build_object('ok',true,'id',novo,'taxa',c.taxa_anuncio);
end $$;

create or replace function public.mercado_comprar(p_codigo text,p_anuncio bigint,p_preco int)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare h text; c public.mercado_config%rowtype; a public.mercado_anuncios%rowtype; taxa int;
begin
 h:=public.mercado_hash(p_codigo);
 select * into c from public.mercado_config where id=1;
 if not c.ligado then return jsonb_build_object('erro','mercado_fechado'); end if;
 if exists(select 1 from public.mercado_banidos where codigo_hash=h) then return jsonb_build_object('erro','banido'); end if;
 select * into a from public.mercado_anuncios where id=p_anuncio for update;
 if not found or a.estado<>'aberto' or a.expira_em<=now() then return jsonb_build_object('erro','indisponivel'); end if;
 if a.vendedor_hash=h then return jsonb_build_object('erro','proprio_anuncio'); end if;
 if a.preco is distinct from p_preco then return jsonb_build_object('erro','preco_mudou'); end if;
 if (select count(*) from public.mercado_anuncios where comprador_hash=h and vendido_em>now()-interval '1 day')>=c.max_compras_dia then
  return jsonb_build_object('erro','limite_diario'); end if;
 taxa:=ceil(a.preco*c.taxa_venda_pct/100.0)::int;
 update public.mercado_anuncios set estado='vendido',comprador_hash=h,vendido_em=now() where id=a.id;
 insert into public.mercado_correio(dono_hash,item,motivo,anuncio_id) values(h,a.item,'compra',a.id);
 insert into public.mercado_correio(dono_hash,brasas,motivo,anuncio_id) values(a.vendedor_hash,a.preco-taxa,'venda',a.id);
 return jsonb_build_object('ok',true);
end $$;

-- O jogo caiu no meio de um anúncio: ele foi criado?
create or replace function public.mercado_anuncio_status(p_codigo text,p_envio text)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare h text; v_id bigint;
begin
 h:=public.mercado_hash(p_codigo);
 select id into v_id from public.mercado_anuncios where vendedor_hash=h and envio=p_envio;
 return jsonb_build_object('existe',found,'id',v_id);
end $$;

-- O jogo caiu no meio de uma compra: este jogador comprou o anúncio?
create or replace function public.mercado_compra_status(p_codigo text,p_anuncio bigint)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare h text;
begin
 h:=public.mercado_hash(p_codigo);
 return jsonb_build_object('comprado',exists(select 1 from public.mercado_anuncios where id=p_anuncio and comprador_hash=h));
end $$;

-- Quantas entregas esperam no correio (para o aviso fora da tela do mercado)
create or replace function public.mercado_correio_contar(p_codigo text)
returns int language plpgsql security definer set search_path=public,pg_temp as $$
declare h text;
begin
 h:=public.mercado_hash(p_codigo);
 perform public.mercado_expirar(h);
 return (select count(*) from public.mercado_correio where dono_hash=h);
end $$;

create or replace function public.mercado_regras() returns jsonb
language sql stable security definer set search_path=public,pg_temp as $$
 select jsonb_build_object('ligado',ligado,'taxa_anuncio',taxa_anuncio,'taxa_venda_pct',taxa_venda_pct,'preco_min',preco_min,
  'preco_max',preco_max,'max_anuncios',max_anuncios,'horas',to_jsonb(horas_permitidas),'bloqueados',to_jsonb(tipos_bloqueados),
  'max_anuncios_dia',max_anuncios_dia,'max_compras_dia',max_compras_dia)
 from public.mercado_config where id=1
$$;

-- O Supabase concede execução ao anon em toda função nova: revogar explicitamente antes de liberar as públicas
revoke all on function public.mercado_normalizar_item(jsonb) from public, anon, authenticated;
revoke all on function public.mercado_anunciar(text,text,jsonb,int,int,text) from public, anon, authenticated;
revoke all on function public.mercado_comprar(text,bigint,int) from public, anon, authenticated;
revoke all on function public.mercado_anuncio_status(text,text) from public, anon, authenticated;
revoke all on function public.mercado_compra_status(text,bigint) from public, anon, authenticated;
revoke all on function public.mercado_correio_contar(text) from public, anon, authenticated;
revoke all on function public.mercado_regras() from public, anon, authenticated;
grant execute on function public.mercado_anunciar(text,text,jsonb,int,int,text) to anon;
grant execute on function public.mercado_comprar(text,bigint,int) to anon;
grant execute on function public.mercado_anuncio_status(text,text) to anon;
grant execute on function public.mercado_compra_status(text,bigint) to anon;
grant execute on function public.mercado_correio_contar(text) to anon;
grant execute on function public.mercado_regras() to anon;
notify pgrst, 'reload schema';
commit;
