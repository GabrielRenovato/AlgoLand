# Goblin de machado — identidade própria

Correção solicitada: o goblin de machado deve ser outro personagem, não o goblin de adaga com arma trocada. Estudo canônico antes de retomar animações. Vista direita, câmera elevada do projeto, mesma altura do player(~31px), silhueta compacta/parruda, ombros e tronco mais largos, pernas curtas fortes, nariz achatado e mandíbula quadrada. Cabeça raspada com faixa de moicano curta; pele verde-musgo escura e orelhas grossas. Colete reforçado castanho avermelhado, pequena ombreira de ferro, gola de pelo e faixa vermelha escura, sem a faixa amarela do adaga.

Machado de batalha de duas mãos, cabo de madeira cerca65% da altura corporal, lâmina única larga e curva de aço. Pegada separada, mãos conectadas ao mesmo cabo, arma inteira dentro da célula. Guarda baixa apontada à direita. Não reutilizar poses do goblin de adaga neste modelo mais pesado. Cabeça/ombros/arma terão nova análise de peso quando animados.

Estudo raster pelo image_gen integrado; prompt integral preservado em prompt_modelo_proprio.txt. Destino futuro:célula640×640, raiz(320,560), escala próxima0,071 ajustada pela altura corporal verificada. Manter modelo ativo anterior até haver estados direcionais revisados.

## Animação autorizada

Direita primeiro. Corrida própria em8 poses4×2,480ms, referência100px/s, ambas as mãos estabilizam o machado e as pernas alternam contato/absorção/passagem/voo. Cabeça e ombros acompanham compressão e impulsão. Ataque de8 poses4×2:guarda/preparação/alto/arco/impacto/continuação/recuperação/guarda; tempos110,140,100,45,55,90,120,160ms,total820ms. Impacto no quadro4 em395ms. Ambos os punhos mantêm pegada separada no mesmo cabo. As fontes da antiga identidade estão canceladas.

### Revisão das fontes

Corrida:v2 corrige a sobreposição das pernas na segunda metade. Ataque:v2 contém a lâmina inteira e limpa o fundo. Quadro-fonte1 rejeitado por inversão da pegada; edição isolada preparacao_maos_corrigida.png também rejeitada por mudar volume/ombreira. Ordem final0,3,2,3,4,5,6,7:posição diagonal alta faz a transição da guarda para cima e volta no início do corte, preservando o mesmo corpo e a pegada. São8 quadros temporais,7 poses únicas; o quadro diagonal tem papel de preparação e passagem. Transformação comum da corrida500/(70,88); ataque550/(65,33). Nenhuma edição isolada de volume aplicada.


## Correção vigente: varrida da referência enviada pelo usuário
A referência principal passou a ser https://www.reddit.com/r/PixelArt/comments/1p4i02s/heavy_axe_attack_looped/ (u/Sufficient_Hornet253). O estudo Wildfire/v3 é secundário, anterior ao link do usuário. A fonte vigente do ataque é `ataque_reddit_direita_v4.png`, gerada por image_gen a partir do modelo aprovado e dos quadros do primeiro golpe. Não há transferência literal dos pixels da referência.

Sequência natural 0..7, sem repetir poses intermediárias: guarda, puxada, preparação alta no lado oposto, liberação, impacto com giro do dorso, continuação baixa, recuperação, guarda. Tempos 80/160/140/45/55/90/130/180 ms, total880ms; impacto425ms. Grade4x2, célula640, transformação comum lado640/deslocamento(0,-23), raiz320/560, escala.071. Limpeza uniforme de alfa <=200/255 para remover ruído semitransparente da fonte; sem recorte ou ajuste de escala por pose. O corpo opaco preserva o desenho.

Corrida preservada: SHA256316b5015323689627e2d1ffc21bff297fe3051abba3ec872961a6daf3d14799a. Esta etapa continua sendo a cena visual própria para direita; não substitui parcialmente o inimigo ativo de quatro direções.


## Rastro pedido pelo usuário
Referência: mesmo GIF do Reddit, quadros21/23/26 do contato. Efeito próprio gerado por image_gen em folha4x2 separada (`efeito_corte_reddit_v1.png`), branco com interior azul claro, transparência real. Célula640, mesma raiz, sem deslocamento; composto sobre o corpo apenas nos quadros3/4/5 (45/55/90ms) do ataque para direita. Surge fino, abre em crescente amplo no impacto, afina e some. Composição no importador garante mesma arte/tempo no Godot e nos GIFs. Preparação, guarda, corpo, corrida e temporização anteriores preservados. O corte não altera colisão ou janela de dano.
