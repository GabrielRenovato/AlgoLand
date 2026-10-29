-- Conta do jogador (fase 1): o perfil guarda o código secreto que o jogo já usa no ranking e no mercado.
-- Quem já joga vincula o código atual à conta nova e não perde o progresso; em outro aparelho, a conta devolve o mesmo código.
-- Aplicar no SQL Editor do Supabase. A autenticação (e-mail e senha) é o Supabase Auth, sem tabelas próprias.

create table if not exists public.perfis (
  id uuid primary key references auth.users(id) on delete cascade,
  apelido text not null default 'JOGADOR' check (char_length(apelido) between 1 and 24),
  codigo_secreto text not null unique check (char_length(codigo_secreto) between 24 and 64),
  criado_em timestamptz not null default now()
);
alter table public.perfis enable row level security;

-- O dono lê o próprio perfil; ninguém grava direto (só pelas funções abaixo).
drop policy if exists perfis_dono_le on public.perfis;
create policy perfis_dono_le on public.perfis for select using (auth.uid() = id);
revoke all on public.perfis from anon, authenticated;
grant select on public.perfis to authenticated;

-- Liga o código do aparelho à conta, ou devolve o que a conta já tem.
-- 'ok' = vinculado agora ou já era o mesmo; 'outro_codigo' = a conta já tem outro (o cliente decide: nuvem na fase 2);
-- 'codigo_em_uso' = esse código pertence a outra conta.
create or replace function public.vincular_conta(p_codigo text, p_apelido text default 'JOGADOR')
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  usuario uuid := auth.uid();
  atual public.perfis%rowtype;
  apelido_limpo text := left(regexp_replace(coalesce(nullif(trim(p_apelido), ''), 'JOGADOR'), '[\r\n\t]', ' ', 'g'), 24);
begin
  if usuario is null then
    return jsonb_build_object('estado', 'sem_login');
  end if;
  if p_codigo is null or char_length(p_codigo) < 24 or char_length(p_codigo) > 64 then
    return jsonb_build_object('estado', 'codigo_invalido');
  end if;
  select * into atual from public.perfis where id = usuario;
  if found then
    if atual.codigo_secreto = p_codigo then
      return jsonb_build_object('estado', 'ok', 'apelido', atual.apelido);
    end if;
    return jsonb_build_object('estado', 'outro_codigo', 'codigo_secreto', atual.codigo_secreto, 'apelido', atual.apelido);
  end if;
  if exists (select 1 from public.perfis where codigo_secreto = p_codigo) then
    return jsonb_build_object('estado', 'codigo_em_uso');
  end if;
  insert into public.perfis (id, apelido, codigo_secreto) values (usuario, apelido_limpo, p_codigo);
  return jsonb_build_object('estado', 'ok', 'apelido', apelido_limpo);
end;
$$;
revoke all on function public.vincular_conta(text, text) from public, anon;
grant execute on function public.vincular_conta(text, text) to authenticated;

-- Troca de apelido pela conta (o ranking continua usando o código).
create or replace function public.mudar_apelido(p_apelido text)
returns void
language sql
security definer
set search_path = public
as $$
  update public.perfis
     set apelido = left(regexp_replace(coalesce(nullif(trim(p_apelido), ''), 'JOGADOR'), '[\r\n\t]', ' ', 'g'), 24)
   where id = auth.uid();
$$;
revoke all on function public.mudar_apelido(text) from public, anon;
grant execute on function public.mudar_apelido(text) to authenticated;
