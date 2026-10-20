# Base masculina CraftPix

Pacote original: [Free 4-Direction Pixel Base Male Character](https://free-game-assets.itch.io/free-base-4-direction-male-character-pixel-art).
Autor: CraftPix / Free Game Assets. A referência de licença incluída pelo autor está em `original/License.txt`: https://craftpix.net/file-licenses/.

- `pacote_original.zip`: download original preservado.
- `original/`: pacote completo, incluindo Aseprite, PSD, PNG e arquivos Tiled.
- `assets/personagens/craftpix_base_masculina/`: cópias dos 75 PNGs, sem modificar pixels, dimensões ou ordem dos quadros.
- `catalogo.json` nessa pasta registra caminhos, dimensões e grades medidas.

Cada célula tem 64×64 pixels e cada folha contém quatro direções. Consultar os arquivos Aseprite para identificar direções, duração e ações antes de conectar ao controlador. Manter o filtro por vizinho mais próximo.

A base normal do AlgoLand permanece como padrão. O controlador `codigo/jogador/heroi_craftpix.gd` pode ser ativado opcionalmente por F3 → PERSONAGEM → CRAFTPIX. Mineração, corte de árvores, roupas e cabelos adicionais ainda precisam ser produzidos.

## Adaptação ao tamanho dos NPCs

`ferramentas/personagem/preparar_craftpix.py` prepara as 75 camadas em `assets/personagens/craftpix_npcs/`: altura parada31px, pés y44, escala1 e direções baixo/direita/cima/esquerda. A transformação é igual para todos os quadros e camadas, com vizinho mais próximo e transparência binária. O ataque correndo tem margem de1px (célula66px, pivô33/45) para não cortar o efeito. O personagem mantém o desenho CraftPix; esta adaptação padroniza dimensões e encaixe com os moradores, sem redesenhar sua anatomia ou paleta.
