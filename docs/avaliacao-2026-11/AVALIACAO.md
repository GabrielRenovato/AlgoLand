# Avaliação da campanha beta — 09/11/2026

Feita no Windows, rodando `testes/teste_interface_campanha.gd` numa cópia isolada (saves de teste) com o Godot 4.7.2. As capturas estão em `capturas/` e todas são da campanha "Primeira Raiz". Não é teste com jogador real. Ritmo, dificuldade e "sensação" de combate não foram avaliados, só a interface, a arte e o conteúdo.

## Veredito curto

A base está boa: a arte pixel do mundo é bonita e coerente, a tela de carregamento e o resultado da expedição têm cara de jogo pronto, e o texto narrativo tem voz própria. O que puxa para baixo é **acabamento de interface**: painéis que se sobrepõem, textos sem acento, ícones pequenos ou ilegíveis e um mapa num estilo de arte diferente do resto. Nada disso é estrutural; é uma rodada de polimento.

## O teste

- Resultado: **2 falhas** em ~60 verificações.
  - `saque do boss aparece com atributos reais`: nenhum drop `raro` recolhido do Cerne Partido. A tela de resultado mostra só 3 itens comuns (Anel de Cobre etc.).
  - `moldura cabe (960, 900)`: o painel de resultado não cabe na janela de 960×900.
- Erro repetido 65 vezes: `Parameter "scenario" is null` em `atlas_herois_3d.gd:95` (`registrar`), chamado por `heroi_base_3d.gd:1117` (`_procurar_atlas`). Não quebra a cena, mas suja o log e pode esconder erros reais.
- Antes de reimportar, o cache `.godot` deste Windows não tinha várias texturas (`primavera.png`, `brasao_raiz.svg`, `mapa_primeira_raiz_cartoon.png`, `tabuleiro.png`). Com isso, `seletor_campanha.gd` nem compilava. Depois de clonar ou trocar de máquina, é preciso rodar `--import` antes de testar.

## Pontos fortes

- **Mundo em pixel art** (`dialogo-576`, `inventario-576`): floresta densa, terreno de terra com borda orgânica, estandarte e baú com boa leitura. Parece um jogo comercial.
- **Carregamento da vila** (`carregamento-vila-576`): ilustração e texto ("Uma vila pequena que aprendeu a fechar os portões cedo…") criam expectativa e dão uma dica útil. É o melhor exemplo do tom do jogo.
- **Resultado da expedição** (`resultado-576`): hierarquia clara (espólios / registro de combate), destaque do item selecionado e três ações bem definidas.
- **Retrato** (`inventario-288`): o inventário se adapta bem ao celular em pé e mostra os atributos.

## Problemas, por prioridade

### Alta

> **Andamento (09/11/2026):** os itens 1 e 3 foram corrigidos e o item 2 não era bug. O teste foi ajustado e passa sem falhas. Detalhes no fim do arquivo.

1. **Painéis sobrepostos.** O painel de controles fica por baixo do diálogo e corta a coluna de teclas (`E / ESPACO` aparece pela metade, `dialogo-576`). A forja abre por cima do HUD e do painel de controles, que continuam visíveis atrás (`forja-576`). Regra sugerida: só um painel modal por vez, e o HUD esmaece quando há modal aberto.
2. **Drop raro do chefe não aparece** (falha do teste). O chefe é o clímax do estágio; sair dele só com comuns tira a recompensa.
3. **Acentos faltando de forma inconsistente.** "MISSÃO" e "Vila das Flores" vêm acentuados, mas aparecem `ESPACO`, `POCAO`, `Trancado`, `FABRICACAO SOMENTE`, `MATERIAIS NECESSARIOS`, `NIVEL`, `+6 Vida Maxima`. Parece que parte dos textos vem de tabelas antigas sem acento.

### Média
4. **Mapa em outro estilo de arte** (`mapa-576`): ilustração pintada em alta resolução, enquanto o jogo inteiro é pixel art. Além disso, um terço de baixo da tela é uma faixa azul vazia, e os marcadores das regiões são pequenos e sem nome.
5. **Árvore de maestria vazia e miúda** (`maestria-576`): ícones de 24 px num painel enorme, ícones repetidos entre nós, e a linha passa por cima do rótulo "DUELISTA". Metade direita sem uso. Faltam o tooltip ou um nó já selecionado para o jogador entender o que ganha.
6. **Forja assusta no começo** (`forja-576`): "Receitas 0/54", 10 páginas, itens trancados como silhuetas pretas e o arco pedindo "Fragmento da arena", que a campanha ainda não apresentou. Sugestão: mostrar só as receitas da região atual e esconder (não escurecer) o resto.
7. **HUD sem rótulo**: a barra amarela (fôlego?) não tem nome, e o `NV 0, 0%` fica pequeno e colado na barra. No retrato, o painel de missão fica cortado atrás do inventário.

### Baixa
8. Ícones de anel e amuleto no resultado estão borrados (escala não inteira).
9. O diálogo da Dara repete "siga a seta até o próximo objetivo", e a tela de resultado diz a mesma coisa logo antes.
10. O espaço vazio grande no painel de texto do carregamento poderia levar a ilustração maior ou uma dica de controle.
11. Em `primeiro_andar.json`, chegada, estrada e vila estão como `conteudo: "planejado"`, embora sejam jogáveis no beta (`REGIOES_HABILITADAS`). Só a Bacia do Moinho está como `jogavel`. Vale conferir se é intencional.

## Conteúdo da campanha

O manifesto tem 14 destinos e 19 missões (13 principais, 6 opcionais), mas o beta libera 4 regiões: chegada, estrada, vila e moinho. As missões principais jogáveis hoje são "Sobreviver à queda", "A estrada interrompida", "Um lugar na vila", "A primeira defesa" e "A água que deixou de voltar". As opcionais da vila incluem duas de pesca. Os nomes têm um tom bom e coerente ("O preço do material", "A proteção que virou ameaça"). A história promete bastante além do que o beta entrega, o que é bom para quem quer continuar jogando.

## Próximos passos sugeridos

1. Corrigir as duas falhas do teste e o erro `scenario is null`.
2. Revisar textos sem acento (buscar `CAO`, `NIVEL`, `Maxima`, `ESPACO` nos dados de interface).
3. Criar a regra de "um modal por vez" no gerenciador de interface.
4. Decidir o estilo do mapa: refazer em pixel art ou dar ao mapa uma moldura de "pergaminho" que justifique o estilo diferente.
5. Jogar os primeiros 20 minutos de verdade (no celular e no PC) para avaliar ritmo e combate, que este relatório não cobre.

## Vila e moradores: o que falta

Fontes: `teste_campanha_pesca_social.gd` (capturas `vila-entrada-576`, `pesca-576`, `mercado-576`), `codigo/dados/moradores_primeira_raiz.json`, `percurso_prototipo.gd` e `docs/narrativa/ROADMAP_PRIMEIRO_ANDAR.md`.

**O que já está bom:** a entrada da vila é a cena mais bonita do jogo (portões, estandartes, lampiões, cerca e flores). Os 15 moradores das personas existem, cada um com aparência, rotina e voz própria. As falas têm personalidade, e várias reagem ao progresso (Cerne derrubado, defesa vencida, água de volta).

### Bugs encontrados (resolvidos em 09/11/2026)
1. **Pedidos de pesca:** não era bug do jogo. Uma das falhas vinha de saves herdados de outro teste rodado na mesma cópia: no Windows não há o `testar_tudo.py`, então é preciso apagar `%APPDATA%/Godot/app_userdata/AlgoLand testes Carrasco` entre testes. As outras duas vinham do teste desatualizado: desde a missão da defesa, a primeira conversa com a Lia dá o aviso da defesa e só a segunda libera o pedido de carpas. O teste foi ajustado e passa sem falhas.
   - **Ponto de design:** o jogador não sabe que a Lia ainda tem um pedido depois do aviso. O "!" continua sobre ela, mas vale a conversa da defesa terminar com "Ah, e tenho um pedido sobre as carpas…".
2. **Marcador "!" sumia ao voltar à vila:** `_atualizar_marcadores` guardava a referência a marcadores já liberados com os moradores antigos. O resultado era o erro `previously freed instance` e o "!" não era recriado. Corrigido em `percurso_prototipo.gd`; o erro não aparece mais nos dois testes.

### Conteúdo
3. **Pouca fala por morador:** 2 a 5 conversas cada (uns 60 textos ao todo para 15 pessoas). Da quinta visita em diante tudo se repete. No roadmap continua aberto: "falas de encontro, missão, andamento, resolução e reação posterior".
4. **Reações ao progresso só em três marcos** (Cerne, defesa, moinho) e não para todos. Missões como "Um lugar na vila" e a estrada quase não mudam o que a cidade diz.
5. **Moradores de apoio sem papel:** Mara, Téo, Nina, Bia, Elia e Noel falam, mas não ligam a nenhuma missão principal nem a serviço próprio (Elia costureira e Noel guarda pediriam isso).
6. **Retratos repetidos no diálogo:** só existem 3 (`lia`, `mistica`, `mercador`). Dara usa o retrato da Lia, e Tomás e o trabalhador usam o do mercador.
7. **O fim do beta é seco:** uma linha no relato ao Nilo. Falta uma cena de encerramento e um gancho para a próxima região.

### Interface na vila
8. **"CHAT GLOBAL OFFLINE"** ocupa o canto inferior esquerdo na campanha solo, sem uso.
9. **Mercado vazio sem conexão** ("SEM CONEXAO COM O MERCADO", também sem acento). No beta, com poucos jogadores, ele fica vazio mesmo com conexão. Ofertas fixas de moradores (Tomás, Cora) dariam vida.

### Arte
10. **Mistura de resolução:** a água da pesca e as barracas do mercado são pixel grande, ampliado e quadriculado, ao lado de árvores pintadas em alta resolução. É o contraste mais visível depois do mapa. Ver `GUIA_ARTE.md`, seção 5.
11. **Moradores pequenos e parecidos de longe:** na entrada, guarda, fazendeiro e criança se distinguem só pela roupa. Silhuetas e cores mais marcadas (avental, chapéu, cesto) ajudariam a reconhecer cada um.

### Do roadmap, ainda aberto
- Mapa regional com destinos visitados, disponíveis e bloqueados.
- Invasões depois da primeira defesa.
- As três famílias de monstros (rebentos, cascudos de minério e sentinelas enxertadas). Hoje o beta usa rebentos e goblins.
- O pomar continua fora do beta.

## Correções de 09/11/2026

- **Painéis sobrepostos:** o `MiniTutorial` procurava a interface uma vez só, no `_ready`. Na campanha o HUD nasce antes da interface (`percurso_prototipo.gd`), então ele nunca via as telas abertas. Agora `mini_tutorial.gd` procura de novo no `_process` enquanto não acha uma interface válida. Conferido nas capturas: o diálogo e a forja aparecem sem o quadro de controles.
- **Acentos:** corrigidos os textos que aparecem nas telas avaliadas: lembrete de controles (`POÇÃO`, `ESPAÇO`, `ANALÓGICO`), forja (`NÍVEL`, `NECESSÁRIOS`, `FABRICAÇÃO`, `ÀS`, `NÍVEL MÁXIMO`, `INDISPONÍVEL`), acessórios iniciais (`VIDA MÁXIMA`, `FÔLEGO MÁXIMO`, `EMPURRÃO`), horários de atendimento (`ABRE ÀS`, `FECHOU ÀS`) e carpintaria. **Pendente:** o resto do código ainda tem uns 180 textos sem acento (`NIVEL`, `POCAO`, `ESPACO`, `ATE`, `VOCE`…) em pesca, mercado, fazenda, comércio, diálogos da cidade e outros lugares. Isso pede uma varredura própria.
- **Drop raro do Cerne:** não é bug. `ferramentas/projeto/SAQUE_INICIAL.md` diz que o "Cerne Partido fica sem drop de equipamento até a definição de sua recompensa", e `catalogo_saque_inicial.gd` segue isso desde o commit `9391105e7`. O teste foi atualizado e agora verifica que o chefe não dá drop de equipamento e que todo saque recolhido aparece com dados reais. Resultado: `teste_interface_campanha.gd` sem falhas (221 OK). Quando a recompensa do Cerne for definida, a verificação precisa ser trocada.
- **Moldura 960×900:** era um problema do ambiente de teste. A janela de 1920×1800 não cabia no monitor e foi reduzida para 1920×1069; com stretch `expand` a área visível ficou 1616×900, e o painel, centralizado nela, passava de x=960. O teste agora compara com `root.get_visible_rect()`.
- **Ainda aberto:** o erro `Parameter "scenario" is null` em `atlas_herois_3d.gd:95` (44 vezes na última rodada).
