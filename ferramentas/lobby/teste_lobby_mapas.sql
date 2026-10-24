-- Executar em banco de testes depois de 20261024140000_lobby_mapas.sql; a transação não deixa nada.
begin;
do $$
declare r jsonb; visual jsonb := '{"versao":1}'; i int; a uuid; b uuid;
begin
 -- Floresta: dois jogadores se enxergam; a cidade não os vê e eles não veem a cidade.
 r:=public.chat_global('mapas_teste_codigo_secreto_a',repeat('a',32),jsonb_build_object('mapa',2,'x',500,'y',300,'aparencia',visual));
 a:=(r->>'eu')::uuid;
 r:=public.chat_global('mapas_teste_codigo_secreto_b',repeat('b',32),jsonb_build_object('mapa',2,'x',510,'y',310,'aparencia',visual));
 b:=(r->>'eu')::uuid;
 if jsonb_array_length(r->'jogadores')<>2 then raise exception 'floresta_nao_enxerga'; end if;
 r:=public.chat_global('mapas_teste_codigo_secreto_c',repeat('c',32),jsonb_build_object('mapa',1,'cidade',true,'x',400,'y',300,'aparencia',visual));
 if jsonb_array_length(r->'jogadores')<>1 then raise exception 'cidade_enxerga_floresta'; end if;
 -- RPC antigo da cidade lista só quem está na cidade.
 r:=public.lobby_cidade('mapas_teste_codigo_secreto_c',repeat('c',32),jsonb_build_object('x',400,'y',300,'aparencia',visual));
 if jsonb_array_length(r->'jogadores')<>1 then raise exception 'rpc_antigo_enxerga_outros_mapas'; end if;
 -- Cliente antigo ("cidade":true, sem mapa) vale mapa 1.
 if (select mapa from public.lobby_sessoes where id=(select (public.chat_global('mapas_teste_codigo_secreto_d',repeat('d',32),jsonb_build_object('cidade',true,'x',1,'y',1,'aparencia',visual))->>'eu')::uuid))<>1 then raise exception 'compatibilidade_cidade'; end if;
 -- Trocar para a praia tira da floresta.
 perform pg_sleep(0.6);
 r:=public.chat_global('mapas_teste_codigo_secreto_a',repeat('a',32),jsonb_build_object('mapa',3,'x',100,'y',100,'aparencia',visual));
 if jsonb_array_length(r->'jogadores')<>1 then raise exception 'praia_deveria_ter_so_o_proprio'; end if;
 perform pg_sleep(0.6);
 r:=public.chat_global('mapas_teste_codigo_secreto_b',repeat('b',32),jsonb_build_object('mapa',2,'x',510,'y',310,'aparencia',visual));
 if jsonb_array_length(r->'jogadores')<>1 then raise exception 'saiu_da_floresta_mas_ficou'; end if;
 -- Sair apaga a presença na hora.
 perform public.lobby_cidade_sair('mapas_teste_codigo_secreto_b',repeat('b',32));
 perform pg_sleep(0.6);
 r:=public.chat_global('mapas_teste_codigo_secreto_a',repeat('a',32),jsonb_build_object('mapa',3,'x',100,'y',100,'aparencia',visual));
 if jsonb_array_length(r->'jogadores')<>1 then raise exception 'estado_inesperado'; end if;
 if exists(select 1 from public.lobby_sessoes where id=b and mapa<>0) then raise exception 'sair_nao_retirou_mapa'; end if;
 -- As oito vagas valem para todos os mapas juntos; o nono ainda conversa, sem avatar.
 delete from public.lobby_sessoes;
 for i in 1..8 loop
  perform public.chat_global('mapas_teste_lotacao_'||lpad(i::text,16,'0'),repeat('e',32),jsonb_build_object('mapa',1+(i%3),'x',10,'y',10,'aparencia',visual));
 end loop;
 r:=public.chat_global('mapas_teste_lotacao_nono_visitante',repeat('f',32),jsonb_build_object('mapa',2,'x',10,'y',10,'aparencia',visual,'apelido','NONO'));
 if r ? 'erro' or (select count(*) from public.lobby_sessoes where mapa>0)<>8 then raise exception 'lotacao_por_mapa'; end if;
 -- Posição fora do envelope e mapa inválido continuam recusados.
 begin perform public.chat_global('mapas_teste_codigo_secreto_g',repeat('9',32),jsonb_build_object('mapa',2,'x',2000,'y',1,'aparencia',visual)); raise exception 'posicao_aceita';
 exception when others then if sqlerrm='posicao_aceita' then raise; end if; end;
 begin perform public.chat_global('mapas_teste_codigo_secreto_h',repeat('8',32),jsonb_build_object('mapa',9,'x',1,'y',1,'aparencia',visual)); raise exception 'mapa_aceito';
 exception when others then if sqlerrm='mapa_aceito' then raise; end if; end;
 raise notice 'LOBBY MAPAS SQL: floresta, praia, cidade, saída, lotação e compatibilidade OK';
end $$;
rollback;
