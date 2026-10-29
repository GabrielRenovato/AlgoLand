# Casa da fazenda — reprodução 3D da fachada existente

Referência canônica: `arte/fontes/fazenda/acabamento_detalhado/casa.png` e suas quatro versões integradas em `assets/cenario/cidade/fachadas_detalhadas/casa_jogador/`. Reproduzir a casa existente, não redesenhar sua arquitetura: telhado largo terracota com cumeeira transversal e bordas inclinadas, pequeno frontão avançado sobre a porta, reboco creme, vigas castanhas, porta retangular de tábuas com argola, duas janelas de quatro vidros, chaminé de pedra à direita e alicerce de blocos. Sem floreiras, arco de pedra, óculo, venezianas ou lanterna acrescentados. `referencia_pintada_v2.png` registra um estudo anterior e não é mais referência do modelo ativo.

Modelo procedural real em `codigo/cenario/casa_fazenda_3d.gd`, shader `casa_pintada_3d.gdshader`. Câmera ortográfica frontal elevada, sem mostrar a lateral. Viewport320×320 exibido em160×160, pivô projetado na soleira original (376,216). Preservar obstáculos, passagem e interior. A cena `terreno_fazenda.tscn` usa a subclasse somente para a casa do jogador.

Quatro estações pelo consumidor de detalhes ambientes; variação dos tons de telha e neve volumétrica no inverno. Geometria: telhas curvas com borda de sobreposição, prismas chanfrados, pedras separadas e ferragem da porta. Materiais pintados por shader. É uma reconstrução procedural simplificada da fachada; a pintura original não é aplicada como plano.

Revisão gráfica: `ferramentas/fazenda/revisar_casa_3d.gd`, em projeto com save isolado. Confere geometria, margens da captura, alinhamento da soleira, destino da porta e quatro estações. Capturas em `/dev/shm/casa3d-*.png`; prévias revisadas em `arte/previas/fazenda/casa_3d/`.

## Acabamento pixel art

Renderização 3D em grade2×, sem MSAA, filtro nearest e contorno/rampas do personagem (`contorno_pixel_base_3d.gdshader`, 12 tons para preservar o desenho da construção). Pintura do material com variação reduzida para evitar ruído na grade. Malhas, câmera ortográfica frontal, iluminação, profundidade, entrada e estações permanecem ativos. As prévias sazonais mostram o resultado final no mapa, incluindo o shader de composição.
