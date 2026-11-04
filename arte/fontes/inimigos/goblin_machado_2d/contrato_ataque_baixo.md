# Ataque para baixo — goblin de machado

Modelo: goblin parrudo aprovado; referências modelo_direita.png e contatos dos ataques direita/cima. Nova vista frontal elevada, alvo abaixo no plano do chão, mesma massa, rosto, roupa, arma e altura31px. Ombreira no ombro anatômico esquerdo (direita da tela); mão direita perto do fim do cabo, esquerda perto da lâmina. Sem trocar pegada ao girar.

Grade4x2, oito células640, raiz320/560, escala.071. Tempos80/160/140/45/55/90/130/180ms, total880ms; impacto4/425ms, sem loop. Guarda, carregamento esquerda da tela, preparação alta esquerda, liberação diagonal para frente/baixo, impacto atravessando frente, continuação direita, recuperação, guarda. Crescente branco/azul somente3/4/5, máximo diante da cintura/coxa no impacto, some antes da guarda.

Guia aproximado na célula640:
0 cabeça320/200, ombros250/290 e390/290, quadril320/430, pés245/560 e395/560; mãos250/365 e400/345.
1 cabeça300/205, ombros235/295 e365/290, quadril305/435; cotovelos200/325 e290/340, mãos210/310 e270/320; apoio esquerdo da tela245/560.
2 cabeça300/195, ombros240/290 e370/285, cotovelos200/240 e300/280, mãos205/215 e270/240, quadril305/435.
3 cabeça315/220, quadril315/435 inicia giro; ombros250/300 e385/300, mãos240/340 e310/365 aceleram para baixo/frente.
4 cabeça335/235, ombros260/305 e400/295, quadril330/440, mãos320/375 e390/385; lâmina adiante/direita da tela, arco x80..595,y360..515.
5 cabeça345/245, ombros270/310 e405/305, quadril335/445; mãos380/405 e425/430, joelhos absorvem; apoio pé direito da tela400/560.
6 cabeça330/215, ombros260/300 e390/295, quadril325/435; mãos retornam frente/baixa.
7 guarda igual0.

Cabeça acompanha ombros; torso mantém volume. Efeito sobre pernas/cintura sem esconder rosto ou mãos. Usar fonte raster gerada por image_gen, sem substituir animações já aceitas. Destino assets/inimigos/goblin_machado_2d, cena visual própria e sinal de impacto compartilhado; preservar mob ativo até conjunto completo. Conferir no Godot/save isolado e guardar contato/GIF em arte/previas.

## Preparação efetiva
Fonte1774x887; transformação única lado500/deslocamento(70,85), alfa<=64/255 limpo, sem escala ou alinhamento por contorno individual. Efeito desenhado na fonte nos quadros3/4/5. Animações `ataque_baixo` e `parado_baixo` disponíveis na cena visual compartilhada. Guarda comparada ao player, revisão em save isolado.
