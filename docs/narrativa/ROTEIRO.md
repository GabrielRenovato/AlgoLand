# AlgoLand — O caminho de volta

> **Arquivo histórico — proposta superada.** O [roteiro vigente e estado da implementação](PRIMEIRO_ANDAR.md) reúne a invocação pela árvore, o baú, os rebentos, o Cerne Partido, a Estrada dos Carreteiros e a continuidade na vila. Referência atualizada em 31/10/2026. A [versão literária em capítulos](LIVRO_PRIMEIRA_RAIZ.md) serve de base à futura HQ. O texto abaixo permanece como referência; não define a abertura nem o passado dos chefes da campanha atual.

Primeira proposta de roteiro. Título de trabalho, acontecimentos novos e falas abaixo estão em discussão; não representam conteúdo já implementado nem substituem automaticamente a história atual.

## Ideia central

A Vila das Flores foi construída sobre uma passagem chamada Limiar. Seus primeiros moradores aprenderam a atravessá-la para buscar materiais e a cultivar raízes capazes de estabilizar suas bordas. A vila cresceu em torno desse acordo: sair, trazer algo e cuidar do lugar para onde se volta.

Agora, o selo da praça enfraquece. Nas profundezas, antigos vigias continuam cumprindo ordens de uma época que ninguém recorda por inteiro. O jogador encontra abrigo na vila e participa da investigação. A fazenda se torna sua casa e seu vínculo com esse lugar.

Pergunta que conduz a história: por que uma passagem feita para ligar lugares passou a aprisionar quem a protege?

Tema: construir um lar exige cuidado compartilhado. Explorar muda o que sabemos; conviver muda o motivo de continuar.

## O que preservar do jogo

O prólogo atual apresenta Bento resgatando o personagem na Arena do Limiar, a espada e o escudo de um antigo guardião, a Vila das Flores e a fazenda vazia. A origem anterior do personagem não é explicada: preservá-la em aberto, sem impor amnésia, parentesco ou profecia.

O primeiro arco já implementado tem quatro missões: A Primeira Vigília, Raízes que Sustentam, O Eco nas Ruínas e A Última Vigília. Seu desfecho restaura o selo e libera a recuperação diária de energia na praça. A fenda continua aberta.

O jogo já possui estações, colheitas, moradores com rotinas, fabricação, expedições, guardiões, Brasas e melhorias permanentes. Orion oferece serviços ao concluir os andares. O roteiro deve aproveitar essas relações.

Referências verificadas: `codigo/introducao/roteiro_introducao.gd`, `codigo/cidade/jornada_limiar.gd` e `codigo/fendas/guia_andar.gd`.

Tudo que segue como nova revelação, missão, cena ou consequência é proposta narrativa.

## Papel do jogador e do coop

O jogador escolhe aparência, nome e modo de viver. A história reconhece suas ações; não exige roupa, personalidade, romance ou origem determinados. Respostas podem expressar curiosidade, pragmatismo ou afeto sem criar três campanhas diferentes.

Ele passa a ser tratado como alguém capaz de fazer a travessia. Outras pessoas também podem atravessar: no coop, os jogadores formam uma equipe de vigília. Falas não devem proclamar que um único escolhido pode salvar o mundo.

Pedidos cotidianos constroem relações, mas a amizade não é uma ferramenta mágica que precisa de pontuação para impedir uma catástrofe. O jogador pode pescar, plantar e descansar sem punição narrativa por adiar a campanha.

## Tom e identidade do mundo

Fantasia acolhedora na superfície, mistério e perigo nas expedições. Moradores têm humor, trabalho e desejos que existem além da crise. As perdas do passado aparecem em objetos, hábitos e conversas, evitando longas aulas de história.

A cultura local mistura cultivo e travessia: sementes guardadas nas partidas, ferramentas consertadas para quem volta e refeições coletivas após uma vigília. São motivos narrativos para orientar futuras artes e cenas, ainda não recursos implementados.

A estação muda a maneira de viver e preparar uma expedição. A campanha, porém, não deve exigir esperar um ano inteiro ou perder uma janela sazonal para avançar.

## Personagens e conflitos

| Personagem | Papel na história proposta | Conflito e mudança |
| --- | --- | --- |
| Bento | Acolhe o jogador e transmite o cultivo das raízes do selo. | Confia no costume herdado da avó; aprende a investigar o motivo por trás dele. |
| Lia | Organiza a proteção e as decisões da vila. | Carrega responsabilidade demais; aprende a dividir decisões e ouvir quem atravessa. |
| Ivo | Reconhece o metal dos vigias e reconstrói sua técnica. | Sua primeira resposta é reforçar tudo; descobre que uma estrutura rígida pode precisar de passagem. |
| Estela | Interpreta sinais e compara registros de vigílias. | Oferece hipóteses, admite erros e passa a trabalhar com as evidências trazidas pelo grupo. |
| Rosa | Dá peso humano aos retornos e aos ferimentos. | Defende limites para a exploração; não trata o jogador como recurso inesgotável. |
| Orion | Conhece caminhos e ofícios preservados dentro do Limiar. | Sabe executar o antigo protocolo, mas precisa descobrir se ainda é correto mantê-lo. Não pressupor traição ou onisciência. |

Os demais moradores participam com seus ofícios e histórias próprias. Nem todo pedido precisa revelar uma peça do mistério central.

## Prólogo — Um lugar para voltar

Objetivo dramático: transformar o resgate em uma relação e a fazenda em um destino desejável.

1. Bento encontra o personagem no Limiar, verifica se consegue andar e indica a saída. Os equipamentos permitem escapar; sua origem fica como pergunta futura.
2. Na vila, Lia verifica a rachadura na praça enquanto outras pessoas seguem trabalhando. O problema é visível, mas a vida continua.
3. Bento apresenta a fazenda. O tutorial de limpar, plantar e regar permanece interativo, com falas curtas nos locais de uso.
4. A primeira colheita leva o jogador até Rosa. O cultivo já ajuda alguém antes de virar requisito de campanha.
5. Lia convida o jogador a investigar a primeira vigília. Aceitar significa colaborar com a comunidade que o acolheu.

Falas propostas para momentos separados:

> Bento, no resgate: “Consegue ficar de pé? Ótimo. O resto a gente descobre lá fora.”
>
> Lia, na praça: “A pedra abriu outra vez. Primeiro vamos cuidar de quem chegou.”
>
> Bento, na fazenda: “A casa precisa de uns reparos. A terra ainda está boa. Se quiser ficar, começamos por aqui.”

Essas falas complementam o tutorial; não substituem instruções essenciais de controles, recuperação ou perda de melhorias temporárias.

## Ato I — A vila que sustenta

Aproveita as quatro missões existentes, preservando seus objetivos e recompensas.

| Missão existente | Ação atual | Função dramática |
| --- | --- | --- |
| A Primeira Vigília | Lia pede a derrota do guardião do primeiro andar. | Revelar que o inimigo foi um vigia; a ameaça tem uma história humana. |
| Raízes que Sustentam | Bento recebe duas colheitas da estação. | Demonstrar que o cuidado na superfície participa da proteção da vila. |
| O Eco nas Ruínas | Ivo pede a vitória contra o guardião do sexto andar. | Ligar o metal das armas à pedra da praça e aos antigos construtores. |
| A Última Vigília | Após aceitar, vencer três andares e voltar a Estela. | Mostrar que retornar faz parte do funcionamento do selo. |

Desfecho preservado: a fonte volta a recuperar energia e a vila celebra a melhora. Esse resultado é verdadeiro e útil.

Gancho novo, posterior à conclusão: Ivo encontra no metal recuperado uma inscrição incompleta. O símbolo do selo aparece ligado a caminhos que continuam além da área protegida. A restauração resolveu o problema local; ainda há algo a descobrir sobre a rede antiga.

## Ato II — Os nomes sob a pedra

Objetivo dramático: conhecer quem criou o sistema e descobrir o custo do protocolo antigo.

### 1. O metal lembra

Ivo compara uma peça recuperada com a inscrição da praça. O jogador leva o registro a Estela e pergunta a Orion sobre a mesma marca. Não acrescentar moeda obrigatória só para sustentar essa conversa.

Revelação: o selo faz parte de uma rede de passagens entre assentamentos. A Vila das Flores preservou apenas uma parte de seu conhecimento.

### 2. Um lugar à mesa

Bento e Rosa organizam uma refeição de retorno usando produtos comuns da estação. A cena apresenta os nomes de vigias que deixaram de voltar e mostra como suas famílias seguiram vivendo.

O jogador escolhe perguntar por uma pessoa ou ouvir uma lembrança. O objetivo é dar significado aos vestígios da próxima expedição, sem exigir entregas repetidas para cada fala.

### 3. A ronda que não terminou

Em uma expedição, o grupo encontra registros de turnos e sinais de manutenção interrompida. A descoberta deve ser anexada a um trecho já existente, escolhido após verificar seus encontros; o roteiro não fixa um andar arbitrário.

Revelação central: durante uma antiga crise, os vigias ativaram um fechamento de emergência. Parte deles ficou presa sustentando o protocolo. Com o tempo, a defesa passou a tratar qualquer travessia como invasão. Os ecos continuam repetindo as últimas ordens.

Isso explica a presença dos vigias; não precisa explicar toda criatura ou mistério do mundo.

### 4. O que Orion sabe

Orion reconhece o procedimento nos registros e explica os limites do que sabe. Ele preservou técnicas de travessia e sobrevivência, mas não tinha acesso às evidências da superfície.

O conflito aparece: reforçar o sistema pode prolongar o aprisionamento; desligá-lo sem preparar uma substituição pode expor a vila. Lia pede tempo para estudar uma terceira solução.

Fim do ato: pela primeira vez, os moradores discutem juntos qual proteção querem manter e quem pode estar pagando por ela.

## Ato III — A vigília de todos

Objetivo dramático: substituir uma obrigação esquecida por uma proteção mantida em conjunto.

### 1. Preparar a volta

Uma preparação finita reúne cultivo, fabricação e investigação. Bento prepara raízes, Ivo produz uma peça de conexão e Estela recompõe a sequência do selo. Rosa organiza o acolhimento de quem retornar.

Implementação futura deve usar sistemas existentes sempre que possível. Sem exigir todas as profissões, concluir amizades, esperar uma estação específica ou cumprir tarefas simultâneas impossíveis em solo.

### 2. A porta por dentro

A expedição final alcança o ponto que mantém o protocolo de emergência. Sua localização e a eventual necessidade de um espaço próprio dependem de uma avaliação técnica posterior. Os mapas existentes não ganham uma conclusão inédita só por este documento.

O último vigia é um personagem novo proposto: alguém que assumiu a responsabilidade de proteger todos e perdeu a capacidade de reconhecer o fim da emergência. Sua presença é antecipada por nome e registros durante o segundo ato.

O confronto começa porque o protocolo impede a intervenção. O objetivo dramático é abrir espaço para a mudança; não apresentar a morte de mais um vigia como solução suficiente para libertar os anteriores.

### 3. A última ordem

Após o confronto, o grupo conecta o trabalho feito na superfície ao ponto de controle. O protocolo antigo pode finalmente encerrar sua ronda. O jogador confirma a intervenção por uma escolha clara, sem uma resposta secreta que invalide todo o preparo.

Falas propostas:

> Último vigia: “Se eu deixar o posto, quem fica?”
>
> Jogador: “A vila inteira.”
>
> Último vigia: “Então… posso voltar?”

A resposta sobre o destino físico ou espiritual dos ecos deve ser definida antes da escrita final da cena. A libertação precisa ser compreensível, sem prometer ressuscitar moradores ou parentes.

### 4. O caminho de volta

O encerramento acontece na praça, com uma refeição e pequenos gestos dos moradores. O lugar continua sendo uma vila que precisa de trabalho e cuidado. O jogador pode responder com afeto, humor ou poucas palavras.

A campanha entrega uma conclusão comum: o protocolo que aprisionava os vigias termina e a proteção passa a ser mantida pela comunidade. As passagens permanecem utilizáveis para exploração.

## Depois da campanha

A fazenda, as relações, as estações e as expedições continuam. Combates repetíveis podem ser apresentados como regiões ainda instáveis e ecos residuais, sem repetir a libertação final como se ela não tivesse acontecido.

Novas histórias podem explorar outros assentamentos da rede. O final desta campanha não depende de anunciar um vilão maior nem de desfazer a conquista da vila.

## Primeiro recorte de produção

Antes de expandir a campanha inteira, revisar o prólogo e a apresentação do arco existente:

- Resgate mais curto, com espaço para o jogador responder.
- Uma cena breve na praça que mostre a preocupação de Lia.
- Uma conversa cotidiana que torne a fazenda pessoal.
- Entregas das quatro missões conectadas à mesma pergunta central.
- Celebração da restauração e uma pista opcional sobre a rede.

Esse recorte permite avaliar o tom e a identidade usando personagens, mapas e objetivos existentes. Só depois detalhar diálogos completos, objetivos técnicos e cenas dos atos seguintes.

## Decisões para a próxima revisão

Esta proposta assume uma campanha acolhedora com mistério, protagonistas livres e solução coletiva. Precisamos escolher o grau de melancolia, como os ecos se manifestam, o limite do conhecimento de Orion e o destino do último vigia. Nomes novos, cenas e novas mecânicas permanecem propostas até essa revisão.
