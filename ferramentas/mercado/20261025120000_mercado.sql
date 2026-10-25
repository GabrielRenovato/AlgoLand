-- Mercado entre jogadores (estilo casa de leilões): anúncios com preço fixo em Brasas, prazo e correio.
-- Tabelas fechadas; o jogo só usa as funções abaixo, autenticadas pelo código secreto (sha256), como no ranking.
-- As Brasas ficam no save do jogador: o jogo desconta antes de comprar/anunciar e devolve se a função falhar.
-- Depende de public.apelido_proibido (ferramentas/ranking/supabase.sql).
begin;

create table if not exists public.mercado_config (
 id int primary key default 1 check (id=1),
 ligado boolean not null default true,
 taxa_anuncio int not null default 1,
 taxa_venda_pct int not null default 10 check (taxa_venda_pct between 0 and 90),
 preco_min int not null default 1,
 preco_max int not null default 9999,
 max_anuncios int not null default 5,
 horas_permitidas int[] not null default '{24,48}',
 tipos_bloqueados text[] not null default '{}'
);
insert into public.mercado_config(id) values(1) on conflict do nothing;

create table if not exists public.mercado_anuncios (
 id bigint generated always as identity primary key,
 vendedor_hash text not null,
 vendedor_apelido text not null,
 item jsonb not null,
 tipo text not null,
 categoria text not null,
 raridade text not null,
 nivel int not null,
 preco int not null,
 estado text not null default 'aberto' check (estado in ('aberto','vendido','cancelado','expirado')),
 criado_em timestamptz not null default now(),
 expira_em timestamptz not null,
 comprador_hash text,
 vendido_em timestamptz
);
create index if not exists mercado_anuncios_busca on public.mercado_anuncios(estado,categoria,raridade,preco);
create index if not exists mercado_anuncios_vendedor on public.mercado_anuncios(vendedor_hash,estado);

create table if not exists public.mercado_correio (
 id bigint generated always as identity primary key,
 dono_hash text not null,
 brasas int not null default 0,
 item jsonb,
 motivo text not null check (motivo in ('venda','compra','devolvido','cancelado')),
 anuncio_id bigint,
 criado_em timestamptz not null default now()
);
create index if not exists mercado_correio_dono on public.mercado_correio(dono_hash);

alter table public.mercado_config enable row level security;
alter table public.mercado_anuncios enable row level security;
alter table public.mercado_correio enable row level security;
revoke all on public.mercado_config, public.mercado_anuncios, public.mercado_correio from public, anon, authenticated;

create or replace function public.mercado_hash(p_codigo text) returns text
language plpgsql immutable set search_path=public,pg_temp as $$
begin
 if p_codigo is null or length(p_codigo) not between 24 and 128 then raise exception 'codigo_invalido'; end if;
 return encode(sha256(convert_to(p_codigo,'UTF8')),'hex');
end $$;

-- Anúncios vencidos de um vendedor voltam para o correio dele (sem tarefa agendada).
create or replace function public.mercado_expirar(p_hash text) returns void
language plpgsql security definer set search_path=public,pg_temp as $$
begin
 with vencidos as (
  update public.mercado_anuncios set estado='expirado'
   where vendedor_hash=p_hash and estado='aberto' and expira_em<=now()
   returning id,item)
 insert into public.mercado_correio(dono_hash,item,motivo,anuncio_id)
  select p_hash,item,'devolvido',id from vencidos;
end $$;

-- Limites atuais, para o jogo mostrar taxa, prazos e preços sem lançar versão.
create or replace function public.mercado_regras() returns jsonb
language sql stable security definer set search_path=public,pg_temp as $$
 select jsonb_build_object('ligado',ligado,'taxa_anuncio',taxa_anuncio,'taxa_venda_pct',taxa_venda_pct,'preco_min',preco_min,
  'preco_max',preco_max,'max_anuncios',max_anuncios,'horas',to_jsonb(horas_permitidas),'bloqueados',to_jsonb(tipos_bloqueados))
 from public.mercado_config where id=1
$$;

create or replace function public.mercado_anunciar(p_codigo text,p_apelido text,p_item jsonb,p_preco int,p_horas int)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare h text; c public.mercado_config%rowtype; nome text; v_tipo text; v_cat text; v_rar text; v_nivel int; v_qtd int; novo bigint;
begin
 h:=public.mercado_hash(p_codigo);
 select * into c from public.mercado_config where id=1;
 if not c.ligado then return jsonb_build_object('erro','mercado_fechado'); end if;
 if p_item is null or jsonb_typeof(p_item)<>'object' or octet_length(p_item::text)>2048 then return jsonb_build_object('erro','item_invalido'); end if;
 v_tipo:=p_item->>'tipo'; v_cat:=coalesce(p_item->>'categoria',''); v_rar:=p_item->>'raridade';
 if v_tipo is null or v_tipo !~ '^[a-z0-9_]+(:[a-z0-9_]+)?$' or length(v_tipo)>48 or v_cat !~ '^[a-z0-9_]{0,24}$'
  or v_rar is null or v_rar not in ('comum','incomum','raro','epico','lendario') then return jsonb_build_object('erro','item_invalido'); end if;
 begin
  v_nivel:=coalesce((p_item->>'nivel')::int,1); v_qtd:=coalesce((p_item->>'quantidade')::int,1);
 exception when others then return jsonb_build_object('erro','item_invalido');
 end;
 if v_nivel not between 1 and 50 or v_qtd not between 1 and 999 then return jsonb_build_object('erro','item_invalido'); end if;
 if v_tipo=any(c.tipos_bloqueados) then return jsonb_build_object('erro','item_bloqueado'); end if;
 if p_preco is null or p_preco not between c.preco_min and c.preco_max then return jsonb_build_object('erro','preco_invalido'); end if;
 if p_horas is null or not (p_horas=any(c.horas_permitidas)) then return jsonb_build_object('erro','prazo_invalido'); end if;
 -- Trava por vendedor: dois anúncios simultâneos não furam o limite
 perform pg_advisory_xact_lock(hashtext('mercado:'||h));
 perform public.mercado_expirar(h);
 if (select count(*) from public.mercado_anuncios where vendedor_hash=h and estado='aberto')>=c.max_anuncios then
  return jsonb_build_object('erro','limite_anuncios'); end if;
 nome:=left(btrim(regexp_replace(coalesce(p_apelido,''),'[[:cntrl:]]','','g')),16);
 if nome='' or public.apelido_proibido(nome) then nome:='sem apelido'; end if;
 insert into public.mercado_anuncios(vendedor_hash,vendedor_apelido,item,tipo,categoria,raridade,nivel,preco,expira_em)
  values(h,nome,p_item,v_tipo,v_cat,v_rar,v_nivel,p_preco,now()+make_interval(hours=>p_horas))
  returning id into novo;
 return jsonb_build_object('ok',true,'id',novo,'taxa',c.taxa_anuncio);
end $$;

-- Filtros opcionais: categoria, tipo, raridade, preco_max, nivel_min. Ordem: barato, caro ou novo. 20 por página.
create or replace function public.mercado_buscar(p_filtros jsonb default '{}',p_pagina int default 0)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare f jsonb:=coalesce(p_filtros,'{}'); ordem text:=coalesce(p_filtros->>'ordem','barato'); lista jsonb; pagina int:=greatest(0,least(coalesce(p_pagina,0),500));
begin
 if jsonb_typeof(f)<>'object' or octet_length(f::text)>512 then raise exception 'filtro_invalido'; end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',a.id,'vendedor',a.vendedor_apelido,'item',a.item,'preco',a.preco,'expira_em',a.expira_em)),'[]') into lista from (
  select * from public.mercado_anuncios
   where estado='aberto' and expira_em>now()
    and (f->>'categoria' is null or categoria=f->>'categoria')
    and (f->>'tipo' is null or tipo=f->>'tipo')
    and (f->>'raridade' is null or raridade=f->>'raridade')
    and (f->>'preco_max' is null or preco<=(f->>'preco_max')::int)
    and (f->>'nivel_min' is null or nivel>=(f->>'nivel_min')::int)
   order by case when ordem='caro' then -preco when ordem='barato' then preco else 0 end,
    case when ordem='novo' then -extract(epoch from criado_em) else 0 end, id
   limit 21 offset pagina*20) a;
 -- Pede 21 para saber se existe próxima página sem contar a tabela
 return jsonb_build_object('anuncios',coalesce((select jsonb_agg(e) from (select e from jsonb_array_elements(lista) e limit 20) x),'[]'),
  'mais',jsonb_array_length(lista)>20);
end $$;

-- p_preco é o preço que o jogador viu e já descontou; diferente disso, a compra é recusada.
create or replace function public.mercado_comprar(p_codigo text,p_anuncio bigint,p_preco int)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare h text; c public.mercado_config%rowtype; a public.mercado_anuncios%rowtype; taxa int;
begin
 h:=public.mercado_hash(p_codigo);
 select * into c from public.mercado_config where id=1;
 if not c.ligado then return jsonb_build_object('erro','mercado_fechado'); end if;
 select * into a from public.mercado_anuncios where id=p_anuncio for update;
 if not found or a.estado<>'aberto' or a.expira_em<=now() then return jsonb_build_object('erro','indisponivel'); end if;
 if a.vendedor_hash=h then return jsonb_build_object('erro','proprio_anuncio'); end if;
 if a.preco is distinct from p_preco then return jsonb_build_object('erro','preco_mudou'); end if;
 taxa:=ceil(a.preco*c.taxa_venda_pct/100.0)::int;
 update public.mercado_anuncios set estado='vendido',comprador_hash=h,vendido_em=now() where id=a.id;
 insert into public.mercado_correio(dono_hash,item,motivo,anuncio_id) values(h,a.item,'compra',a.id);
 insert into public.mercado_correio(dono_hash,brasas,motivo,anuncio_id) values(a.vendedor_hash,a.preco-taxa,'venda',a.id);
 return jsonb_build_object('ok',true);
end $$;

create or replace function public.mercado_cancelar(p_codigo text,p_anuncio bigint)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare h text; a public.mercado_anuncios%rowtype;
begin
 h:=public.mercado_hash(p_codigo);
 select * into a from public.mercado_anuncios where id=p_anuncio and vendedor_hash=h for update;
 if not found or a.estado<>'aberto' then return jsonb_build_object('erro','indisponivel'); end if;
 update public.mercado_anuncios set estado='cancelado' where id=a.id;
 insert into public.mercado_correio(dono_hash,item,motivo,anuncio_id) values(h,a.item,'cancelado',a.id);
 return jsonb_build_object('ok',true);
end $$;

-- Anúncios do jogador nos últimos 7 dias (abertos sempre aparecem)
create or replace function public.mercado_meus(p_codigo text)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare h text;
begin
 h:=public.mercado_hash(p_codigo);
 perform public.mercado_expirar(h);
 return coalesce((select jsonb_agg(jsonb_build_object('id',id,'item',item,'preco',preco,'estado',estado,'expira_em',expira_em,'vendido_em',vendido_em) order by id desc)
  from public.mercado_anuncios where vendedor_hash=h and (estado='aberto' or criado_em>now()-interval '7 days')),'[]');
end $$;

-- Retirada em duas etapas: retirar lista sem apagar; o jogo grava o save (guardando os ids aplicados) e depois confirma.
-- Se cair entre as duas, a próxima retirada repete os mesmos ids e o jogo ignora os que já aplicou.
create or replace function public.mercado_correio_retirar(p_codigo text)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare h text;
begin
 h:=public.mercado_hash(p_codigo);
 perform public.mercado_expirar(h);
 return coalesce((select jsonb_agg(jsonb_build_object('id',id,'brasas',brasas,'item',item,'motivo',motivo,'anuncio',anuncio_id) order by id)
  from (select * from public.mercado_correio where dono_hash=h order by id limit 50) x),'[]');
end $$;

create or replace function public.mercado_correio_confirmar(p_codigo text,p_ids bigint[])
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare h text; n int;
begin
 h:=public.mercado_hash(p_codigo);
 if p_ids is null or cardinality(p_ids)>50 then raise exception 'ids_invalidos'; end if;
 delete from public.mercado_correio where dono_hash=h and id=any(p_ids);
 get diagnostics n=row_count;
 return jsonb_build_object('ok',true,'apagados',n);
end $$;

-- O Supabase concede execução ao anon em toda função nova: revogar explicitamente antes de liberar as públicas
revoke all on function public.mercado_hash(text) from public, anon, authenticated;
revoke all on function public.mercado_expirar(text) from public, anon, authenticated;
revoke all on function public.mercado_regras() from public, anon, authenticated;
revoke all on function public.mercado_anunciar(text,text,jsonb,int,int) from public, anon, authenticated;
revoke all on function public.mercado_buscar(jsonb,int) from public, anon, authenticated;
revoke all on function public.mercado_comprar(text,bigint,int) from public, anon, authenticated;
revoke all on function public.mercado_cancelar(text,bigint) from public, anon, authenticated;
revoke all on function public.mercado_meus(text) from public, anon, authenticated;
revoke all on function public.mercado_correio_retirar(text) from public, anon, authenticated;
revoke all on function public.mercado_correio_confirmar(text,bigint[]) from public, anon, authenticated;
grant execute on function public.mercado_regras() to anon;
grant execute on function public.mercado_anunciar(text,text,jsonb,int,int) to anon;
grant execute on function public.mercado_buscar(jsonb,int) to anon;
grant execute on function public.mercado_comprar(text,bigint,int) to anon;
grant execute on function public.mercado_cancelar(text,bigint) to anon;
grant execute on function public.mercado_meus(text) to anon;
grant execute on function public.mercado_correio_retirar(text) to anon;
grant execute on function public.mercado_correio_confirmar(text,bigint[]) to anon;
notify pgrst, 'reload schema';
commit;
