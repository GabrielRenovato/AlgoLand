# Goblins da Bacia do Moinho — modelos base

Dois inimigos comuns em pintura 2D: lanceiro e espadachim com escudo. A folha do Goblin Maromba orienta acabamento e perspectiva; não copiar sua massa corporal de chefe. Goblins compactos, corpo menor que o player, equipamentos legíveis e silhuetas diferentes.

Folha canônica: 1536×1024, três colunas de 512×512 (baixo, direita, cima), duas linhas (lanceiro, espada e escudo). Raiz comum em (256,448), altura corporal prevista de 280 pixels na fonte; escala final deve ser conferida junto do jogador. Esquerda exige conservar a mão anatômica do escudo: não espelhar a folha para trocar a mão da arma sem revisar a oclusão.

Lanceiro: haste de madeira e ponta de ferro, guarda com duas mãos, couro castanho e tecido ocre. Espadachim: espada curta na direita, escudo redondo de madeira na esquerda, couro castanho e tecido vinho. Mesma anatomia, rosto, vestes e equipamento nas três vistas de cada indivíduo. Costas verdadeiras, sem rosto na nuca. Luz superior esquerda, alfa transparente, pés no solo.

Esta entrega define o desenho base para as animações. Não tratar as três vistas estáticas como caminhada/ataque nem substituir mobs ativos por essas poses. Caminhada, patrulha, estocada, corte, defesa, dano e morte precisam de produção e revisão próprias antes da substituição no mapa. As tarefas de população e navegação do estágio continuam necessárias nessa integração.

Fontes e prompts nesta pasta; prévias em `arte/previas/inimigos/goblins_moinho/`. Ferramenta de geração: image_gen incorporado.

## Revisão do modelo v1

Folha gerada por image_gen e inspecionada: seis desenhos, frente/perfil/costas reais; espada na direita e escudo na esquerda. Fonte com alfa transparente confirmado. O gerador usou pés próximos de y480 no lanceiro e y448 no espadachim; a prévia compensa isso por linha, sem recentralizar cada vista. Corpo desenhado com cerca de 350 pixels de altura na fonte; escala de estudo 0,075, cerca de 26 pixels lógicos, menor que o jogador. Sem alterações nos mobs ativos.

Prévia real no Godot 4.7.2, save isolado `/tmp/algoland-revisao-mobs4`, com jogador ao lado. Ferramenta: `ferramentas/inimigos/previa_goblins_moinho.gd`. Esta revisão cobre aparência e escala estáticas; não cobre animação, colisão, patrulha ou combate.
