# Servidor do lobby (WebSocket)

Presença por mapa (cidade, floresta e praia) e chat global sem passar pelo banco: posições e jogadores online ficam só na memória do processo, e nada pessoal é gravado. Ranking e apelidos continuam no Supabase, direto do jogo. A identidade é o hash do código secreto do perfil (nunca publicado). O formato das respostas é o mesmo do RPC `chat_global`, então o jogo reaproveita o parser.

## Rodar

```bash
cd ferramentas/lobby/servidor
npm install
node servidor.mjs            # porta 8787 (PORTA=...), /saude mostra quantos estão online
node teste.mjs               # testes do servidor com clientes WebSocket reais
```

Variáveis: `PORTA`, `MAX_CONEXOES` (200), `MAX_POR_MAPA` (24), `EXPIRA_MS` (20000, tempo sem estado até sumir), `ORIGENS_PERMITIDAS` (lista separada por vírgula; vazio aceita todas, inclusive o jogo nativo, que não envia origem).

Em container: `docker build -t algoland-lobby . && docker run -p 8787:8787 algoland-lobby` (o mesmo serve no Fly.io, em região `gru`, com uma máquina sempre ligada e sem desligar por inatividade).

## Teste na própria máquina (túnel temporário)

`./testar_na_minha_maquina.sh` sobe o servidor e um túnel "quick" da Cloudflare (sem conta, via podman) e imprime `wss://...trycloudflare.com`. O endereço muda a cada execução e não há garantia de disponibilidade: serve para testar. Como serviço de usuário: `systemd-run --user --unit=algoland-lobby ./testar_na_minha_maquina.sh` (logs: `journalctl --user -u algoland-lobby`; parar: `systemctl --user stop algoland-lobby`).

Para o jogo usar o servidor, qualquer um destes (só `wss://` ou `ws://127.0.0.1`, porque o código secreto vai na entrada):
- argumento: `flatpak run org.godotengine.Godot --path . -- --lobby-ws=wss://ENDERECO`
- `opcoes.cfg`: seção `[lobby]`, `servidor="wss://ENDERECO"`
- padrão do jogo: `LOBBY_WS` em `codigo/dados/ranking_config.gd` (vazio = continua pelo banco)

Depois ligue **CHAT GLOBAL / ONLINE** na pausa. Duas instâncias com o mesmo perfil se substituem (a mais nova assume); para ver dois avatares é preciso outro perfil, outro aparelho ou o P2 do cooperativo.

## Protocolo

Cliente para servidor, em JSON de texto: `{"t":"entrar","codigo","geracao","depois","estado"}` (primeira mensagem, em até 5 s), `{"t":"estado","estado":{mapa,x,y,direcao,andando,apelido,aparencia?}}` (a 4 Hz com presença; a cada 4 s sem presença; o servidor remove quem fica 20 s calado), `{"t":"msg","texto","envio"}` (160 caracteres, 0,5 s entre mensagens, `envio` é um nonce hexadecimal que evita duplicar) e `{"t":"sair"}`. Posições vão no envelope 1024×576 e o jogo escala cada mapa. Servidor para cliente: objetos `{eu,mapa,jogadores,mensagens,confirmado,aviso,limite}` quando algo muda, ou `{erro}`. Máximo de 30 mensagens por segundo por conexão e 8 KiB por mensagem.

Lotação: `MAX_POR_MAPA` avatares por mapa; quem não cabe fica conectado e conversa, sem avatar. Mesmo perfil reconectando assume a identidade e derruba a conexão antiga (`substituida`).

## Painel de controle (no seu PC)

`./abrir_painel.sh` abre `http://127.0.0.1:8790`: liga, desliga e reinicia o serviço `algoland-lobby`, libera ou bloqueia o acesso pela internet (Tailscale Funnel) e mostra jogadores online (apelido, mapa, há quanto tempo), contagem por mapa, pico, conexões, mensagens recentes e recusadas, ações, memória e o registro do serviço, atualizando a cada 2 s. O servidor expõe esses dados em `127.0.0.1:8788/estado` (porta administrativa, em outra porta que o Funnel nunca publica; sem códigos secretos). O painel só aceita `127.0.0.1`/`localhost`, as ações exigem o token que a página recebe e recusam outra origem. Para subir sempre com a sessão: `cp painel/algoland-painel.service ~/.config/systemd/user/ && systemctl --user daemon-reload && systemctl --user enable --now algoland-painel`.

## Dormir quando vazio (ativação por socket)

Com `socket/algoland-lobby.socket` e `socket/algoland-lobby.service`, o systemd mantém a porta 8787 aberta (só em `127.0.0.1`, para onde o Funnel entrega) e **só sobe o servidor quando alguém conecta**. Depois de `OCIOSO_MS` (padrão 10 min) sem nenhum jogador online, ele encerra sozinho e libera a memória; a conexão seguinte o acorda em uma fração de segundo (o systemd segura a conexão até ele estar pronto). Os contadores do painel zeram a cada despertar. O painel mostra "Dormindo", e **Desligar** fecha também a porta, para nada acordar o servidor. Isso economiza só uns 20 MB de memória: o gasto real é o computador ligado.

Trocar o serviço sempre ligado por este modo:

```bash
cd ~/AlgoLand/ferramentas/lobby/servidor && systemctl --user disable --now algoland-lobby && cp socket/algoland-lobby.service socket/algoland-lobby.socket ~/.config/systemd/user/ && systemctl --user daemon-reload && systemctl --user enable --now algoland-lobby.socket
```

Voltar ao modo sempre ligado: `systemctl --user disable --now algoland-lobby.socket algoland-lobby.service`, copiar `algoland-lobby.service` desta pasta e `systemctl --user enable --now algoland-lobby`.

