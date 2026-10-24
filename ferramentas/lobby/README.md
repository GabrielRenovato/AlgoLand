# Lobby opcional na cidade

`cidade.gd` cria `LobbyCidade` apenas na cidade externa. `sessao_lobby.gd` mantém uma sessão por personagem local; `jogador_lobby.gd` desenha somente aparência e movimento, usando o compositor Raven existente. NPCs, missões, inventário e progresso continuam locais.

`codigo/ui/falas_lobby.gd` desenha balões na câmera e escala de cada vista, com a mesma moldura das falas dos NPCs. Mensagens novas aparecem sobre o remetente por alguns segundos, no máximo três linhas por trecho; o histórico inicial não gera balões e offline remove as falas.

A cidade começa offline. A tela de pausa oferece **CIDADE ONLINE / OFFLINE**, também com controle; o chat tem teclado virtual **ABC**. No PC o canto inferior esquerdo mostra o registro do chat (últimas 30 mensagens, translúcido) com um campo de texto: Enter foca o campo, Enter envia e devolve o controle ao jogo, Esc cancela; `Controle.digitando` zera o movimento enquanto escreve. Offline, o registro mostra o estado e Enter abre o painel central com a escolha online/offline. Celular e tela dividida com toque mantêm o ícone de balão no canto, que abre o painel central. O campo do canto é só do jogador 1; o P2 usa o painel central. `opcoes.cfg`, seção `lobby`, guarda `online_p1` e `online_p2` separadamente. Sair da cidade encerra a sessão; retornar respeita a preferência.

## Servidor

Aplicar as migrações SQL em ordem. Tabelas com RLS e sem acesso direto; RPCs recebem o segredo já existente do perfil e publicam somente UUID, apelido, aparência, posição e mensagens. Nunca incluir hash/código do perfil no snapshot. O envelope 1024×576 corresponde à cidade externa.

Oito participantes simultâneos; quem encontrar a sala cheia aguarda com reconexão. Consulta HTTPS a cada 0,55 s desde o início do pedido, sem somar outra espera após a resposta (o servidor recusa menos de 0,5 s; o avatar remoto interpola nesse tempo); queda de conexão remove remotos e tenta novamente. Presença expira em 20 s sem atualização. Gerações encerradas impedem um poll atrasado de religar o jogador que escolheu offline. Aparência por revisão evita repetir todos os sprites/dados; chat de 160 caracteres com intervalo de 0,5 s, nonce e confirmação evita duplicatas. Snapshots incluem o horário da posição no servidor; o avatar usa o tempo real entre amostras, ignora respostas antigas e não reinicia trechos ao receber a mesma posição. Retenção de 1 h e cerca de 500 mensagens; cada snapshot traz no máximo 40.

Não habilita plano pago, Auth adicional ou Realtime. Orçamento interno de 64 MiB/dia com margem por pedido e 500 identidades novas/dia interrompe o lobby ao alcançar o limite; o jogo local permanece disponível. Esse orçamento é estimado pelo payload e não substitui as métricas reais do provedor. Conferir o uso no painel antes de ampliar limites.

## Validação

- `python3 testes/teste_lobby_cidade.py`: duas instâncias Godot com servidor HTTP localhost, saves isolados, movimento, chat longo/idempotente, online/offline, preferência P1/P2, tela dividida e capturas em celular/desktop e quatro estações.
- `teste_lobby_latencia.gd`: pedido em trânsito, confirmação, intervalo restante, snapshots repetidos/antigos e movimento sem aceleração após atraso.
- `teste_banco.sql`: executar sobre o esquema aplicado em transação revertida; vagas, TTL, snapshots por revisão, apelidos, segredo, antispam, confirmação, saída vs poll tardio e orçamento.
- Scripts de testes e diretórios `AlgoLand testes...` não podem conectar ao servidor real; só o override localhost é aceito.

Distribuição por patch cumulativo da base 2026.10.23.1 e exportação Web própria. Não mudar autoloads/núcleo nem a versão do save para esta funcionalidade.
