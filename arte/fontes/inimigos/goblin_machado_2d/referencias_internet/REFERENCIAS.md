# Referências de movimento — correção do ataque

Fonte primária:Alexandermb, equipe de arte do0A.D., estudos de machado de duas mãos,2/4/2018: https://wildfiregames.com/forum/topic/24143-two-handed-animations/ . DoisGIFs de91 quadros, duas vistas da sequência, preservados nesta pasta apenas como referência de análise; não são recursos do jogo. Marcas e conteúdo originais preservados.

- wildfire_machado_1.gif: estudo usado no corte; frames30,36,39,42,44,46,49,54 extraídos em referencia_corte_vertical_contato.png.
- wildfire_machado_2.gif: outra vista, usada para conferir ombros e relação mãos/cabo.
- O tópico inclui críticas aos cortes laterais e revisão posterior; esta adaptação usa o corte vertical central, sem tratar toda a sequência como modelo perfeito.

Análise visual:guarda com haste baixa, flexão e giro antes de elevar a arma, cotovelos guiando a descida, cabeça seguindo torso, continuação baixa e recuperação. O gesto deve passar pelo impacto, sem parar ou voltar a uma pose anterior no meio da aceleração. As poses anteriores0,3,2,3,4... geravam essa volta e foram rejeitadas pelo usuário.

Guia próprio:guia_corte_proprio.png/json contém8 fases em células640 e raiz320/560, posições de cabeça/ombros/cotovelos/mãos/quadril/pés e cabeça da arma. Vermelho=mão direita anatômica próxima da base do cabo; azul=mão esquerda mais próxima da cabeça do machado. É interpretação do estudo adaptada ao goblin, não transferência literal de articulações humanas, nem arte final. Canon visual:modelo_direita.png aceito pelo usuário. Prompt da nova folha usa o canon, o guia e o contato da referência.

Manter a corrida aprovada inalterada; hash SHA256316b5015323689627e2d1ffc21bff297fe3051abba3ec872961a6daf3d14799a.

## Referência escolhida pelo usuário

Heavy axe attack (Looped),u/Sufficient_Hornet253: https://www.reddit.com/r/PixelArt/comments/1p4i02s/heavy_axe_attack_looped/ . Mídia pública vinculada:https://i.redd.it/7vu7ab1y0z2g1.gif .89 quadros384×162,40ms por quadro; estudo do primeiro golpe0..30 com preparação segurada e grande varrida diagonal/lateral. Analisados0,8,15,19,21,23,26,30, ampliados sem filtro no contato. Torso sai do perfil, passa pela frente e mostra costas ao terminar o giro; joelhos recebem peso e arma continua após impacto. Esta passa a ser a referência principal de gesto;0A.D. fica como estudo secundário de pegada. A fonte não foi convertida em sprite do jogo: a adaptação usa o goblin canônico próprio e um único golpe, com recuperação autorada. Guia:guia_reddit_adaptado.json.
