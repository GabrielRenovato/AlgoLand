# Roadmap — Primeiro andar completo do AlgoLand

Estado em 31/10/2026: quatro áreas iniciais integradas no protótipo, com abertura de invocação, tela de carregamento narrativa, NPCs procedurais variados e primeira defesa da vila. Chegada e estrada receberam montagem modular e encontros próprios. Consultar o [roteiro vigente](PRIMEIRO_ANDAR.md) para a sequência e os limites do conteúdo. O restante do andar segue em planejamento, sem prazo ou duração final certificados.

## Resultado que queremos entregar

Uma pessoa começa na área da queda, encontra espada e escudo, sobrevive, descobre a vila e entende seu chamado pela árvore. Encontra outros jogadores na cidade, explora as regiões do primeiro andar, evolui e fabrica equipamentos. Missões, descobertas e uma defesa da vila levam à investigação da dungeon principal. Um grupo resolve seu puzzle, vence o chefe e conquista a relíquia fixa da temporada. A relíquia registra o desbloqueio do próximo andar no mapa-múndi. Sair e voltar preserva o progresso definido para mundo e personagem.

A região deve oferecer exploração e histórias de múltiplas sessões; duração e dificuldade serão medidas jogando. A conclusão do primeiro andar inclui revelar o destino seguinte e apresentar corretamente sua disponibilidade. Construir o segundo andar não faz parte deste roadmap; uma transição de teste não será apresentada como segundo andar pronto.

## Direção atual e decisões ainda abertas

Direção consolidada na conversa:

- Mapa-múndi de andares; dentro de cada andar, mapa regional com cidade, áreas perigosas e dungeons acessíveis.
- Cidade como ponto de encontro de jogadores; expedições cooperativas em áreas próprias.
- Relíquias com destinos fixos durante a temporada; novas configurações possíveis nas temporadas seguintes.
- Personagem personalizável, invocado pela árvore, reconhecido como herói conforme suas ações.
- Primeiro andar extenso em conteúdo, com história e consequências por território. Dungeon principal cooperativa com desafio de raciocínio e combate.
- Bento é provisório. Não fixar sua permanência nem reutilizar a história anterior dos vigias aprisionados.

Decisões tratadas na especificação inicial da etapa 0, ainda revisáveis durante o protótipo:

- Quem guarda o progresso: personagem, mundo do anfitrião ou grupo; e o que acontece ao trocar de grupo.
- Número mínimo para a dungeon principal. Proposta inicial: duas pessoas, com suporte até quatro; não é uma escolha já confirmada.
- Recompensa para participantes atrasados, vitória repetida e quem já tem a relíquia.
- Disponibilidade do mundo sem anfitrião e regras da cidade social. Não presumir servidor persistente de mundo.
- Relação entre temporada, saves antigos, fazenda, personagem e equipamentos. Nenhum reset está autorizado.
- Ordem das primeiras relíquias e o destino imediatamente posterior ao primeiro andar.

## Entrega de planejamento — etapas 0 e 1

As [regras de trabalho do protótipo](REGRAS_PRIMEIRO_ANDAR.md) e as [fichas dos doze territórios](FICHAS_TERRITORIOS.md) estão detalhadas. Elas registram decisões iniciais revisáveis, fases por personagem, requisitos de grupo, quatorze missões, oito atividades opcionais e a sequência até a relíquia fixa. Implementação, balanceamento e revisão visual permanecem pendentes.

A base escolhida para iniciar o protótipo é progresso de campanha por personagem, instâncias compartilhadas de expedição e cidade social separada da instância de defesa. Isso substitui a sugestão anterior de campanha presa a um grupo permanente.

## Implementação inicial — catálogo e progresso isolado

Implementado em `codigo/campanha/`: catálogo versionado de 12 territórios e dois destinos de andar, 14 missões com validação de dependências e relíquia fixa. O modelo de progresso é opt-in, separado por pasta/perfil/campanha, sem autoload ou integração com a partida atual. A conclusão do chefe concede a chave de campanha; ativá-la registra o destino seguinte. A posse da relíquia e o acesso derivam do mesmo registro persistido de missões, evitando duas escritas independentes para esse desbloqueio.

O save valida versão, identidade e pré-requisitos, escreve em temporário e só atualiza o estado em memória após renomear o arquivo. Rejeita saves incompatíveis e escritores com leitura desatualizada; exige um escritor por perfil, sem prometer bloqueio entre processos. Um temporário abandonado não substitui a última confirmação.

Validação recorrente: `python3 ferramentas/projeto/harness.py testar --perfil campanha`. O teste usa save isolado e reabre o progresso em outro processo do Godot. Essa entrega não certifica persistência em navegador/aparelho físico, autoridade de rede, objetivos de missão, seleção de fases nem as interfaces novas. Todos os destinos do protótipo permanecem em preparação até haver cenas realmente integradas.

## Integração experimental — missões e navegação em duas telas

O protótipo isolado agora inicia em `cenas/campanha/seletor_campanha.tscn`: mapa-múndi → selecionar andar 1 → mapa regional com doze destinos → selecionar região → entrar. O cenário retorna ao mapa regional. Destinos sem conteúdo e regiões bloqueadas não iniciam cenas inexistentes.

As quatro primeiras missões têm objetivos persistidos, dependências e contexto de região em `controlador_campanha.gd`. A última interação confirma a missão junto do registro de objetivos. Novos saves guardam objetivos parciais; saves deste protótipo anteriores a essa extensão continuam aceitos sem inventar tarefas parciais. Registros contraditórios de conclusão e objetivos são recusados.

`percurso_prototipo.gd` abre quatro cenas próprias: chegada, estrada, vila e pomar, com layouts, caminhos, colisões e navegação separados. Chegada e estrada usam tiles modulares e objetos separados, com terra detalhada da fazenda e recursos sazonais nas quatro estações. A estrada acrescenta carroça e abrigo próprios, também sazonais. Espada e escudo são itens reais, equipados após a coleta; a migração do inventário comum não pode antecipá-los. O diário permite reconciliar a entrega depois de reabrir. O combate usa os rebentos de raiz, seus combos e ataques anunciados, além do ataque normal do jogador. A chegada inclui as ondas e o chefe Cerne Partido; a estrada tem nove rebentos em quatro encontros locais.

Objetivos e ponto seguro de retorno persistem no perfil isolado. Derrota retorna à entrada da região com equipamentos e descobertas preservados, sem confirmar combate perdido. O mapa regional permite selecionar as áreas liberadas e retomar a região salva. O reparo do pomar altera cerca, colisão e navegação e é restaurado pelo diário. A bancada e o reparo continuam demonstrando a sequência de objetivos, sem economia definitiva de materiais. O elenco da vila usa a base do gerador atual. O trabalhador da estrada também usa `npc_gerado.tscn`, com roupa de trabalho, calça cargo, botinas, cabelo cacheado e animações de espera e conversa. Não voltar aos sprites antigos nas novas entregas. Há seleção de salas, criação/entrada, lobby com até quatro participantes, chat e integração experimental de expedição online. Isso não certifica cidade social persistente nem recuperação completa de desconexões; os testes de retomada local mantêm seu escopo próprio.

A interface usa o HUD, o cartão compacto de missão, os indicadores F/Y/toque e a caixa de diálogo já existentes no jogo. O botão/ação de mapa padrão retorna ao mapa regional. A saída da clareira confirma a conclusão no pergaminho e indica a vila no mapa; revisitas mantêm a saída utilizável e não repetem a recompensa. O relato final do pomar encerra explicitamente o percurso disponível, sem declarar o primeiro andar inteiro pronto. As telas de estágio e sala usam acabamento de madeira escura discreta, metal envelhecido e detalhes âmbar; a revisão completa de responsividade ainda precisa encerrar seu próprio trabalho.

Direção visual: usar os recursos cartoon de alta qualidade existentes, incluindo o acabamento detalhado do chão, mantendo geometria, profundidade e variantes sazonais. Não entregar o atlas pixelado básico como apresentação final destas regiões.

Validação direcionada ao sistema alterado, com saves isolados; não repetir o percurso completo a cada ajuste. Para a estrada, usar `estrada-carreteiros`, que verifica apenas o segundo estágio, incluindo passagens, NPC, investigação, resgate, estações e capturas em desktop/retrato. Usar `campanha` ou `campanha-percurso` somente quando a mudança realmente afetar esses contratos. Há avisos de recursos gráficos ao encerrar o Godot nos logs, sem falhas funcionais nos testes selecionados. Iniciar manualmente com `python3 ferramentas/projeto/jogar_campanha.py`, que mantém dados fora da partida normal.

## Base existente que podemos aproveitar

| Base identificada | Trabalho de adaptação necessário |
| --- | --- |
| Combate, equipamentos, inventário, fabricação e fazenda | Selecionar conteúdo, ajustar curva e conectar recursos às regiões e missões novas. |
| Tutorial em `codigo/introducao/` | Reescrever a chegada e manter controles, acessibilidade e retomada. |
| Missões da vila em `codigo/cidade/` | Aproveitar estruturas de estados, diário e rastreio; o arco atual não é automaticamente a campanha nova. |
| Mapa em `codigo/ui/tela_mapa_mundi.gd` e seus dados | Avaliar adaptação para dois níveis de navegação e destinos instanciados. |
| Presença social em `codigo/cidade/sessao_lobby.gd` | Validar encontro na cidade, entrada em grupo e saída para expedição. Presença visual não equivale a mundo persistente. |
| Coop em `codigo/coop_online/`, até quatro participantes | Adaptar da partida de andar para regiões, objetivos, puzzle e recompensas compartilhadas. |
| Saves em `codigo/globais/saves.gd` | Projetar separação mundo/personagem, versionamento e compatibilidade; o save coop local existente não prova persistência de um grupo online. |
| Mapas, NPCs e recursos já disponíveis | Inventariar por território antes de produzir arte, sem presumir compatibilidade de todas as peças. |
| Harness e testes direcionados | Reutilizar runners e acrescentar verificações dos novos contratos e percursos. |

Existência de um sistema não significa que sua integração nova esteja pronta ou validada.

## Ordem das entregas

| Etapa | Entrega concreta | Depende de | Critério para encerrar |
| --- | --- | --- | --- |
| 0 | Regras do primeiro andar | — | Decisões de progresso, grupo, relíquia e temporada registradas; escopo de conteúdo fechado. |
| 1 | Projeto de conteúdo e geografia regional | 0 | Cada destino tem função, missão, inimigos, descobertas, recompensa e consequência; conexões fazem sentido. |
| 2 | Estrutura técnica e persistência | 0–1 | IDs, estados, transições e autoridade definidos; protótipo salva e restaura um desbloqueio. |
| 3 | Percurso inicial jogável | 2 | Queda → vila → missão → expedição → retorno funciona com recursos provisórios e retomada. |
| 4 | Integração social e coop | 3 | Encontrar parceiro, formar grupo, viajar, completar objetivo e retornar funciona; falhas de conexão têm recuperação definida. |
| 5 | Cidade, NPCs e campanha | 1, 3–4 | Serviços e missões formam uma sequência compreensível, com consequências persistentes e estados por jogador/grupo. |
| 6 | Todas as regiões de exploração | 4–5 | Territórios do escopo são jogáveis, conectados, preenchidos e diferentes em atividade e ritmo. |
| 7 | Dungeon principal e relíquia | 4–6 | Grupo descobre o acesso, resolve puzzle, vence chefe e recebe o desbloqueio correto uma única vez. |
| 8 | Arte final, animação e áudio | Validação dos trechos de 3–7 | Identidade consistente, quatro estações aplicáveis integradas, renderização e movimento revisados. |
| 9 | Balanceamento e revisão integral | 5–8 | Jornada testada por jogadores novos, sem bloqueios; exploração, evolução, desafio e repetição ajustados. |
| 10 | Candidato a lançamento e publicação | 9 | Checklist final aprovado, pacote revisado; publicação só mediante solicitação e conferência antes/depois. |

A produção final de um território pode começar após validar seu próprio percurso. Não é necessário esperar todas as regiões para iniciar arte, nem finalizar toda a arte antes de testar a história.

## Etapa 0 — Fechar as regras do jogo

- [x] Registrar o destino fixo da primeira relíquia e sua identificação na temporada.
- [x] Definir propriedade e escopo dos estados: progresso pessoal, mundo/grupo, cidade social e sessão de combate.
- [x] Definir tamanho de grupo, chegada tardia, repetição e desconexão, inclusive saída do anfitrião.
- [x] Definir a apresentação da árvore, o primeiro contato na vila e a explicação inicial da invocação.
- [x] Fechar a lista de territórios, NPCs, inimigos, missões e atividades opcionais desta entrega.
- [x] Definir estados antigos que serão preservados e a estratégia de compatibilidade dos saves.

Saída: decisões curtas e verificáveis, sem começar por um servidor para cinquenta jogadores ou por um sistema completo de temporadas.

## Etapa 1 — Dar função a cada lugar

Para cada território, produzir uma ficha: entrada e saídas; atividade principal; conflito; NPC relacionado; objetivos; pistas; espécies de inimigos; recursos; segredos; consequência; estado salvo; requisitos de grupo; recursos de arte necessários.

Escopo territorial proposto, baseado em [PRIMEIRO_ANDAR.md](PRIMEIRO_ANDAR.md):

| Destino | Conteúdo central | Mudança observável |
| --- | --- | --- |
| Clareiras da Chegada | Equipamentos, sobrevivência e sinais da invocação | Prólogo concluído e saída descoberta. |
| Estrada dos Carreteiros | Investigar ataque, localizar desaparecido e carga | Retorno de trabalhador e referência de rota. |
| Vila das Flores e Cinturão Rural | Relações, serviços, cultivo, preparo e defesa | Reconhecimento dos moradores e reparos conforme a missão. |
| Pomar das Cercas Partidas | Investigar invasões e recuperar cultivo | Parcela restaurada e pista sobre os canais. |
| Bacia do Moinho | Investigar água e consertar comportas | Moinho retomado e travessia acessível. |
| Várzeas Afundadas | Explorar margens, obter amostras e registros | Preparo de expedição e rota alternativa. |
| Pedreira dos Veios Vivos | Investigar minério e enfrentar criaturas de pedra | Receita testada, extração segura e posto de apoio. |
| Túneis do Carvão | Dungeon secundária e história de uma equipe isolada | Evidência do núcleo e saída de manutenção. |
| Mata das Cascas Ocas | Rastrear criaturas e descobrir seu ponto de energia | Localização dos jardins e novo circuito de exploração. |
| Observatório das Passagens | Interpretar encaixes e cartografia de relíquias | Mapa de andares compreendido e relíquia utilizável. |
| Jardins da Raiz Antiga | Aprender o circuito num mecanismo preservado | Parte do jardim recuperada e intervenção preparada. |
| Bastião do Enxerto | Investigação final, puzzle e chefe | Problema local resolvido e próxima região revelada. |

Os nomes e enredos continuam revisáveis. A nova navegação permite territórios em cenas separadas, com espaços internos extensos. A ilustração contínua representa relações geográficas, sem obrigar carregar tudo ao mesmo tempo.

- [x] Desenhar o mapa de dependências das missões e informações.
- [x] Marcar caminhos obrigatórios, alternativos, opcionais e atalhos posteriores.
- [x] Definir colecionáveis por uso: história, receitas, sementes, registro natural e domínio de desafios.
- [x] Separar descoberta do acesso à dungeon de preparo para vencê-la.
- [ ] Dimensionar percursos e encontros antes de fechar tamanho físico e tempo esperado.

## Etapas 2–4 — Estrutura e primeiro percurso completo

- [x] Criar catálogo versionado de temporada, andares, destinos regionais, relíquias e pré-requisitos, com IDs estáveis.
- [x] Separar os dados de navegação dos desenhos dos mapas.
- [ ] Adaptar mapa-múndi e mapa regional com destinos visitados, disponíveis, desconhecidos e bloqueados.
- [ ] Definir transição entre cidade social, área individual e instância de grupo; preservar ponto de retorno e grupo.
- [ ] Persistir missões, descobertas, estados de região e desbloqueio da relíquia, com tratamento de escrita interrompida.
- [ ] Distinguir conclusão de objetivo pessoal e alteração compartilhada do mundo; definir quem valida cada ação.
- [ ] Montar a queda, o caminho inicial, uma parte funcional da vila e uma expedição de investigação usando bases existentes.
- [ ] Garantir que o mesmo percurso funciona ao sair e continuar depois.
- [ ] Formar grupo pela cidade, iniciar expedição, sincronizar objetivos e voltar ao ponto social correto.
- [ ] Tratar integrante com outra etapa de história, chegada tardia, morte/reanimação e queda da conexão.
- [ ] Validar recompensas e interações no responsável pela sessão, evitando duas entregas pelo mesmo evento.

Esse primeiro percurso é uma entrega intermediária de integração. Não conta como primeiro andar completo e não reduz o escopo das demais regiões.

## Etapas 5–6 — Campanha, NPCs, criaturas e exploração

### Cidade e personagens

- [ ] Fechar as personas propostas de Dara, Lia, Ivo, Rosa, Tomás, Nilo, Osvaldo e Estela; revisar nomes e funções.
- [ ] Escrever falas de encontro, missão, andamento, resolução e reação posterior.
- [ ] Integrar agenda, localização, serviço e disponibilidade, incluindo atendimento com mais de um jogador.
- [ ] Fazer a explicação do chamado e a reputação de herói aparecerem em acontecimentos e reações.
- [ ] Preservar personalização e pluralidade de invocados; resolver referências ao guia provisório.

### Jornada e defesa

- [ ] Implementar estados e rastreio das missões, com pistas conservadas no diário.
- [ ] Conectar história a cultivo, coleta, fabricação e exploração; ajustar receitas e fontes de materiais.
- [x] Defesa da vila: aviso de Lia, ligação de Ivo montada na barreira da entrada, três ondas de rebentos pelo sul (3, 4 e 5) e reparos com Osvaldo (`defesa_vila.gd`, missão `defesa_da_vila`). A ligação muda a defesa: ferro tira um rebento da primeira onda, raiz tira 3 de vida de todos. Derrota recomeça a defesa sem perder o que já foi feito.
- [ ] Definir invasões posteriores e sua frequência; evitar ações destrutivas enquanto o mundo está desconectado.
- [ ] Implementar e revisar as histórias locais e suas mudanças observáveis nos doze territórios do escopo.

### Monstros e atividades

- [ ] Inventariar inimigos atuais e escolher o que reaproveitar, adaptar ou produzir.
- [ ] Desenvolver as três famílias propostas: rebentos, cascudos de minério e sentinelas enxertadas.
- [ ] Dar papéis diferentes às variantes: aproximação, distância, defesa e encontros especiais; definir sinais e oportunidades de resposta.
- [ ] Ajustar níveis ou outra forma de evolução, recursos e equipamento necessários a cada estágio; a curva ainda precisa ser escolhida e medida.
- [ ] Integrar loot, fabricação e recompensas opcionais sem depender de sorte para obter uma pista essencial.
- [ ] Construir segredos e colecionáveis com função e contexto; preservar sua coleta e recompensas ao reconectar.
- [ ] Testar cada território sozinho e dentro do percurso da campanha.

## Etapa 7 — Dungeon, puzzle, chefe e relíquia

- [ ] Desenhar a dungeon principal e a secundária separadamente das imagens do mapa.
- [ ] Especificar o puzzle de circuitos com solução, pistas, possibilidades de erro, feedback e retomada.
- [ ] Ensinar os princípios no moinho e jardins, mantendo desafio no conjunto final.
- [ ] Usar formas, posições e sinais além de cores; manter leitura em telas pequenas.
- [ ] Dimensionar ações cooperativas para o grupo mínimo escolhido e tratar saída de um participante.
- [ ] Integrar encontros, pontos de retomada e o Custódio do Enxerto, ou o chefe que for escolhido na revisão.
- [ ] Fazer o combate exigir aprendizado e preparo, com sinais claros e colisões coerentes.
- [ ] Conceder a relíquia fixa conforme a regra de posse, sem duplicação por reconexão ou repetição de mensagem.
- [ ] Instalar/ativar a relíquia no observatório e atualizar mapa-múndi, diário e reações da vila.
- [ ] Mostrar o estado real do próximo destino: aberto se houver conteúdo disponível, em preparação se não houver.
- [ ] Definir repetição do chefe e expedições posteriores sem desfazer a conquista narrativa.

## Etapa 8 — Produção visual e sonora

- [ ] Aprovar câmera, referência do personagem, escala dos objetos, materiais, paleta e identidade de cada família.
- [ ] Fazer lista por território de terrenos, construções, props, personagens, criaturas, efeitos, ícones e áudio.
- [ ] Reutilizar peças coerentes; produzir conjuntos modulares de floresta, vila, água, mineração e ruínas.
- [ ] Integrar primavera, verão, outono e inverno em todo cenário externo novo, preservando geometria e uso.
- [ ] Aplicar bordas, cantos, transições, profundidade, colisões e navegação corretas.
- [ ] Conferir NPCs, inimigos, ferramentas e chefe em movimento no motor, inclusive equipamento e direções.
- [ ] Revisar mapas e interfaces em desktop, celular, rotação e tela dividida suportada; textos e símbolos com margens e alinhamento.
- [ ] Integrar música, ambiente e efeitos relevantes à exploração, aos sinais dos puzzles e ao combate.

As imagens em [conceitos/](conceitos/) orientam a discussão. Não comprovam arte integrada, escala, navegação, desempenho ou cenas prontas. Aplicar as [regras visuais](../../ferramentas/projeto/REGRAS_VISUAIS.md) e skills correspondentes durante a execução.

## Etapas 9–10 — Validação e entrega

### Jogabilidade

- [ ] Fazer a campanha do zero até a relíquia com jogadores sem conhecer as soluções.
- [ ] Medir orientação, tempo de atividade, repetição, dificuldade e trechos sem propósito.
- [ ] Ajustar progressão e recursos para permitir preparo significativo sem repetição obrigatória de entregas vazias.
- [ ] Conferir conteúdo opcional, estados após a vitória e diferenças entre grupos que exploram em ordens distintas.

### Persistência e coop

- [ ] Conferir salvar/continuar em cada mudança crítica de estado.
- [ ] Testar dois jogadores e o limite de quatro, com entrada e saída em fases diferentes.
- [ ] Testar inventário cheio, recompensa já recebida, pedido repetido, queda de conexão e encerramento do anfitrião.
- [ ] Verificar isolamento entre mundos, personagens e temporadas e compatibilidade com saves preservados.

### Plataformas e revisão

- [ ] Testar os percursos relevantes em Web, Android e desktop; incluir desempenho em aparelho alvo e redes distintas.
- [ ] Inspecionar renderização real, estações, margens da interface, ordem de camadas e legibilidade dos sinais.
- [ ] Criar testes dos novos contratos de progressão, puzzle e relíquia; usar saves isolados.
- [ ] Executar perfis pertinentes do harness e aproveitar resultados apenas quando ele confirmar o estado.
- [ ] Preparar pacote e descrição concreta do conteúdo entregue; publicar apenas quando solicitado, com conferência local e no ar.

O perfil atual `coop-online` cobre um cenário de conjuntos, não certifica esta campanha. Testes existentes de introdução, mapa-múndi e inventário ajudam a detectar regressões, mas não substituem os testes novos nem a revisão visual.

## Definição de primeiro andar completo

Só marcar a entrega completa quando todos estes itens forem verdadeiros:

- Queda, chamado, vida na vila, exploração, defesa e conclusão formam uma história compreensível.
- Os doze territórios do escopo final têm conteúdo funcional e consequências próprias, sem locais prometidos apenas como decoração inacessível.
- Personagens e serviços estão integrados; as famílias de inimigos e o chefe são legíveis e funcionais.
- Cidade social, formação de grupo e expedições funcionam com os limites declarados.
- Dungeon secundária, dungeon principal e puzzle podem ser concluídos e retomados conforme suas regras.
- Relíquia fixa é concedida corretamente e seu destino aparece no mapa-múndi.
- Save, progressão, inventário e recompensas sobrevivem às transições e falhas previstas.
- Arte, animações, som, estações aplicáveis e plataformas alvo passaram pelas revisões correspondentes.

## Vila: chegada e atividades

Plano em `PRIMEIRO_ANDAR.md`, seção "Vila e Cinturão Rural". Ordem de implementação: abrigo, preparo com Ivo, treino com Dara e as três missões secundárias.

- [x] Preparo com Ivo: a bancada oferece a ligação de ferro ou a de raiz trançada. Código em `codigo/campanha/preparos_ivo.gd`, `progresso_campanha.gd` (`preparo`, `registrar_preparo`) e `percurso_prototipo.gd` (`_usar_bancada`). A escolha usa o diálogo existente com opções (`iniciar_com_opcoes`). A barreira do pomar mostra o texto da ligação escolhida. Hoje Também muda a defesa da vila (ver abaixo).
- [x] Abrigo de Lia: banco de descanso ao lado dela (alvo `descanso` da vila) que recupera vida e fôlego; Lia o menciona na segunda conversa.
- [x] Treino de Dara (mecânica): ao fim da conversa, quem tem espada e escudo pode treinar bloqueio (3), esquiva (3) e contra-ataque (2) contra um boneco que avisa e ataca de leve (`treino_dara.gd`, `boneco_treino.gd`). Sem XP de maestria e sem salvar nada; repetível quando quiser. O boneco é um desenho provisório. Falta ligar o treino à missão "Antes de sair outra vez", com dinheiro e o treino livre como recompensa.
- [x] Missões secundárias: "Ferro que ainda serve" (Ivo), "Quem ficou para trás" (Rosa) e "Antes de sair outra vez" (Dara), opcionais, após o acolhimento. Objetivos no catálogo (`primeiro_andar.json`), falas por etapa em `percurso_prototipo.gd` (`FALAS_PASSOS`) e gatilhos na estrada (`encontro_estrada.gd`). Aviso "Missão concluída" com a recompensa e recibo no save (`recompensas`), sem entrega dupla. A Dara conclui ao terminar o treino.
- [~] Reações da vila ao progresso (inclui a defesa concluída): feitas na segunda conversa de Lia, Rosa, Ivo, Nilo, Osvaldo, Tomás e Dara (`_reacao`); falta o trabalhador recuperado visível (exige um morador novo) e novos pedidos por região liberada (só existem pomar, estrada e chegada).
- [x] Serviços em ouro dentro da campanha: Tomás vende ferro, madeira e fibra e compra o que passa de 5 de cada material; Rosa trata ferimentos (10) e vende poção de cura (20) (`servicos_vila.gd`, menus por `iniciar_com_opcoes`). Nada de Brasas nem moeda de forja na campanha: HUD sem elas e prêmios só em ouro, materiais, poções e receita.

## Próxima entrega recomendada

Expandir a campanha da defesa para os territórios ainda planejados, começando pela Bacia do Moinho, e aprofundar as consequências visíveis na cidade. Revisar cidade social, grupos e autoridade de sessão antes de certificar retomada online. Os demais territórios, famílias de criaturas, dungeons, puzzle e chefe continuam no escopo do primeiro andar completo. Publicação depende de solicitação própria.

## Apresentação do mapa de relíquias

A primeira peça é uma relíquia em 3D real, com a ilha da Primeira Raiz, árvore, raízes, casinhas e base rochosa, baseada na miniatura cartoon, flutuando e girando no próprio eixo dentro de um SubViewport transparente. Cada domínio ocupa exatamente uma célula da grade pintada. A primeira peça fica na coluna 4, linha 3, com a ilustração inteira e o destaque dentro desse espaço, preservando margem e proporção ao redimensionar a tela.

A seleção externa apresenta o primeiro domínio como uma miniatura independente sobre um tabuleiro de terra/pergaminho. A água é uma camada de shader animada, separada do recorte estático do tabuleiro e da peça. Somente a Primeira Raiz é exposta nesta entrega. Clicar ou tocar na peça abre diretamente suas regiões com transição de escurecimento, sem painel ou botão de confirmação no mapa-múndi; os demais espaços ficam vazios. A nomenclatura proposta na interface é **Domínios**; os IDs `andar_01` e `andar_02` são preservados para compatibilidade dos saves e regras existentes.

O reforço dos encontros, o lobby por estágio e a navegação regional com personagem continuam pendentes: a correção de direção desta tarefa concentrou a implementação no tabuleiro externo e na primeira peça.

## Mapa regional em tela inteira

A Primeira Raiz usa uma ilustração cartoon própria com trilhas, pontes e relevos conectando seus doze locais. O mapa cobre a janela, sem barras vazias; a câmera acompanha a seleção e permite arrastar com mouse ou toque. As setas escolhem lugares pela direção e Enter confirma a região. Marcadores pequenos distinguem locais disponíveis, concluídos e em preparação, mantendo as regras existentes. Uma faixa compacta de viagem substitui o painel grande; os marcadores não transformam territórios planejados em cenários jogáveis. Não há personagem caminhando pelas rotas nesta entrega.

Por decisão do usuário, a seleção regional voltou à ilustração fixa original `assets/ui/campanha/mapa_primeira_raiz_cartoon.png` (1536×1024). A textura usa importação sem perdas, sem limite de tamanho e com mipmaps; não é ampliada artificialmente como se tivesse novos detalhes. Pontos clicáveis, progresso e enquadramento por mouse/toque/setas permanecem independentes da arte. Não há água, cachoeiras ou outros efeitos animados sobre a pintura regional. A montagem experimental em TileMaps permanece disponível no código, mas não é carregada nessa tela. O tabuleiro externo conserva a peça 3D e suas animações. A imagem é cartografia simbólica da interface e não muda as estações dos cenários jogáveis.


### Cidade: composição ampliada em peças do jogo

A referência está em `arte/fontes/campanha/cidade_primeira_raiz/conceito.png`, com prompt e contrato no mesmo diretório. A implantação segue dez edifícios e duas torres, numa área de 1536×1024 unidades, com posições e proporções medidas nessa imagem. Cinco atlas próprios reproduzem as arquiteturas e a árvore da praça nas quatro estações. Pisos Wang, vegetação de fundo, cercas e pequenos enfeites continuam modulares; o pavimento tem pedras menores, compatíveis com a escala da referência. Há praça, mercado de três tendas, oficinas, moradias, enfermaria e entrada ao sul. Colisões e navegação permanecem independentes da arte, e a ilustração não é o piso jogável. Os diálogos e a sequência de missões do percurso permanecem disponíveis. As outras regiões ainda precisam de produção de conteúdo para atingir a escala solicitada: vários encontros, história, missões e exploração. Não considerar o combate com um slime como fase final.
