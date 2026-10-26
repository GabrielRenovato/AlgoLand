-- Correção compatível com o PC, Android e Web já publicados. Não altera saves nem ranking.
begin;

-- Envia o save. p_codigo_secreto identifica o aparelho (o mesmo do ranking; só o hash é guardado).
-- Mantém até 10 códigos ativos por jogador. Reenviar o mesmo pacote devolve o código ainda válido.
-- Um envio diferente preserva os anteriores até o prazo informado.
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
 perform pg_advisory_xact_lock(hashtextextended(v_hash, 0));
 delete from public.transferencias_save where expira_em < now();
 delete from public.transferencias_tentativas where criado_em < now() - interval '1 day';
 select codigo into v_codigo from public.transferencias_save
  where origem_hash=v_hash and dados=p_dados and expira_em > now()
  order by criado_em desc limit 1;
 if v_codigo is not null then
  return jsonb_build_object('codigo',v_codigo,'minutos',
   (select greatest(1,ceil(extract(epoch from (expira_em-now()))/60)::int) from public.transferencias_save where codigo=v_codigo));
 end if;
 if (select count(*) from public.transferencias_save where origem_hash=v_hash and criado_em > now() - interval '1 hour') >= 10 then
  return jsonb_build_object('erro','muitos_envios');
 end if;
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

-- Baixar não consome o código: permite repetir após resposta perdida, validação ou confirmação cancelada.
-- A importação confirmada encerra o código. Clientes antigos podem repetir dentro dos 15 minutos.
-- Muitas tentativas erradas no último minuto travam todos por 1 minuto,
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
 select dados into v_dados from public.transferencias_save where codigo=v_codigo and expira_em > now();
 insert into public.transferencias_tentativas(acertou) values (v_dados is not null);
 if v_dados is null then
  return jsonb_build_object('erro','nao_encontrado');
 end if;
 return jsonb_build_object('dados',v_dados);
end $$;

-- Só encerra depois de gravar o save; exige a identidade que veio dentro do pacote.
create or replace function public.transferencia_confirmar(p_codigo text, p_codigo_secreto text) returns jsonb
language plpgsql volatile security definer set search_path=public,pg_temp as $$
declare v_codigo text;
begin
 if p_codigo_secreto is null or length(p_codigo_secreto) < 24 or length(p_codigo_secreto) > 128 then
  return jsonb_build_object('erro','codigo_invalido');
 end if;
 v_codigo:=upper(regexp_replace(coalesce(p_codigo,''),'[^A-Za-z0-9]','','g'));
 delete from public.transferencias_save where codigo=v_codigo
  and origem_hash=encode(sha256(convert_to(p_codigo_secreto,'UTF8')),'hex');
 return jsonb_build_object('ok',found);
end $$;

revoke all on function public.transferencia_enviar(text,text) from public, anon, authenticated;
revoke all on function public.transferencia_receber(text) from public, anon, authenticated;
revoke all on function public.transferencia_confirmar(text,text) from public, anon, authenticated;
grant execute on function public.transferencia_enviar(text,text) to anon;
grant execute on function public.transferencia_receber(text) to anon;
grant execute on function public.transferencia_confirmar(text,text) to anon;

notify pgrst, 'reload schema';
commit;
