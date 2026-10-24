-- Executar depois da migração, sempre em transação revertida. Nenhum player fictício permanece.
begin;
set local role anon;
do $$
declare r jsonb; v jsonb:='{"versao":1,"pele":0,"cabelo":12,"roupa":8}';
begin
 for i in 1..8 loop
  r:=public.lobby_cidade('lobby_teste_codigo_secreto_numero_'||i,repeat('a',31)||i::text,
    jsonb_build_object('x',400+i,'y',320,'apelido',case when i<3 then '' else 'Player_'||i end,'aparencia',v));
  if r ? 'erro' then raise exception 'entrada_falhou_%_%',i,r; end if;
 end loop;
 r:=public.lobby_cidade('lobby_teste_codigo_secreto_numero_9',repeat('b',32),jsonb_build_object('x',440,'y',320,'aparencia',v));
 if r->>'erro'<>'cidade_cheia' then raise exception 'capacidade_nao_respeitada'; end if;
 r:=public.lobby_cidade('lobby_teste_codigo_secreto_numero_1',repeat('a',31)||'1',jsonb_build_object('x',401,'y',320,'apelido',''));
 if r->>'erro'<>'aguarde' then raise exception 'limite_de_frequencia_falhou'; end if;
end $$;
reset role;
update public.lobby_sessoes set sincronizado_em='-infinity' where codigo_hash=encode(sha256(convert_to('lobby_teste_codigo_secreto_numero_1','UTF8')),'hex');
set local role anon;
do $$
declare r jsonb; meu text; revisao text; conhecidos jsonb;
begin
 r:=public.lobby_cidade('lobby_teste_codigo_secreto_numero_1',repeat('a',31)||'1','{"x":405,"y":321,"apelido":"José da Vila"}','{}',0,'OI GALERA',repeat('c',32));
 if r->>'confirmado'<>repeat('c',32) or jsonb_array_length(r->'mensagens')<>1 then raise exception 'chat_falhou'; end if;
 meu:=r->>'eu';
 if (select count(*) from jsonb_array_elements(r->'jogadores') as j where j->>'apelido'='sem apelido')<>1 then raise exception 'apelido_padrao_falhou'; end if;
 if exists(select 1 from jsonb_array_elements(r->'jogadores') as j where j ? 'codigo_hash' or j ? 'geracao') then raise exception 'segredo_exposto'; end if;
end $$;
reset role;
update public.lobby_sessoes set sincronizado_em='-infinity' where codigo_hash=encode(sha256(convert_to('lobby_teste_codigo_secreto_numero_1','UTF8')),'hex');
set local role anon;
do $$
declare r jsonb;
begin
 r:=public.lobby_cidade('lobby_teste_codigo_secreto_numero_1',repeat('a',31)||'1','{"x":405,"y":321,"apelido":"José da Vila"}','{}',0,'OI GALERA',repeat('c',32));
 if jsonb_array_length(r->'mensagens')<>1 or r->>'confirmado'<>repeat('c',32) then raise exception 'repeticao_duplicou_chat'; end if;
 perform public.lobby_cidade_sair('lobby_teste_codigo_secreto_numero_1',repeat('a',31)||'1');
 r:=public.lobby_cidade('lobby_teste_codigo_secreto_numero_1',repeat('a',31)||'1','{"x":405,"y":321}');
 if r->>'erro'<>'sessao_encerrada' then raise exception 'poll_tardio_reconectou_offline'; end if;
 perform public.lobby_cidade_sair('lobby_teste_que_desligou_antes_de_entrar',repeat('d',32));
 r:=public.lobby_cidade('lobby_teste_que_desligou_antes_de_entrar',repeat('d',32),'{"x":405,"y":321}');
 if r->>'erro'<>'sessao_encerrada' then raise exception 'saida_antes_da_entrada_falhou'; end if;
end $$;
reset role;
-- Delata de aparência, limite do chat e liberação automática de vagas.
update public.lobby_sessoes set sincronizado_em='-infinity'
 where codigo_hash=encode(sha256(convert_to('lobby_teste_codigo_secreto_numero_2','UTF8')),'hex');
set local role anon;
do $$
declare r jsonb; revisoes jsonb;
begin
 r:=public.lobby_cidade('lobby_teste_codigo_secreto_numero_2',repeat('a',31)||'2','{"x":1020,"y":570,"apelido":""}','{}',0,'OLA',repeat('f',32));
 if r->>'confirmado'<>repeat('f',32) then raise exception 'chat_segundo_player_falhou'; end if;
 select jsonb_object_agg(j->>'id',j->'revisao') into revisoes from jsonb_array_elements(r->'jogadores') j;
 -- Outra geração evita o intervalo do poll; o intervalo de mensagens continua valendo por perfil.
 r:=public.lobby_cidade('lobby_teste_codigo_secreto_numero_2',repeat('b',32),'{"x":1020,"y":570,"apelido":""}',revisoes,0,'SPAM',repeat('1',32));
 if r->>'aviso'<>'aguarde_mensagem' or r->>'confirmado' is not null then raise exception 'intervalo_chat_falhou'; end if;
 if exists(select 1 from jsonb_array_elements(r->'jogadores') j where j->'aparencia'<>'null') then raise exception 'delta_aparencia_falhou'; end if;
end $$;
reset role;
-- Uma segunda fala depois de 0,6 s já pode ser publicada; não espera três segundos.
update public.lobby_sessoes set sincronizado_em=clock_timestamp()-interval '600 milliseconds',
 mensagem_em=clock_timestamp()-interval '600 milliseconds'
 where codigo_hash=encode(sha256(convert_to('lobby_teste_codigo_secreto_numero_2','UTF8')),'hex');
set local role anon;
do $$
declare r jsonb;
begin
 r:=public.lobby_cidade('lobby_teste_codigo_secreto_numero_2',repeat('b',32),'{"x":1020,"y":570,"apelido":""}','{}',0,'SEGUNDA FALA',repeat('3',32));
 if r->>'confirmado'<>repeat('3',32) or coalesce(r->>'aviso','')<>'' then raise exception 'chat_continua_esperando_tres_segundos'; end if;
 if exists(select 1 from jsonb_array_elements(r->'jogadores') j where jsonb_typeof(j->'instante') is distinct from 'number') then raise exception 'movimento_sem_horario_da_amostra'; end if;
end $$;
reset role;
update public.lobby_sessoes set visto_em=clock_timestamp()-interval '21 seconds'
 where codigo_hash=encode(sha256(convert_to('lobby_teste_codigo_secreto_numero_3','UTF8')),'hex');
set local role anon;
do $$
declare r jsonb;
begin
 r:=public.lobby_cidade('lobby_teste_codigo_secreto_numero_9',repeat('2',32),'{"x":1000,"y":570,"aparencia":{"versao":1}}');
 if r ? 'erro' then raise exception 'vaga_expirada_nao_liberada'; end if;
 if exists(select 1 from jsonb_array_elements(r->'jogadores') j where j->>'apelido'='Player_3') then raise exception 'player_expirado_ainda_visivel'; end if;
end $$;
reset role;
update public.lobby_uso set bytes=67108864 where dia=current_date;
set local role anon;
do $$
declare r jsonb;
begin
 r:=public.lobby_cidade('lobby_teste_codigo_secreto_numero_9',repeat('e',32),'{"x":405,"y":321,"aparencia":{"versao":1}}');
 if r->>'erro'<>'limite_gratuito' then raise exception 'orcamento_falhou'; end if;
 if has_table_privilege('anon','public.lobby_sessoes','select') or has_table_privilege('anon','public.lobby_mensagens','insert') then raise exception 'tabelas_expostas'; end if;
end $$;
reset role;
rollback;
