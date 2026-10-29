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
2. **Save na nuvem**: tabela `saves_nuvem` com `rev` e `pacote`, reutilizando `transferencia_save.gd` (empacotar/validar/aplicar);
   sincroniza ao entrar, ao dormir e ao sair; conflito pergunta qual manter; sempre com backup local.
3. **Amigos e salas**: `amizades` + convites por conta; sala de coop/duelo por convite.
4. **Identidade nos servidores**: lobby/coop/duelo passam a conferir o token da conta.

## Antes de ligar a obrigatoriedade (no painel do Supabase)
- Authentication > Providers > Email ligado.
- Confirmação de e-mail: desligada, ou SMTP próprio. O serviço de e-mail padrão tem limite de poucos envios por hora.
- Authentication > URL Configuration: definir o Site URL.
- Aplicar `ferramentas/conta/20261029200000_conta.sql` no SQL Editor.
