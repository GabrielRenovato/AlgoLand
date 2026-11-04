# Harness do AlgoLand

Entrada única para diminuir leituras repetidas, comandos improvisados e logs na conversa. Usa os runners existentes; não substitui a revisão visual nem certifica aparelhos físicos.

Execute na raiz do jogo:

```bash
python3 ferramentas/projeto/harness.py contexto
python3 ferramentas/projeto/harness.py testar --perfil NOME
```

| Perfil | O que executa |
| --- | --- |
| `interface-campanha` | Tema da Primeira Raiz, fontes com acentos, raio de 4 px, salas e resultado real da tentativa: dano efetivo, 19 abates, drop azul, coleta, maestria, controles e reinício. Capturas em desktop, paisagem, retrato e tela dividida. |
| `instancias-campanha` | Duas entradas por estágio, objetivos/baú/inimigos/Cerne reiniciados, azul por tentativa, itens e maestria preservados, entrega do pomar entre regiões e cinema pulável nas três proporções. Saves isolados; revisar capturas. |
| `drops-iniciais` | Tabelas dos dois estágios, peça azul do Cerne, acessórios e slots persistentes, pendência com mochila cheia, coleta única e renderização das quatro peças no jogador. Revisar imagens e movimento. |
| `maestria` | Sete arvores de arma, curva e pontos, persistencia e recibos da rede, tecnicas no combate real e nos/tooltip em paisagem, retrato e tela dividida. Saves isolados; exige revisao das capturas. |
| `salas-campanha` | Detalhes do estágio, salas abertas, entrada rápida, quatro personagens, líder/convidado, conversa e encaixe de textos em desktop, retrato e tela dividida. A sala real e o chat também são verificados por `campanha-online`. |
| `cerne-partido` | Queda anunciada, dano e empurrão únicos, combo, segunda fase, apoios cortáveis, vulnerabilidade, morte, quadros e reprodução no Godot. Save isolado; exige revisão das capturas e do movimento. |
| `mapas-modulares` | Clareira com terreno reutilizável, objetos independentes, transições locais, remoção sem resíduo no fundo, densidade nativa para desktop, quatro estações e capturas em 1080p/1440p. Registra custo de renderização; não transforma resultado funcional em aprovação artística. |
| `monstro-raizes` | Rebento animado: combo em duas etapas, avisos e erupções, esquiva, interrupção, bloqueio por parede, morte única e capturas das poses no Godot. Revisar contatos e GIFs, além da reprodução real; testes não aprovam a arte. |
| `estrada-carreteiros` | Segundo estágio modular: quatro estações, carroça e abrigo, passagem física das rotas, posições dos encontros, perseguição real, investigação/resgate sem abate obrigatório e telas pequenas. Execução isolada, sem testar o primeiro estágio nem o percurso completo. |
| `goblins-pomar` | Rig e empunhadura Mixamo, laudo de interseções vinculado ao GLB, 32 goblins no estágio 4, entrada segura, impacto único, esquiva, recuo, parede, reentrada e capturas reais do pomar. |
| `campanha-percurso` | Percurso experimental e navegação mundo → andar → regiões → cenário, com capturas em paisagem/retrato. Cobre quatro terrenos próprios sazonais, equipamentos reais, ataque, derrota/retomada e encaixe do toque. NPCs e inimigo reutilizados; não certifica campanha final, multiplayer ou crafting real. |
| `campanha` | Catálogo do primeiro andar e persistência isolada por perfil: dependências, relíquia fixa, idempotência, arquivos incompatíveis e reabertura em outro processo Godot. Não certifica mapas, objetivos, multiplayer ou UI ainda não integrados. |
| `web` | Fontes, glifos e margens da conta com GPU, incluindo rotação. |
| `coop-online` | Servidor local, anfitrião e convidado por WebRTC; golpe físico, maestria confirmada pelo anfitrião, equipamento trocado após entrar e rejeição de poderes elementais antigos. Usa o modo `--somente-conjuntos` do teste existente. Não é a bateria completa do coop. |
| `conjuntos` | Regras e bônus dos conjuntos. |
| `pacotes` | Formato, partição e regressões do empacotador. |
| `harness` | Regressões de cache, falhas, processos e conferência de publicação. |
| `selecionado` | Um ou mais testes existentes, informados com `--teste NOME`; exige seleção explícita. |
| `web-browser` | Build já preparado, navegador Chromium descartável com perfil de celular, digitação e três capturas. Exige `--url` ou `--build`. |

`--teste NOME` seleciona um teste do runner comum, sem o prefixo `teste_` ou extensão. Não se aplica a `coop-online`/`web-browser`. O harness não escolhe uma bateria ampla sozinho. `contexto` sugere perfis pelos caminhos alterados; a seleção final deve acompanhar o sistema da tarefa.

## Reuso e relatórios

Testes aprovados são reutilizados por padrão somente com os mesmos conteúdos versionados/alterados (inclusive recursos, arquivos novos e removidos), motor, perfil, seleção e limite. Usa os hashes do índice e lê do disco apenas as alterações; commitar os mesmos bytes não exige repetir o teste. Uma edição durante a execução invalida o resultado. Falhas não entram no cache. Use `--forcar` quando houver uma razão para repetir, por exemplo uma mudança externa ao repositório.

Logs, saves, capturas e JSON ficam sob `/tmp/algoland-harness/execucao-*`; `ultimo.json` aponta o relatório mais recente. `--cache /tmp/OUTRA-PASTA` separa sessões. O coop inicia e encerra o próprio servidor e os dois processos; um erro fatal interrompe ambos. Os saves usam `XDG_DATA_HOME` isolado também no Flatpak.

A saída mostra um resumo e até três erros por etapa. Os diagnósticos conhecidos de encerramento continuam no JSON/log. Não varrer logs inteiros se o resumo já explica o resultado.

Nos perfis gráficos, abra as capturas listadas em `relatorio.json` e inspecione a renderização real. O resultado funcional e seu reuso deixam `revisao_visual: pendente`: não representam aprovação artística, inspeção em celular físico ou validação de todas as telas do jogo.

Para o navegador, use o Playwright já previsto no `package.json` da wiki. O harness pode servir o build local e encerrar o servidor ao terminar:

```bash
python3 ferramentas/projeto/harness.py testar --perfil web-browser \
  --build ../AlgoLand-wiki/dist
```

Para um servidor já aberto, troque `--build` por `--url http://127.0.0.1:4173/jogar/`. O teste usa uma sessão nova e não envia o formulário da conta. `web-browser` sempre executa; não reutiliza um resultado para um servidor que pode ter mudado.

## Conferir e publicar

```bash
# Somente arquivos locais; não exporta, publica ou altera o site.
python3 ferramentas/projeto/harness.py publicacao

# Espera os manifestos locais aparecerem no endereço e confere os arquivos por SHA256.
python3 ferramentas/projeto/harness.py publicacao \
  --url https://wikialgoland.netlify.app/jogar/ --esperar 600

# Mostra os passos sem escrever arquivos, commit ou push.
python3 ferramentas/projeto/harness.py publicar --resumo "Descrição da mudança" --simular

# Executa a publicação quando ela tiver sido solicitada.
python3 ferramentas/projeto/harness.py publicar --resumo "Descrição da mudança"
```

A conferência valida as assinaturas RSA e hashes das três plataformas, a igualdade dos números de conteúdo, as partes e o hash completo do Web e a casca processada. Com `--url`, compara os dois manifestos e baixa os arquivos para conferir seus hashes; não usa cache de aprovação. Uma falha retorna código diferente de zero e grava relatório.

O publicador existente gera os patches, exporta o Web, compila a wiki, confere os arquivos locais, faz commit/push e só informa conclusão após verificar a hospedagem. Logs extensos vão para `/tmp/algoland-publicar-*`. Ele preserva o comportamento existente de incluir alterações pendentes em `codigo/`, `cenas/`, `recursos/` e na wiki: confira o escopo antes de chamá-lo. Publicar não executa automaticamente todos os testes ou uma revisão visual; execute os perfis pertinentes antes. Se falhar depois de gerar parte das plataformas, confira os manifestos locais antes de tentar novamente; números divergentes bloqueiam a publicação.

Para economizar contexto em uma tarefa nova, rode `contexto`, leia apenas o sistema indicado, execute o perfil pertinente e consulte o JSON somente quando houver falha ou revisão visual necessária. O mapa técnico continua sendo a referência para sistemas que ainda não têm perfil.

## Contexto e configurações econômicas

O `AGENTS.md` mantém o fluxo geral; `REGRAS_VISUAIS.md` guarda integralmente as regras de personagens, armaduras e cenários. Ler essa referência antes dessas tarefas, inclusive alterações por código. As regras globais de interface continuam valendo.

`.codex/config.toml` define para novas sessões locais neste projeto: GPT-6 Luna, raciocínio baixo e Standard. Seleções explícitas e políticas do ambiente prevalecem; esse arquivo não troca o modelo de uma conversa já aberta. Para integrações, selecionar o modelo intermediário; elevar capacidade/esforço quando a dificuldade exigir, conforme a skill econômica.

Apps conectados ficam desabilitados por padrão neste projeto, assim como PixelLab e os plugins locais Sites, Work Pets e OpenAI Templates. As instalações, credenciais e configurações globais ficam preservadas. Ferramentas nativas de shell, busca, imagens e revisão local continuam disponíveis. Ambientes gerenciados podem fornecer ferramentas independentemente desse arquivo; a lista do chat atual não foi recarregada.

Quando uma tarefa exigir essas integrações, habilitar apenas a necessária nas configurações do projeto ou com override para aquela execução. Exemplos no CLI:

```bash
codex -c 'mcp_servers.pixellab.enabled=true'
codex -c 'apps._default.enabled=true'
codex -c 'plugins."sites@openai-curated-remote".enabled=true'
```

O segundo comando reativa os apps conectados para aquela execução. Preferir `apps.ID.enabled=true` quando o ID específico for conhecido. Não desinstalar integrações para reduzir contexto.

Para sistemas ainda sem perfil próprio, selecionar testes existentes sem improvisar outro runner:

```bash
python3 ferramentas/projeto/harness.py testar --perfil selecionado --teste inventario
```

Criar um perfil dedicado quando a mesma seleção se repetir e os testes forem pertinentes; não executar uma bateria ampla só para economizar comandos.

Ao separar assuntos grandes, preparar um resumo curto, revisar as pendências e colar em outra conversa:

```bash
python3 ferramentas/projeto/harness.py retomar \
  --objetivo "Corrigir inventário" --pendente "Inspecionar a tela no celular" \
  --saida /tmp/algoland-retomar.txt
```

O arquivo deve ser novo: o comando não sobrescreve trabalho existente. Sem `--saida`, imprime o resumo. Ele registra objetivo, commit, caminhos alterados e pendências explícitas, sem abrir chats, presumir testes aprovados ou transferir autorização de publicação. Separar conversas não reinicia a cota. Resumos são temporários, fora do mapa técnico.

Referência das opções de configuração: https://learn.chatgpt.com/docs/config-file/config-reference

## Abrir a campanha experimental

```bash
python3 ferramentas/projeto/jogar_campanha.py
```

O launcher cria uma cópia do projeto e dados separados em `/tmp/algoland-campanha-jogavel`. Abre primeiro o mapa-múndi; escolher o andar 1 abre o mapa regional, onde o jogador seleciona um destino e confirma a entrada. O botão de mapa no cenário retorna às regiões. O andar 2 fica em preparação.

Quatro destinos do percurso usam o mesmo terreno existente como cenário temporário, com pontos de interação diferentes. A imagem regional é um estudo gerado, não prova de mapas produzidos. Dara usa uma aparência existente temporária; o inimigo inicial é um slime existente. Interações de ofício/reparo validam a sequência de objetivos, mas ainda não executam a fabricação e o consumo de materiais definitivos. A rede de cidade e grupo não está integrada nesse fluxo experimental.

Movimento e ataque usam os controles atuais do jogador; `E` ou o botão inferior interage com o ponto próximo. O progresso parcial é preservado nesse perfil de teste. `--pasta /tmp/OUTRA-PASTA` permite uma sessão de dados separada, fora do repositório.

`campanha` cobre catálogo, persistência e controlador de objetivos (incluindo reabertura parcial em processo novo). `campanha-percurso` cobre o cenário gráfico e os seletores. Inspecionar as capturas continua obrigatório; o harness mantém a revisão visual como pendente até a análise humana/visual. Avisos conhecidos de recursos gráficos no encerramento permanecem nos logs.

## Critério de montagem dos mapas

Uma ilustração inteira dividida em tiles continua sendo uma composição fixa. Cenários jogáveis devem ter terreno reutilizável com transições, água e margens próprias, e peças independentes com colisão e profundidade. O fluxo é analisar a referência inteira, decompor as peças, produzir com densidade nativa para desktop, montar, testar mudanças locais e revisar no motor.

O perfil `mapas-modulares` rejeita uma célula exclusiva por trecho de uma pintura, verifica edição local de terreno e remoção real de objeto, registra métricas e gera evidências visuais sazonais e de desktop. Ele cobre atualmente `clareiras_chegada.gd`; novos cenários devem ser acrescentados ao teste. As regras completas estão em [REGRAS_VISUAIS.md](REGRAS_VISUAIS.md#mapas-jogáveis-montagem-modular-obrigatória).

### Revisão da água animada

Aplicar o [contrato de água por quadros](REGRAS_VISUAIS.md#água-animação-por-quadros-obrigatória) em toda produção ou alteração de água. O relatório de `mapas-modulares` lista os critérios visuais pendentes; o resultado funcional não aprova o ciclo automaticamente.

- Conferir ficha com dimensões, grade, ordem, quantidade, FPS/durações e fechamento do ciclo; todos os quadros devem existir e corresponder ao movimento planejado.
- Inspecionar a folha de contato e ao menos dois ciclos reais no Godot, com a velocidade final, sem salto ou flash na repetição.
- Conferir tiles adjacentes, curvas e margens em todos os quadros; colisões e passagens permanecem estáveis.
- Revisar as quatro estações e o detalhe em desktop. Anexar caminhos das evidências e registrar pendências concretas.

Esses itens são critérios de revisão, não validações automáticas de atlas já implementadas. A água atual de `terreno_modular.gdshader` ainda usa deslocamento contínuo de UV e precisa ser convertida antes de ser aprovada nesse contrato.

## Instâncias dos estágios

Entrar pelo mapa, iniciar uma expedição ou recomeçar após derrota cria uma nova tentativa. O ponto inicial, tempo, objetivos, baú e encontros reiniciam; inventário, maestria, relíquias e acessos permanecem. As cenas da chegada e de Dara reaparecem com opção de pular.

`progresso_campanha.gd` grava `tentativas` separadamente do histórico de conclusões. Objetivos em outra região (pedido/entrega de Tomás) atravessam o mapa; entrar novamente no pomar reinicia a investigação e aproveita o pedido já recebido. O argumento `abrir_regiao(id,false)` restaura fixtures internas e não é usado pelo fluxo de entrada do jogador.

## Interface e relatório da campanha

`codigo/ui/estilo_campanha.gd` contém o tema local (Noto Sans, Noto Serif, papel, bronze, verde e raio de 4 px). Mapa, salas, falas de Dara, HUD, mochila, maestria, pausa e serviços da campanha o reutilizam. Controles marcados com `acabamento_campanha` preservam o acabamento local; o adaptador legado não reaplica sua arte nem desloca o fechar para fora da moldura. Os nós da árvore mantêm seus estados e os slots mantêm a raridade. A aplicação de fontes nos controles compartilhados é local à instância da campanha.

`registro_run.gd` acompanha a tentativa atual: dano efetivo, mortes, abates, vida perdida, bloqueios, drops e XP realmente adquirido. O anfitrião confirma o ranking por `resumo_campanha`; convidados rejeitam remetentes diferentes do anfitrião. O relatório não concede itens nem XP e pode ser reaberto pelo botão Relatório. O relatório usa slots com raridade e inspeção ao selecionar, faixa de estatísticas e placar com retratos. Em telas estreitas, Saque e Combate alternam as duas áreas; Saque é a aba inicial. A entrada revela título, recompensas e placar em sequência.

`codigo/campanha/tela_resultado.gd` é o componente do jogo; `ferramentas/campanha/previa_resultado_run.gd` apenas o apresenta com dados demonstrativos em um projeto isolado. Limpar os encontros abre o relatório de combate; a missão continua apontando a saída se ainda houver um objetivo. O diálogo de fim de estágio abre o relatório antes do mapa. Rejogar em grupo volta à preparação pelo mapa.
