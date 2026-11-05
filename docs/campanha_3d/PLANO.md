# Campanha em 3D — plano

Decisão do usuário (02/11/2026): a campanha inteira sai do 2D e vira um mundo 3D com uma câmera só, cara de pixel
art (estilo HD-2D), com personagens 3D desde já (herói, inimigos e NPCs). Vila, fazenda, fendas e arena fora da
campanha continuam 2D. Pode mexer direto nos arquivos atuais da campanha.

## Por quê

Hoje cada peça 3D é desenhada num `SubViewport` próprio e colada no mapa 2D como imagem. A Bacia tem mais de 100
dessas telas (grama por bloco, frente de grama por árvore e por ator, moinho, mecanismo, ponte, entrada); cada uma
é uma passada inteira de câmera e luz. Um mundo 3D único desenha tudo numa passada, com profundidade real (sem a
gambiarra de "frente da grama" e de z_index por pé).

## Arquitetura

- **Lógica no plano, visual em 3D.** Posições, colisão, IA, combate e o coop online continuam no plano (x, y) em
  pixels, como hoje. Cada entidade ganha um "corpo" 3D que só a desenha. Isso evita reescrever combate, navegação,
  saves e a sincronização do coop, e permite migrar região por região.
- **Projeção única.** A que a natureza da Bacia já usa: 32 px = 1 m, câmera ortográfica a 45°, sem giro
  (`ESTILO_3D_ALGOLAND.md`). Do plano para o 3D: `X = x/32`, `Z = y/(32·0,7071)`, `Y = altura do terreno`.
  A câmera 3D segue a `Camera2D` atual, então HUD, toque e interação continuam iguais.
- **Uma tela.** Um `SubViewport` do tamanho da tela lógica (576×324, com 2x de supersample se couber no
  celular), filtro de pixel no final (o `filtro_pixel_natureza`), e a camada 2D só para HUD, balões e efeitos.
- **Renderizador.** Continua `gl_compatibility`: a Web (iPhone) só roda nele, e uma passada só já é barata.
  Mudar `project.godot` exige APK novo.

## Fases

1. **Bacia, cenário.** Nó `Mundo3D` da região: terreno (a malha de solo que a natureza já monta por bloco, agora
   no mesmo mundo), grama em MultiMesh com o shader de vento/pisada lendo atores do mundo, árvores do
   `modelo_natureza_bacia_3d`, moinho, ponte, mecanismo e entrada da dungeon postos direto, sombras de uma luz
   só. Água e espuma: plano 3D com o shader atual. Medir no Android (fps e tempo de quadro) contra a versão 2D.
2. **Herói e coop.** O `heroi_base_3d` deixa de ter `SubViewport` próprio na campanha e entra no mundo; o parceiro
   do coop também. Golpes e efeitos ganham versão 3D ou ficam como sprites 3D (Sprite3D billboard).
3. **Inimigos da Bacia e do pomar.** Modelos 3D de goblin (já existem capuz, comum e machado em `assets/inimigos`),
   rebento de raízes, cerne partido, besouro do barranco, válvula errante e arraia do junco. Cada modelo com rig e
   animações de andar, atacar, levar dano e morrer.
4. **Demais regiões.** Chegada, estrada dos carreteiros, pomar e vila da Primeira Raiz. A vila precisa de casas
   3D modulares (o moinho e a ponte são o padrão) e NPCs 3D.
5. **Limpeza.** Remover o caminho 2D antigo da campanha, os `SubViewport`s por peça e os shaders que só existiam
   para compor 3D em 2D. Atualizar testes da campanha.

Cada fase termina com captura nas duas resoluções (576×324 e 288×512), medição no celular e publicação só com
pedido do usuário.

## Riscos

- Arte: inimigos, NPCs e casas 3D são o maior volume de trabalho; a fase 3 e 4 dependem disso.
- Coop online da campanha (`sessao_expedicao.gd`) replica posições 2D: continua funcionando se a lógica ficar no
  plano.
- Outra sessão estava mexendo na Bacia em 02/11 (uns 260 arquivos sem commit); o usuário autorizou seguir por cima.

## Andamento

- **Fase 1, parte A (02/11, feita, não publicada):** o solo e a grama da Bacia saem de um mundo 3D único em
  `natureza_bacia_lowpoly.gd` (`_criar_mundo`, `_seguir_camera`): duas telas do tamanho da tela do jogo (solo e
  grama) com a câmera 3D presa à Camera2D e travada na grade de 2 px, no lugar de 24 blocos x 2 telas. A sombra das
  árvores é um proxy por árvore no mundo, e a frente da grama é uma por ator. Visual conferido lado a lado com a
  versão antiga (idêntico). Megapixels de grama por quadro: ~12 (antes) -> ~3,7 no PC e ~1,3 no celular (2x).
- **Fase 1, parte B (falta):** árvores, moinho, mecanismo, ponte e entrada da dungeon ainda são imagens de telas
  próprias coladas no 2D. Para entrarem no mundo único é preciso que os atores também estejam nele (billboard ou
  3D), senão a árvore deixa de tapar o jogador. Por isso a parte B anda junto com a fase 2.

## Decisão de 05/11: cenário 3D, objetos em sprite 2D, personagens 3D

O usuário quer manter a mistura 2D + 3D. Fica assim:

- **Cenário 3D no mundo único:** terreno, casas, moinho, ponte e árvores entram direto no `Mundo3D` da região (sem
  `SubViewport` por peça).
- **Objetos 2D como `Sprite3D`:** a mesma arte (flores, caixas, cercas, móveis, efeitos, inimigos ainda 2D) vira
  sprite em pé, `billboard` fixo (a câmera não gira), `pixel_size` = 1/32 m, `texture_filter` nearest e
  `alpha_cut` (recorte, sem mistura: evita a ordem piscando). Sombra redonda no chão.
- **Personagens 3D como estão hoje:** herói, moradores e inimigos 3D saem do `SubViewport` próprio (`heroi_base_3d`,
  160×160 px por personagem, redesenhado a todo quadro) e entram no mesmo mundo. É o principal ganho no celular:
  na vila são ~16 telas por quadro.
- **Lógica no plano** como na arquitetura acima; HUD, balões e números de dano seguem na camada 2D.

Motivo imediato: travada num Poco M6 Pro (Helio G99 / Mali-G57). Ordem proposta: vila primeiro (moradores 3D são
o maior custo e as casas já são 3D), depois chegada, estrada, pomar e Bacia. Paliativos enquanto isso: 30 FPS
padrão no Android, personagem fora da tela sem redesenho, personagem longe/parado a ~12 FPS e um "Modo leve".

### Andamento da vila (05/11, não publicado)

- **Feito:** grama no mundo único (`codigo/cenario/grama_3d_no_mapa.gd`, vale para vila, chegada e cidade principal).
  Os 24 blocos de 256 px moram num só mundo 3D e saem de uma tela do tamanho da tela do jogo (`_criar_mundo_grama`,
  `_seguir_camera`); supersample = `resolucao_grama/288` (vila 3x, cidade 1x; celular no máximo 2x); sol sem sombra.
  Faixas de contato e a grama à frente do pé das árvores viraram recortes da tela única (`_recorte`), com a região
  refeita a cada quadro. Vila: 194 -> 87 telas 3D; ~80 MB de textura de grama -> ~9 MB (PC 3x) / ~4 MB (celular).
- **Feito:** personagens num álbum (`codigo/jogador/atlas_herois_3d.gd`, criado pelo `percurso_prototipo`): todos
  os `heroi_base_3d` da campanha moram num mundo 3D só, lado a lado (6x4 células de 160 px com 20% de folga), e
  saem de uma tela só; cada sprite mostra o recorte da sua célula e mantém o z 2D. A tela e a câmera de cada herói
  ficam paradas (UPDATE_DISABLED) mas servem às contas de projeção (ponta da arma, pesca, cabeça), que não mudaram.
  Fora da tela o corpo não entra na passada. Armadilhas: trocar o `world_3d` solta a malha do esqueleto (pose de T)
  -> `_religar_esqueletos`; moradores não rodam `_process`, então o registro também sai do `_ready` (deferred).
  Vila: telas que redesenham a todo quadro ~20 -> 2 (álbum e grama).
- **Falta (opcional):** casas e objetos 3D das oficinas desenham uma vez só (custo por quadro baixo); levá-los ao
  mundo único exige o cenário 3D com objetos 2D em `Sprite3D` (profundidade real), descrito acima.
