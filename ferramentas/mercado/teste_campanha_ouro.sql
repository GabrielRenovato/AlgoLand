-- Gerado por gerar_campanha.py; somente banco de testes.
-- Executar em banco de testes depois das migrações e de tipos_mercado.sql; a transação não deixa anúncios nem entregas.
begin;
create or replace function pg_temp.envio() returns text language sql as $$ select md5(clock_timestamp()::text||random()::text) $$;
do $$
declare r jsonb; vend text:='campanha_mercado_teste_codigo_vendedor_1'; comp text:='campanha_mercado_teste_codigo_comprador_1'; outro text:='campanha_mercado_teste_codigo_outro_jogador';
 espada jsonb:='{"id":"teste_1","tipo":"espada_basica","categoria":"arma","nivel":3,"raridade":"epico","afixos":{"critico":0.05,"vitalidade":2},"quantidade":1,"extra":"lixo"}';
 id1 bigint; id2 bigint; ids bigint[]; i int; e text;
begin
 update public.campanha_mercado_config set ligado=true,taxa_anuncio=1,taxa_venda_pct=10,preco_min=1,preco_max=9999,max_anuncios=5,horas_permitidas='{24,48}',
  tipos_bloqueados='{}',max_anuncios_dia=20,max_compras_dia=30 where id=1;
 delete from public.mercado_banidos where codigo_hash in (select encode(sha256(convert_to(x,'UTF8')),'hex') from unnest(array[vend,comp,outro]) x);

 -- Anunciar, normalizar e validar entradas
 e:=pg_temp.envio();
 r:=public.campanha_mercado_anunciar(vend,'Vendedor',espada,100,24,e);
 if not coalesce((r->>'ok')::boolean,false) then raise exception 'anuncio_recusado %',r; end if;
 id1:=(r->>'id')::bigint;
 if (select item ? 'extra' or item->>'id'<>'espada_basica' from public.campanha_mercado_anuncios where id=id1) then raise exception 'item_nao_normalizado'; end if;
 -- Mesmo envio não duplica (o jogo repete depois de uma queda)
 r:=public.campanha_mercado_anunciar(vend,'Vendedor',espada,100,24,e);
 if (r->>'id')::bigint<>id1 or not (r ? 'repetido') then raise exception 'envio_duplicou %',r; end if;
 if not (public.campanha_mercado_anuncio_status(vend,e)->>'existe')::boolean then raise exception 'status_anuncio_falhou'; end if;
 if (public.campanha_mercado_anuncio_status(vend,pg_temp.envio())->>'existe')::boolean then raise exception 'status_anuncio_inventado'; end if;
 if (public.campanha_mercado_anunciar(vend,'V',espada,100,24,'curto'))->>'erro' is distinct from 'envio_invalido' then raise exception 'envio_curto_aceito'; end if;
 if (public.campanha_mercado_anunciar(vend,'V',espada,100,12,pg_temp.envio()))->>'erro' is distinct from 'prazo_invalido' then raise exception 'prazo_aceito'; end if;
 if (public.campanha_mercado_anunciar(vend,'V',espada,0,24,pg_temp.envio()))->>'erro' is distinct from 'preco_invalido' then raise exception 'preco_zero_aceito'; end if;
 -- Itens inventados ou fora das regras do jogo
 foreach r in array array[
  '{"tipo":"espada_lendaria_hack","raridade":"epico"}'::jsonb,
  '{"tipo":"espada_basica","raridade":"divino"}',
  '{"tipo":"espada_basica","raridade":"comum","nivel":6}',
  '{"tipo":"espada_basica","raridade":"comum","nivel":"abc"}',
  '{"tipo":"espada_basica","raridade":"raro","afixos":{"critico":0.5}}',
  '{"tipo":"espada_basica","raridade":"raro","afixos":{"defesa":2}}',
  '{"tipo":"espada_basica","raridade":"raro","afixos":{"voar":1}}',
  '{"tipo":"escudo_basico","raridade":"raro","encantamento":"fogo","nivel_encantamento":1}',
  '{"tipo":"espada_basica","raridade":"raro","encantamento":"fogo","nivel_encantamento":4}',
  '{"tipo":"material:ferro","raridade":"comum","quantidade":5000}',
  '{"tipo":"enxada","raridade":"comum"}'] loop
  if (public.campanha_mercado_anunciar(vend,'V',r,10,24,pg_temp.envio()))->>'erro' is distinct from 'item_invalido' then raise exception 'item_falso_aceito %',r; end if;
 end loop;
 begin perform public.campanha_mercado_anunciar('curto','x',espada,10,24,pg_temp.envio()); raise exception 'codigo_curto_aceito';
 exception when raise_exception then if sqlerrm<>'codigo_invalido' then raise; end if; end;
 -- Pilha com prefixo: categoria vem da tabela, não do jogo
 r:=public.campanha_mercado_anunciar(outro,'Outro','{"tipo":"material:ferro","categoria":"arma","raridade":"comum","quantidade":7,"nivel":9}',3,24,pg_temp.envio());
 if not coalesce((r->>'ok')::boolean,false) then raise exception 'material_recusado %',r; end if;
 if (select categoria<>'material' or nivel<>1 or (item->>'quantidade')::int<>7 from public.campanha_mercado_anuncios where id=(r->>'id')::bigint) then raise exception 'pilha_mal_normalizada'; end if;
 perform public.campanha_mercado_cancelar(outro,(r->>'id')::bigint);
 delete from public.campanha_mercado_correio where dono_hash=encode(sha256(convert_to(outro,'UTF8')),'hex');

 -- Busca mostra o anúncio sem expor o vendedor
 r:=public.campanha_mercado_buscar('{"categoria":"arma","raridade":"epico"}',0);
 if not exists(select 1 from jsonb_array_elements(r->'anuncios') a where (a->>'id')::bigint=id1) then raise exception 'busca_sem_anuncio'; end if;
 if r::text like '%'||encode(sha256(convert_to(vend,'UTF8')),'hex')||'%' then raise exception 'hash_exposto'; end if;
 r:=public.campanha_mercado_buscar('{"preco_max":50}',0);
 if exists(select 1 from jsonb_array_elements(r->'anuncios') a where (a->>'id')::bigint=id1) then raise exception 'filtro_preco_ignorado'; end if;

 -- Comprar: preço conferido, próprio anúncio recusado, segunda compra recusada, situação consultável
 if (public.campanha_mercado_comprar(vend,id1,100))->>'erro' is distinct from 'proprio_anuncio' then raise exception 'comprou_o_proprio'; end if;
 if (public.campanha_mercado_comprar(comp,id1,90))->>'erro' is distinct from 'preco_mudou' then raise exception 'preco_divergente_aceito'; end if;
 if (public.campanha_mercado_compra_status(comp,id1)->>'comprado')::boolean then raise exception 'status_compra_antes'; end if;
 r:=public.campanha_mercado_comprar(comp,id1,100);
 if not coalesce((r->>'ok')::boolean,false) then raise exception 'compra_recusada %',r; end if;
 if (public.campanha_mercado_comprar(outro,id1,100))->>'erro' is distinct from 'indisponivel' then raise exception 'vendido_duas_vezes'; end if;
 if not (public.campanha_mercado_compra_status(comp,id1)->>'comprado')::boolean then raise exception 'status_compra_falhou'; end if;
 if (public.campanha_mercado_compra_status(outro,id1)->>'comprado')::boolean then raise exception 'status_compra_alheio'; end if;

 -- Correio: comprador recebe o item, vendedor recebe preço menos 10%; contagem para o aviso
 if public.campanha_mercado_correio_contar(comp)<>1 or public.campanha_mercado_correio_contar(vend)<>1 then raise exception 'contagem_correio'; end if;
 r:=public.campanha_mercado_correio_retirar(comp);
 if jsonb_array_length(r)<>1 or r->0->>'motivo'<>'compra' or r->0->'item'->>'tipo'<>'espada_basica' then raise exception 'item_nao_entregue %',r; end if;
 r:=public.campanha_mercado_correio_retirar(vend);
 if jsonb_array_length(r)<>1 or (r->0->>'ouro')::int<>90 then raise exception 'ouro_erradas %',r; end if;
 if jsonb_array_length(public.campanha_mercado_correio_retirar(vend))<>1 then raise exception 'retirada_nao_repete'; end if;
 select array_agg((x->>'id')::bigint) into ids from jsonb_array_elements(r) x;
 if (public.campanha_mercado_correio_confirmar(outro,ids)->>'apagados')::int<>0 then raise exception 'apagou_correio_alheio'; end if;
 perform public.campanha_mercado_correio_confirmar(vend,ids);
 if jsonb_array_length(public.campanha_mercado_correio_retirar(vend))<>0 then raise exception 'confirmacao_nao_apagou'; end if;

 -- Cancelar devolve; só o dono cancela
 id2:=(public.campanha_mercado_anunciar(vend,'Vendedor',espada,20,48,pg_temp.envio())->>'id')::bigint;
 if (public.campanha_mercado_cancelar(comp,id2))->>'erro' is distinct from 'indisponivel' then raise exception 'cancelou_alheio'; end if;
 perform public.campanha_mercado_cancelar(vend,id2);
 r:=public.campanha_mercado_correio_retirar(vend);
 if jsonb_array_length(r)<>1 or r->0->>'motivo'<>'cancelado' then raise exception 'cancelamento_sem_devolucao %',r; end if;
 perform public.campanha_mercado_correio_confirmar(vend,array[(r->0->>'id')::bigint]);

 -- Expirar: some da busca, não pode ser comprado e volta ao dono (a contagem também expira)
 id2:=(public.campanha_mercado_anunciar(vend,'Vendedor',espada,20,24,pg_temp.envio())->>'id')::bigint;
 update public.campanha_mercado_anuncios set expira_em=now()-interval '1 second' where id=id2;
 if exists(select 1 from jsonb_array_elements(public.campanha_mercado_buscar('{}',0)->'anuncios') a where (a->>'id')::bigint=id2) then raise exception 'vencido_na_busca'; end if;
 if (public.campanha_mercado_comprar(comp,id2,20))->>'erro' is distinct from 'indisponivel' then raise exception 'comprou_vencido'; end if;
 if public.campanha_mercado_correio_contar(vend)<>1 then raise exception 'contagem_sem_expirar'; end if;
 r:=public.campanha_mercado_correio_retirar(vend);
 if jsonb_array_length(r)<>1 or r->0->>'motivo'<>'devolvido' then raise exception 'vencido_sem_devolucao %',r; end if;
 perform public.campanha_mercado_correio_confirmar(vend,array[(r->0->>'id')::bigint]);

 -- Limites: abertos, diário de anúncios, diário de compras
 for i in 1..5 loop perform public.campanha_mercado_anunciar(outro,'Outro',espada,5,24,pg_temp.envio()); end loop;
 if (public.campanha_mercado_anunciar(outro,'Outro',espada,5,24,pg_temp.envio()))->>'erro' is distinct from 'limite_anuncios' then raise exception 'limite_furado'; end if;
 if (select count(*) from jsonb_array_elements(public.campanha_mercado_meus(outro)) x where x->>'estado'='aberto')<>5 then raise exception 'meus_anuncios_incompletos'; end if;
 update public.campanha_mercado_config set max_anuncios=50,max_anuncios_dia=6 where id=1;
 if (public.campanha_mercado_anunciar(outro,'Outro',espada,5,24,pg_temp.envio()))->>'erro' is distinct from 'limite_diario' then raise exception 'limite_diario_anuncios'; end if;
 update public.campanha_mercado_config set max_compras_dia=1 where id=1;
 select id into id2 from public.campanha_mercado_anuncios where vendedor_hash=encode(sha256(convert_to(outro,'UTF8')),'hex') and estado='aberto' limit 1;
 if (public.campanha_mercado_comprar(comp,id2,5))->>'erro' is distinct from 'limite_diario' then raise exception 'limite_diario_compras'; end if;

 -- Banido não anuncia nem compra
 insert into public.mercado_banidos(codigo_hash,motivo) values(encode(sha256(convert_to(comp,'UTF8')),'hex'),'teste');
 update public.campanha_mercado_config set max_compras_dia=30 where id=1;
 if (public.campanha_mercado_comprar(comp,id2,5))->>'erro' is distinct from 'banido' then raise exception 'banido_comprou'; end if;
 if (public.campanha_mercado_anunciar(comp,'C',espada,5,24,pg_temp.envio()))->>'erro' is distinct from 'banido' then raise exception 'banido_anunciou'; end if;

 -- Bloqueio por tipo e mercado desligado
 update public.campanha_mercado_config set tipos_bloqueados='{espada_basica}' where id=1;
 if (public.campanha_mercado_anunciar(vend,'V',espada,5,24,pg_temp.envio()))->>'erro' is distinct from 'item_bloqueado' then raise exception 'bloqueio_ignorado'; end if;
 update public.campanha_mercado_config set ligado=false,tipos_bloqueados='{}' where id=1;
 if (public.campanha_mercado_anunciar(vend,'V',espada,5,24,pg_temp.envio()))->>'erro' is distinct from 'campanha_mercado_fechado' then raise exception 'campanha_mercado_desligado_aceita'; end if;

 -- Permissões: tabelas fechadas, funções internas fechadas, só as públicas liberadas
 if has_table_privilege('anon','public.campanha_mercado_anuncios','select') or has_table_privilege('anon','public.campanha_mercado_correio','insert')
  or has_table_privilege('anon','public.campanha_mercado_config','update') or has_table_privilege('anon','public.mercado_banidos','select')
  or has_table_privilege('anon','public.mercado_tipos','insert') then raise exception 'tabelas_expostas'; end if;
 if has_function_privilege('anon','public.campanha_mercado_expirar(text)','execute') or has_function_privilege('anon','public.campanha_mercado_normalizar_item(jsonb)','execute')
  or has_function_privilege('anon','public.campanha_mercado_hash(text)','execute') then raise exception 'funcao_interna_exposta'; end if;
 if not has_function_privilege('anon','public.campanha_mercado_comprar(text,bigint,int)','execute')
  or not has_function_privilege('anon','public.campanha_mercado_anunciar(text,text,jsonb,int,int,text)','execute')
  or not has_function_privilege('anon','public.campanha_mercado_correio_contar(text)','execute') then raise exception 'rpc_indisponivel'; end if;
 raise notice 'MERCADO SQL: normalizar, idempotencia, situacao, comprar, taxa, correio, cancelar, expirar, limites, banimento e permissoes OK';
end $$;
rollback;
