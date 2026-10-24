#!/usr/bin/env python3
"""Gerador da floresta entre a vila e a fazenda. Python puro, sem PIL/numpy; determinístico (semente fixa).

Como usar (da raiz do projeto):
    python3 ferramentas/floresta/gerar_floresta.py
    flatpak run org.godotengine.Godot --headless --path . --import

Saída:
  - cenas/terreno_floresta.tscn : o mapa, com os mesmos nós e sistemas do terreno da fazenda (Estacoes, Extracao, Plantio,
    NaturezaFazenda, ChaoFazenda): quatro estações, ferramentas e pintura detalhada vêm de graça.
  - cenas/floresta.tscn : o terreno + Jogador, luz, HUD, Interface e vinheta.

Geografia: a fazenda fica a oeste da vila. A vila sai pelo oeste e entra aqui pelo LESTE; a estrada atravessa a floresta e sai
pelo OESTE na fazenda. Pontos de interesse: paredão ao norte com a PEDREIRA ao pé dele, o LAGO GRANDE ao sul com o cantinho de
pesca, o ACAMPAMENTO dos lenhadores a nordeste e campinas de flores. A mata tem manchas fechadas e clareiras (ruído suave).
O gerador confere por busca em grade que a estrada e todos os pontos de interesse continuam alcançáveis a pé.

Reaproveita de gerar_fazenda.py o escritor de .tscn e de gerar_arena.py a terra em autotile e o paredão.
ATENÇÃO: os valores de árvore abaixo seguem a cena real terreno_fazenda.tscn (arte 128x128, pivô 64,127), não o gerador antigo.
"""
import math
import os
import random
import sys
from collections import deque

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(AQUI, "..", "fazenda"))
import gerar_fazenda as F  # noqa: E402  (traz o gerar_arena como G, o tscn como T e o escritor de cenas)

G, T = F.G, F.T
TILE = 16
RNG = random.Random(20261022)
G.RNG = RNG
RAIZ = F.RAIZ

MAPA_W, MAPA_H = 88, 54
LIMITES = (0, 0, MAPA_W * TILE, MAPA_H * TILE)
LARG, ALT = LIMITES[2], LIMITES[3]
PE_NORTE = 5                                   # linha de tiles do pé do paredão ao norte

# Arte real das árvores na cena da fazenda: 128x128, pivô na base (64,127); colisão só no tronco
ARVORE_REGIAO = (0, 0, 128, 128)
ARVORE_OFFSET = (-64, -127)
COL_CARVALHO = (-9, -8, 9, 0)                  # relativa à base (x, y)
COL_ABETO = (-6, -8, 6, 0)

# Entradas: a vila (leste) e a fazenda (oeste)
Y_LESTE, Y_OESTE = 440, 420
PORTAO_LESTE = (LARG - 40, Y_LESTE)
PORTAO_OESTE = (40, Y_OESTE)
CHEGADA_CIDADE = (LARG - 72, Y_LESTE - 9)
CHEGADA_FAZENDA = (72, Y_OESTE - 9)


def catmull(pontos, passos=10):
    """Curva suave que passa pelos pontos (Catmull-Rom); estrada sem quinas."""
    p = [pontos[0]] + list(pontos) + [pontos[-1]]
    saida = []
    for i in range(1, len(p) - 2):
        p0, p1, p2, p3 = p[i - 1], p[i], p[i + 1], p[i + 2]
        for k in range(passos):
            t = k / passos
            t2, t3 = t * t, t * t * t
            saida.append(tuple(0.5 * ((2 * p1[j]) + (-p0[j] + p2[j]) * t + (2 * p0[j] - 5 * p1[j] + 4 * p2[j] - p3[j]) * t2
                                      + (-p0[j] + 3 * p1[j] - 3 * p2[j] + p3[j]) * t3) for j in (0, 1)))
    saida.append(pontos[-1])
    return saida


ESTRADA = catmull([(LARG + 40, Y_LESTE), (LARG - 120, Y_LESTE), (1210, 446), (1080, 456), (940, 440), (800, 418),
                   (650, 424), (510, 446), (370, 456), (240, 446), (120, Y_OESTE), (-40, Y_OESTE)])
# Pontos de interesse (px)
LAGO = (700, 624)
LAGO_RAIO = (150, 78)
LAGO_PONTOS = 44
PEDREIRA = (360, 112, 880, 236)
AGLOMERADOS = [(440, 168), (590, 190), (690, 156), (850, 196)]   # centros dos blocos de pedra da pedreira                # clareira ao pé do paredão: pedras da picareta
ACAMPAMENTO = (1150, 262)                      # clareira dos lenhadores
RAIO_ACAMPAMENTO = 78
TRILHA_LAGO = [(652, 424), (662, 470), (680, 500), (688, 516)]
TRILHA_PEDREIRA = [(806, 414), (792, 340), (772, 260), (764, 222)]
TRILHA_ACAMPAMENTO = [(1080, 456), (1098, 400), (1128, 330), (1148, 290)]
CAMINHOS = [ESTRADA, catmull(TRILHA_LAGO, 6), catmull(TRILHA_PEDREIRA, 6), catmull(TRILHA_ACAMPAMENTO, 6)]
CAMPINAS = [(130, 560, 310, 690), (1030, 600, 1220, 730)]   # flores e borboletas

SAIDA_TERRENO = os.path.join(RAIZ, "cenas", "terreno_floresta.tscn")
SAIDA_FLORESTA = os.path.join(RAIZ, "cenas", "floresta.tscn")


# ---------------------------------------------------------------- geometria auxiliar
def dist_caminho(px, py):
    return min(G.dist_segmento((px, py), c[i], c[i + 1]) for c in CAMINHOS for i in range(len(c) - 1))


def no_lago(x, y, folga):
    return ((x - LAGO[0]) / (LAGO_RAIO[0] + folga)) ** 2 + ((y - LAGO[1]) / (LAGO_RAIO[1] + folga)) ** 2 < 1.0


def na_pedreira(x, y, folga=0):
    return PEDREIRA[0] - folga <= x <= PEDREIRA[2] + folga and PEDREIRA[1] - folga <= y <= PEDREIRA[3] + folga


def no_acampamento(x, y, folga=0):
    return math.hypot(x - ACAMPAMENTO[0], y - ACAMPAMENTO[1]) <= RAIO_ACAMPAMENTO + folga


def contorno_lago(angulo):
    """Mesma fórmula de lago_fazenda.gd::_contorno (margem 0)."""
    onda = 1.0 + 0.08 * math.sin(angulo * 3.0 + 0.6) + 0.05 * math.sin(angulo * 5.0 + 1.9)
    return (LAGO[0] + math.cos(angulo) * LAGO_RAIO[0] * onda, LAGO[1] + math.sin(angulo) * LAGO_RAIO[1] * onda)


def _hash(ix, iy, semente=7):
    n = (ix * 374761393 + iy * 668265263 + semente * 1274126177) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0


def ruido(x, y, escala, semente=7):
    """Ruído de valor suave em 0..1."""
    fx, fy = x / escala, y / escala
    ix, iy = math.floor(fx), math.floor(fy)
    tx, ty = fx - ix, fy - iy
    tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
    a, b = _hash(ix, iy, semente), _hash(ix + 1, iy, semente)
    c, d = _hash(ix, iy + 1, semente), _hash(ix + 1, iy + 1, semente)
    return (a + (b - a) * tx) * (1 - ty) + (c + (d - c) * tx) * ty


def densidade(x, y):
    """Quão fechada é a mata ali (0 = clareira, 1 = copas encostadas): fecha nas bordas e em manchas."""
    borda = max(0.0, 1.0 - min(x, LARG - x, y, ALT - y) / 250.0)
    n = 0.65 * ruido(x, y, 230) + 0.35 * ruido(x, y, 90, 11)
    return max(0.0, min(1.0, 0.7 * borda + (n - 0.46) * 2.2))


class Grade:
    """Índice espacial simples para a conferência de distância entre árvores e props."""

    def __init__(self, celula=48):
        self.c = celula
        self.itens = {}

    def adicionar(self, x, y, raio):
        self.itens.setdefault((int(x // self.c), int(y // self.c)), []).append((x, y, raio))

    def livre(self, x, y, raio):
        gx, gy = int(x // self.c), int(y // self.c)
        for ix in range(gx - 2, gx + 3):
            for iy in range(gy - 2, gy + 3):
                for ox, oy, orr in self.itens.get((ix, iy), ()):
                    if math.hypot(x - ox, y - oy) < orr + raio:
                        return False
        return True


class Mapa:
    def __init__(self):
        self.chao, self.terra, self.penhasco, self.detalhes = {}, {}, {}, {}
        self.sprites = []
        self.obstaculos = []
        self.recursos = []
        self.pesca = []      # (x, y, dx, dy)
        self.moveis = []     # [tipo, x, y]: móveis do cais (banco que senta, equipamento e caixas de pesca)
        self.adornos = []    # [tipo, x, y, larg_col, alt_col]
        self.placas = []     # (nome, texto, x, y)
        self.populacao = []  # [especie, variante, x, y]: a fauna (animal_selvagem.gd)
        self.refugios = []   # clareiras livres onde os bichos voltam depois de fugir
        self.pontos_interesse = {}
        self.grade = Grade()


def construir_mapa():
    m = Mapa()
    grade = m.grade

    def obstaculo(poli):
        m.obstaculos.append(poli)
        return "Obstaculos/Obstaculo%d" % len(m.obstaculos)

    # ---- paredão ao norte (a face de um platô largo; o topo fica fora do mapa) com abetos em cima
    norte = G.montar_mesa(-2, PE_NORTE - 7, MAPA_W + 4, False)
    m.penhasco.update(norte)
    m.obstaculos.append(F.retangulo(-80, -80, LARG + 80, (PE_NORTE + 1) * TILE - 4))
    ZONA_NORTE = (PE_NORTE + 2) * TILE

    # ---- terra: a estrada e as três trilhas
    proibido = {(cx, cy) for cy in range(-2, MAPA_H + 2) for cx in range(-2, MAPA_W + 2)
                if not (1 <= cx < MAPA_W - 1 and 1 <= cy < MAPA_H - 1)}
    S = {(cx, cy) for cy in range(MAPA_H) for cx in range(MAPA_W)
         if (cx, cy) not in proibido and dist_caminho(cx * TILE + 8, cy * TILE + 8) <= 20.0}
    S |= {(cx, cy) for cy in range(MAPA_H) for cx in range(MAPA_W - 3, MAPA_W) if abs(cy * TILE + 8 - Y_LESTE) <= 20}
    S |= {(cx, cy) for cy in range(MAPA_H) for cx in range(0, 3) if abs(cy * TILE + 8 - Y_OESTE) <= 20}
    S = G.regularizar_terra(S, proibido - S)
    m.terra = G.tiles_terra(S)

    # ---- chão: grama com flores esparsas e campinas de flores
    for cy in range(-3, MAPA_H + 3):
        for cx in range(-3, MAPA_W + 3):
            m.chao[(cx, cy)] = RNG.choice(G.FLORES) if RNG.random() < 0.035 else RNG.choice(G.GRAMA)
    for x0, y0, x1, y1 in CAMPINAS:
        for cy in range(y0 // TILE, y1 // TILE + 1):
            for cx in range(x0 // TILE, x1 // TILE + 1):
                if (cx, cy) not in m.terra and RNG.random() < 0.7:
                    m.chao[(cx, cy)] = RNG.choice(G.FLORES)
        grade.adicionar((x0 + x1) / 2, (y0 + y1) / 2, 60)

    def livre_geral(x, y, raio, folga_estrada=38):
        if not (24 + raio <= x <= LARG - 24 - raio and ZONA_NORTE + raio <= y <= ALT - 20 - raio):
            return False
        if dist_caminho(x, y) < folga_estrada + raio:
            return False
        if no_lago(x, y, 46 + raio) or na_pedreira(x, y, 26 + raio) or no_acampamento(x, y, 10 + raio):
            return False
        return grade.livre(x, y, raio)

    # ---- pontos de pesca em volta do lago, virados para a água (o jogador para na margem; a pesca é "rio")
    for graus in (-90, -58, -122, 0, 180, 38, 142):
        a = math.radians(graus)
        px, py = contorno_lago(a)
        nx, ny = math.cos(a) / LAGO_RAIO[0], math.sin(a) / LAGO_RAIO[1]
        n = math.hypot(nx, ny)
        nx, ny = nx / n, ny / n
        m.pesca.append((round(px + nx * 14), round(py + ny * 14), -nx, -ny))
        grade.adicionar(px + nx * 30, py + ny * 30, 22)
    m.pontos_interesse["lago_norte"] = (round(LAGO[0] - 10), round(LAGO[1] - LAGO_RAIO[1] - 30))

    # ---- cantinho de pesca na margem norte, junto ao fim da trilha: banco que senta, equipamento e caixas
    bx, by = 650, 506
    m.moveis += [["banco", bx - 34, by], ["equipamento_pesca", bx + 38, by - 4], ["caixas_peixes", bx + 86, by + 2]]
    for x, y, r in ((bx - 34, by, 26), (bx + 38, by - 4, 26), (bx + 86, by + 2, 34)):
        grade.adicionar(x, y, r)
    # capim e pedras de enfeite na orla
    for graus in range(0, 360, 24):
        a = math.radians(graus + RNG.uniform(-6, 6))
        px, py = contorno_lago(a)
        nx, ny = math.cos(a) / LAGO_RAIO[0], math.sin(a) / LAGO_RAIO[1]
        n = math.hypot(nx, ny)
        d = RNG.uniform(10, 24)
        x, y = px + nx / n * d, py + ny / n * d
        if y < LAGO[1] - LAGO_RAIO[1] - 4 and abs(x - 670) < 90:
            continue   # deixa a trilha e o cantinho de pesca livres
        if grade.livre(x, y, 10) and ZONA_NORTE < y < ALT - 70:
            tipo = "capim" if RNG.random() < 0.7 else "pedras"
            m.adornos.append([tipo, round(x), round(y), 0, 0])
            grade.adicionar(x, y, 8)

    # ---- acampamento dos lenhadores: troncos, bancos e capim ao redor de uma clareira
    ax, ay = ACAMPAMENTO
    camp = [("madeira", -30, -6), ("madeira", -22, -12), ("madeira", -26, -19), ("madeira", 18, -8), ("madeira", 26, -14),
            ("madeira", 22, -21), ("madeira", 44, 12), ("madeira", 52, 8), ("madeira", -8, 10), ("madeira", -46, 22),
            ("capim", 62, -22), ("capim", -62, -6), ("capim", 6, -38), ("capim", -28, 36), ("capim", 38, 40)]
    for tipo, dx, dy in camp:
        m.adornos.append([tipo, ax + dx, ay + dy, 22 if tipo == "madeira" else 0, 6 if tipo == "madeira" else 0])
        grade.adicionar(ax + dx, ay + dy, 14)
    m.moveis += [["banco", ax - 70, ay + 34], ["banco", ax + 72, ay + 38]]
    grade.adicionar(ax - 70, ay + 34, 26)
    grade.adicionar(ax + 72, ay + 38, 26)

    # ---- carvalhos que a machadinha corta: em volta do acampamento, ao longo da estrada e em bosquetes leves
    def carvalho(x, y):
        nome = "Carvalho%02d" % (sum(1 for s in m.sprites if s["tipo"] == "carvalho") + 1)
        m.sprites.append({"nome": nome, "x": x, "y": y, "tipo": "carvalho"})
        m.recursos.append({"chave": "F_" + nome, "tipo": "arvore", "pos": (x, y), "no": "Objetos3D/" + nome,
                           "obstaculo": obstaculo(F.retangulo(x + COL_CARVALHO[0], y + COL_CARVALHO[1], x + COL_CARVALHO[2], y + COL_CARVALHO[3]))})
        grade.adicionar(x, y, 30)

    # anel em volta do acampamento (a clareira fica livre)
    for k in range(10):
        a = math.tau * k / 10 + RNG.uniform(-0.2, 0.2)
        r = RAIO_ACAMPAMENTO + RNG.uniform(34, 70)
        x, y = round(ax + math.cos(a) * r), round(ay + math.sin(a) * r)
        if livre_geral(x, y, 30, 34):
            carvalho(x, y)
    tentativas = 0
    while sum(1 for s in m.sprites if s["tipo"] == "carvalho") < 44 and tentativas < 20000:
        tentativas += 1
        x, y = RNG.uniform(48, LARG - 48), RNG.uniform(ZONA_NORTE + 20, ALT - 60)
        d = densidade(x, y)
        perto = dist_caminho(x, y)
        if not (0.05 <= d <= 0.7) or perto > 230 or not livre_geral(round(x), round(y), 32, 44):
            continue
        carvalho(round(x), round(y))

    # ---- mata de abetos: uma fileira fechada no limite do mapa (com as bocas da estrada), a copa do paredão e as manchas de mata
    def abeto(x, y):
        x, y = round(x), round(y)
        m.sprites.append({"nome": "Abeto%03d" % len(m.sprites), "x": x, "y": y, "tipo": "abeto"})
        m.obstaculos.append(F.retangulo(x + COL_ABETO[0], y + COL_ABETO[1], x + COL_ABETO[2], y + COL_ABETO[3]))
        grade.adicionar(x, y, 13)

    for k in range(LARG // 30 + 1):
        if RNG.random() > 0.12:
            abeto(k * 30 + RNG.uniform(0, 18), RNG.uniform(8, 24))
    passo = 25
    for k in range(int((ALT - ZONA_NORTE) / passo) + 1):
        y = ZONA_NORTE + 6 + k * passo + RNG.uniform(-2, 2)
        if y > ALT - 2:
            continue
        if abs(y - Y_OESTE) >= 58:
            abeto(10 + RNG.uniform(-4, 8), y + RNG.uniform(-5, 5))
        if abs(y - Y_LESTE) >= 58:
            abeto(LARG - 10 + RNG.uniform(-8, 4), y + RNG.uniform(-5, 5))
    for k in range(int((LARG - 2 * 40) / passo) + 1):
        abeto(40 + k * passo + RNG.uniform(-5, 5), ALT - 4 - RNG.uniform(0, 12))
    tentativas = 0
    pinheiros = 0
    while pinheiros < 190 and tentativas < 60000:
        tentativas += 1
        x, y = RNG.uniform(30, LARG - 30), RNG.uniform(ZONA_NORTE + 10, ALT - 14)
        d = densidade(x, y)
        if RNG.random() > d ** 1.2 or not livre_geral(x, y, 15, 40):
            continue
        abeto(x, y)
        pinheiros += 1

    # ---- arbustos que a machadinha corta
    def espalhar(qtd, raio, tentativas=9000):
        pts = []
        for _ in range(tentativas):
            if len(pts) >= qtd:
                break
            x, y = RNG.uniform(40, LARG - 40), RNG.uniform(ZONA_NORTE + 10, ALT - 30)
            if livre_geral(x, y, raio):
                pts.append((round(x), round(y)))
                grade.adicionar(x, y, raio)
        return pts

    for i, (x, y) in enumerate(espalhar(20, 22.0)):
        tipo = "arbusto_g" if i % 2 == 0 else "arbusto_m"
        nome = "Arbusto%02d" % (i + 1)
        m.sprites.append({"nome": nome, "x": x, "y": y, "tipo": tipo})
        cfg = G.ARBUSTO_G if tipo == "arbusto_g" else G.ARBUSTO_M
        ox, oy = cfg["offset"]
        c = cfg["colisao"]
        m.recursos.append({"chave": "F_" + nome, "tipo": "arbusto", "pos": (x, y), "no": "Objetos3D/" + nome,
                           "obstaculo": obstaculo(F.retangulo(x + ox + c[0], y + oy + c[1], x + ox + c[2], y + oy + c[3]))})

    # ---- pedras: a pedreira na clareira ao pé do paredão e algumas soltas (a picareta quebra todas)
    usadas = set()

    def pedra(cel):
        if cel in usadas or cel in m.terra:
            return False
        usadas.add(cel)
        t = RNG.choice(G.ROCHAS)
        m.detalhes[cel] = t
        r = G.retangulo_rocha(t)
        m.recursos.append({"chave": "F_Pedra_%d_%d" % cel, "tipo": "pedra", "pos": (cel[0] * TILE + 8, cel[1] * TILE + r[3]),
                           "celula": cel, "obstaculo": obstaculo(F.retangulo(cel[0] * TILE + r[0], cel[1] * TILE + r[1],
                                                                              cel[0] * TILE + r[2], cel[1] * TILE + r[3]))})
        grade.adicionar(cel[0] * TILE + 8, cel[1] * TILE + 8, 12)
        return True

    quebradas = 0
    for cx, cy in AGLOMERADOS:
        # cada bloco: 8 a 10 pedras coladas (com ruído) ao redor do centro; o resto da pedreira fica livre para andar
        meta, tentativas = quebradas + RNG.randint(13, 16), 0
        while quebradas < meta and tentativas < 800:
            tentativas += 1
            a = RNG.uniform(0, math.tau)
            r = RNG.uniform(0, 40) * (0.5 + ruido(cx + math.cos(a) * 20, cy + math.sin(a) * 20, 40, 23))
            x, y = cx + math.cos(a) * r, cy + math.sin(a) * r * 0.7
            if not na_pedreira(x, y) or dist_caminho(x, y) < 26 or not grade.livre(x, y, 5):
                continue
            if pedra((int(x // TILE), int(y // TILE))):
                quebradas += 1
    for (x, y) in espalhar(16, 22.0):
        pedra((int(x // TILE), int(y // TILE)))
    # pedras grandes de cenário (4 estações, com colisão) ao pé do paredão e nos blocos da pedreira
    for gx, gy in ((410, 134), (520, 128), (640, 134), (748, 130), (866, 140), (470, 214), (640, 222), (880, 226)):
        if grade.livre(gx, gy, 16) and dist_caminho(gx, gy) > 34:
            m.adornos.append(["pedras", gx, gy, 26, 8])
            grade.adicionar(gx, gy, 16)

    # ---- plantinhas soltas (enfeite sem colisão)
    for (x, y) in espalhar(60, 12.0):
        cel = (int(x // TILE), int(y // TILE))
        if cel in usadas or cel in m.terra:
            continue
        usadas.add(cel)
        m.detalhes[cel] = RNG.choice(G.PLANTAS)

    # ---- fauna: clareiras livres (refúgios) e os bichos do Tiny RPG
    def achar_livre(cx, cy, raio_max, raio_obj=12, tentativas=900):
        for _ in range(tentativas):
            a, r = RNG.uniform(0, math.tau), RNG.uniform(0, raio_max)
            x, y = cx + math.cos(a) * r, cy + math.sin(a) * r
            if livre_geral(x, y, raio_obj, 20):
                return (round(x), round(y))
        return None

    for _ in range(20000):
        if len(m.refugios) >= 36:
            break
        x, y = RNG.uniform(80, LARG - 80), RNG.uniform(ZONA_NORTE + 40, ALT - 90)
        if densidade(x, y) < 0.6 and livre_geral(x, y, 16, 26) and all(math.hypot(x - a, y - b) > 80 for a, b in m.refugios):
            m.refugios.append((round(x), round(y)))
    cervos = [(0, 0), (1, 1), (2, 1)]            # (índice do refúgio, variante): um macho e duas fêmeas
    passo_ref = max(1, len(m.refugios) // 3)
    for k, var in cervos:
        x, y = m.refugios[(k * passo_ref + 2) % len(m.refugios)]
        m.populacao.append(["cervo", var, x, y])
    for i in range(7):
        ponto = (achar_livre(*(( (CAMPINAS[i % 2][0] + CAMPINAS[i % 2][2]) // 2, (CAMPINAS[i % 2][1] + CAMPINAS[i % 2][3]) // 2 )), 90, 10)
                 if i < 4 else m.refugios[(i * 5 + 1) % len(m.refugios)])
        if ponto:
            m.populacao.append(["coelho", i % 4, ponto[0], ponto[1]])
    for graus, var in ((180, 0), (8, 1)):
        a = math.radians(graus)
        px, py = contorno_lago(a)
        ponto = achar_livre(px + math.cos(a) * 54, py + math.sin(a) * 34, 40, 10)
        if ponto:
            m.populacao.append(["capivara", var, ponto[0], ponto[1]])
    for cx, cy in ((ACAMPAMENTO[0] - 40, ACAMPAMENTO[1] + 50), (620, 262), (330, 560)):
        ponto = achar_livre(cx, cy, 90, 10)
        if ponto:
            m.populacao.append(["corvo", 0, ponto[0], ponto[1]])

    # ---- placas de madeira nos cruzamentos (o balão com o destino aparece quando o jogador chega perto)
    m.placas += [("PlacaVila", "VILA", LARG - 140, Y_LESTE - 36), ("PlacaFazenda", "FAZENDA", 150, Y_OESTE - 36),
                 ("PlacaLago", "LAGO", 628, 396), ("PlacaPedreira", "PEDREIRA", 832, 372),
                 ("PlacaAcampamento", "ACAMPAMENTO", 1052, 452)]
    m.pontos_interesse.update({"leste": (LARG - 80, Y_LESTE), "oeste": (80, Y_OESTE), "pedreira": (764, 232),
                               "acampamento": (ACAMPAMENTO[0], ACAMPAMENTO[1] + 6)})
    return m


def conferir_alcance(m):
    """Busca em largura em grade de 8 px: os obstáculos (retângulos) inflados pelo corpo do jogador e o lago bloqueiam; a estrada
    de ponta a ponta e cada ponto de interesse e cada ponto de pesca precisam ser alcançáveis."""
    passo = 8
    gw, gh = LARG // passo, ALT // passo
    bloqueado = [[False] * gw for _ in range(gh)]
    folga = 7
    for poli in m.obstaculos:
        xs, ys = [p[0] for p in poli], [p[1] for p in poli]
        if min(ys) < -50:
            continue
        x0, x1, y0, y1 = min(xs) - folga, max(xs) + folga, min(ys) - folga, max(ys) + folga
        for gy in range(max(0, int(y0 // passo)), min(gh, int(y1 // passo) + 1)):
            for gx in range(max(0, int(x0 // passo)), min(gw, int(x1 // passo) + 1)):
                bloqueado[gy][gx] = True
    for gy in range(gh):
        for gx in range(gw):
            x, y = gx * passo + 4, gy * passo + 4
            if no_lago(x, y, 2) or y < (PE_NORTE + 1) * TILE:
                bloqueado[gy][gx] = True
    for x, y, w, h in ((px, py, wc, hc) for _, px, py, wc, hc in m.adornos if wc):
        for gy in range(int((y - h - folga) // passo), int((y + folga) // passo) + 1):
            for gx in range(int((x - w / 2 - folga) // passo), int((x + w / 2 + folga) // passo) + 1):
                if 0 <= gy < gh and 0 <= gx < gw:
                    bloqueado[gy][gx] = True
    for tipo, x, y in m.moveis:
        w = {"banco": 38, "equipamento_pesca": 36, "caixas_peixes": 56}[tipo]
        for gy in range(int((y - 10 - folga) // passo), int((y + folga) // passo) + 1):
            for gx in range(int((x - w / 2 - folga) // passo), int((x + w / 2 + folga) // passo) + 1):
                if 0 <= gy < gh and 0 <= gx < gw:
                    bloqueado[gy][gx] = True

    def celula(p):
        return (min(gw - 1, max(0, int(p[0] // passo))), min(gh - 1, max(0, int(p[1] // passo))))

    inicio = celula((PORTAO_LESTE[0] - 24, Y_LESTE))
    alcancado = {inicio}
    fila = deque([inicio])
    while fila:
        cx, cy = fila.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (cx + dx, cy + dy)
            if 0 <= n[0] < gw and 0 <= n[1] < gh and n not in alcancado and not bloqueado[n[1]][n[0]]:
                alcancado.add(n)
                fila.append(n)
    problemas = []
    alvos = dict(m.pontos_interesse)
    for i, (x, y, _, _) in enumerate(m.pesca):
        alvos["pesca%d" % (i + 1)] = (x, y)
    for nome, p in alvos.items():
        if celula(p) not in alcancado:
            # tolerância: o ponto pode cair numa célula bloqueada por pouco; procura uma vizinha alcançada
            cx, cy = celula(p)
            if not any((cx + dx, cy + dy) in alcancado for dx in range(-3, 4) for dy in range(-3, 4)):
                problemas.append(nome)
    return problemas


def escrever_terreno(m):
    c = F.Cena()
    folha = c.recurso("Texture2D", "res://assets/cenario/Seasonal Forest/arena/spring.png", "arena_folha")
    ev_inverno = c.recurso("Texture2D", "res://assets/cenario/23.05a - Arctic Woodland 1.1/evergreen trees/evergreen trees (winter, top snow) 80x112.png", "evergreen_inverno")
    s_grupo = c.recurso("Script", "res://codigo/cenario/profundidade_grupo.gd", "prof_grupo")
    s_estacoes = c.recurso("Script", "res://codigo/cenario/estacoes.gd", "estacoes_script")
    s_passagem = c.recurso("Script", "res://codigo/logica/passagem.gd", "passagem_script")
    s_extracao = c.recurso("Script", "res://codigo/logica/extracao_fazenda.gd", "extracao_script")
    s_plantio = c.recurso("Script", "res://codigo/logica/plantio.gd", "plantio_script")
    s_vida = c.recurso("Script", "res://codigo/cenario/vida_fazenda.gd", "vida_script")
    s_lago = c.recurso("Script", "res://codigo/cenario/lago_fazenda.gd", "lago_script")
    s_pesca = c.recurso("Script", "res://codigo/pesca/ponto_pesca.gd", "pesca_script")
    s_placa = c.recurso("Script", "res://codigo/cidade/placa_local.gd", "placa_script")
    s_adornos = c.recurso("Script", "res://codigo/cenario/adornos_floresta.gd", "adornos_script")
    s_animais = c.recurso("Script", "res://codigo/floresta/animais_floresta.gd", "animais_script")

    fonte = ["texture = ExtResource(\"%s\")" % folha] + ["%d:%d/0 = 0" % (tx, ty) for tx, ty in G.TILES_USADOS]
    c.sub_recurso("TileSetAtlasSource", "Fonte_floresta", fonte)
    c.sub_recurso("TileSet", "TileSet_floresta", ['sources/0 = SubResource("Fonte_floresta")'])
    # Mesma arte e região da cena real da fazenda: a textura base vira a folha da estação e o NaturezaFazenda veste a arte 4x
    for ident, nome in (("Atlas_abeto", "arvore_var"), ("Atlas_carvalho", "arvore")):
        c.sub_recurso("AtlasTexture", ident, ['resource_name = "%s"' % nome, 'atlas = ExtResource("%s")' % ev_inverno,
                                              "region = Rect2(%d, %d, %d, %d)" % ARVORE_REGIAO])
    for ident, cfg in (("Atlas_arbusto_g", G.ARBUSTO_G), ("Atlas_arbusto_m", G.ARBUSTO_M)):
        rg = cfg["regiao"]
        c.sub_recurso("AtlasTexture", ident, ['resource_name = "amostra"', 'atlas = ExtResource("%s")' % folha,
                                              "region = Rect2(%d, %d, %d, %d)" % rg])
    c.sub_recurso("RectangleShape2D", "Forma_pesca", ["size = Vector2(40, 30)"])
    # A zona cobre a abertura inteira da mata (±58 px da estrada) e chega até a parede do mapa: o jogador não pode passar por fora dela
    c.sub_recurso("RectangleShape2D", "Forma_saida", ["size = Vector2(44, 124)"])

    c.no("Terrains", "Node2D", props=["texture_filter = 1", "metadata/sem_plantio = true"], raiz=True)
    F.camada(c, "Chao", m.chao, "TileSet_floresta")
    F.camada(c, "Terra", m.terra, "TileSet_floresta")
    F.camada(c, "Agua", {}, "TileSet_floresta")
    F.camada(c, "Penhasco", m.penhasco, "TileSet_floresta")
    F.camada(c, "Detalhes", m.detalhes, "TileSet_floresta")

    c.no("Lago", "Node2D", props=["position = " + F.vec(*LAGO), 'script = ExtResource("%s")' % s_lago,
                                  "raio = " + F.vec(*LAGO_RAIO), "pontos = %d" % LAGO_PONTOS])
    c.no("Objetos3D", "Node2D", props=['script = ExtResource("%s")' % s_grupo])
    cfgs = {"abeto": ("Atlas_abeto", ARVORE_OFFSET), "carvalho": ("Atlas_carvalho", ARVORE_OFFSET),
            "arbusto_g": ("Atlas_arbusto_g", G.ARBUSTO_G["offset"]), "arbusto_m": ("Atlas_arbusto_m", G.ARBUSTO_M["offset"])}
    for s in sorted(m.sprites, key=lambda s: (s["y"], s["x"])):
        tex, off = cfgs[s["tipo"]]
        c.no(s["nome"], "Sprite2D", "Objetos3D", [
            "position = %s" % F.vec(s["x"], s["y"]), 'texture = SubResource("%s")' % tex, "centered = false",
            "offset = %s" % F.vec(off[0], off[1])])

    c.no("Obstaculos", "StaticBody2D", props=["collision_layer = 64", "collision_mask = 0"])
    for i, poli in enumerate(m.obstaculos):
        c.no("Obstaculo%d" % (i + 1), "CollisionPolygon2D", "Obstaculos", ["polygon = %s" % T.poligono(poli)])

    c.no("LimiteFloresta", "StaticBody2D", props=["collision_layer = 64", "collision_mask = 0"])
    x0, y0, x1, y1 = LIMITES
    paredes = [("Norte", -80, -80, x1 + 80, y0 + 6), ("Sul", -80, y1 - 6, x1 + 80, y1 + 80),
               ("Oeste", -80, -80, x0 + 14, y1 + 80), ("Leste", x1 - 14, -80, x1 + 80, y1 + 80)]
    for nome, ax, ay, bx, by in paredes:
        c.sub_recurso("RectangleShape2D", "Forma_limite_" + nome, ["size = %s" % F.vec(bx - ax, by - ay)])
        c.no("Limite" + nome, "CollisionShape2D", "LimiteFloresta", [
            "position = %s" % F.vec((ax + bx) / 2, (ay + by) / 2), 'shape = SubResource("Forma_limite_%s")' % nome])

    # passagens pelas bordas: andar para a borda atravessa (sem F/Y)
    c.no("PassagemCidade", "Area2D", props=["position = %s" % F.vec(*PORTAO_LESTE), 'script = ExtResource("%s")' % s_passagem,
                                           'cena_destino = "res://cenas/cidade.tscn"', 'ponto_chegada = "fazenda"',
                                           "so_entre_ondas = false", "direcao_saida = Vector2(1, 0)",
                                           "deslocamento_aviso = Vector2(0, -30)"])
    c.no("Forma", "CollisionShape2D", "PassagemCidade", ['shape = SubResource("Forma_saida")'])
    c.no("PassagemFazenda", "Area2D", props=["position = %s" % F.vec(*PORTAO_OESTE), 'script = ExtResource("%s")' % s_passagem,
                                            'cena_destino = "res://cenas/fazenda.tscn"', 'ponto_chegada = "cidade"',
                                            "so_entre_ondas = false", "direcao_saida = Vector2(-1, 0)",
                                            "deslocamento_aviso = Vector2(0, -30)"])
    c.no("Forma", "CollisionShape2D", "PassagemFazenda", ['shape = SubResource("Forma_saida")'])
    for nome, texto, x, y in m.placas:
        c.no(nome, "Node2D", ".", ["position = %s" % F.vec(x, y), 'script = ExtResource("%s")' % s_placa, 'texto = "%s"' % texto])
    c.no("Chegada_cidade", "Marker2D", ".", ["position = %s" % F.vec(*CHEGADA_CIDADE)], grupos=["chegada"])
    c.no("Chegada_fazenda", "Marker2D", ".", ["position = %s" % F.vec(*CHEGADA_FAZENDA)], grupos=["chegada"])

    for i, (x, y, dx, dy) in enumerate(m.pesca):
        c.no("PescaLago%d" % (i + 1), "Area2D", ".", ["position = %s" % F.vec(x, y), 'script = ExtResource("%s")' % s_pesca,
                                                       "direcao = %s" % F.vec(round(dx, 3), round(dy, 3)), 'ambiente = "rio"'])
        c.no("Forma", "CollisionShape2D", "PescaLago%d" % (i + 1), ['shape = SubResource("Forma_pesca")'])

    def lista(itens):
        return "[" + ", ".join("[" + ", ".join('"%s"' % v if isinstance(v, str) else str(v) for v in it) + "]" for it in itens) + "]"

    c.no("Adornos", "Node2D", ".", ['script = ExtResource("%s")' % s_adornos, "moveis = " + lista(m.moveis),
                                    "adornos = " + lista(m.adornos)])
    c.no("Animais", "Node2D", ".", ['script = ExtResource("%s")' % s_animais, "populacao = " + lista(m.populacao),
                                    "refugios = PackedVector2Array(%s)" % ", ".join("%d, %d" % p for p in m.refugios),
                                    "limites = Rect2(%d, %d, %d, %d)" % (LIMITES[0], LIMITES[1], LARG, ALT)])
    c.no("Estacoes", "Node", ".", ['script = ExtResource("%s")' % s_estacoes, "seguir_calendario = true"])
    c.no("Plantio", "Node2D", ".", ['script = ExtResource("%s")' % s_plantio])
    itens = []
    for rec in m.recursos:
        campos = ['"chave": "%s"' % rec["chave"], '"tipo": "%s"' % rec["tipo"], '"pos": %s' % F.vec(*rec["pos"]),
                  '"obstaculo": NodePath("%s")' % rec["obstaculo"]]
        if "no" in rec:
            campos.append('"no": NodePath("%s")' % rec["no"])
        if "celula" in rec:
            campos.append('"celula": Vector2i(%d, %d)' % rec["celula"])
        itens.append("{" + ", ".join(campos) + "}")

    def desenho_e_colisao(cfg):
        ox, oy = cfg["offset"]
        x0, y0, x1, y1 = cfg["colisao"]
        return "Rect2(%d, %d, 0, 0)" % (ox, oy), "Rect2(%d, %d, %d, %d)" % (ox + x0, oy + y0, x1 - x0, y1 - y0)

    des_m, col_m = desenho_e_colisao(G.ARBUSTO_M)
    des_g, col_g = desenho_e_colisao(G.ARBUSTO_G)
    col_rochas = ", ".join("Rect2(%d, %d, %d, %d)" % (r[0], r[1], r[2] - r[0], r[3] - r[1]) for r in map(G.retangulo_rocha, G.ROCHAS))
    c.no("Extracao", "Node2D", ".", ['script = ExtResource("%s")' % s_extracao, "recursos = [%s]" % ", ".join(itens),
                                     "desenho_arbusto = " + des_m, "desenho_arvoreta = " + des_g,
                                     "colisao_arbusto = " + col_m, "colisao_arvoreta = " + col_g,
                                     "colisoes_pedra = Array[Rect2]([%s])" % col_rochas, "variantes_mato = %d" % len(G.PLANTAS),
                                     "usa_entulho = false"])
    canteiros = [(x0, y0, x1 - x0, y1 - y0) for x0, y0, x1, y1 in CAMPINAS]
    c.no("Vida", "Node2D", ".", ['script = ExtResource("%s")' % s_vida,
                                 "area = Rect2(64, 96, %d, %d)" % (LARG - 128, ALT - 160),
                                 "canteiros = Array[Rect2]([%s])" % ", ".join("Rect2(%d, %d, %d, %d)" % r for r in canteiros)])
    return c.texto()


def escrever_floresta():
    c = F.Cena()
    terreno = c.recurso("PackedScene", "res://cenas/terreno_floresta.tscn", "terreno")
    jogador = c.recurso("PackedScene", "res://cenas/jogador.tscn", "jogador")
    vinheta = c.recurso("PackedScene", "res://cenas/efeitos/vinheta.tscn", "vinheta")
    s_luz = c.recurso("Script", "res://codigo/efeitos/iluminacao.gd", "iluminacao")
    ui = c.recurso("PackedScene", "res://cenas/ui.tscn", "ui")
    interface = c.recurso("PackedScene", "res://cenas/ui/interface.tscn", "interface")
    s_raiz = c.recurso("Script", "res://codigo/logica/floresta.gd", "floresta_gd")
    c.no("floresta", "Node2D", props=['script = ExtResource("%s")' % s_raiz, "limites = Rect2(%d, %d, %d, %d)" % (
        LIMITES[0], LIMITES[1], LARG, ALT), 'metadata/titulo_hud = "FLORESTA"', "metadata/barra_ferramentas = true"], raiz=True)
    c.no("Terrains", "", ".", instancia=terreno)
    c.no("Jogador", "", ".", ["z_index = 1", "position = %s" % F.vec(*CHEGADA_CIDADE), "collision_mask = 96"], instancia=jogador)
    c.no("Vinheta", "", ".", ["layer = 1"], instancia=vinheta)
    c.no("Iluminacao", "Node", ".", ['script = ExtResource("%s")' % s_luz])
    c.no("CanvasModulate", "CanvasModulate", "Iluminacao", ["color = Color(0.86, 0.88, 1, 1)"])
    c.no("assets/ui", "", ".", instancia=ui)
    c.no("Interface", "", ".", instancia=interface)
    return c.texto()


def main():
    m = construir_mapa()
    problemas = conferir_alcance(m)
    open(SAIDA_TERRENO, "w", encoding="utf-8").write(escrever_terreno(m))
    open(SAIDA_FLORESTA, "w", encoding="utf-8").write(escrever_floresta())
    abetos = sum(1 for s in m.sprites if s["tipo"] == "abeto")
    carvalhos = sum(1 for s in m.sprites if s["tipo"] == "carvalho")
    pedras = sum(1 for r in m.recursos if r["tipo"] == "pedra")
    print("cenas: terreno_floresta, floresta")
    print("camadas: chao=%d terra=%d penhasco=%d detalhes=%d | sprites=%d (abetos %d, carvalhos %d) | pedras=%d | obstaculos=%d | pesca=%d"
          % (len(m.chao), len(m.terra), len(m.penhasco), len(m.detalhes), len(m.sprites), abetos, carvalhos, pedras, len(m.obstaculos), len(m.pesca)))
    print("fauna: " + ", ".join("%s x%d" % (e, sum(1 for a in m.populacao if a[0] == e)) for e in ("cervo", "coelho", "capivara", "corvo")) + " | refugios=%d" % len(m.refugios))
    print("alcance a pe: %s" % ("OK (estrada, trilhas e pesca alcancaveis)" if not problemas else "FALHA em " + ", ".join(problemas)))
    for i, poli in enumerate(m.obstaculos):
        if len(poli) < 3 or G.auto_intersecao(poli):
            print("PROBLEMA: Obstaculo%d invalido" % (i + 1))
    if problemas:
        sys.exit(1)


if __name__ == "__main__":
    main()
