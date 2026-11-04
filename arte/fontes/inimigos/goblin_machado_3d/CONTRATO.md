# Goblin brutamontes com machado — contrato visual

- **Função:** modelo 3D estático de um inimigo mais forte que o goblin da adaga; não substitui nem integra os inimigos existentes.
- **Referência canônica:** `referencia.png`, imagem de frente, três-quartos e costas fornecida pelo usuário. Corpo compacto musculoso, costas expostas, arreio de couro, ombreira angular e machado em meia-lua na diagonal.
- **Forma e materiais:** proporção baixa e larga, pele verde-oliva, cabeça expressiva, roupa improvisada em couro marrom, calça escura, botas pesadas e ombreira de ferro fosco. Machado grande de cabo de madeira em empunhadura de duas mãos.
- **Escala e eixos:** altura de 1,723 m incluindo o cabelo; origem no chão; Z para cima; frente Blender −Y, correspondente à frente Godot +Z.
- **Geometria:** escultura volumétrica em Blender, pele contínua, botas ajustadas aos pés e ombreira em placas. Machado independente. Sem rig, animação, colisão ou IA nesta entrega.
- **Empunhadura:** duas mãos fechadas em malhas independentes; dedos curvos com orientação estável, polegares em oposição e cavidade das palmas ajustada ao couro do cabo. Mãos e machado usam a mesma transformação rígida de inclinação. Capturas de detalhe frontal e lateral em `empunhadura.png` e `empunhadura_lateral.png`.
- **Pintura:** albedos de 128×128 com agrupamentos de pixels e cinco tons por material, gerados a partir de `materiais_pixel.png`. Arquivos editáveis em `assets/inimigos/goblin_machado_3d/texturas/`, incorporados ao GLB e ao Blender. Amostragem nearest.
- **Filtro solicitado:** `previa_modelo.gd -- --pixel` acrescenta o shader `contorno_pixel_base_3d.gdshader` à renderização 160×160, ampliada para 800×800 por vizinho mais próximo. As capturas `*_filtro_pixel.png` usam esse tratamento; as `*_pintura.png` mostram os albedos sem pós-processamento.
- **Revisão:** capturas frontal, três-quartos, lateral e costas no Godot em `arte/previas/inimigos/goblin_machado_3d/`. Projeto de revisão isolado, sem carregar saves.
- **Fonte:** `goblin_machado.blend`, com malhas, UVs, materiais, imagens incorporadas e palco de iluminação.
- **Arquivo de jogo:** `assets/inimigos/goblin_machado_3d/goblin_machado.glb`.
