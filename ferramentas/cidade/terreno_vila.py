"""Mapa do terreno da vila (1024x576) em vértices de 16 px: grama, terra, pedra (praça e caminhos) e água (rio e lago).
Usado por gerar_cidade.py (camada de tiles) e layout_decoracao.py (para espalhar flores só na grama).
"""
import math
import json
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(RAIZ / 'ferramentas/fazenda'))
import gerar_fazenda as F
G = F.G

LARGURA, ALTURA = 1024, 576
# Traçado da vila: rua principal leste-oeste (da fazenda à ponte), rua norte-sul (da sede ao parque), rua sul para a fileira
# de baixo, a praça no cruzamento e o lago no parque. Cada rua é (início, fim, meia largura)
LAYOUT = json.loads((RAIZ / "codigo/cidade/layout_vila.json").read_text())
PRACA = tuple(LAYOUT["praca_piso"]["centro"])
RAIO_PRACA = tuple(LAYOUT["praca_piso"]["raios"])
RAIO_CANTO_PRACA = LAYOUT["praca_piso"]["raio_canto"]
LAGO = (440, 530)
RAIO_LAGO = (66, 34)
MEIA_LARGURA_RIO = 20
# Ponte alinhada à rua: piso em y252..292; os corrimãos fecham suas laterais.
PONTE_APOIO_Y = 298
PONTE_LIMITE_NORTE = 252
PONTE_LIMITE_SUL = 292
RUAS = [((0, 272), (676, 272), 22),      # rua principal: entrada da fazenda até a ponte
        ((336, 168), (336, 576), 20),     # rua da sede até a saída sul da praia
        ((64, 448), (608, 448), 18),      # rua de baixo, das portas da pousada, do Bento e da mística
        ((488, 120), (488, 272), 16)]
# Acessos das portas usam o mesmo calçamento das ruas e da praça.
PORTAS = 24
QUINTAL = LAYOUT["quintal_carpinteiro"]
def margem_rio(y):
    return 676 + 6 * math.sin(y / 80)


def caminhos_pedra(predios):
    """Rede contínua: portas, portal e coreto desembocam nas ruas da praça."""
    caminhos = list(RUAS)
    caminhos.append(((410, 326), (448, 420), 14))
    centro_portao = sum(QUINTAL["portao"]) / 2
    caminhos.append(((centro_portao, 272), (centro_portao, QUINTAL["cercado"][1] + 8), 24))
    for p in predios.values():
        bx, by = p['base']
        # Centralizar na grade mantém dois tiles úteis mesmo nas portas entre células.
        porta_x = round((bx + p.get('porta_x', 0)) / 16) * 16
        rua_y = 272 if by <= 272 else 448
        caminhos.append(((porta_x, by - 4), (porta_x, rua_y), PORTAS))
    return caminhos


def terreno(x, y, predios):
    """Terreno no ponto (x, y) do mapa: prioridade água > pedra > terra > grama"""
    if abs(x - margem_rio(y)) < MEIA_LARGURA_RIO:
        return 'agua'
    if ((x - LAGO[0]) / RAIO_LAGO[0]) ** 2 + ((y - LAGO[1]) / RAIO_LAGO[1]) ** 2 < 1:
        return 'agua'
    # Praça com cantos arredondados e braços pavimentados: as ruas entram no mesmo piso.
    px, py = abs(x - PRACA[0]), abs(y - PRACA[1])
    canto_x = max(px - (RAIO_PRACA[0] - RAIO_CANTO_PRACA), 0)
    canto_y = max(py - (RAIO_PRACA[1] - RAIO_CANTO_PRACA), 0)
    praca = (px < RAIO_PRACA[0] and py < RAIO_PRACA[1]
             and canto_x * canto_x + canto_y * canto_y < RAIO_CANTO_PRACA ** 2)
    # Os braços continuam alinhados à fonte e às ruas existentes.
    acesso = (abs(x - 336) < 112 and abs(y - 272) < 18) or (abs(x - 336) < 18 and 168 < y < 350)
    # Terminação reta alinhada à grade; a ponta circular criava uma língua de um tile.
    rua_leste = 676 <= x <= 960 and abs(y - 272) < 18
    if praca or acesso or rua_leste or any(G.dist_segmento((x, y), a, b) < meia for a, b, meia in caminhos_pedra(predios)):
        return 'pedra'
    return 'grama'


# Folha de cada par: (fonte no TileSet, terreno superior). O inferior é grama, exceto no par terra/pedra
PARES = {0: ('terra',), 1: ('pedra',), 2: ('pedra',), 3: ('agua',)}


def tile_da_celula(cantos, x, y):
    """cantos = terrenos NO, NE, SO, SE. Devolve (fonte, coluna, linha) na folha 4x6 do par escolhido"""
    conjunto = set(cantos)
    # Só a primeira variação do PixelLab (as outras têm tom diferente e formavam quadrados escuros); a variedade vem das flores
    variante = 0
    puros = {'grama': (0, variante, 4), 'terra': (0, variante, 5), 'pedra': (1, variante, 5), 'agua': (3, variante, 5)}
    if len(conjunto) == 1:
        return puros[cantos[0]]
    if 'agua' in conjunto:
        fonte, superior, inferior = 3, 'agua', None
    elif conjunto <= {'grama', 'terra'}:
        fonte, superior, inferior = 0, 'terra', 'grama'
    elif conjunto <= {'grama', 'pedra'}:
        fonte, superior, inferior = 1, 'pedra', 'grama'
    else:
        fonte, superior, inferior = 2, 'pedra', 'terra'
    indice = 0
    for k, canto in enumerate(cantos):
        # Cantos que não são do superior valem como inferior (grama na água, terra no meio de grama/terra/pedra)
        indice |= (1 if canto == superior else 0) << (3 - k)
    return (fonte, indice % 4, indice // 4)


def mapa(predios, tw, th, margem=2):
    vertices = {(vx, vy): terreno(vx * 16, vy * 16, predios) for vy in range(-margem, th + margem + 2) for vx in range(-margem, tw + margem + 2)}
    celulas = {}
    for y in range(-margem, th + margem):
        for x in range(-margem, tw + margem):
            cantos = [vertices[(x, y)], vertices[(x + 1, y)], vertices[(x, y + 1)], vertices[(x + 1, y + 1)]]
            celulas[(x, y)] = tile_da_celula(cantos, x, y)
    return celulas
