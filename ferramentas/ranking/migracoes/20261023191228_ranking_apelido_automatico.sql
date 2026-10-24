-- Identidade é o código secreto por player; apelido é o nome do personagem, não um cadastro.
-- Não limpa pontuações, perfis, contagens ou temporadas existentes.
begin;
drop index if exists public.ranking_apelido_unico;
alter table public.ranking drop constraint if exists ranking_apelido_check;
alter table public.ranking add constraint ranking_apelido_check check(char_length(apelido) between 1 and 16);
alter function public.apelido_proibido(text) set search_path=public,pg_temp;
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

revoke all on function public.enviar_pontuacao_ranking(text,text,int,int) from public;
grant execute on function public.enviar_pontuacao_ranking(text,text,int,int) to anon;
notify pgrst,'reload schema';
commit;
