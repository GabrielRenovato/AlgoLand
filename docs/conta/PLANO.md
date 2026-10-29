# Sistema de conta

Decisões (29/10/2026): e-mail e senha pelo Supabase Auth; a conta guarda identidade, save na nuvem e amigos/salas;
a conta é obrigatória, mas quem já joga vincula o progresso atual sem perder nada.

## Modelo
- Identidade atual: código secreto local (`ranking.json`) enviado como `p_codigo` às RPCs de ranking, mercado e transferência.
- A conta é o **cofre desse código**: `perfis.codigo_secreto` (RLS: só o dono lê). Vincular não muda nenhuma RPC existente.
- Em outro aparelho, o login devolve o mesmo código; na fase 2 a nuvem traz também o save.

## Fases
1. **Conta e vínculo** (feito): `codigo/conta/cliente_conta.gd`, `tela_conta.gd`, SQL `ferramentas/conta/20261029200000_conta.sql`.
   Chave `Config`-like `CONTA_OBRIGATORIA` fica **falsa** até o Supabase estar configurado (ver abaixo).
2. **Save na nuvem** (feito): `ferramentas/conta/20261029210000_nuvem.sql` (`saves_nuvem` com revisão, versão anterior guardada) e
   `codigo/conta/nuvem_save.gd`. Reaproveita `transferencia_save.gd`. Sobe ao criar a conta, ao dormir e ao sair; baixa só no menu inicial;
   conflito abre `conflito_nuvem.gd` (manter este aparelho / usar a nuvem), sempre com cópia local em `user://backups` e a anterior na nuvem.
   Menu de pausa tem CONTA (`painel_conta.gd`) para criar a conta no meio do jogo. Só o mundo solo vai à nuvem (o coop local não).
3. **Amigos e convites** (feito): `20261029220000_amigos.sql` (código de amigo curto, pedidos, convites de 5 min só entre amigos), `codigo/conta/amigos.gd`, `tela_amigos.gd`, `convite_popup.gd`. Botões AMIGOS no menu de pausa e no painel da conta; CONVIDAR na sala do coop. Convites chegam por consulta a cada 25 s. Convite de **duelo** ainda não tem tela (a RPC aceita o tipo; falta ligar a sala do duelo).
4. **Identidade nos servidores** (feito): `ferramentas/lobby/servidor/conta.mjs` confere o token no `entrar` (pergunta ao Auth quem é o dono, com cache); lobby, coop e duelo enviam o token. `EXIGIR_CONTA=1` no `fly.toml` recusa quem entra sem conta; hoje `0`. **Exige deploy do servidor** para valer.

## Antes de ligar a obrigatoriedade (no painel do Supabase)
- Authentication > Providers > Email ligado.
- Confirmação de e-mail: desligada, ou SMTP próprio. O serviço de e-mail padrão tem limite de poucos envios por hora.
- Authentication > URL Configuration: definir o Site URL.
- SQL: aplicado em 29/10 pela CLI (`npx supabase db query --linked --project-ref mqaurdqxvpxoqccypqnh -f arquivo.sql`): `conta`, `nuvem` e `amigos`. `ferramentas/conta/teste_conta.sql` roda numa transação com rollback (31 checagens, nada fica no banco).

## Testes (servidor falso local, nunca produção)
`python3 ferramentas/conta/servidor_falso.py 8799 &` e, na cópia de testes com `override.cfg` (`custom_user_dir_name="AlgoLand testes conta"`),
`--script res://ferramentas/conta/teste_conta_local.gd`, `teste_nuvem_local.gd` e `teste_nuvem_titulo.gd` com `-- --conta-url=http://127.0.0.1:8799`.
