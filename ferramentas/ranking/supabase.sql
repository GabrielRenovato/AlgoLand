begin;
-- Instalação idempotente do ranking atual. Preserva jogadores e temporada existentes.
-- O reset autorizado está separado em temporada_inicial.sql: não reaplicar aquele arquivo.
-- A tabela fica fechada: o jogo só lê a visão pública e só grava pelas funções abaixo.

create table if not exists public.ranking (
  codigo_hash text primary key,
  apelido text not null check (char_length(apelido) between 1 and 16),
  andar int not null check (andar between 1 and 1000),
  aparencia jsonb,
  atualizado_em timestamptz not null default now()
);
alter table public.ranking add column if not exists aparencia jsonb;
drop index if exists public.ranking_apelido_unico;
alter table public.ranking drop constraint if exists ranking_apelido_check;
alter table public.ranking add constraint ranking_apelido_check check(char_length(apelido) between 1 and 16);
create index if not exists ranking_ordem on public.ranking (andar desc, atualizado_em asc);

-- Relógio do servidor: a partida só vale o tempo que realmente passou desde que ela começou.
create table if not exists public.ranking_partidas (
  codigo_hash text primary key,
  inicio timestamptz not null default now(),
  andar_inicial int not null check (andar_inicial between 1 and 1000)
);

alter table public.ranking enable row level security;
alter table public.ranking_partidas enable row level security;
revoke all on public.ranking from anon, authenticated;
revoke all on public.ranking_partidas from anon, authenticated;

alter table public.ranking add column if not exists armas_usadas jsonb not null default '{}'::jsonb;
alter table public.ranking add column if not exists arma_mais_usada text not null default '';
create table if not exists public.ranking_configuracao (
  id boolean primary key default true check(id),
  temporada int not null check(temporada>0)
);
insert into public.ranking_configuracao(id,temporada) values(true,1)
  on conflict(id) do nothing;
alter table public.ranking_configuracao enable row level security;
revoke all on public.ranking_configuracao from anon,authenticated;
alter table public.ranking add column if not exists temporada int not null default 0;
alter table public.ranking_partidas add column if not exists temporada int not null default 0;
-- Filtro de apelidos: minúsculas, números parecidos viram letras (0→o, 1→i, 3→e, 4→a, 5→s, 7→t, 8→b),
-- sem "_" e sem letras repetidas. Os termos abaixo já estão sem repetição ("porra" vira "pora").
-- Termos longos valem em qualquer parte do nome; os curtos só quando o apelido inteiro é igual.
create or replace function public.apelido_proibido(p_apelido text)
returns boolean language sql immutable set search_path=public,pg_temp as $$
  with n as (
    select regexp_replace(
      regexp_replace(translate(lower(p_apelido), '0134578_', 'oieastb'), '[^a-z]', '', 'g'),
      '(.)\1+', '\1', 'g') as t
  )
  select exists (
    select 1 from n, unnest(array[
      'caralho','pora','buceta','foder','fodase','fodido','puta','merda','viado','arombado','cuzao',
      'cuzinho','punheta','xereca','piroca','cacete','estupr','pedofil','nazi','hitler','fuck','shit',
      'bitch','cunt','nigga','fagot','ashole','whore','slut','porn','sexo','pussy','dick'
    ]) as termo where n.t like '%' || termo || '%'
  ) or exists (
    select 1 from n where n.t = any(array[
      'cu','pau','rola','pica','xota','cock','niga','niger','mongol','retardado','fdp','pqp','vsf','vtnc','tnc','bosta'
    ])
  );
$$;

create or replace view public.ranking_publico as
  select apelido,andar,atualizado_em,aparencia,arma_mais_usada,temporada from public.ranking
  where temporada=(select temporada from public.ranking_configuracao where id=true);
grant select on public.ranking_publico to anon;

create or replace function public.iniciar_partida_ranking(p_codigo text,p_andar_inicial int,p_temporada int)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare v_hash text; v_melhor int; v_inicial int;
begin
  if p_temporada is distinct from (select temporada from public.ranking_configuracao where id=true) then raise exception 'temporada_invalida'; end if;
  if p_codigo is null or char_length(p_codigo)<24 then raise exception 'codigo_invalido'; end if;
  v_hash:=encode(sha256(convert_to(p_codigo,'UTF8')),'hex');
  select andar into v_melhor from public.ranking where codigo_hash=v_hash and temporada=p_temporada;
  v_inicial:=greatest(1,least(p_andar_inicial,coalesce(v_melhor,1)));
  insert into public.ranking_partidas(codigo_hash,inicio,andar_inicial,temporada) values(v_hash,now(),v_inicial,p_temporada)
    on conflict(codigo_hash) do update set inicio=now(),andar_inicial=v_inicial,temporada=p_temporada;
end $$;

create or replace function public.enviar_pontuacao_ranking(p_codigo text,p_apelido text,p_andar int,p_temporada int)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare v_hash text; v_anterior int; v_partida public.ranking_partidas%rowtype; v_limite int; v_andar int;
begin
  if p_temporada is distinct from (select temporada from public.ranking_configuracao where id=true) then raise exception 'temporada_invalida'; end if;
  if p_codigo is null or char_length(p_codigo)<24 then raise exception 'codigo_invalido'; end if;
  p_apelido:=left(btrim(regexp_replace(coalesce(p_apelido,''),'[[:cntrl:]]','','g')),16);
  if p_apelido='' or public.apelido_proibido(p_apelido) then p_apelido:='sem apelido'; end if;
  if p_andar is null or p_andar<1 then raise exception 'andar_invalido'; end if;
  v_hash:=encode(sha256(convert_to(p_codigo,'UTF8')),'hex');
  select andar into v_anterior from public.ranking where codigo_hash=v_hash and temporada=p_temporada;
  select * into v_partida from public.ranking_partidas where codigo_hash=v_hash and temporada=p_temporada;
  if found then v_limite:=v_partida.andar_inicial+1+floor(extract(epoch from now()-v_partida.inicio)/20)::int;
  else v_limite:=coalesce(v_anterior,0)+3; end if;
  v_andar:=greatest(1,least(p_andar,v_limite,1000));
  insert into public.ranking(codigo_hash,apelido,andar,temporada) values(v_hash,p_apelido,v_andar,p_temporada)
    on conflict(codigo_hash) do update set apelido=excluded.apelido,
      andar=case when ranking.temporada=excluded.temporada then greatest(ranking.andar,excluded.andar) else excluded.andar end,
      atualizado_em=case when ranking.temporada<>excluded.temporada or excluded.andar>ranking.andar then now() else ranking.atualizado_em end,
      aparencia=case when ranking.temporada=excluded.temporada then ranking.aparencia else null end,
      armas_usadas=case when ranking.temporada=excluded.temporada then ranking.armas_usadas else '{}'::jsonb end,
      arma_mais_usada=case when ranking.temporada=excluded.temporada then ranking.arma_mais_usada else '' end,
      temporada=excluded.temporada;
end $$;

create or replace function public.atualizar_perfil_ranking(p_codigo text, p_aparencia jsonb, p_armas_usadas jsonb,p_temporada int)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_hash text;
  v_total jsonb;
  v_arma text;
  v_contagem bigint;
  v_favorita text;
  v_permitidas constant text[] := array['arco_curto','arco_curvo','arco_longo','espada_basica','espada_gemea','lanca_basica','maca','machado'];
begin
  if p_temporada is distinct from (select temporada from public.ranking_configuracao where id=true) then raise exception 'temporada_invalida'; end if;
  if p_codigo is null or char_length(p_codigo)<24 then raise exception 'codigo_invalido'; end if;
  if p_aparencia is not null and (jsonb_typeof(p_aparencia)<>'object' or octet_length(p_aparencia::text)>4096) then
    raise exception 'aparencia_invalida';
  end if;
  if p_armas_usadas is null or jsonb_typeof(p_armas_usadas)<>'object' or octet_length(p_armas_usadas::text)>2048 then
    raise exception 'armas_invalidas';
  end if;
  if exists(select 1 from jsonb_object_keys(p_armas_usadas) as t(arma) where not (arma=any(v_permitidas))) then
    raise exception 'armas_invalidas';
  end if;
  v_hash := encode(sha256(convert_to(p_codigo,'UTF8')),'hex');
  select armas_usadas into v_total from public.ranking where codigo_hash=v_hash and temporada=p_temporada for update;
  if not found then raise exception 'jogador_fora_do_ranking'; end if;
  foreach v_arma in array v_permitidas loop
    if p_armas_usadas ? v_arma then
      if jsonb_typeof(p_armas_usadas->v_arma)<>'number' or (p_armas_usadas->>v_arma) !~ '^[0-9]{1,10}$' then
        raise exception 'armas_invalidas';
      end if;
      v_contagem := (p_armas_usadas->>v_arma)::bigint;
      if v_contagem>1000000000 then raise exception 'armas_invalidas'; end if;
      -- Repetir a mesma fotografia não soma golpes novamente nem reduz contagens anteriores.
      v_contagem := greatest(v_contagem,coalesce((v_total->>v_arma)::bigint,0));
      if v_contagem>0 then v_total := jsonb_set(v_total,array[v_arma],to_jsonb(v_contagem)); end if;
    end if;
  end loop;
  select key into v_favorita from jsonb_each_text(v_total)
    where value::bigint>0 order by value::bigint desc,key asc limit 1;
  v_favorita := coalesce(v_favorita,'');
  update public.ranking set armas_usadas=v_total,arma_mais_usada=v_favorita,
    aparencia=coalesce(nullif(p_aparencia,'{}'::jsonb),aparencia) where codigo_hash=v_hash;
  return jsonb_build_object('armas_usadas',v_total,'arma_mais_usada',v_favorita);
end $$;

create or replace function public.iniciar_partida(p_codigo text,p_andar_inicial int) returns void language plpgsql security definer set search_path=public,pg_temp as $$ begin raise exception 'atualize_o_jogo'; end $$;

create or replace function public.enviar_pontuacao(p_codigo text,p_apelido text,p_andar int) returns void language plpgsql security definer set search_path=public,pg_temp as $$ begin raise exception 'atualize_o_jogo'; end $$;

create or replace function public.atualizar_aparencia_ranking(p_codigo text,p_aparencia jsonb) returns void language plpgsql security definer set search_path=public,pg_temp as $$ begin raise exception 'atualize_o_jogo'; end $$;

create or replace function public.atualizar_perfil_ranking(p_codigo text,p_aparencia jsonb,p_armas_usadas jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$ begin raise exception 'atualize_o_jogo'; end $$;

revoke all on function public.iniciar_partida_ranking(text,int,int) from public;
grant execute on function public.iniciar_partida_ranking(text,int,int) to anon;

revoke all on function public.enviar_pontuacao_ranking(text,text,int,int) from public;
grant execute on function public.enviar_pontuacao_ranking(text,text,int,int) to anon;

revoke all on function public.atualizar_perfil_ranking(text,jsonb,jsonb,int) from public;
grant execute on function public.atualizar_perfil_ranking(text,jsonb,jsonb,int) to anon;

notify pgrst,'reload schema';
commit;
