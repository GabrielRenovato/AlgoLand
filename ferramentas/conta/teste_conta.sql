-- Teste das funções de conta, nuvem e amigos. Roda numa transação e DESFAZ tudo no fim (rollback): não deixa usuário nem linha.
--   supabase db query --linked -f ferramentas/conta/teste_conta.sql
begin;
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'ana@teste.invalid'),
  ('22222222-2222-2222-2222-222222222222', 'beto@teste.invalid'),
  ('33333333-3333-3333-3333-333333333333', 'caio@teste.invalid');

create temp table _resultado (passo text, ok boolean);
grant all on _resultado to authenticated;

do $$
declare
  ana text := '11111111-1111-1111-1111-111111111111';
  beto text := '22222222-2222-2222-2222-222222222222';
  caio text := '33333333-3333-3333-3333-333333333333';
  r jsonb; cod_ana text; cod_beto text; id_convite bigint;
  segredo_ana text := repeat('a1', 18);
  segredo_beto text := repeat('b2', 18);
  n integer;
begin
  -- Ana
  perform set_config('request.jwt.claims', json_build_object('sub', ana, 'role', 'authenticated')::text, true);
  set local role authenticated;
  r := public.vincular_conta(segredo_ana, 'ANA');
  insert into _resultado values ('vincular conta nova', r->>'estado' = 'ok');
  r := public.vincular_conta(segredo_ana, 'ANA');
  insert into _resultado values ('vincular de novo o mesmo codigo', r->>'estado' = 'ok');
  r := public.vincular_conta(repeat('c3', 18), 'ANA');
  insert into _resultado values ('outro codigo devolve o da conta sem trocar', r->>'estado' = 'outro_codigo' and r->>'codigo_secreto' = segredo_ana);
  select count(*) into n from public.perfis;
  insert into _resultado values ('RLS: Ana so enxerga o proprio perfil', n = 1);
  cod_ana := public.meu_codigo_amigo();
  insert into _resultado values ('codigo de amigo gerado (6 caracteres)', cod_ana is not null and char_length(cod_ana) = 6);
  insert into _resultado values ('codigo de amigo estavel', public.meu_codigo_amigo() = cod_ana);
  begin
    perform 1 from public.saves_nuvem;
    insert into _resultado values ('tabela saves_nuvem fechada para leitura direta', false);
  exception when insufficient_privilege then
    insert into _resultado values ('tabela saves_nuvem fechada para leitura direta', true);
  end;

  -- Beto
  perform set_config('request.jwt.claims', json_build_object('sub', beto, 'role', 'authenticated')::text, true);
  r := public.vincular_conta(segredo_ana, 'BETO');
  insert into _resultado values ('codigo ja usado por outra conta e recusado', r->>'estado' = 'codigo_em_uso');
  r := public.vincular_conta(segredo_beto, 'BETO');
  insert into _resultado values ('Beto vincula o proprio codigo', r->>'estado' = 'ok');
  cod_beto := public.meu_codigo_amigo();

  -- Nuvem (Beto)
  r := public.salvar_nuvem('pacote1', 0, '1.0', 2, 'PC');
  insert into _resultado values ('nuvem: primeiro envio cria revisao 1', r->>'estado' = 'ok' and (r->>'rev')::int = 1);
  r := public.salvar_nuvem('pacote2', 0, '1.0', 2, 'CELULAR');
  insert into _resultado values ('nuvem: envio sem conhecer a revisao e conflito', r->>'estado' = 'conflito' and (r->>'rev')::int = 1);
  r := public.meta_nuvem();
  insert into _resultado values ('nuvem: meta informa a revisao', (r->>'existe')::boolean and (r->>'rev')::int = 1);
  r := public.baixar_nuvem(false);
  insert into _resultado values ('nuvem: baixa o ultimo pacote', r->>'pacote' = 'pacote1');
  r := public.salvar_nuvem('pacote3', 99, '1.0', 2, 'PC');
  insert into _resultado values ('nuvem: revisao errada e conflito', r->>'estado' = 'conflito');
  r := public.salvar_nuvem(repeat('x', 1500001), 1, '1.0', 2, 'PC');
  insert into _resultado values ('nuvem: pacote grande demais recusado', r->>'estado' = 'tamanho_invalido');

  -- Amizade (Ana pede, Beto aceita)
  perform set_config('request.jwt.claims', json_build_object('sub', ana, 'role', 'authenticated')::text, true);
  r := public.pedir_amizade('ZZZZZZ');
  insert into _resultado values ('amizade: codigo inexistente', r->>'estado' = 'nao_encontrado');
  r := public.pedir_amizade(cod_ana);
  insert into _resultado values ('amizade: nao da para pedir a si mesmo', r->>'estado' = 'proprio');
  r := public.pedir_amizade(lower(cod_beto));
  insert into _resultado values ('amizade: pedido enviado (codigo em minuscula)', r->>'estado' = 'enviado');
  r := public.pedir_amizade(cod_beto);
  insert into _resultado values ('amizade: pedido repetido', r->>'estado' = 'ja_pedido');
  r := public.enviar_convite(cod_beto, 'coop', 'ABCDEF012345', 3);
  insert into _resultado values ('convite: so entre amigos', r->>'estado' = 'nao_sao_amigos');

  perform set_config('request.jwt.claims', json_build_object('sub', beto, 'role', 'authenticated')::text, true);
  r := public.listar_amigos();
  insert into _resultado values ('amizade: Beto ve o pedido recebido', r->'lista'->0->>'estado' = 'recebido' and r->'lista'->0->>'apelido' = 'ANA' and not (r->'lista'->0 ? 'id'));
  perform public.responder_amizade(cod_ana, true);
  r := public.listar_amigos();
  insert into _resultado values ('amizade: aceita vira amigo', r->'lista'->0->>'estado' = 'amigo');

  -- Convite (Ana -> Beto)
  perform set_config('request.jwt.claims', json_build_object('sub', ana, 'role', 'authenticated')::text, true);
  r := public.enviar_convite(cod_beto, 'coop', 'ABCDEF012345', 3);
  insert into _resultado values ('convite enviado', r->>'estado' = 'ok');
  r := public.enviar_convite(cod_beto, 'coop', 'ABCDEF012345', 3);
  insert into _resultado values ('convite: limite de 1 a cada 5 s', r->>'estado' = 'rapido');
  r := public.enviar_convite(cod_beto, 'ataque', 'X', 1);
  insert into _resultado values ('convite: tipo invalido recusado', r->>'estado' = 'convite_invalido');

  perform set_config('request.jwt.claims', json_build_object('sub', beto, 'role', 'authenticated')::text, true);
  r := public.listar_convites();
  id_convite := (r->'lista'->0->>'id')::bigint;
  insert into _resultado values ('convite: Beto recebe com apelido, sala e andar',
    r->'lista'->0->>'de' = 'ANA' and r->'lista'->0->>'sala' = 'ABCDEF012345' and (r->'lista'->0->>'andar')::int = 3);

  -- Caio nao ve convites alheios nem descarta convite de outro
  perform set_config('request.jwt.claims', json_build_object('sub', caio, 'role', 'authenticated')::text, true);
  perform public.vincular_conta(repeat('d4', 18), 'CAIO');
  r := public.listar_convites();
  insert into _resultado values ('convite: terceiro nao ve convite alheio', jsonb_array_length(r->'lista') = 0);
  perform public.descartar_convite(id_convite);
  perform set_config('request.jwt.claims', json_build_object('sub', beto, 'role', 'authenticated')::text, true);
  r := public.listar_convites();
  insert into _resultado values ('convite: terceiro nao descarta convite alheio', jsonb_array_length(r->'lista') = 1);
  perform public.descartar_convite(id_convite);
  r := public.listar_convites();
  insert into _resultado values ('convite: o dono descarta', jsonb_array_length(r->'lista') = 0);

  -- Remover amizade
  perform public.remover_amizade(cod_ana);
  r := public.listar_amigos();
  insert into _resultado values ('amizade: remover apaga dos dois lados', jsonb_array_length(r->'lista') = 0);

  -- Sem login
  perform set_config('request.jwt.claims', '{}', true);
  r := public.meta_nuvem();
  insert into _resultado values ('sem login: funcoes recusam', r->>'estado' = 'sem_login');
end;
$$;

reset role;
select count(*) filter (where ok) as passou, count(*) filter (where not ok) as falhou,
       coalesce(string_agg(passo, '; ') filter (where not ok), 'nenhum') as falhas
  from _resultado;
rollback;
