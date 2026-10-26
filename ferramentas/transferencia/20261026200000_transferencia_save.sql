-- Transferência de save entre aparelhos (PC <-> celular) por código curto de uso único.
-- O aparelho de origem envia o pacote do save e recebe um código de 6 letras válido por 15 minutos;
-- o de destino digita o código e baixa o pacote uma única vez. Nada fica guardado depois disso.
begin;

create table if not exists public.transferencias_save (
 codigo text primary key,
 origem_hash text not null,
 dados text not null,
 criado_em timestamptz not null default now(),
 expira_em timestamptz not null
);
create index if not exists transferencias_save_origem on public.transferencias_save(origem_hash, criado_em);
create table if not exists public.transferencias_tentativas (
 id bigserial primary key,
 criado_em timestamptz not null default now(),
 acertou boolean not null
);
create index if not exists transferencias_tentativas_quando on public.transferencias_tentativas(criado_em);
alter table public.transferencias_save enable row level security;
alter table public.transferencias_tentativas enable row level security;
revoke all on public.transferencias_save, public.transferencias_tentativas from public, anon, authenticated;

-- Envia o save. p_codigo_secreto identifica o aparelho (o mesmo do ranking; só o hash é guardado).
-- Até 10 envios por hora por jogador; um envio novo cancela o código anterior ainda não usado.
create or replace function public.transferencia_enviar(p_codigo_secreto text, p_dados text) returns jsonb
language plpgsql volatile security definer set search_path=public,pg_temp as $$
declare v_hash text; v_codigo text; v_alfabeto text:='ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; i int; tentativa int;
begin
 if p_codigo_secreto is null or length(p_codigo_secreto) < 24 or length(p_codigo_secreto) > 128 then
  return jsonb_build_object('erro','codigo_invalido');
 end if;
 if p_dados is null or octet_length(p_dados) < 2 or octet_length(p_dados) > 524288 then
  return jsonb_build_object('erro','tamanho_invalido');
 end if;
 v_hash:=encode(sha256(convert_to(p_codigo_secreto,'UTF8')),'hex');
 delete from public.transferencias_save where expira_em < now();
 delete from public.transferencias_tentativas where criado_em < now() - interval '1 day';
 if (select count(*) from public.transferencias_save where origem_hash=v_hash and criado_em > now() - interval '1 hour') >= 10 then
  return jsonb_build_object('erro','muitos_envios');
 end if;
 delete from public.transferencias_save where origem_hash=v_hash;
 for tentativa in 1..20 loop
  v_codigo:='';
  for i in 1..6 loop
   v_codigo:=v_codigo||substr(v_alfabeto, 1+floor(random()*length(v_alfabeto))::int, 1);
  end loop;
  begin
   insert into public.transferencias_save(codigo,origem_hash,dados,expira_em)
    values (v_codigo,v_hash,p_dados,now()+interval '15 minutes');
   return jsonb_build_object('codigo',v_codigo,'minutos',15);
  exception when unique_violation then
   -- Código repetido: sorteia outro.
  end;
 end loop;
 return jsonb_build_object('erro','sem_codigo');
end $$;

-- Recebe o save pelo código (uso único). Muitas tentativas erradas no último minuto travam todos por 1 minuto,
-- o que torna inviável adivinhar um código de 6 letras (32^6 ~ 1 bilhão) nos 15 minutos de validade.
create or replace function public.transferencia_receber(p_codigo text) returns jsonb
language plpgsql volatile security definer set search_path=public,pg_temp as $$
declare v_codigo text; v_dados text;
begin
 if (select count(*) from public.transferencias_tentativas where not acertou and criado_em > now() - interval '1 minute') >= 60 then
  return jsonb_build_object('erro','aguarde');
 end if;
 v_codigo:=upper(regexp_replace(coalesce(p_codigo,''),'[^A-Za-z0-9]','','g'));
 if length(v_codigo) <> 6 then
  return jsonb_build_object('erro','codigo_invalido');
 end if;
 delete from public.transferencias_save where codigo=v_codigo and expira_em > now() returning dados into v_dados;
 insert into public.transferencias_tentativas(acertou) values (v_dados is not null);
 if v_dados is null then
  return jsonb_build_object('erro','nao_encontrado');
 end if;
 return jsonb_build_object('dados',v_dados);
end $$;

revoke all on function public.transferencia_enviar(text,text) from public, anon, authenticated;
revoke all on function public.transferencia_receber(text) from public, anon, authenticated;
grant execute on function public.transferencia_enviar(text,text) to anon;
grant execute on function public.transferencia_receber(text) to anon;
commit;
