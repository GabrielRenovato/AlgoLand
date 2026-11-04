# Martelada para baixo — vista frontal

Canônico e movimento: `martelada_folha_escolhida_usuario.png`, fornecida e aprovada pelo usuário ao montar `martelada_folha_escolhida.gif`. A versão de pegada fechada v3 foi rejeitada; não usá-la como referência desta direção.

- Mesma identidade, volume corporal, martelo, couro, ferro, faixa vermelha e manto azul-petróleo do canônico aprovado.
- Direção: baixo/sul do mapa, rosto e peito de frente para a câmera elevada do jogo. Não é girar uma imagem de perfil nem golpear para a lateral.
- Manto no ombro anatômico direito (esquerda da imagem frontal), placa de ferro no esquerdo (direita da imagem frontal). Manter mão dominante e ordem das mãos no cabo conforme a folha aprovada.
- Nove poses, grade 3×3: guarda, carregar, preparar atrás da cabeça, ápice vertical, descer, contato à frente dos pés, absorver, recuperar, guarda. Chão e centro dos pés comuns; joelhos flexionam e o tronco participa do golpe. O martelo cruza o plano à frente do corpo em direção à parte inferior da imagem.
- Cabeça, ombros, quadril, cotovelos, mãos e pés devem mostrar anatomia frontal e trajetória contínua. Na preparação a arma sobe; no contato ambas as mãos permanecem vinculadas ao cabo e a cabeça de pedra alcança o chão abaixo/à frente dos pés.
- Tempos: 100/150/180/60/50/80/110/160/170 ms, com 500 ms extras ao final apenas na demonstração GIF.
- Enquadramento fixo, escala comum à folha, fundo transparente, corpo e arma inteiros em todos os quadros. Reservar espaço abaixo dos pés para a cabeça da marreta no contato. Medir o desenho exportado antes de registrar a transformação final; não normalizar poses por contorno.
- Fontes/prompts nesta pasta; folha de contato e GIF em `arte/previas/inimigos/lorde_goblin_2d/`. Esta etapa produz a nova direção do estudo 2D aprovado.

## Correção e montagem

O usuário apontou a pose de elevação (terceiro quadro): a cabeça da marreta estava no meio de uma barra entre as mãos. `baixo_quadro_03_corrigido_v2.png` corrige a montagem, com cabo contínuo e pedra em uma ponta, após descartar a primeira correção por reduzir as proporções do corpo. Os dois quadros de impacto receberam acabamento na parte inferior da pedra, que vinha cortada na primeira folha. As outras cinco poses usam os desenhos originais da folha frontal.

Atlas montado: `martelada_baixo_v6.png`, células640², raiz320/500. `registro_martelada_baixo.json` contém todas as transformações de resolução e registro pelo corpo/pés. `ferramentas/inimigos/lorde_goblin_2d/montar_baixo.py` reproduz o atlas e o GIF; valida margem mínima e mantém a mesma transformação para corpo, roupa e arma de cada fonte de correção. A fonte original não é reescalada por contorno.

Prévia: `arte/previas/inimigos/lorde_goblin_2d/martelada_baixo.gif`. Contato dos nove quadros e contato renderizado no Godot ficam na mesma pasta. `validacao_baixo_harness.json` registra a reprodução de dois ataques, nove poses observadas e encerramento na guarda, com projeto gráfico mínimo sem autoloads ou saves do usuário. Essa revisão é do estudo frontal em fundo neutro; não representa integração no combate nem aprovação estética do usuário.


## Preparação para trás das costas

O usuário corrigiu a direção do movimento: a preparação lateral com a marreta na diagonal acima do ombro não serve para este golpe para baixo. A pedra deve carregar atrás da nuca/costas, com arco para a frente. A primeira tentativa deixou as mãos muito altas e foi rejeitada. A pose atual `baixo_quadro03_costas_maos_proximas.png` baixa as mãos junto à cabeça, dobra mais os cotovelos e mantém a pedra parcialmente encoberta atrás da nuca. O cabo usa escorço em profundidade; não voltar à barra horizontal ou à marreta aberta para um canto da imagem.

O GIF anterior foi preservado em `martelada_baixo_anterior_pose_lateral.gif`. A alteração atual troca apenas o terceiro quadro; os quadros de impacto e as outras poses permanecem iguais. O registro e o empacotador usam o novo canônico dessa preparação. A aprovação estética continua com o usuário.


## Pegada efetiva no cabo

O usuário apontou que os punhos apenas se tocavam ao lado do cabo. A fonte atual é `baixo_quadro03_costas_pegada_real.png`: mãos empilhadas verticalmente no mesmo eixo da madeira, dedos fechados em torno dela e punhos conectados aos antebraços. A correção foi inspecionada em recorte ampliado antes da montagem. Preservar a preparação atrás da nuca e os cotovelos dobrados; não voltar aos dois punhos lado a lado sem contato real com o cabo. O atlas derivado é v4 e o teste lê a versão consumida de `registro_martelada_baixo.json`. O detalhe da pegada e o GIF com nome novo estão na pasta de prévias.


## Mãos coladas à cabeça e só a ponta do cabo

Esclarecimento do usuário: mãos encostadas no topo/trás da cabeça e cabeça da marreta inteiramente escondida atrás do corpo. A única parte visível da arma nessa preparação é a pequena ponta de cabo acima das mãos. Não expor pedra ou tiras de ferro atrás das orelhas. A fonte atual é `baixo_quadro03_maos_na_cabeca.png`; mantém as duas mãos fechadas no cabo e aproxima o punho inferior do cabelo. Atlas derivado v5. O GIF atualizado tem o nome `martelada_baixo_maos_na_cabeca.gif`, com detalhe ampliado da preparação na mesma pasta de prévias.


## Quadro intermediário com marreta vertical

Pedido do usuário: inserir entre a preparação e a descida um quadro com a marreta acima da cabeça em linha reta. A fonte `baixo_intermediario_marreta_vertical.png` tem cabo vertical no centro do corpo, mãos empilhadas agarradas à madeira e pedra visível no alto. Foi inserida no índice3 (quarto quadro), com60ms. Os oito desenhos do atlas v5 permanecem intactos. O atlas atual é v6, grade3×3 com nove células640². A transformação única da nova fonte é627² em7/5, mantendo o apoio dos pés. Prompt e referências estão preservados nesta pasta.

Prévia atual: `martelada_baixo_9quadros.gif`; folha: `martelada_baixo_folha_9quadros.png`. O registro descreve a ordem e os tempos; a revisão isolada no Godot reproduz os nove quadros em dois ataques. A montagem segue como estudo, sem substituir o chefe do jogo.
