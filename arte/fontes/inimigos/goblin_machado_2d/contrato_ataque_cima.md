# Goblin de machado: ataque para cima

Modelo: goblin parrudo aprovado, mesma roupa e machado do ataque à direita. Vista elevada de costas, nuca/dorso/calcanhares; ombreira no ombro anatômico esquerdo. Pegada direita perto do fim do cabo, esquerda perto da lâmina. Corpo31px na escala.071, célula640, raiz320/560. Sem corrida nova nesta etapa de ataque.

8 quadros em grade4x2, tempos80/160/140/45/55/90/130/180ms; total880ms, impacto4/425ms, sem repetição. Guarda, carregamento no lado direito, preparação alta direita, liberação com giro para esquerda, impacto contra alvo acima, continuação esquerda, recuperação e guarda.

Guia de articulações aproximado (x,y na célula640):
- Guarda: cabeça320/200, ombros260/290 e380/290, quadril320/425, pés250/560 e390/560; mãos na frente/direita parcialmente oclusas.
- Carregamento: cabeça340/205, ombros270/300 e400/285; cotovelos380/340 e450/335, mãos425/340 e460/310, quadril330/435; apoio pé direito400/560.
- Preparação: cabeça340/195, ombros270/295 e400/280, cotovelos385/240 e450/285, mãos410/210 e455/245, quadril330/435; pés250/560 e400/560.
- Liberação: quadril320/435 inicia, ombros270/285 e385/300 giram, mãos390/225 e355/230; cabeça320/210 acompanha alvo acima.
- Impacto: cabeça300/215, ombros250/285 e375/300, quadril310/435, mãos300/245 e350/260; lâmina acima/esquerda, arco x90..595 y135..295.
- Continuação: cabeça300/235, ombros245/300 e365/315, mãos220/300 e270/320, quadril305/445; joelhos flexionam, apoio esquerdo245/560.
- Recuperação: cabeça310/210, ombros255/295 e380/295, quadril315/430, mãos voltam à frente baixa.
- Guarda igual à inicial.

Oclusão: braços podem passar atrás do dorso na preparação; no golpe arma/efeito aparecem acima do corpo. Crescente branco com azul claro apenas3/4/5, cresce no impacto e afina na continuação. Não virar o sprite lateral por rotação. Fonte/prompt em arte/fontes, atlas/SpriteFrames em assets/inimigos/goblin_machado_2d, GIFs/contatos/capturas em arte/previas. Cena visual própria; não substituir parcialmente mob ativo.

## Preparação efetiva
Fonte1774x887; transformação única para toda a folha: lado600/deslocamento(20,10), alfa<=64/255 limpo no importador. Corpo de guarda ~31px, sem normalizar poses por contorno. Efeito já desenhado nos quadros3/4/5 da fonte. `ataque_cima` e `parado_cima` disponíveis na cena visual compartilhada; sinal de impacto usa quadro4 e retorno automático escolhe a mesma direção. Cena de revisão exibe guarda e dois ataques ao lado do jogador, com save isolado.
