-- Save na nuvem (fase 2). Um save por conta, com controle de revisão: quem grava informa a revisão que conhece;
-- se outro aparelho gravou antes, a função devolve 'conflito' em vez de sobrescrever. A versão anterior fica guardada (desfazer).
-- Depende de 20261029200000_conta.sql. Aplicar no SQL Editor do Supabase.

create table if not exists public.saves_nuvem (
  id uuid primary key references auth.users(id) on delete cascade,
  rev integer not null default 1,
  pacote text not null,
  versao_app text not null default '',
  versao_save integer not null default 0,
  aparelho text not null default '',
  tamanho integer not null default 0,
  atualizado_em timestamptz not null default now(),
  pacote_anterior text,
  rev_anterior integer,
  anterior_em timestamptz
);
alter table public.saves_nuvem enable row level security;
-- Sem políticas: ninguém lê nem grava direto; tudo passa pelas funções abaixo (security definer, sempre auth.uid()).
revoke all on public.saves_nuvem from anon, authenticated;

create or replace function public.meta_nuvem()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare s public.saves_nuvem%rowtype;
begin
  if auth.uid() is null then return jsonb_build_object('estado', 'sem_login'); end if;
  select * into s from public.saves_nuvem where id = auth.uid();
  if not found then return jsonb_build_object('estado', 'ok', 'existe', false); end if;
  return jsonb_build_object('estado', 'ok', 'existe', true, 'rev', s.rev, 'atualizado_em', s.atualizado_em,
    'aparelho', s.aparelho, 'versao_app', s.versao_app, 'versao_save', s.versao_save, 'tamanho', s.tamanho,
    'tem_anterior', s.pacote_anterior is not null);
end;
$$;

create or replace function public.salvar_nuvem(p_pacote text, p_rev_esperada integer, p_versao_app text, p_versao_save integer, p_aparelho text default '')
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  usuario uuid := auth.uid();
  s public.saves_nuvem%rowtype;
  tam integer := octet_length(coalesce(p_pacote, ''));
begin
  if usuario is null then return jsonb_build_object('estado', 'sem_login'); end if;
  if tam < 2 or tam > 1500000 then return jsonb_build_object('estado', 'tamanho_invalido'); end if;
  if p_versao_save is null or p_versao_save < 1 then return jsonb_build_object('estado', 'versao_invalida'); end if;
  select * into s from public.saves_nuvem where id = usuario for update;
  if not found then
    if coalesce(p_rev_esperada, 0) <> 0 then return jsonb_build_object('estado', 'conflito', 'rev', 0); end if;
    insert into public.saves_nuvem (id, rev, pacote, versao_app, versao_save, aparelho, tamanho)
    values (usuario, 1, p_pacote, left(coalesce(p_versao_app, ''), 32), p_versao_save, left(coalesce(p_aparelho, ''), 40), tam);
    return jsonb_build_object('estado', 'ok', 'rev', 1);
  end if;
  if coalesce(p_rev_esperada, -1) <> s.rev then
    return jsonb_build_object('estado', 'conflito', 'rev', s.rev, 'atualizado_em', s.atualizado_em, 'aparelho', s.aparelho);
  end if;
  if now() - s.atualizado_em < interval '15 seconds' then return jsonb_build_object('estado', 'rapido'); end if;
  update public.saves_nuvem
     set pacote_anterior = s.pacote, rev_anterior = s.rev, anterior_em = s.atualizado_em,
         pacote = p_pacote, rev = s.rev + 1, versao_app = left(coalesce(p_versao_app, ''), 32), versao_save = p_versao_save,
         aparelho = left(coalesce(p_aparelho, ''), 40), tamanho = tam, atualizado_em = now()
   where id = usuario;
  return jsonb_build_object('estado', 'ok', 'rev', s.rev + 1);
end;
$$;

create or replace function public.baixar_nuvem(p_anterior boolean default false)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare s public.saves_nuvem%rowtype;
begin
  if auth.uid() is null then return jsonb_build_object('estado', 'sem_login'); end if;
  select * into s from public.saves_nuvem where id = auth.uid();
  if not found then return jsonb_build_object('estado', 'ok', 'existe', false); end if;
  if p_anterior then
    if s.pacote_anterior is null then return jsonb_build_object('estado', 'ok', 'existe', false); end if;
    return jsonb_build_object('estado', 'ok', 'existe', true, 'rev', s.rev, 'pacote', s.pacote_anterior, 'atualizado_em', s.anterior_em,
      'versao_app', s.versao_app, 'versao_save', s.versao_save, 'aparelho', s.aparelho);
  end if;
  return jsonb_build_object('estado', 'ok', 'existe', true, 'rev', s.rev, 'pacote', s.pacote, 'atualizado_em', s.atualizado_em,
    'versao_app', s.versao_app, 'versao_save', s.versao_save, 'aparelho', s.aparelho);
end;
$$;

-- Quem escolhe manter o save deste aparelho leva também o código dele: a conta passa a apontar para ele.
create or replace function public.trocar_codigo_conta(p_codigo text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then return jsonb_build_object('estado', 'sem_login'); end if;
  if p_codigo is null or char_length(p_codigo) < 24 or char_length(p_codigo) > 64 then return jsonb_build_object('estado', 'codigo_invalido'); end if;
  if not exists (select 1 from public.perfis where id = auth.uid()) then return jsonb_build_object('estado', 'sem_perfil'); end if;
  if exists (select 1 from public.perfis where codigo_secreto = p_codigo and id <> auth.uid()) then return jsonb_build_object('estado', 'codigo_em_uso'); end if;
  update public.perfis set codigo_secreto = p_codigo where id = auth.uid();
  return jsonb_build_object('estado', 'ok');
end;
$$;

revoke all on function public.meta_nuvem() from public, anon;
revoke all on function public.salvar_nuvem(text, integer, text, integer, text) from public, anon;
revoke all on function public.baixar_nuvem(boolean) from public, anon;
revoke all on function public.trocar_codigo_conta(text) from public, anon;
grant execute on function public.meta_nuvem() to authenticated;
grant execute on function public.salvar_nuvem(text, integer, text, integer, text) to authenticated;
grant execute on function public.baixar_nuvem(boolean) to authenticated;
grant execute on function public.trocar_codigo_conta(text) to authenticated;
