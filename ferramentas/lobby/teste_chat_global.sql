-- Executar em banco de testes; a transação não deixa mensagens nem identidades.
begin;
do $$
declare r jsonb; visual jsonb := '{"versao":1}'; estado jsonb; i int;
begin
 for i in 1..8 loop
  perform public.lobby_cidade('global_teste_codigo_secreto_'||i,repeat('a',32),
   jsonb_build_object('x',400,'y',320,'aparencia',visual));
 end loop;
 estado:=jsonb_build_object('cidade',false,'x',0,'y',0,'aparencia',visual);
 r:=public.chat_global('global_teste_codigo_secreto_floresta',repeat('b',32),estado,'{}',0,'GLOBAL DA FLORESTA',repeat('c',32));
 if r ? 'erro' or jsonb_array_length(r->'jogadores')<>0 then raise exception 'global_bloqueado_pela_cidade'; end if;
 if not exists(select 1 from public.lobby_sessoes where id=(r->>'eu')::uuid and not online) then raise exception 'avatar_fantasma'; end if;
 -- O nono visitante pode conversar mesmo sem vaga para desenhar seu avatar.
 r:=public.chat_global('global_teste_codigo_secreto_visitante',repeat('d',32),
  jsonb_build_object('cidade',true,'x',400,'y',320,'aparencia',visual));
 if r ? 'erro' or jsonb_array_length(r->'jogadores')<>8 then raise exception 'cidade_cheia_impede_chat'; end if;
 if not exists(select 1 from jsonb_array_elements(r->'mensagens') m where m->>'texto'='GLOBAL DA FLORESTA') then raise exception 'mensagem_nao_global'; end if;
 if (select count(*) from public.lobby_sessoes where online)<>8 then raise exception 'limite_visual_removido'; end if;
 -- Viajar retira somente a presença visual e mantém identidade, nonce e histórico.
 r:=public.chat_global('global_teste_codigo_secreto_1',repeat('e',32),estado);
 if r ? 'erro' or jsonb_array_length(r->'jogadores')<>0 then raise exception 'viagem_nao_retirou_presenca'; end if;
 if (select count(*) from public.lobby_sessoes where online)<>7 then raise exception 'viagem_nao_liberou_vaga'; end if;
 perform public.lobby_cidade_sair('global_teste_codigo_secreto_floresta',repeat('b',32));
 r:=public.chat_global('global_teste_codigo_secreto_floresta',repeat('b',32),estado);
 if r->>'erro' is distinct from 'sessao_encerrada' then raise exception 'ressuscita_sessao_encerrada'; end if;
 if not has_function_privilege('anon','public.chat_global(text,text,jsonb,jsonb,bigint,text,text)','execute') then raise exception 'rpc_indisponivel'; end if;
 if has_table_privilege('anon','public.lobby_mensagens','insert') then raise exception 'mensagens_expostas'; end if;
 raise notice 'CHAT GLOBAL SQL: mapas, lotação, histórico, viagem, encerramento e permissões OK';
end $$;
rollback;
