-- Uso acumulado por identidade do ranking. Sem tabela/evento por golpe e sem recurso pago.
begin;
alter table public.ranking add column if not exists armas_usadas jsonb not null default '{}'::jsonb;
alter table public.ranking add column if not exists arma_mais_usada text not null default '';
create or replace view public.ranking_publico as
  select apelido, andar, atualizado_em, aparencia, arma_mais_usada from public.ranking;
grant select on public.ranking_publico to anon;

create or replace function public.atualizar_perfil_ranking(p_codigo text, p_aparencia jsonb, p_armas_usadas jsonb)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_hash text;
  v_total jsonb;
  v_arma text;
  v_contagem bigint;
  v_favorita text;
  v_permitidas constant text[] := array['arco_curto','arco_curvo','arco_longo','espada_basica','espada_gemea','lanca_basica','maca','machado'];
begin
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
  select armas_usadas into v_total from public.ranking where codigo_hash=v_hash for update;
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
revoke all on function public.atualizar_perfil_ranking(text,jsonb,jsonb) from public;
grant execute on function public.atualizar_perfil_ranking(text,jsonb,jsonb) to anon;
notify pgrst,'reload schema';
commit;
