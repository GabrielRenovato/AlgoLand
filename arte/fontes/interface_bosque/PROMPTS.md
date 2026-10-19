# Interface Bosque — pedidos de geração

Ferramenta: image_gen, fundo transparente. Recursos próprios para substituir as molduras CraftPix da interface; fontes e ícones de gameplay existentes preservados.

## Atlas

Production pixel-art UI sprite atlas for AlgoLand, a cozy farming action RPG with Mana Seed environment art. Warm walnut and honey wood, muted bronze fittings, parchment, dark cocoa interior. Clean chunky native pixel clusters, sharp square pixels, 3–4 tones per material, no text, no symbols. Four columns × three rows of isolated equal cells: titled panel 48×48 (16px title), symmetric dark panel 48×48, parchment panel 48×48, neutral inventory slot 24×24; parchment buttons 48×24 normal/hover/pressed/disabled; sage primary buttons normal/hover/pressed and dark recessed input frame. Six-pixel panel borders, small chamfer corners, uniform straight edge centers for nine-patch stretching, decorative details confined to corners, transparent outside. No foliage, emblems, tiny decorative noise or illustrated mockups.

## Barras

Three isolated horizontal tiny status bars, identical shape, logical48×8 each: coral full health, empty cocoa trough, neutral ivory full bar for stamina/energy tint. Thin muted brass rim, brown outline, 1px highlight. First16px left cap, middle16px uniform repeat, last16px right cap. Transparent outside, no text/icons/gradients/soft shading. Same footprint and outline in every state.

## Preparação e integração

Recortes e tamanhos efetivos estão em `geracao.json`; originais preservados em `atlas_original.png` e `barras_original.png`. O preparador reduz os blocos simples com vizinho mais próximo, fixa alpha/paleta e ajusta a faixa de título ao contrato de 16px. Conferir os recursos nativos e as capturas reais; a resolução da fonte não certifica qualidade. Execução: `python3 ferramentas/cidade/preparar_interface_bosque.py`.
