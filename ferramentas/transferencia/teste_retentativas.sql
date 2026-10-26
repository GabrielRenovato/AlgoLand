-- Executar após corrigir_retentativas.sql. Todas as escritas são desfeitas.
begin;
set local role anon;
do $$
declare
 segredo text := 'teste-retentativas-' || gen_random_uuid()::text;
 primeiro jsonb;
 repetido jsonb;
 segundo jsonb;
 recebido jsonb;
 resultado jsonb;
 i int;
begin
 primeiro := public.transferencia_enviar(segredo, '{"teste":1}');
 assert primeiro ? 'codigo', 'gera o primeiro código';
 repetido := public.transferencia_enviar(segredo, '{"teste":1}');
 assert primeiro->>'codigo' = repetido->>'codigo', 'reenviar o mesmo save preserva o código';
 segundo := public.transferencia_enviar(segredo, '{"teste":2}');
 assert segundo ? 'codigo', 'gera código para o save atualizado';
 recebido := public.transferencia_receber(lower(primeiro->>'codigo'));
 assert recebido->>'dados' = '{"teste":1}', 'novo envio não invalida código anterior';
 repetido := public.transferencia_receber(primeiro->>'codigo');
 assert recebido = repetido, 'resposta perdida ou importação cancelada permite nova tentativa';
 resultado := public.transferencia_confirmar(primeiro->>'codigo', 'outra-identidade-' || gen_random_uuid()::text);
 assert resultado->>'ok' = 'false', 'outra identidade não pode encerrar o código';
 assert public.transferencia_receber(primeiro->>'codigo') = recebido, 'confirmação incorreta preserva o código';
 resultado := public.transferencia_confirmar(primeiro->>'codigo', segredo);
 assert resultado->>'ok' = 'true', 'confirmação da importação encerra o código';
 assert public.transferencia_receber(primeiro->>'codigo')->>'erro' = 'nao_encontrado', 'código confirmado não funciona novamente';
 assert public.transferencia_receber(segundo->>'codigo')->>'dados' = '{"teste":2}', 'outro código continua válido';
 for i in 3..11 loop
  resultado := public.transferencia_enviar(segredo, jsonb_build_object('teste',i)::text);
  assert resultado ? 'codigo', 'até dez códigos ativos';
 end loop;
 resultado := public.transferencia_enviar(segredo, '{"teste":12}');
 assert resultado->>'erro' = 'muitos_envios', 'limita os códigos ativos';
 assert public.transferencia_receber('x')->>'erro' = 'codigo_invalido', 'código incompleto é recusado';
 assert not has_table_privilege('anon','public.transferencias_save','select'), 'pacotes não são listáveis por clientes';
end $$;
reset role;
do $$
declare
 segredo text := 'teste-expiracao-' || gen_random_uuid()::text;
 envio jsonb;
begin
 envio := public.transferencia_enviar(segredo, '{"teste":true}');
 update public.transferencias_save set expira_em=now()-interval '1 second' where codigo=envio->>'codigo';
 assert public.transferencia_receber(envio->>'codigo')->>'erro' = 'nao_encontrado', 'prazo de validade continua sendo respeitado';
end $$;
rollback;
select 'Retentativas, reenvios, confirmação, limites, expiração e permissões: OK' as resultado;
