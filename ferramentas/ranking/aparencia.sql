-- Preparação do pódio: executar DEPOIS de supabase.sql no SQL Editor do mesmo projeto.
-- Preserva pontuações, desempate, apelidos e clientes antigos. Não publica o código/hash.
begin;

alter table public.ranking add column if not exists aparencia jsonb;

-- Acrescentar ao fim mantém as colunas já consumidas pelo jogo.
create or replace view public.ranking_publico as
  select apelido, andar, atualizado_em, aparencia from public.ranking;
grant select on public.ranking_publico to anon;

-- Atualizar o visual nunca altera pontuação nem a data usada para desempate.
-- O jogo deve enviar somente ids de catálogo e cores, nunca caminhos de recursos ou o save.
create or replace function public.atualizar_aparencia_ranking(p_codigo text, p_aparencia jsonb)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_hash text;
begin
  if p_codigo is null or char_length(p_codigo) < 24 then
    raise exception 'codigo_invalido';
  end if;
  if p_aparencia is null or jsonb_typeof(p_aparencia) <> 'object'
      or octet_length(p_aparencia::text) > 4096 then
    raise exception 'aparencia_invalida';
  end if;
  v_hash := encode(sha256(convert_to(p_codigo, 'UTF8')), 'hex');
  update public.ranking set aparencia = p_aparencia where codigo_hash = v_hash;
  if not found then raise exception 'jogador_fora_do_ranking'; end if;
end $$;
revoke all on function public.atualizar_aparencia_ranking(text, jsonb) from public;
grant execute on function public.atualizar_aparencia_ranking(text, jsonb) to anon;

notify pgrst, 'reload schema';
commit;
