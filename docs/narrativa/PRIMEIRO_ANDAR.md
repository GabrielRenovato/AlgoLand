# AlgoLand — Primeiro andar: roteiro atual e produção

Estado atualizado em 31/10/2026: premissa e percurso inicial consolidados, com integração experimental da chegada, estrada, vila, pomar e primeira defesa da vila. As seções abaixo distinguem conteúdo integrado, direção aprovada e planejamento futuro. A existência de código não significa acabamento final, balanceamento concluído ou publicação.

A adaptação em prosa, escrita como livro para apoiar a futura HQ, está em [O chamado da Primeira Raiz](LIVRO_PRIMEIRA_RAIZ.md). Ela acompanha os acontecimentos e mantém as notas técnicas neste documento.

Este é o roteiro vigente. [ROTEIRO.md](ROTEIRO.md) preserva a proposta anterior, superada; não usar o resgate por Bento na arena nem a história dos vigias humanos aprisionados como abertura desta campanha.

## 0. Estado consolidado da jornada

O personagem é invocado pela Árvore-Mãe, nome ainda provisório, e chega às Clareiras da Chegada sem equipamentos. Seu passado anterior permanece aberto. Há outros invocados possíveis: o jogo não o apresenta como único escolhido. Sobreviver, investigar e ajudar os moradores constrói sua importância na história.

### Sequência disponível no protótipo

1. **Clareiras da Chegada:** invocação → abrir o baú de resgate → recolher espada e escudo → enfrentar o primeiro rebento → investigar sulcos → seguir sinais do posto de resgate → resistir às três ondas na clareira maior → vencer o Cerne Partido → descobrir a saída.
2. **Estrada dos Carreteiros:** examinar a carroça atacada → seguir os rastros pelo desvio até o abrigo → conversar com o trabalhador refugiado → voltar à vila e informar Dara. É possível observar a pista antes de receber o pedido; isso não antecipa os objetivos da missão.
3. **Vila das Flores:** depois do resgate, Dara recebe o relato; Lia acolhe o personagem e Estela relaciona a chegada aos sinais da árvore. Ivo oferece a escolha de preparo para a próxima saída.
4. **Pomar das Cercas Partidas:** investigar os sulcos e as cercas, acompanhar a rota dos rebentos e relatar a descoberta a Tomás.
5. **Defesa da vila:** Lia orienta a montagem da ligação de Ivo na entrada sul; o jogador segura a rua contra três levas de rebentos e conversa com Osvaldo sobre os reparos. Essa defesa já está integrada ao percurso experimental. Os demais territórios, a dungeon principal e a próxima região continuam planejados.

### O que mudou na apresentação e no jogo

- **Cenários modulares:** terrenos por tiles reutilizáveis, árvores, pedras, ruínas e objetos independentes; solo real sob os objetos, colisões nas bases e profundidade pelos pés. A imagem de referência orienta a composição, sem virar fundo fixo de mapa completo. Usar a terra detalhada da fazenda e preservar definição no desktop.
- **Chegada:** baú interativo com animação de abertura e coleta real dos equipamentos; sinais de resgate, ruínas, ponte e inimigos de raiz. A raiz gigante com seiva foi retirada da decoração: raízes hostis têm função de criatura. A primeira chegada apresenta a invocação com folhas, luz, materialização, ajoelhar/levantar e opção de pular. Reentradas usam uma chegada curta; durante uma vigília em curso, quem chega não fica preso à cena. Outros jogadores veem um brilho e poeira no avatar que chega.
- **Apresentação dos estágios:** a tela de carregamento mostra uma imagem do local e um trecho curto de contexto para a chegada, estrada, vila ou pomar, em vez da tela cinza com o personagem isolado. O texto prepara a exploração sem substituir a narrativa descoberta em jogo.
- **Água:** direção obrigatória de animação por quadros, com superfície, margens e colisões separadas. A integração de atlas não encerra a revisão do ciclo, emendas e quatro estações exigida pelas regras visuais.
- **Combate:** rebentos com movimento, combo de dois golpes, ataques de raízes anunciados e reações; grupos espalhados para testar combate e exploração. Cerne Partido é o chefe da chegada, não o chefe final do andar.
- **Estrada:** mapa modular próprio de 2048×1280 unidades, estrada de terra com trechos de calçamento antigo, sulcos de rodas, carroça danificada, mantimentos espalhados, muretas e cercas incompletas, desvio de fuga e abrigo aberto. Nove rebentos em quatro grupos com percepção local; encontrar o trabalhador não exige eliminar todos. Carroça e abrigo têm quatro variantes sazonais integradas.
- **NPCs:** usar o gerador atual, com o corpo, roupas, cabelos e animações compartilhados do jogo. Não introduzir os antigos sprites de moradores nas novas entregas. O trabalhador da estrada usa camisa de trabalho, calça cargo, botinas e cabelo cacheado; espera e conversa usam o rig atual. Novas roupas e cabelos podem ser produzidos quando houver necessidade de identidade.
- **Casas e comércio:** plantas, mobiliário, pisos e paredes devem refletir cada casa e atividade. Nos imóveis mistos, comércio reconhecível na frente e quartos nos fundos, com acessos coerentes. A direção e as adaptações por casa estão estabelecidas; acabamento fino permanece para refinamento.
- **Estágios e salas:** seleção com informações do destino, lista de salas, criação e entrada; sala com até quatro participantes, representação dos personagens, chat e início pelo líder. Referências externas servem de inspiração, sem copiar a interface. Acabamento escolhido: madeira escura discreta, metal envelhecido e âmbar. A base está integrada; acabamento e revisão completa de responsividade permanecem trabalho próprio.
- **Ritmo:** fases perigosas têm mínimo de um minuto ativo; a duração maior depende da exploração e dos encontros, podendo chegar a sessões longas. O mínimo não substitui conteúdo nem comprova duração final. Retomada preserva equipamentos e descobertas no save isolado.

### Mistérios que continuam abertos

O jogador vê a invocação antes de entender sua causa. O símbolo do resgate, os sulcos e a fala do Cerne ligam a chegada à rede de raízes. Explicações chegam em partes, pelos moradores e pela exploração. A hipótese da seca, desvio de água e núcleo defeituoso continua proposta de desenvolvimento; as novas cenas não a tornam uma revelação já apresentada ao jogador.

O estudo visual anterior serve para discutir aparência e marcos. Seu tamanho e suas distâncias não são a escala final. Este primeiro andar é uma região extensa, com territórios próprios e múltiplas saídas da vila. Cada território deve comportar vários trechos de câmera, encontros, caminhos e descobertas; um ponto no desenho não equivale a uma única sala.

## 1. Identidade e conflito da região

Direção atual de navegação: mapa-múndi de andares, mapa regional do primeiro andar e áreas jogáveis acessadas separadamente. A cidade funciona como ponto social e as áreas perigosas recebem expedições de grupo. A ilustração contínua organiza a geografia, sem exigir que toda a região seja um único mapa carregado. Ver o [roadmap de produção](ROADMAP_PRIMEIRO_ANDAR.md).

Nome de trabalho: Vale da Primeira Raiz. A vila permanece chamada Vila das Flores nesta proposta. A árvore que convoca os jogadores será chamada Árvore-Mãe até escolhermos seu nome próprio; Yggdrasil é a referência provisória indicada pelo usuário.

A região cresceu em torno de raízes que distribuem energia e água por estruturas antigas. Moradores aproveitaram parte dessas estruturas para irrigação, mineração e proteção. Agora, canais estão secando, ferramentas minerais apresentam veios luminosos e criaturas de raiz e pedra abandonam seus territórios, chegando às casas.

Hipótese narrativa proposta: em uma seca anterior, moradores desviaram água de uma instalação antiga para sustentar as plantações. O desvio manteve a vila viva, mas interrompeu a refrigeração de um núcleo enterrado. O mecanismo de proteção reagiu lentamente: passou a extrair energia das raízes, formar defensores e tratar pessoas como invasores. A crise atual reúne consequências de uma decisão compreensível, conhecimento perdido e um sistema que perdeu seu equilíbrio.

Esse é o conflito do primeiro andar. O motivo mais profundo para a rede entre regiões estar fragmentada permanece aberto para a campanha futura. Não atribuir todos os males do mundo a esse único acidente.

A Árvore-Mãe invoca pessoas de fora porque precisa de agentes capazes de alcançar instalações às quais suas raízes não chegam sem alimentar o próprio mecanismo defeituoso. Isso é uma proposta de explicação a revelar na vila; o jogador começa sem saber. Há vários invocados possíveis. A reputação de herói é conquistada ao proteger pessoas e resolver problemas.

## 2. Estrutura territorial maior

A composição final terá quatro conjuntos conectados: terras habitadas a oeste, bacia de água ao sul, mata e vestígios antigos ao norte, território mineral e complexo principal a leste. Eles compartilham linguagem visual, mas têm topografia, uso e encontros diferentes.

As estradas estabelecem referências. Trilhas, passagens de margem e atalhos permitem descobrir outras rotas. A entrada da dungeon fica distante da queda e exige investigação para ser compreendida; a maior parte da exploração continua relevante depois que ela for localizada.

Não fixamos metragem, número de telas ou duração de campanha pela ilustração. Essas medidas devem resultar do planejamento de encontros e de percursos jogáveis. A intenção é uma jornada de múltiplas sessões, a ser medida em testes, sem prometer uma quantidade de horas ainda não validada.

| Território | Localização proposta | Papel na região |
| --- | --- | --- |
| Clareiras da Chegada | Sudoeste | Invocação, sobrevivência inicial e indícios de outras travessias. |
| Estrada dos Carreteiros | Oeste e ligação central | Encontrar a civilização, investigar ataques e abrir rotas seguras. |
| Vila das Flores e Cinturão Rural | Centro-oeste | Relações, ofícios, cultivo, descanso, preparação e defesa. |
| Pomar das Cercas Partidas | Oeste da vila | Primeiro conflito rural e exploração de trajetos usados pelas criaturas. |
| Bacia do Moinho | Sul | Água, pesca, irrigação e primeira parte do mistério técnico. |
| Várzeas Afundadas | Sudeste | Exploração de margens, coleta especializada e caminhos sujeitos ao controle da água. |
| Pedreira dos Veios Vivos | Leste | Equipamentos, mineração, risco e vestígios da falha no núcleo. |
| Túneis do Carvão | Sob a pedreira | Dungeon secundária, investigação e abertura de um atalho. |
| Mata das Cascas Ocas | Centro-norte | Rastreamento de monstros, ervas e encontros que exigem observação. |
| Observatório das Passagens | Noroeste | Identidade das relíquias, inscrições e mapa das regiões futuras. |
| Jardins da Raiz Antiga | Norte | Mecanismos preservados e explicação do ciclo de energia. |
| Bastião do Enxerto | Nordeste | Território de aproximação e dungeon principal, encerrando o arco. |

## 3. Moradores da primeira vila

Reutilizar nomes e funções atuais quando fizer sentido, sem tornar o texto abaixo uma afirmação sobre personalidades já implementadas. Bento é provisório e não será tratado como personagem permanente. Orion não recebe automaticamente o papel de explicar toda a história.

### Dara — vigia da estrada; nome novo provisório

Prática, atenta e desconfiada de promessas. Conhece rotas e procedimentos de resgate, mas não entende o mecanismo da invocação. Quer manter as estradas transitáveis e impedir desaparecimentos. Seu defeito é tentar resolver os problemas patrulhando sozinha; aprende a organizar ajuda.

Primeiro encontro: no posto de entrada, depois que o jogador encontrou o caminho por conta própria. Ela reconhece um sinal associado à árvore e procura Lia para acolhê-lo. Não aparece no instante da queda nem dá uma aula de história.

Missão pessoal: recuperar os sinais de três patrulhas interrompidas e determinar o que aconteceu, incluindo sobreviventes que mudaram de rota. Recompensa: conhecimento de atalhos e confiança para participar das vigílias. Fala de referência: “Antes de prometer que vai resolver, me diz por onde você pretende voltar.”

### Lia — responsável pela organização da vila

Direta, boa de memória, humor seco. Quer garantir abrigo e abastecimento, mas sabe que manter tudo fechado também põe a comunidade em risco. Guarda registros de invocações anteriores; não conhece todas as respostas.

Missão pessoal: preparar uma defesa distribuindo recursos entre estrada, abrigo e praça. As prioridades escolhidas modificam pequenas cenas e quais reparos serão necessários depois, sem criar uma perda irrecuperável da campanha. Reconhece o jogador pelas ações vistas e relatadas.

### Ivo — ferreiro e estudioso involuntário do metal antigo

Orgulhoso do trabalho, impaciente com improvisos e disposto a rir dos próprios fracassos quando confia em alguém. Quer produzir equipamento confiável com o que a região oferece. Precisa admitir que certo minério está se comportando de forma imprevisível.

Missão pessoal: rastrear a origem dos veios luminosos, testar uma peça e ajustar a fabricação com a descoberta da pedreira. Consequência: uma receita útil se torna disponível e os trabalhadores passam a separar material instável. A história deve mostrar o teste, não apenas uma entrega de minério.

### Rosa — curandeira e ponto de encontro dos retornos

Acolhedora, observadora e firme sobre limites. Conhece os efeitos da crise no corpo das pessoas. Quer distinguir água contaminada, exaustão e exposição mineral, evitando culpar toda doença na magia.

Missão pessoal: comparar amostras de fontes distintas e acompanhar uma recuperação. Descobre que o problema segue canais específicos. Consequência: orientações e um preparo protetor para uma área de risco. O jogador ganha evidências e uma relação com a pessoa ajudada.

### Tomás — sementes e abastecimento

Sociável, calculista com estoques e constrangido quando precisa negar crédito. Quer atravessar a crise sem perder a próxima safra. Teme que o entusiasmo pelas expedições tire trabalhadores e mantimentos da vila.

Missão pessoal: recuperar sementes locais e experimentar um cultivo em terra recuperada. Consequência: acesso a uma variedade e restauração visual de uma parcela do pomar. Sementes comuns continuam acessíveis; o jogador não precisa esperar uma estação específica para avançar na campanha.

### Nilo — pescador e leitor dos rios

Irônico, paciente e atento ao que a corrente carrega. Conhece antigos pontos de travessia. Quer recuperar o trecho de pesca próximo do moinho, mas desconfia da promessa de que basta abrir uma comporta.

Missão pessoal: mapear entradas e saídas de água e testar a vazão com o grupo. Consequência: uma margem antes inacessível pode ser explorada e um ponto de pesca volta a funcionar. Não existe navegação por barco presumida nesta proposta.

### Osvaldo — carpinteiro e mantenedor do moinho

Metódico, caloroso e econômico nas palavras. Quer consertar o que sustenta a vida diária. Conhece reparos herdados, mas encontra registros de que uma alteração antiga teve efeitos inesperados.

Missão pessoal: reconstruir o histórico do desvio e reparar o conjunto de comportas com materiais adequados. Precisa reconhecer o erro sem transformar antigos moradores em vilões. Consequência: moinho funcional, rota curta e mudança no curso controlado da água.

### Estela — pesquisadora dos sinais da árvore

Curiosa, imaginativa e explícita ao distinguir certeza de hipótese. Quer entender a rede de passagens. Precisa revisar a interpretação inicial de que a doença das raízes começou na floresta.

Missão pessoal: comparar símbolos do observatório, jardins e fragmentos encontrados. Consequência: o grupo compreende o mecanismo do bastião e, após a vitória, pode usar a relíquia no mapa regional. Ela explica parte do chamado da árvore, sem impor um passado ao personagem.

Outros moradores dão vida às casas, serviços e atividades, mas não precisam receber um arco completo de imediato. As relações não devem existir apenas como dispensadores de objetivos.

## 4. Criaturas: ecologia, combate e produção

Os nomes abaixo são provisórios. As criaturas têm uma causa comum, mas ocupam habitats diferentes e exigem respostas distintas. A produção deve começar verificando o que pode ser aproveitado das bases existentes; este plano não declara modelos prontos.

| Família | Formas e comportamento propostos | Territórios e função narrativa |
| --- | --- | --- |
| Rebentos errantes | Pequenos corpos de madeira e raízes, núcleo de resina. Um perseguidor se aproxima; um lançador se fixa antes de disparar sementes; uma forma defensora protege o núcleo e expõe as costas durante a recuperação. | Clareiras, pomar e mata. O jogador descobre que seguem antigos sulcos de energia, em vez de atacarem por acaso. Compartilham uma base visual com silhuetas próprias. |
| Cascudos de minério | Criaturas baixas e robustas com placas de pedra e veios minerais. Escavadores anunciam onde vão emergir; guardas pesados se prendem ao chão para atacar; quebradores derrubam apoios frágeis em arenas preparadas. | Pedreira, túneis e bastião. Revelam que a extração atingiu estruturas ainda ativas. Compartilham outra base de corpo e material. |
| Sentinelas enxertadas | Montagens de pedra ligadas por raízes e juntas metálicas. Ativação legível, ataques com intervalos e pontos de ligação expostos. Poucas unidades, encontros elaborados. | Observatório, jardins e complexo final. São equipamentos antigos de defesa. Uma base modular pode dar origem a versões e ao tema do chefe. |

Peixes, aves e animais de criação continuam parte da região. A floresta não precisa conter apenas seres hostis. Animais comuns não se tornam automaticamente monstros por uma troca de cor.

Chefe proposto: Custódio do Enxerto, mecanismo de proteção alimentado pelo núcleo superaquecido. Sua silhueta reúne pedra, raiz e conexões metálicas já antecipadas. Suas fases usam os canais aprendidos no puzzle. Ele não é o antagonista definitivo da campanha nem um antigo vigia humano preso ao dever, como na proposta descartada.

## 5. Histórias, missões e consequências por território

### Clareiras da Chegada — Sobreviver antes de compreender

O personagem chega pela invocação da árvore. A abertura em integração mostra a floresta reagindo, folhas subindo, luz próxima ao solo e o corpo se materializando pouco acima da terra. Ele desce, apoia-se de joelhos, toca o chão e se levanta; o controle volta ao jogador. A primeira entrada usa a sequência longa, que pode ser pulada; revisitas usam entrada curta. Não há explicação sobre seu passado nem um NPC dando uma aula de história na queda.

Espada e escudo pertencem ao conjunto de emergência de uma antiga rota de resgate. Estão no baú, que o jogador abre com uma animação antes de recolhê-los. A árvore não materializa armas. Um rebento permite praticar ataque, defesa e esquiva; sinais no chão e tecido azul conduzem à investigação do posto de resgate.

Na clareira maior, investigar as raízes inicia três ondas de rebentos. Após vencê-las, o Cerne Partido cai do céu: uma marca anuncia o impacto, que causa dano e empurra quem estiver na área. O chefe se desloca e persegue; não permanece preso a um ponto. Usa combo de duas varridas e pancada no chão. Na segunda fase, acrescenta investida e conjuração de raízes. Cortar os três apoios interrompe a conjuração e abre uma janela de vulnerabilidade.

Falas integradas:

> Chegada: “A Árvore ainda chama vocês…” / “Mas esta passagem permanece fechada.”
>
> Segunda fase: “Minha casca pode ceder.” / “Minha vigília, não.”
>
> Derrota: “Eu… ainda guardava…”

O Cerne sugere uma função de guarda ligada às raízes, sem confirmar a antiga história descartada de um vigia humano aprisionado. Sua derrota libera a etapa de saída; não concede a relíquia principal nem encerra o primeiro andar. O Custódio do Enxerto continua reservado ao bastião planejado.

Consequência integrada: equipamentos e objetivos registrados, clareira concluída e indicação da vila no mapa regional. Na sessão cooperativa, a invocação não deve interromper os demais: cada participante pode pular a própria cena, e quem chega durante uma vigília usa a entrada curta. Fragmento opcional com marca de outras travessias permanece planejado.

### Estrada dos Carreteiros — A rota interrompida

Um carreto de mantimentos não chegou à vila. A investigação da estrada acontece antes do acolhimento completo na cidade: o personagem segue os vestígios, encontra o trabalhador refugiado e só então retorna para contar a Dara. O cenário integrado mostra uma rota de abastecimento em uso antigo: calçamento descontínuo sobre terra, marcas de rodas, carroça com eixo danificado, carga caída e limites de pedra e madeira tomados pela vegetação.

Examinar a carroça revela que as raízes vieram por baixo das rodas e que alguém conseguiu fugir. A trilha lateral leva ao abrigo de madeira, com frente aberta e apoios físicos que não bloqueiam a aproximação. O trabalhador encontrado ali usa o gerador atual de NPCs, com aparência reproduzível, animação de espera e conversa voltada ao jogador.

Fala integrada:

> “Eu carregava mantimentos para a vila. As raízes vieram por baixo das rodas… Soltei a carga e corri até este abrigo. Se encontrar a Dara, diga que estou vivo. Ela conhece este caminho.”

Nove rebentos estão distribuídos em quatro encontros: curva de entrada, área do carreto, desvio dos rastros e aproximação da saída. Sua percepção é local; não perseguem desde a outra ponta do mapa. O resgate depende de investigar e conversar, sem exigir abater todos. O registro de missão pede o relato a Dara na vila. Explorar antes de falar com ela permite ler os vestígios, mas não pula essa dependência do diário.

Consequência já registrada: localização do trabalhador e objetivo de relato a Dara. O deslocamento dele até a vila, a retomada visível das entregas, o atalho de retorno, o diário/retrato opcionais e o mapa antigo do vale permanecem planejados; conversar no abrigo não significa que esses eventos já estejam implementados.

### Vila e Cinturão Rural — Ganhar um lugar

O jogador recebe abrigo e uma explicação inicial do chamado. A participação em um trabalho útil, numa conversa e na preparação da defesa apresenta os moradores por suas ações. A fazenda pertence ao cotidiano, à fabricação e aos preparos de expedição.

**Acolhimento após a estrada.** Dara recebe o relato do trabalhador resgatado. Lia oferece abrigo e explica a situação da vila. O jogador se prepara: visita Ivo, testa os golpes com Dara ou cuida dos equipamentos encontrados. Estela liga a chegada do jogador aos acontecimentos da floresta e conduz a investigação, sem tirar o combate do plano físico. Tomás pede ajuda com o pomar e abre a próxima saída. Na bancada, Ivo oferece duas ligações: a de ferro segura no lugar, a de raiz trançada cede e volta. A escolha é do jogador, fica salva e influencia tanto a barreira do pomar quanto a defesa posterior.

**Atividades da vila.**

| Lugar ou personagem | O que fazer |
| --- | --- |
| Ivo, forja | Fabricar equipamentos, melhorar peças e aproveitar materiais das expedições. |
| Dara, área de treino | Experimentar combos, bloqueios, esquivas e técnicas já desbloqueadas. |
| Rosa, cuidados | Preparar curativos e suprimentos para a próxima saída. |
| Tomás, comércio | Vender excedentes e comprar materiais básicos. |
| Ponto de descanso | Recuperar-se e organizar a próxima expedição. |
| Quadro de expedições | Escolher estágio, rever recompensas e reunir o grupo. |

A maestria continua ligada ao uso da arma. A cidade ajuda o jogador a entender e preparar sua especialização.

**Três missões secundárias iniciais.** Cada uma apresenta uma atividade. Os itens azuis dos bosses continuam sendo as recompensas importantes; estas tarefas dão preparo, receitas e serviços.

- **Ivo, "Ferro que ainda serve":** recuperar ferragens do carreto na segunda região e levá-las à forja. Recompensa: 40 de ouro, 3 de minério, 2 de madeira e a receita de luvas.
- **Rosa, "Quem ficou para trás":** levar suprimentos ao trabalhador resgatado e descobrir mais sobre o ataque. Recompensa: 25 de ouro, 4 de fibra, 2 poções de cura e uma conversa que reconhece o resgate.
- **Dara, "Antes de sair outra vez":** treino curto de bloqueio, esquiva e contra-ataque contra um boneco que avisa o golpe com o braço erguido. Recompensa: dinheiro e acesso ao treino livre. A missão fecha quando o jogador completa o treino e paga 60 de ouro. O treino continua livre depois.

**A vila reage ao progresso.** Moradores comentam a vitória contra o Cerne; as conversas mudam após a defesa. Ivo ganha receitas conforme recebe materiais. Depois do pomar, Lia convoca a defesa e Osvaldo conversa sobre os reparos. Serviços desbloqueados, relações e missões concluídas ficam salvos mesmo com a cidade instanciada; a recepção completa acontece só na primeira chegada. Na cidade, concluir uma tarefa gera um aviso de missão e recompensa; o relatório com dano e ranking fica para as expedições de combate.

**Primeira defesa (implementada).** Depois do pomar, Lia avisa que os sulcos chegam à vila. O jogador monta a ligação de Ivo na barreira da entrada sul e chama a defesa: três levas de rebentos (3, 4 e 5) pela rua. A ligação de ferro tira um rebento da primeira leva; a de raiz tira vida de todos. Ao resistir, Osvaldo cuida dos reparos e a vila paga 80 de ouro, 2 de minério e 4 de madeira. Perder recomeça a defesa, sem punir o que já foi feito. Os moradores comentam a rua que ficou de pé.

Uma invasão ligada ao marco da história apresenta a ameaça. Lia oferece aviso e preparação antes de iniciar. Repetições posteriores dependem de regras ainda a definir; não atacar o mundo desconectado nem impor invasões constantes enquanto o grupo quer explorar.

Consequência: reparos visíveis e moradores que reconhecem o ocorrido. Sem apagar progresso agrícola, matar personagens de serviço permanentemente ou punir ausentes por padrão.

### Pomar das Cercas Partidas — O caminho debaixo da terra

Tomás perde brotos mesmo em áreas cercadas. Investigar revela que os rebentos percorrem sulcos antigos sob os canteiros. O jogador testa barreiras e restaura uma parcela para observar por onde as criaturas retornam.

Coletável: variedade local de semente e trecho de receita cotidiana. Consequência: parcela recuperada, produção local retomada e uma pista sobre o sentido dos canais. As árvores e cercas deixam marcas reconhecíveis da intervenção.

### Bacia do Moinho — A água que deixou de voltar

Nilo observa que uma margem recebe menos água; Osvaldo encontra adaptações feitas durante a seca. A missão percorre comportas e reservatórios, com medição visual simples e testes de vazão.

Coletável: caderno de reparos com desenhos legíveis. Consequência: reativar o moinho e abrir uma travessia curta. A alteração é controlada por estados definidos, evitando que uma escolha inunde a vila e bloqueie a campanha.

### Várzeas Afundadas — O que a corrente preservou

A região guarda restos de uma antiga travessia e plantas usadas por Rosa. O nível controlado de água revela caminhos adicionais e objetos presos nas margens. Certas pistas são encontradas olhando o ambiente e acompanhando a corrente.

Coletáveis: registros de uma expedição anterior e amostras botânicas. Consequência: preparo protetor, descoberta de uma ligação com a pedreira e uma rota alternativa. Evitar depender de uma chuva aleatória ou de uma estação distante para a missão principal.

### Pedreira dos Veios Vivos — O preço do material

Ivo precisa entender por que peças iguais se comportam de forma diferente. O jogador acompanha marcas de extração e encontra alojamentos evacuados. Os cascudos defendem pontos específicos de contato com o mecanismo antigo.

Coletáveis: amostras de veios e anotações de trabalhadores. Consequência: separar material instável, fabricar uma peça confiável e criar um pequeno posto seguro. Algumas áreas difíceis continuam opcionais, com recompensas de especialização.

### Túneis do Carvão — A equipe que ficou isolada

Uma dungeon secundária leva a um trecho de manutenção desconhecido pelos atuais trabalhadores. A missão combina rastreamento, restauração de apoios em pontos definidos e um encontro de combate. O destino da equipe precisa ser mostrado; não se resume a recolher objetos sem descobrir quem os deixou.

Coletável: projeto incompleto que ganha sentido junto de uma peça do observatório. Consequência: acesso de manutenção ao exterior e evidência de que o núcleo perdeu refrigeração. Não exige simulação livre de desabamentos nem terreno destrutível.

### Mata das Cascas Ocas — Observar antes de perseguir

Rebentos se juntam em determinados horários de um ciclo próprio curto, indicado por som e movimento. O grupo pode seguir uma formação e descobrir onde recebe energia. O comportamento é uma pista, não só uma animação decorativa.

Coletáveis: resina característica e páginas de observação. Consequência: localizar os Jardins da Raiz Antiga e aprender uma abertura de defesa útil em combate. Uma trilha retorna ao norte da vila, formando um circuito de exploração.

### Observatório das Passagens — O círculo que perdeu seus destinos

O círculo de pedra desenhado no alto à esquerda ganha uma função proposta: é um antigo observatório e encaixe de relíquias. A imagem, sozinha, não estabelecia que fosse um portal. No começo, está inativo e mostra apenas marcas incompletas.

Estela pede que o grupo compare as posições dos encaixes com inscrições encontradas. O jogador pode compreender sua função antes de possuir uma relíquia. As sentinelas daqui protegem a instalação, antecipando a linguagem do bastião.

Coletáveis: fragmentos de cartografia que registram relações entre símbolos e regiões. Consequência: leitura parcial da rede. Depois da dungeon principal, colocar a relíquia completa o próximo destino e permite uma travessia pela estrutura da árvore, cuja apresentação visual ainda será definida.

### Jardins da Raiz Antiga — A máquina ainda inteira

É o lugar onde parte do mecanismo original continua preservada. Canais, árvores e pedras de regulagem oferecem um modelo observável do ciclo: captar, distribuir, devolver e resfriar. O jogador pode testar uma seção pequena, com feedback claro, antes de enfrentar o conjunto defeituoso.

Coletável: registro dos mantenedores e peças com marcas de orientação. Consequência: compreender a falha e preparar a intervenção no bastião. Restaurar o jardim muda a aparência de uma área delimitada e abre um abrigo de expedição.

### Bastião do Enxerto — A proteção que virou ameaça

O território externo tem postos, pátios ocupados e acessos de serviço; a dungeon interna será desenhada separadamente. A localização pode ser encontrada antes do preparo completo, mas suas conexões e seu mecanismo exigem a investigação feita na região.

O grupo entra para restabelecer o circuito e retirar do Custódio sua fonte de energia descontrolada. O confronto final exige compreender o sistema, lidar com inimigos e coordenar ações.

Consequência: ataques daquele núcleo diminuem, o caminho de manutenção vira atalho e a vila reage à vitória. A região continua explorável, com criaturas residuais e desafios repetíveis coerentes; o jogo não precisa declarar uma nova crise principal toda vez que um chefe reaparecer.

## 6. Puzzle principal, força e aprendizado

A dificuldade deve reunir raciocínio, preparo e execução. Não basta entregar três objetos e ver uma porta abrir. Os três conjuntos de evidências — água, extração e jardins — permitem deduzir a causa da falha e o funcionamento da instalação.

Proposta de puzzle: o bastião tem circuitos conectados, símbolos de função e indicadores de pressão. O grupo precisa identificar conexões, testar o sentido dos fluxos e estabilizar a sequência antes de enfrentar o Custódio. Os mesmos princípios aparecem em versões menores no moinho e nos jardins, sem entregar uma solução por cor.

Os símbolos combinam forma, posição e movimento; cores ajudam, mas não são a única informação. Erros produzem feedback localizado e recuperável. Registros encontrados ficam no diário, evitando obrigar o grupo a decorar longos textos fora do jogo.

A dungeon principal é cooperativa conforme a direção pedida pelo usuário. O número mínimo de participantes e as ações simultâneas serão definidos antes de construir o puzzle. Usar regras compatíveis com o tamanho do grupo; evitar exigir quatro participantes se duas pessoas puderem iniciar a mesma atividade. Exploração, preparo e histórias paralelas continuam possíveis individualmente.

Evoluir e fabricar equipamentos amplia as condições de sobrevivência. Níveis exatos, dano, vida, recursos exigidos e duração de preparo dependem de testes. A solução do puzzle não será substituída apenas por aumentar atributos.

## 7. Jornada principal e liberdade de exploração

1. Chegar, sobreviver, encontrar a estrada e a vila.
2. Conhecer o chamado e participar da preparação da primeira defesa.
3. Investigar as rotas dos ataques no pomar e nas estradas.
4. Comparar as pistas do moinho e da pedreira. Esses ramos podem avançar em ordens diferentes.
5. Explorar a mata, encontrar os jardins e reconstruir o funcionamento do circuito.
6. Compreender o observatório e preparar a intervenção com os moradores.
7. Formar o grupo, vencer o bastião e conquistar a relíquia.
8. Instalar a relíquia no observatório, revelar e abrir a próxima região.

O mundo não deve exigir concluir todos os colecionáveis, favores ou pontos de exploração para avançar. Conteúdo opcional tem histórias e recompensas próprias. A investigação principal precisa de alternativas para obter informação suficiente, sem depender de sorte no drop de uma pista essencial.

## 8. Colecionáveis e motivos para sair da estrada

- Fragmentos de cartografia: completam relações entre símbolos e lugares, com versões opcionais de contexto além das evidências principais.
- Cadernos e objetos de moradores: revelam pessoas e acontecimentos; certos conjuntos fecham uma história com retorno ao dono ou à família.
- Variedades de sementes e receitas: alteram possibilidades de cultivo, preparo e fabricação sem tornar toda coleta obrigatória.
- Descobertas naturais: espécies, pontos de pesca e resinas alimentam um registro de campo com uso concreto nos ofícios.
- Desafios de domínio: encontros opcionais e mecanismos secundários recompensam aprendizado com cosméticos, projetos ou alternativas de equipamento a definir.

Cada descoberta tem contexto e localização justificáveis. Quantidades e recompensas serão calibradas após o planejamento de conteúdo; não encher margens vazias com ícones apenas para aumentar uma contagem.

## 9. Relíquia, mundo compartilhado e continuidade

A recompensa central é uma relíquia de expansão do mundo. Direção atual: a primeira vitória válida concede a relíquia com destino fixo definido para aquela temporada. A configuração pode mudar em temporadas posteriores; não há sorteio de destinos a cada vitória. Seu significado é um vínculo com outra região da rede, compreendido no observatório.

A especificação inicial registra a política de relíquia única, colocação e participação elegível. A tabela de recompensas repetíveis e uma futura troca de temporada ainda precisam ser dimensionadas. Na especificação inicial do protótipo, o desbloqueio de campanha pertence ao personagem; o grupo compartilha a instância e seus objetivos. As regras detalhadas de progresso, recompensa e retorno estão em [REGRAS_PRIMEIRO_ANDAR.md](REGRAS_PRIMEIRO_ANDAR.md).

A vitória encerra o problema local do primeiro núcleo. A sequência de destinos da temporada continua a investigação maior com progressão narrativa planejada. Não prometer dez regiões prontas nem cinquenta etapas implementadas por causa da ideia inicial.

## 10. Produção e validação antes de virar conteúdo do jogo

A região grande é a direção pretendida. O trabalho será organizado por territórios, mantendo o plano completo: geografia e rotas; missões e estados; encontros; arte compartilhada; revisão de renderização e testes de progressão.

O mapa deve ter distâncias medidas caminhando, atalhos úteis, terreno aproveitado e múltiplas atividades por território. Testar com quem conhece a solução e com quem a descobre pela primeira vez. A imagem não comprova duração, navegação ou dificuldade.

Arte externa nova segue as quatro estações e as regras visuais do projeto. Definir contratos de escala, câmera, grade e referências antes de produzir. NPCs novos ou substituídos usam o gerador atual e a base personalizável, sem recorrer aos sprites antigos; famílias de inimigos compartilham bases planejadas, preservando comportamento e leitura de silhueta. Animações, colisões e camadas exigem revisão real.

No coop, persistir os estados de mundo e definir retomada após desconexão. O plano não transforma a sala atual em um servidor persistente automaticamente. Nenhum save do usuário será convertido ou substituído durante experimentos.

Antes de ampliar o percurso implementado, revisar: explicação aprofundada da invocação; identidade do primeiro contato; causa local da crise; destino dos trabalhadores; puzzle principal; quantidade mínima de participantes; política de relíquias e consequências permitidas nas invasões. As propostas aqui fornecem uma base concreta para essa revisão, sem tratar silêncio como aprovação.
