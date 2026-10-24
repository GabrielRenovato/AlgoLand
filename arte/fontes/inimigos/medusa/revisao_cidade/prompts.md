# Produção da Medusa

Ferramenta integrada `imagegen`; as folhas finais preservam o alfa gerado. A primeira proposta pintada foi descartada. A segunda é o modelo canônico usado como referência das quatro ações.

## Modelo e movimento

Create a production pixel-art sprite sheet for AlgoLand, a top-down three-quarter farming action RPG with warm natural Mana Seed-like city tiles. Female gorgon, pale sage skin, expressive stern face, thick distinct dark jade snake hair with tiny coral eyes, antique gold breastplate and bracers, plum waist cloth, muscular single coiled jade serpent tail with broad ochre belly plates. Carefully shaded broad clusters, selective dark outlines, warm upper-left light. Six columns and four rows, front/down, rear/up, profile/right, profile/left. Six coherent looping slither frames, stable head/pelvis volumes and alternating arm sway. Fixed root, genuine RGBA transparency, no painted background, effects, text or grid.

Correção dirigida: preserve character design, directions and layout; remove painted texture/background, use native pixel clusters and broad jade tail volumes, keep scale and identity across24 poses. Fonte1536×1024, grade256px, destino128px.

## Ações (edições do modelo canônico)

Instruções comuns: KEEP EXACT same canonical character, face, snake hair, pale sage skin, jade and ochre tail, gold armor, plum cloth, pixel-art style, scale and palette. Change only the poses. Exact sheet1536×1024, six columns/four rows,256px cells, representing128px logical cells at2×. Rows DOWN/front, UP/back, RIGHT/profile, LEFT/profile. Fixed root logical(64,120), stable pelvis, no cropped hands/hair/tail. Native crisp chunky pixel clusters matching16px Mana Seed RPG city tiles, no smooth painting or noisy stippled scales. Actual transparent RGBA background, no ground shadows or spell effects. Six phases show anticipation, strike and recovery.

- **Garras:** coil tail, draw elbows back; raise bent claw hands; twist torso without changing facing; lunge and sweep claws toward facing direction; low follow-through; return neutral. Correção: primeira linha inteira permanece frontal, golpe para baixo em escorço; segunda permanece de costas, golpe para cima; preservar perfis.
- **Cauda:** tight coil; tail tip draws back; torso braces; broad low sweep; complete arc; neutral. Correção: encurtar e curvar a ponta da cauda da quarta coluna para caber inteiramente em x768..1023, margem8px, sem reduzir cabeça/tronco ou invadir a quinta coluna.
- **Bote:** contract coil; lean torso back and tuck arms; crouched anticipation; thrust toward facing direction with tail behind; low shoulders and extended claws; neutral coil. No stretched anatomy or incorrect rear face.
- **Olhar:** raise shoulders and bend elbows; lift palms by shoulders; spread arms in invocation; mint glowing eyes and outward palms; lower arms on release; neutral. Rear never shows face or eyes; side shows one visible eye. No baked rays or aura.

A marca de Ruína e o canal são desenhados por código e shaders em pixels do mundo; não foram gerados como folha raster.

## Estudo dirigido do bote

Produzir apenas oito sprites: duas colunas (impacto/continuação), quatro linhas (frente, costas, direita, esquerda). Referência movimento só para identidade. Frente permanece frontal nas duas poses, costas não mostra rosto, perfis preservam direção. Tronco projeta-se para a frente e abaixa no segundo quadro; cauda compacta sob o quadril, sem alongar ou juntar poses vizinhas. Preservar paleta, rosto, armadura, serpentes e tecido. Sem efeitos ou fundo; alfa real. Saída pedida512×1024, recebida1024×1536, registrada por direção no preparador.

## Integração final

A grade gerada precisou de leitura com margem para recuperar serpentes acima das divisões e remover fragmentos de poses vizinhas. Os quadros finais têm160×160 com16px de margem adicional, sem ampliar o personagem; raiz(80,136). A composição é reproduzida pelo preparador Godot, com transformação comum, sem alinhamento independente pela silhueta.
