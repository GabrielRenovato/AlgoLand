-- Amigos e convites (fase 3). Cada perfil ganha um código de amigo curto (ex.: K7P4QX) para compartilhar; ninguém vê o id da conta de ninguém.
-- Convite de sala vale por 5 minutos e só entre amigos. Tudo por funções (security definer, sempre auth.uid()). Depende de 20261029200000_conta.sql.

alter table public.perfis add column if not exists codigo_amigo text unique;

create table if not exists public.amizades (
  a uuid not null references auth.users(id) on delete cascade,   -- quem pediu
  b uuid not null references auth.users(id) on delete cascade,   -- quem recebeu
  estado text not null default 'pendente' check (estado in ('pendente', 'aceita')),
  criado_em timestamptz not null default now(),
  primary key (a, b),
  check (a <> b)
);
create unique index if not exists amizades_par on public.amizades (least(a, b), greatest(a, b));
alter table public.amizades enable row level security;
revoke all on public.amizades from anon, authenticated;

create table if not exists public.convites (
  id bigserial primary key,
  de uuid not null references auth.users(id) on delete cascade,
  para uuid not null references auth.users(id) on delete cascade,
  tipo text not null check (tipo in ('coop', 'duelo')),
  sala text not null check (char_length(sala) between 1 and 40),
  andar integer not null default 1,
  criado_em timestamptz not null default now(),
  expira_em timestamptz not null default now() + interval '5 minutes'
);
create index if not exists convites_para on public.convites (para, expira_em);
alter table public.convites enable row level security;
revoke all on public.convites from anon, authenticated;

-- Código de amigo da própria conta (cria na primeira chamada).
create or replace function public.meu_codigo_amigo()
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  usuario uuid := auth.uid();
  atual text;
  alfabeto text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  novo text;
  tentativas integer := 0;
begin
  if usuario is null then return null; end if;
  select codigo_amigo into atual from public.perfis where id = usuario;
  if not found then return null; end if;          -- sem perfil ainda (vincular_conta cria)
  if atual is not null then return atual; end if;
  loop
    novo := '';
    for i in 1..6 loop
      novo := novo || substr(alfabeto, 1 + floor(random() * length(alfabeto))::int, 1);
    end loop;
    begin
      update public.perfis set codigo_amigo = novo where id = usuario;
      return novo;
    exception when unique_violation then
      tentativas := tentativas + 1;
      if tentativas > 20 then return null; end if;
    end;
  end loop;
end;
$$;

-- Pedido de amizade pelo código. Se a pessoa já tinha pedido para você, vira amizade na hora.
create or replace function public.pedir_amizade(p_codigo_amigo text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  usuario uuid := auth.uid();
  alvo uuid;
  existente public.amizades%rowtype;
begin
  if usuario is null then return jsonb_build_object('estado', 'sem_login'); end if;
  select id into alvo from public.perfis where codigo_amigo = upper(trim(coalesce(p_codigo_amigo, '')));
  if alvo is null then return jsonb_build_object('estado', 'nao_encontrado'); end if;
  if alvo = usuario then return jsonb_build_object('estado', 'proprio'); end if;
  select * into existente from public.amizades where (a = usuario and b = alvo) or (a = alvo and b = usuario);
  if found then
    if existente.estado = 'aceita' then return jsonb_build_object('estado', 'ja_amigos'); end if;
    if existente.a = alvo then
      update public.amizades set estado = 'aceita' where a = alvo and b = usuario;
      return jsonb_build_object('estado', 'amigos');
    end if;
    return jsonb_build_object('estado', 'ja_pedido');
  end if;
  if (select count(*) from public.amizades where a = usuario and estado = 'pendente') >= 20 then
    return jsonb_build_object('estado', 'muitos_pedidos');
  end if;
  if (select count(*) from public.amizades where (a = usuario or b = usuario) and estado = 'aceita') >= 100 then
    return jsonb_build_object('estado', 'lista_cheia');
  end if;
  insert into public.amizades (a, b) values (usuario, alvo);
  return jsonb_build_object('estado', 'enviado');
end;
$$;

-- Amigos e pedidos, só com apelido e código de amigo.
create or replace function public.listar_amigos()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare resultado jsonb;
begin
  if auth.uid() is null then return jsonb_build_object('estado', 'sem_login'); end if;
  select coalesce(jsonb_agg(jsonb_build_object(
      'codigo', p.codigo_amigo, 'apelido', p.apelido,
      'estado', case when m.estado = 'aceita' then 'amigo' when m.a = auth.uid() then 'enviado' else 'recebido' end)
      order by (m.estado = 'aceita') desc, p.apelido), '[]'::jsonb)
    into resultado
    from public.amizades m
    join public.perfis p on p.id = case when m.a = auth.uid() then m.b else m.a end
   where (m.a = auth.uid() or m.b = auth.uid()) and p.codigo_amigo is not null;
  return jsonb_build_object('estado', 'ok', 'lista', resultado);
end;
$$;

create or replace function public.responder_amizade(p_codigo_amigo text, p_aceitar boolean)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare alvo uuid;
begin
  if auth.uid() is null then return jsonb_build_object('estado', 'sem_login'); end if;
  select id into alvo from public.perfis where codigo_amigo = upper(trim(coalesce(p_codigo_amigo, '')));
  if alvo is null then return jsonb_build_object('estado', 'nao_encontrado'); end if;
  if p_aceitar then
    update public.amizades set estado = 'aceita' where a = alvo and b = auth.uid() and estado = 'pendente';
  else
    delete from public.amizades where a = alvo and b = auth.uid() and estado = 'pendente';
  end if;
  return jsonb_build_object('estado', 'ok');
end;
$$;

create or replace function public.remover_amizade(p_codigo_amigo text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare alvo uuid;
begin
  if auth.uid() is null then return jsonb_build_object('estado', 'sem_login'); end if;
  select id into alvo from public.perfis where codigo_amigo = upper(trim(coalesce(p_codigo_amigo, '')));
  if alvo is null then return jsonb_build_object('estado', 'nao_encontrado'); end if;
  delete from public.amizades where (a = auth.uid() and b = alvo) or (a = alvo and b = auth.uid());
  delete from public.convites where (de = auth.uid() and para = alvo) or (de = alvo and para = auth.uid());
  return jsonb_build_object('estado', 'ok');
end;
$$;

-- Convite para uma sala (só entre amigos; um por vez para a mesma pessoa; no máximo 1 a cada 5 s).
create or replace function public.enviar_convite(p_codigo_amigo text, p_tipo text, p_sala text, p_andar integer default 1)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  usuario uuid := auth.uid();
  alvo uuid;
begin
  if usuario is null then return jsonb_build_object('estado', 'sem_login'); end if;
  if p_tipo not in ('coop', 'duelo') or p_sala is null or char_length(p_sala) not between 1 and 40 then
    return jsonb_build_object('estado', 'convite_invalido');
  end if;
  select id into alvo from public.perfis where codigo_amigo = upper(trim(coalesce(p_codigo_amigo, '')));
  if alvo is null then return jsonb_build_object('estado', 'nao_encontrado'); end if;
  if not exists (select 1 from public.amizades where estado = 'aceita' and ((a = usuario and b = alvo) or (a = alvo and b = usuario))) then
    return jsonb_build_object('estado', 'nao_sao_amigos');
  end if;
  if exists (select 1 from public.convites where de = usuario and criado_em > now() - interval '5 seconds') then
    return jsonb_build_object('estado', 'rapido');
  end if;
  delete from public.convites where de = usuario and para = alvo;
  insert into public.convites (de, para, tipo, sala, andar) values (usuario, alvo, p_tipo, p_sala, greatest(coalesce(p_andar, 1), 1));
  delete from public.convites where expira_em < now() - interval '1 hour';
  return jsonb_build_object('estado', 'ok');
end;
$$;

create or replace function public.listar_convites()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare resultado jsonb;
begin
  if auth.uid() is null then return jsonb_build_object('estado', 'sem_login'); end if;
  select coalesce(jsonb_agg(jsonb_build_object('id', c.id, 'tipo', c.tipo, 'sala', c.sala, 'andar', c.andar,
      'de', p.apelido, 'codigo', p.codigo_amigo) order by c.criado_em desc), '[]'::jsonb)
    into resultado
    from public.convites c join public.perfis p on p.id = c.de
   where c.para = auth.uid() and c.expira_em > now();
  return jsonb_build_object('estado', 'ok', 'lista', resultado);
end;
$$;

create or replace function public.descartar_convite(p_id bigint)
returns void
language sql
security definer
set search_path = public
as $$
  delete from public.convites where id = p_id and para = auth.uid();
$$;

revoke all on function public.meu_codigo_amigo() from public, anon;
revoke all on function public.pedir_amizade(text) from public, anon;
revoke all on function public.listar_amigos() from public, anon;
revoke all on function public.responder_amizade(text, boolean) from public, anon;
revoke all on function public.remover_amizade(text) from public, anon;
revoke all on function public.enviar_convite(text, text, text, integer) from public, anon;
revoke all on function public.listar_convites() from public, anon;
revoke all on function public.descartar_convite(bigint) from public, anon;
grant execute on function public.meu_codigo_amigo() to authenticated;
grant execute on function public.pedir_amizade(text) to authenticated;
grant execute on function public.listar_amigos() to authenticated;
grant execute on function public.responder_amizade(text, boolean) to authenticated;
grant execute on function public.remover_amizade(text) to authenticated;
grant execute on function public.enviar_convite(text, text, text, integer) to authenticated;
grant execute on function public.listar_convites() to authenticated;
grant execute on function public.descartar_convite(bigint) to authenticated;
