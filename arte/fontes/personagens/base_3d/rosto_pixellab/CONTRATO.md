# Rosto discreto, sem filtro sobre o personagem

Pedido atual: aproximar a aparência de Mana Seed, usar PixelLab e retirar o filtro que produz serrilhado. O rig 3D, corpo, equipamento e animações continuam os mesmos. Não houve troca para sprites 2D.

Referência local: morador `assets/npcs/cidade/tomas.png`, visto na mesma escala. Olhos pequenos e castanhos, boca curta, sobrancelhas discretas; o estudo anterior de olhos grandes foi rejeitado e fica apenas nas fontes.

Produção: PixelLab Pixen gerou a base; ajustes exatos de paleta, olhos e encaixe foram feitos no próprio `pixelart_workbench`. Histórico e IDs em `pixellab.json`; arte final `02b1093f-f74d-4eda-9cb9-670194c31c34`. Duas gerações, seguidas de edições determinísticas gratuitas. Não houve pintura ou redimensionamento da textura por Python.

Textura canônica: `assets/personagens/base_3d/rosto_cabelo_pixel/rosto_mana_32.png`, 32×32, oito cores, fundo de pele uniforme. Cópia original em `rosto_mana_32.png` nesta pasta. `rosto.png` anterior preservado.

Integração: desenho sobre a pele da própria malha no espaço de repouso da cabeça; máscara frontal impede olhos na nuca. Sem deformar cada olho por UV, amostrar uma ilustração de 1254×1254 ou recolocar pixels de boca por offsets. Pele segue a seleção; íris reconhecida pela cor da fonte e tingida pela opção de olhos. Dormir mantém a faixa de olhos fechados. Franja frontal levantada levemente sem alterar UVs, pesos, nuca ou topologia.

Renderização padrão: `acabamento_pixel_art=false` no herói, jogador e criação; sem material de pós-processamento ou contorno no Sprite2D final. Viewport 320×320, escala 0,25, MSAA2; texturas pintadas permanecem nearest no material. O modo anterior de grade é apenas uma opção de teste explícita. Não usar o viewport antigo de 640×640 como padrão no celular.

Validação: `ferramentas/personagem/base_3d/revisar_rosto_legivel.gd` exige save isolado e confere ausência de filtro e conservação do rig/UV da franja. Captura oito direções, três tons de pele × cinco cabelos, olhos fechados e 24 fases da corrida em cinco direções. Tempos reais do clipe em `/tmp/algoland-rosto-legivel/previas/tempos.json`. PNGs/GIF finais em `arte/previas/personagens/base_3d/rosto_pixellab/`; GIF arredonda as durações a centésimos, o motor usa os tempos originais.

A aproximação do estilo vem da arte e da paleta; o personagem continua sendo um modelo 3D. Não considerar este estudo aprovado pelo usuário antes de ele ver o resultado. Não publicado em produção.


Cabeça e pescoço atuais: a cabeça esférica e os ajustes que produziram cone/calombo foram rejeitados. `ajuste_rosto_base_3d.gd` recupera os triângulos da cabeça original do manequim, preservando crânio, orelhas, nariz e mandíbula. Somente a parte posterior inferior é recolhida suavemente, abaixo do crânio, para eliminar a extensão da nuca que aparecia como uma pontinha de pele atrás do cabelo. Normais acompanham essa alteração; coordenadas pintadas do rosto e demais atributos do corpo preservados. A cabeça usa o próprio osso; a malha fonte não é alterada. O pescoço continua com dois anéis de espessura final constante, compensando a escala da cabeça no topo, sem restabelecer a nuca antiga. Raios 0,055 m de largura e 0,055 m de profundidade antes da escala comum do tronco. A elevação da cabeça é 0,035 m sobre sua posição original. Malha calculada uma vez por instância e reutilizada; sem geração ou edição raster nesta correção de geometria.

Validação atual: oito direções, três tons de pele e cinco cabelos; corrida de 24 fases nas direções 0, 1, 2, 6 e 7, incluindo os dois perfis, totalizando 120 capturas. A revisão confere a preservação dos atributos do corpo (normais na precisão de reempacotamento do motor), ausência de valores não finitos e limite da saliência posterior na base da nuca. Captura final sem filtro e sem ampliação em `arte/previas/personagens/base_3d/rosto_pixellab/perfil_nuca_corrigida_sem_filtro.png`; movimento em `nuca_corrigida_corrida.gif`. Precedentes com esfera/cone não representam a versão atual. Alteração local, sem publicação.

Pedido posterior: teste de novos cabelos e movimento descartado. Chanel e longo removidos do catálogo e da criação; saves com esses IDs, cacheado, tranças ou rabo usam cabelo_curto. Bagunçado, raspado e espetado permanecem. Sem cabelo_dinamico_3d no runtime.
