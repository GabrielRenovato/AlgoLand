# Goblin King

Modelo tridimensional próprio, modelado em Blender a partir da referência do chat.
É uma interpretação mais simples da referência: rosto, coroa, guarda da espada,
bordados e ornamentos não são uma reprodução exata da ilustração.

- Modelo importável: `res://assets/inimigos/goblin_king/goblin_king.glb`.
- Fonte editável: `arte/fontes/inimigos/goblin_king/goblin_king.blend`.
- Cena 3D: `res://cenas/inimigos/goblin_king_3d.tscn`.
- Apresentação no mundo 2D: `res://cenas/inimigos/goblin_king_visual.tscn`.
- Referência preservada: `arte/fontes/inimigos/goblin_king/referencia.png`.
- Renderizações reais: `arte/previas/inimigos/goblin_king/`.

O GLB contém geometria completa em todos os lados, materiais PBR, albedos
incorporados, 16 ossos com pesos e uma animação de respiração (`parado`).
O manifesto informa a quantidade de triângulos. Ainda não há caminhada,
ataques, expressões faciais, colisões ou IA. Não substitui o Goblin Maromba.
A malha tem aproximadamente 110 mil triângulos e 18 materiais; não foi
perfilada em Android/Web nem apresentada como otimizada para esses alvos.

No Blender, a frente é -Y e o chão é Z=0; no Godot, a frente é +Z e a
altura está em Y. A escala é em metros e a altura total é cerca de 3,31 m.
O rig está na pose da referência; novas animações devem ser produzidas
para esse rig. Não se assume compatibilidade automática com Mixamo.

Para colocar a apresentação no mapa 2D, instanciar `goblin_king_visual.tscn`
como filho do ator. A origem representa os pés. A cena renderiza o modelo
real em um SubViewport transparente, com 100 pixels de altura por padrão.
O acabamento padrão reutiliza exatamente o filtro do personagem
(`contorno_pixel_base_3d.gdshader`), com duas amostras por pixel, nearest e
MSAA desativado. As texturas e os materiais originais do GLB permanecem.
`acabamento_pixel_art=false` permite ver o modelo sem esse acabamento.
`definir_direcao(Vector2)` gira a malha; `altura_pixels` deve ser configurada
antes da entrada na árvore. A cena é somente visual e não executa combate.

Para regenerar (Blender 4.5):

```bash
blender --background --factory-startup \
  --python ferramentas/inimigos/goblin_king/gerar_modelo.py -- --renderizar
```

A revisão foi executada em projeto mínimo separado em
`/tmp/algoland-goblin-king`, sem autoloads ou saves do jogo:

```bash
flatpak run --filesystem=/tmp org.godotengine.Godot \
  --path /tmp/algoland-goblin-king \
  --script res://ferramentas/inimigos/goblin_king/revisar_modelo.gd
```

Os relatórios `validacao_godot.json` e `validacao_glb.json` registram importação,
vistas sem corte, animação, esqueleto, índices e pesos. A prévia `visual_2d.png`
mostra quatro orientações na cena consumidora; `respiracao.gif` usa quadros
do Godot nos tempos reais. Essas verificações não comprovam identidade
visual com a referência nem aprovação artística pelo usuário.
`comparacao_filtro.png` mostra o render original à esquerda e o mesmo modelo
com o filtro à direita, ampliados 4× a partir da escala de uso.
