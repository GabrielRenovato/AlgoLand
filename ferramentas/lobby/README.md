# Lobby opcional na cidade

`codigo/globais/chat_global.gd`, filho persistente de `Cooperativo`, mantém uma sessão por personagem local em qualquer mapa. `cidade.gd` cria `LobbyCidade` apenas para os avatares da cidade externa; `jogador_lobby.gd` desenha somente aparência e movimento, usando o compositor Raven existente. NPCs, missões, inventário e progresso continuam locais.

`codigo/ui/falas_lobby.gd` desenha balões na câmera e escala de cada vista, com a mesma moldura das falas dos NPCs. Mensagens novas aparecem sobre o remetente por alguns segundos, no máximo três linhas por trecho; o histórico inicial não gera balões e offline remove as falas.

O chat global começa offline. A tela de pausa oferece **CHAT GLOBAL / ONLINE** em todos os mapas, também com controle; o chat tem teclado virtual **ABC**. No PC o canto inferior esquerdo mostra o registro do chat (últimas 30 mensagens, translúcido) com um campo de texto: Enter foca o campo, Enter envia e devolve o controle ao jogo, Esc cancela; `Controle.digitando` zera o movimento enquanto escreve. Offline, o registro mostra o estado e Enter abre o painel central com a escolha online/offline. Celular e tela dividida com toque mantêm o ícone de balão no canto, que abre o painel central. O campo do canto é só do jogador 1; o P2 usa o painel central. `opcoes.cfg`, seção `lobby`, guarda `online_p1` e `online_p2` separadamente. Viajar mantém identidade, conexão, histórico e envio pendente. O retorno ao menu encerra a sessão após a curta tolerância de troca de cena; trocar de mundo solo/coop limpa as sessões para não misturar perfis. Fora da cidade, consultas em repouso usam 3 s; enviar respeita somente o restante dos 0,55 s desde o pedido anterior.

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

## Canal global

`20261024090000_chat_global.sql` adiciona o RPC `chat_global`, reutilizando o histórico, nonce, filtros e orçamento existentes. A flag `cidade` publica presença visual somente na praça; os demais mapas não enviam posições do mundo nem geram avatares na cidade. As oito vagas continuam limitando a presença visual, sem impedir mensagens globais quando ocupadas. Os RPCs antigos continuam disponíveis e compartilham o mesmo histórico. Não há novo autoload nem alteração no núcleo do aplicativo.

`python3 testes/teste_chat_global.py` testa dois clientes em mapas diferentes, viagem fenda→floresta, histórico, ausência de avatares fantasmas e interface móvel. `teste_chat_global.sql` roda em banco isolado e usa rollback; nunca executar os testes de mensagens no servidor dos jogadores.

## Presença por mapa (cidade, floresta e praia)

`20261024140000_lobby_mapas.sql` acrescenta `mapa` (0 a 3) às sessões e redefine `chat_global` e `lobby_cidade_sair`. O cliente envia `mapa` (1 cidade, 2 floresta, 3 praia) e mantém `cidade` verdadeiro só na praça, então servidores sem a migração continuam funcionando: a floresta e a praia apenas não mostram avatares até aplicá-la. Cada jogador recebe somente quem está no mesmo mapa; as oito vagas valem para todos os mapas juntos e quem está online sem mapa (RPC antigo) conta como cidade. Sair zera o mapa na hora. `lobby_cidade.gd` é criado por `cidade.gd` (cidade e praia, `local`) e por `floresta.gd`, com `mapa` próprio; as posições viajam no envelope 1024×576 e cada mapa as escala pelos próprios `limites` (cidade 1024×576, praia 704×576, floresta 1408×864). A floresta não tem grade de navegação: o avatar remoto anda em linha reta entre as amostras.

Validação: `teste_lobby_mapas.sql` (e os testes SQL anteriores) contra um Postgres isolado, por exemplo `podman run -d --rm --name lobbydb -e POSTGRES_PASSWORD=x postgres:17-alpine`, criando os papéis `anon` e `authenticated` e uma `apelido_proibido` de teste antes das migrações; `python3 testes/teste_chat_global.py` confere dois clientes se encontrando na floresta e na praia.

## Servidor próprio (WebSocket)

`ferramentas/lobby/servidor/` substitui as consultas HTTP ao banco por uma conexão WebSocket quando existe `LOBBY_WS` (`ranking_config.gd`), `[lobby] servidor` em `opcoes.cfg` ou `--lobby-ws=`. Sem endereço, o jogo continua usando o RPC `chat_global` (e a migração `20261024140000_lobby_mapas.sql` só é necessária nesse caminho). A presença deixa de gastar a cota do Supabase, as amostras chegam a 4 Hz e o limite sobe de 8 para 24 avatares por mapa. `sessao_lobby.gd` mantém um único `_processar` para as duas formas de resposta. Detalhes, execução e túnel de teste em `servidor/README.md`. `python3 testes/teste_chat_global.py --ws` (e `teste_lobby_cidade.py --ws`) sobem o servidor e dois jogos reais.

