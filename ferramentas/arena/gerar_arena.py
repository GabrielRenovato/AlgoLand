#!/usr/bin/env python3
"""Gerador do mapa sazonal da arena (cenas/terreno.tscn). Python puro, sem PIL/numpy.

Como usar (da raiz do projeto):
    python3 ferramentas/arena/gerar_arena.py
    flatpak run org.godotengine.Godot --headless --path . --import      # importa as folhas geradas
    flatpak run org.godotengine.Godot --headless --path . --script res://testes/teste_arena.gd

O resultado e deterministico (semente fixa): rodar de novo gera arquivos identicos.

Entrada:
  - ferramentas/arena/base/terreno_base.tscn.txt: o terreno antigo (inverno). Dele sao reaproveitados, sem mexer, a barraca,
    a fogueira, o contorno da arena (LimiteArena), a navegacao e as arvores/props (mesmos nomes e posicoes).
    A extensao .txt evita o Godot ler essa copia como cena (o uid dela duplicaria o de cenas/terreno.tscn).
  - Tiles/Seasonal Forest/seasonal sample (estacao).png: as 4 folhas 256x256 (mesmo layout nas 4 estacoes).
Saida:
  - cenas/terreno.tscn
  - Tiles/Seasonal Forest/arena/<estacao>.png: a folha da estacao + tiles de margem de lagoa gerados por codigo
    (a folha de exemplo nao traz margem grama/agua). As coordenadas originais ficam iguais; os tiles novos entram
    a partir da linha 16 do atlas. E essa folha que Codigos/Design/estacoes.gd coloca no TileSetAtlasSource.

Mapa de tiles da folha (coluna, linha em tiles de 16 px) - conferido visualmente nas 4 estacoes:
  grama base ............ (0,1) (0,2) (0,3) (0,4) (0,5)        flores/detalhes de grama: (0..3, 6..7)
  terra (blob 3x3) ...... cantos (1,0) (3,0) (1,2) (3,2); bordas (2,0) (1,1) (3,1) (2,2); centro (2,1) e (4,0..4)
  terra, canto interno .. (1,3) grama em SE, (2,3) grama em SO, (1,4) grama em NE, (2,4) grama em NO
                          (sem peca para 2 cantos internos ou borda+canto: a mascara e ajustada ate nao precisar)
  pedras no chao ........ (4,6) (4,7) (4,8) (4,9)  (tiles com grama de fundo)
  plantas pequenas ...... (0,8) (0,9)  (tiles com grama de fundo)
  arbustos .............. (1,8)-(1,9) medio 16x32; (2..3, 8..9) grande 32x32 (sprites, origem na base)
  plato/penhasco ........ colunas 5..10: topo (linhas 0..3, miolo transparente), face (4..6), pe na grama (7),
                          pe na agua (11 e 12); as colunas do meio (7,8) se repetem para alargar o plato
  caverna ............... (11..15, 7..11)  (as laterais sao cortes retos: o mapa as esconde com dois abetos)
  arvore grande ......... (11..15, 0..6) = 80x112 com a sombra no chao e uma placa de grama sob as raizes
  agua .................. (11,13) (12,13) (13,13) (12,14) (13,14); animacao de brilho em "seasonal water animations"
  muro de pedra ......... (2..4, 10..12)  (montar_muro; desligado em USAR_MURO: as pontas sao cortes retos)

Composicao do mapa (coordenadas do terreno, px): plato com pe na lagoa a noroeste, caverna ao norte entre dois abetos,
clareira de terra do acampamento a nordeste com uma trilha que sai para a floresta ao sul, carvalhos grandes, arbustos,
pedras e plantas espalhados fora do raio do acampamento, dos spawns e da agua. As arvores evergreen do aro da arena
continuam as mesmas (posicao e variante); as colisoes sao recalculadas pelos pixels do tronco/base de cada sprite.
"""
import math
import os
import random
import re
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
import png_puro as P  # noqa: E402
import tscn as T  # noqa: E402

RAIZ = os.path.abspath(os.path.join(AQUI, "..", ".."))
BASE = os.path.join(AQUI, "base", "terreno_base.tscn.txt")
SAIDA = os.path.join(RAIZ, "cenas", "terreno.tscn")
PASTA_TILES = os.path.join(RAIZ, "Tiles", "Seasonal Forest")
PASTA_FOLHAS = os.path.join(PASTA_TILES, "arena")
# indice 0..3 = primavera, verao, outono, inverno (o mesmo de estacoes.gd)
ESTACOES = ["spring", "summer", "autumn", "winter"]
BRILHO_ARQUIVOS = ["spring water sparkles B.png", "summer water sparkles B 16x16.png",
                   "autumn water sparkles B 16x16.png", "winter water sparkles B 16x16.png"]
ESTACAO_INICIAL = 3  # a cena sai no inverno (como o terreno antigo); estacoes.gd troca ao carregar

USAR_MURO = False
TILE = 16
# Caverna ao norte (origem em tiles). A boca fica no meio da base do bloco 5x5; a passagem para a fazenda
# (Area2D) e o ponto de chegada de quem volta de la ficam logo a frente dela
CAV_OX, CAV_OY = 14, -12
PASSAGEM_CAVERNA = (CAV_OX * TILE + 40, (CAV_OY + 5) * TILE + 6)  # centro da zona de interacao
CHEGADA_CAVERNA = (CAV_OX * TILE + 40, (CAV_OY + 5) * TILE + 30)
RNG = random.Random(20260711)

# Pontos de spawn dos inimigos (Marker2D do enemySpawner) em coordenadas do terreno. O spawner tem escala
# (0.441821, 0.927851) em gerar-slime.tscn: mundo = cenario(6,0) + enemySpawner(215,176) + escala*marcador;
# terreno = mundo - (cenario + Terrains(-10,14)) = mundo + (4, -14)
SPAWNS = [(123.0, 163.0), (214.0, 89.0), (322.0, 156.0)]
# Acampamento (barraca, fogueira, mercador, moradores, jogador): nao pode ter obstaculo novo aqui
ACAMPAMENTO = (550.0, 185.0)
RAIO_ACAMPAMENTO = 125.0


# ---------------------------------------------------------------- geometria basica
def ponto_em_poligono(p, poli):
    x, y = p
    dentro = False
    n = len(poli)
    for i in range(n):
        x1, y1 = poli[i]
        x2, y2 = poli[(i + 1) % n]
        if (y1 > y) != (y2 > y) and x < (x2 - x1) * (y - y1) / (y2 - y1) + x1:
            dentro = not dentro
    return dentro


def dist_segmento(p, a, b):
    ax, ay = a
    bx, by = b
    dx, dy = bx - ax, by - ay
    t = 0.0 if dx == dy == 0 else max(0.0, min(1.0, ((p[0] - ax) * dx + (p[1] - ay) * dy) / (dx * dx + dy * dy)))
    return math.hypot(p[0] - (ax + t * dx), p[1] - (ay + t * dy))


def dist_borda(p, poli):
    return min(dist_segmento(p, poli[i], poli[(i + 1) % len(poli)]) for i in range(len(poli)))


def dist_assinada(p, poli):
    """Positiva dentro da arena, negativa fora."""
    d = dist_borda(p, poli)
    return d if ponto_em_poligono(p, poli) else -d


def simplificar(pts, tol):
    """Douglas-Peucker em polilinha aberta."""
    if len(pts) < 3:
        return pts
    a, b = pts[0], pts[-1]
    mx, mi = -1.0, 0
    for i in range(1, len(pts) - 1):
        d = dist_segmento(pts[i], a, b)
        if d > mx:
            mx, mi = d, i
    if mx > tol:
        return simplificar(pts[:mi + 1], tol)[:-1] + simplificar(pts[mi:], tol)
    return [a, b]


def simplificar_anel(pts, tol):
    if len(pts) < 4:
        return pts
    # divide no ponto mais distante do primeiro para evitar degenerar
    i0 = 0
    ifar = max(range(len(pts)), key=lambda i: math.hypot(pts[i][0] - pts[i0][0], pts[i][1] - pts[i0][1]))
    a = simplificar(pts[i0:ifar + 1], tol)
    b = simplificar(pts[ifar:] + [pts[i0]], tol)
    return a[:-1] + b[:-1]


# ---------------------------------------------------------------- ruido deterministico
def _hash(ix, iy, semente):
    n = (ix * 374761393 + iy * 668265263 + semente * 2147483647) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0


def ruido(x, y, escala, semente):
    gx, gy = x / escala, y / escala
    ix, iy = math.floor(gx), math.floor(gy)
    fx, fy = gx - ix, gy - iy
    fx = fx * fx * (3 - 2 * fx)
    fy = fy * fy * (3 - 2 * fy)
    a = _hash(ix, iy, semente)
    b = _hash(ix + 1, iy, semente)
    c = _hash(ix, iy + 1, semente)
    d = _hash(ix + 1, iy + 1, semente)
    return (a + (b - a) * fx) + ((c + (d - c) * fx) - (a + (b - a) * fx)) * fy  # 0..1


# ---------------------------------------------------------------- folhas
class Folha:
    def __init__(self, estacao):
        self.estacao = estacao
        self.img = P.carregar(os.path.join(PASTA_TILES, "seasonal sample (%s).png" % estacao))

    def tile_usado(self, tx, ty):
        im = self.img
        for y in range(16):
            for x in range(16):
                if im.alfa(tx * 16 + x, ty * 16 + y) > 0:
                    return True
        return False

    def pix(self, tx, ty, x, y):
        return self.img.pixel(tx * 16 + x, ty * 16 + y)


FOLHAS = {e: Folha(e) for e in ESTACOES}
VERAO = FOLHAS["summer"]

GRAMA = [(0, 1), (0, 2), (0, 3), (0, 4), (0, 5)]
FLORES = [(0, 6), (1, 6), (2, 6), (3, 6), (0, 7), (1, 7), (2, 7), (3, 7)]
AGUA = [(11, 13), (12, 13), (13, 13), (12, 14), (13, 14)]
CENTRO_TERRA = [(2, 1), (4, 0), (4, 1), (4, 2), (4, 3), (4, 4)]
BORDA_TERRA = {"NO": (1, 0), "N": (2, 0), "NE": (3, 0), "O": (1, 1), "L": (3, 1), "SO": (1, 2), "S": (2, 2), "SE": (3, 2)}
CANTO_INTERNO = {"SE": (1, 3), "SO": (2, 3), "NE": (1, 4), "NO": (2, 4)}  # onde fica a grama

# tiles usados na folha (qualquer estacao) -> entram no TileSetAtlasSource
TILES_USADOS = sorted({(tx, ty) for tx in range(16) for ty in range(16) if any(f.tile_usado(tx, ty) for f in FOLHAS.values())},
                      key=lambda t: (t[1], t[0]))


# ---------------------------------------------------------------- mapa: formas em pixels
class Lagoa:
    """Campo de distancia assinada da agua (negativo dentro) em pixels do terreno."""

    def __init__(self):
        # lobos elipticos (cx, cy, raio_x, raio_y)
        self.lobos = [(26.0, 100.0, 100.0, 38.0), (112.0, 72.0, 34.0, 32.0), (-44.0, 74.0, 34.0, 32.0)]
        # pe do penhasco: retangulo dentro da agua logo abaixo da mesa (definido depois que a mesa existe)
        self.pe = None
        self.k = 14.0  # suavizacao da uniao

    def _elipse(self, x, y, c):
        cx, cy, rx, ry = c
        v = math.hypot((x - cx) / rx, (y - cy) / ry)
        return (v - 1.0) * min(rx, ry) * 0.85

    def _caixa(self, x, y, r):
        x0, y0, x1, y1 = r
        cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
        hx, hy = (x1 - x0) / 2, (y1 - y0) / 2
        dx, dy = abs(x - cx) - hx, abs(y - cy) - hy
        return math.hypot(max(dx, 0), max(dy, 0)) + min(max(dx, dy), 0)

    def dist(self, x, y):
        ds = [self._elipse(x, y, c) for c in self.lobos]
        if self.pe:
            ds.append(self._caixa(x, y, self.pe))
        # uniao suave (smooth-min polinomial)
        d = ds[0]
        for e in ds[1:]:
            h = max(self.k - abs(d - e), 0.0) / self.k
            d = min(d, e) - h * h * self.k * 0.25
        # margem organica
        d += (ruido(x, y, 11.0, 7) - 0.5) * 3.6 + (ruido(x, y, 29.0, 3) - 0.5) * 5.0
        return d


# ---------------------------------------------------------------- leitura do terreno antigo
class Base:
    def __init__(self, caminho):
        self.texto = open(caminho, encoding="utf-8").read()
        self.blocos = re.split(r"\n(?=\[)", self.texto)
        self.ext = {}
        self.sub = {}
        self.nos = []
        for b in self.blocos:
            if b.startswith("[ext_resource"):
                self.ext[re.search(r' id="([^"]+)"', b).group(1)] = b
            elif b.startswith("[sub_resource"):
                self.sub[re.search(r' id="([^"]+)"', b).group(1)] = b
            elif b.startswith("[node"):
                m = re.match(r'\[node name="([^"]+)" type="([^"]+)"(?: parent="([^"]*)")?', b)
                nome, tipo, pai = m.groups()
                caminho_no = nome if pai is None else (nome if pai == "." else pai + "/" + nome)
                self.nos.append({"nome": nome, "tipo": tipo, "pai": pai, "caminho": caminho_no, "bloco": b})

    def poligono_limite(self):
        for n in self.nos:
            if n["caminho"] == "LimiteArena/Contorno":
                m = re.search(r"polygon = PackedVector2Array\(([^)]*)\)", n["bloco"])
                v = [float(x) for x in m.group(1).split(",")]
                return list(zip(v[0::2], v[1::2]))
        raise RuntimeError("LimiteArena/Contorno nao encontrado")

    def raiz(self):
        return self.nos[0]


def refs(texto):
    return set(re.findall(r'(?:Sub|Ext)Resource\("([^"]+)"\)', texto))


# ---------------------------------------------------------------- medidas por pixel de sprites
def _classe_madeira(px):
    r, g, b, a = px
    return a >= 200 and r >= g


def medir_base_arvore(img, regiao, solido=_classe_madeira):
    """Retangulo de colisao (x0, y0, x1, y1) relativo a regiao do sprite, pelo tronco visivel nas ultimas linhas.
    O sprite tem a origem na base, centrado no tronco: a largura vem dos pixels de madeira (raizes incluidas) e,
    quando as raizes abrem muito, fica em ~metade (12..18 px, como no terreno antigo)."""
    x, y, w, h = [int(v) for v in regiao]
    cols = []
    for yy in range(h - 6, h):
        for xx in range(w):
            if solido(img.pixel(x + xx, y + yy)):
                cols.append(xx)
    if not cols:
        for yy in range(h - 6, h):
            for xx in range(w):
                if img.alfa(x + xx, y + yy) >= 200:
                    cols.append(xx)
    medida = (max(cols) + 1 - min(cols)) if cols else 12
    if medida > 20:
        medida = max(12, min(18, round(medida * 0.5)))
    medida = max(medida, 12)
    cx = w / 2.0
    return (cx - medida / 2.0, h - 8, cx + medida / 2.0, h)


def medir_opaco(img, regiao, linhas=8, limiar=128):
    x, y, w, h = [int(v) for v in regiao]
    cols = []
    for yy in range(max(0, h - linhas), h):
        for xx in range(w):
            if img.alfa(x + xx, y + yy) >= limiar:
                cols.append(xx)
    if not cols:
        return None
    return (min(cols), h - min(linhas, h), max(cols) + 1, h)


def silhueta_pixels(solido_fn, largura, altura, passo=2):
    """Extremos esquerdo/direito do solido a cada `passo` linhas -> poligono (lista de pontos) ou []"""
    esq, dire = [], []
    for y in range(0, altura, passo):
        xs = [x for x in range(largura) if solido_fn(x, y) or solido_fn(x, min(y + 1, altura - 1))]
        if xs:
            esq.append((min(xs), y))
            dire.append((max(xs) + 1, y + passo))
    if not esq:
        return []
    return esq + dire[::-1]


# ---------------------------------------------------------------- pecas de cenario montadas em tiles
def coluna_mesa(i, largura):
    if i == 0:
        return 5
    if i == 1:
        return 6
    if i == largura - 2:
        return 9
    if i == largura - 1:
        return 10
    return 7 if i % 2 == 0 else 8


def montar_mesa(ox, oy, largura, pe_na_agua):
    """Platô redondo (topo + face) com `largura` tiles (par, >= 6). Com pe_na_agua usa as linhas 11/12 da folha
    (face encostando na agua); senao a linha 7 (face encostando na grama). Retorna {celula: tile}."""
    celulas = {}
    linhas = [0, 1, 2, 3, 4, 5, 6] + ([11, 12] if pe_na_agua else [7])
    for j, ly in enumerate(linhas):
        for i in range(largura):
            c = coluna_mesa(i, largura)
            if ly == 12 and c in (5, 10) and (i == 0 or i == largura - 1):
                continue  # (5,12)/(10,12) sao cantos de outro platô
            if VERAO.tile_usado(c, ly):
                celulas[(ox + i, oy + j)] = (c, ly)
    return celulas


def montar_muro(ox, oy, largura):
    """Muro de pedra horizontal (3 linhas de tiles): pontas (2,.) e (4,.), meio (3,.) repetido."""
    celulas = {}
    for j, ly in enumerate((10, 11, 12)):
        for i in range(largura):
            c = 2 if i == 0 else (4 if i == largura - 1 else 3)
            if VERAO.tile_usado(c, ly):
                celulas[(ox + i, oy + j)] = (c, ly)
    return celulas


def montar_caverna(ox, oy):
    celulas = {}
    for j in range(5):
        for i in range(5):
            c, ly = 11 + i, 7 + j
            if VERAO.tile_usado(c, ly):
                celulas[(ox + i, oy + j)] = (c, ly)
    return celulas


def _agua_like(px):
    r, g, b, a = px
    return a > 0 and b > r + 30


def _grama_like(px):
    r, g, b, a = px
    return a > 0 and g > r + 6 and g > b + 12


def poligono_de_stamp(celulas, solido_pix, passo=4, tol=1.6):
    """Silhueta (por extremos de cada linha de pixels) de um conjunto de tiles posicionados -> poligono em px do mundo."""
    xs0 = min(c[0] for c in celulas)
    ys0 = min(c[1] for c in celulas)
    xs1 = max(c[0] for c in celulas) + 1
    ys1 = max(c[1] for c in celulas) + 1
    larg, alt = (xs1 - xs0) * TILE, (ys1 - ys0) * TILE

    def solido(x, y):
        cel = (xs0 + x // TILE, ys0 + y // TILE)
        t = celulas.get(cel)
        if not t:
            return False
        px = VERAO.pix(t[0], t[1], x % TILE, y % TILE)
        return solido_pix(px)

    pts = silhueta_pixels(solido, larg, alt, passo)
    pts = simplificar_anel(pts, tol)
    return [(xs0 * TILE + x, ys0 * TILE + y) for x, y in pts]


def solido_penhasco(px):
    return px[3] > 0 and not _agua_like(px)


def solido_caverna(px):
    return px[3] > 0 and not _grama_like(px)


# ---------------------------------------------------------------- terra (autotile de blob 3x3 com cantos internos)
def classificar_terra(S, x, y):
    N, E, So, O = (x, y - 1) in S, (x + 1, y) in S, (x, y + 1) in S, (x - 1, y) in S
    NE, NO, SE, SO = (x + 1, y - 1) in S, (x - 1, y - 1) in S, (x + 1, y + 1) in S, (x - 1, y + 1) in S
    if N and E and So and O:
        falta = [k for k, v in (("NE", NE), ("NO", NO), ("SE", SE), ("SO", SO)) if not v]
        if not falta:
            return "centro", None
        if len(falta) == 1:
            return "interno", falta[0]
        return "ruim", falta
    n = sum([N, E, So, O])
    if n == 3:
        if not N:
            ok = SE and SO
            return ("N", None) if ok else ("ruim", [k for k, v in (("SE", SE), ("SO", SO)) if not v])
        if not So:
            ok = NE and NO
            return ("S", None) if ok else ("ruim", [k for k, v in (("NE", NE), ("NO", NO)) if not v])
        if not O:
            ok = NE and SE
            return ("O", None) if ok else ("ruim", [k for k, v in (("NE", NE), ("SE", SE)) if not v])
        ok = NO and SO
        return ("L", None) if ok else ("ruim", [k for k, v in (("NO", NO), ("SO", SO)) if not v])
    if n == 2 and not (N and So) and not (E and O):
        if So and E:
            return ("NO", None) if SE else ("remover", None)
        if So and O:
            return ("NE", None) if SO else ("remover", None)
        if N and E:
            return ("SO", None) if NE else ("remover", None)
        if N and O:
            return ("SE", None) if NO else ("remover", None)
    return "remover", None


def regularizar_terra(S, proibido):
    """Ajusta a mascara de terra ate todo tile ter peca correspondente na folha (sem 'manchas' nem costuras)."""
    S = set(S)
    for _ in range(60):
        mudou = False
        for (x, y) in sorted(S):
            tipo, extra = classificar_terra(S, x, y)
            if tipo == "remover":
                S.discard((x, y))
                mudou = True
            elif tipo == "ruim":
                d = {"NE": (1, -1), "NO": (-1, -1), "SE": (1, 1), "SO": (-1, 1)}
                add = [(x + d[k][0], y + d[k][1]) for k in extra]
                if any(c in proibido for c in add):
                    S.discard((x, y))
                else:
                    S.update(add)
                mudou = True
        if not mudou:
            return S
    raise RuntimeError("terra nao convergiu")


def tiles_terra(S):
    out = {}
    for (x, y) in S:
        tipo, extra = classificar_terra(S, x, y)
        if tipo == "centro":
            out[(x, y)] = RNG.choice(CENTRO_TERRA)
        elif tipo == "interno":
            out[(x, y)] = CANTO_INTERNO[extra]
        else:
            out[(x, y)] = BORDA_TERRA[tipo]
    return out


# ---------------------------------------------------------------- agua: contorno e tiles de margem gerados
def contornos(f, x0, y0, x1, y1, passo, limiar=0.0):
    """Marching squares: curvas de nivel f(x,y) == limiar -> lista de aneis [(x,y), ...]."""
    nx = int((x1 - x0) / passo) + 2
    ny = int((y1 - y0) / passo) + 2
    v = [[f(x0 + i * passo, y0 + j * passo) - limiar for i in range(nx)] for j in range(ny)]

    def interp(p, q, a, b):
        t = a / (a - b) if a != b else 0.5
        return (p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t)

    tabela = {1: [(3, 0)], 2: [(0, 1)], 3: [(3, 1)], 4: [(1, 2)], 6: [(0, 2)], 7: [(3, 2)], 8: [(2, 3)], 9: [(0, 2)],
              11: [(1, 2)], 12: [(3, 1)], 13: [(0, 1)], 14: [(3, 0)]}
    segs = []
    for j in range(ny - 1):
        for i in range(nx - 1):
            a, b, c, d = v[j][i], v[j][i + 1], v[j + 1][i + 1], v[j + 1][i]
            idx = (a < 0) * 1 + (b < 0) * 2 + (c < 0) * 4 + (d < 0) * 8
            if idx in (0, 15):
                continue
            pa = (x0 + i * passo, y0 + j * passo)
            pb = (pa[0] + passo, pa[1])
            pc = (pa[0] + passo, pa[1] + passo)
            pd = (pa[0], pa[1] + passo)
            # arestas: 0 topo (a-b), 1 direita (b-c), 2 base (d-c), 3 esquerda (a-d)
            chave = {0: ("h", i, j), 1: ("v", i + 1, j), 2: ("h", i, j + 1), 3: ("v", i, j)}
            pos = {0: interp(pa, pb, a, b), 1: interp(pb, pc, b, c), 2: interp(pd, pc, d, c), 3: interp(pa, pd, a, d)}
            if idx in (5, 10):
                centro = (a + b + c + d) / 4
                if idx == 5:
                    pares = [(0, 1), (3, 2)] if centro < 0 else [(3, 0), (1, 2)]
                else:
                    pares = [(0, 3), (2, 1)] if centro < 0 else [(0, 1), (2, 3)]
            else:
                pares = tabela[idx]
            for e1, e2 in pares:
                segs.append(((chave[e1], pos[e1]), (chave[e2], pos[e2])))
    viz = {}
    for k, (s1, s2) in enumerate(segs):
        viz.setdefault(s1[0], []).append(k)
        viz.setdefault(s2[0], []).append(k)
    usado = [False] * len(segs)
    aneis = []
    for k0 in range(len(segs)):
        if usado[k0]:
            continue
        usado[k0] = True
        s1, s2 = segs[k0]
        anel = [s1[1], s2[1]]
        atual = s2[0]
        while True:
            prox = None
            for k in viz.get(atual, []):
                if not usado[k]:
                    prox = k
                    break
            if prox is None:
                break
            usado[prox] = True
            a, b = segs[prox]
            if a[0] == atual:
                anel.append(b[1])
                atual = b[0]
            else:
                anel.append(a[1])
                atual = a[0]
        aneis.append(anel)
    return aneis


def luminosidade_escura(c, k=0.55):
    return (int(c[0] * k), int(c[1] * k), int(c[2] * k), 255)


def pintar_margem(folha, grid_d, var_grama, var_agua):
    """Tile 16x16 (lista de 256 RGBA) para uma celula de margem, a partir das distancias assinadas por pixel."""
    rim_mid = folha.pix(7, 12, 4, 8)
    rim_claro = folha.pix(7, 12, 4, 9)
    rim_fundo = folha.pix(7, 12, 4, 10)
    out = []
    for y in range(16):
        for x in range(16):
            d = grid_d[y * 16 + x]
            if d >= 1.0:
                p = folha.pix(var_grama[0], var_grama[1], x, y)
            elif d >= 0.0:
                p = luminosidade_escura(folha.pix(var_grama[0], var_grama[1], x, y))
            elif d >= -1.0:
                p = rim_mid
            elif d >= -2.0:
                p = rim_claro
            elif d >= -3.0:
                p = rim_fundo
            else:
                p = folha.pix(var_agua[0], var_agua[1], x, y)
            out.append(p)
    return out


def gerar_folha_estacao(estacao, tiles_margem):
    """Folha 256x256 original + tiles de margem (linhas 16 em diante). tiles_margem: lista de (grid_d, var_grama, var_agua)."""
    folha = FOLHAS[estacao]
    linhas_extra = (len(tiles_margem) + 15) // 16
    alt = 256 + linhas_extra * 16
    img = P.Imagem(256, alt, bytearray(256 * alt * 4))
    img.dados[:256 * 256 * 4] = folha.img.dados
    for k, (grid_d, vg, va) in enumerate(tiles_margem):
        tx, ty = k % 16, 16 + k // 16
        px = pintar_margem(folha, grid_d, vg, va)
        for y in range(16):
            for x in range(16):
                r, g, b, a = px[y * 16 + x]
                i = ((ty * 16 + y) * 256 + tx * 16 + x) * 4
                img.dados[i:i + 4] = bytes((r, g, b, a))
    os.makedirs(PASTA_FOLHAS, exist_ok=True)
    caminho = os.path.join(PASTA_FOLHAS, "%s.png" % estacao)
    P.salvar(img, caminho)
    return caminho


# ---------------------------------------------------------------- montagem do mapa
class Mundo:
    """Reune tudo que o gerador decide: tiles por camada, sprites novos e poligonos de colisao."""

    def __init__(self, base):
        self.base = base
        self.poli = base.poligono_limite()
        self.chao = {}
        self.terra = {}
        self.agua = {}
        self.penhasco = {}
        self.detalhes = {}
        self.brilho = {}
        self.sprites_novos = []   # dicts: nome, x, y, regiao, offset, recurso, grupos
        self.obstaculos = []      # listas de pontos (poligonos)
        self.ocupados = []        # (x, y, raio) para espacar as pecas soltas
        self.tiles_margem = []
        self.retangulos_bloqueados = []  # (x0,y0,x1,y1) mesa e caverna
        self.lagoa = Lagoa()

    # -- consultas
    def na_agua(self, x, y, folga=0.0):
        return self.lagoa.dist(x, y) < folga

    def em_bloqueado(self, x, y, folga=0.0):
        return any(x0 - folga <= x <= x1 + folga and y0 - folga <= y <= y1 + folga for x0, y0, x1, y1 in self.retangulos_bloqueados)

    def na_terra(self, x, y, folga=0):
        cx, cy = int(math.floor(x / TILE)), int(math.floor(y / TILE))
        return any((cx + dx, cy + dy) in self.terra for dx in range(-folga, folga + 1) for dy in range(-folga, folga + 1))

    def livre(self, x, y, raio, margem_borda=30.0, em_terra=False):
        if dist_assinada((x, y), self.poli) < margem_borda:
            return False
        if self.na_agua(x, y, 26.0 + raio * 0.3) or self.em_bloqueado(x, y, 18.0 + raio * 0.3):
            return False
        if not em_terra and self.na_terra(x, y, 2):
            return False
        if math.hypot(x - ACAMPAMENTO[0], y - ACAMPAMENTO[1]) < RAIO_ACAMPAMENTO + raio:
            return False
        for sx, sy in SPAWNS:
            if math.hypot(x - sx, y - sy) < 50.0 + raio:
                return False
        for ox, oy, orr in self.ocupados:
            if math.hypot(x - ox, y - oy) < orr + raio:
                return False
        return True

    def espalhar(self, quantidade, raio, tentativas=4000, **kw):
        pts = []
        xs = [p[0] for p in self.poli]
        ys = [p[1] for p in self.poli]
        for _ in range(tentativas):
            if len(pts) >= quantidade:
                break
            x = RNG.uniform(min(xs), max(xs))
            y = RNG.uniform(min(ys), max(ys))
            if self.livre(x, y, raio, **kw):
                pts.append((round(x), round(y)))
                self.ocupados.append((x, y, raio))
        return pts


def construir(base):
    m = Mundo(base)

    # ---- platô com pe na agua (norte da lagoa) e caverna (norte da arena)
    MESA_OX, MESA_OY, MESA_W = -2, -5, 10
    m.penhasco.update(montar_mesa(MESA_OX, MESA_OY, MESA_W, True))
    yf = (MESA_OY + 7) * TILE
    mesa_x0, mesa_x1 = MESA_OX * TILE, (MESA_OX + MESA_W) * TILE
    m.lagoa.pe = (mesa_x0 - 9, yf + 4, mesa_x1 + 9, yf + 64)
    caverna = montar_caverna(CAV_OX, CAV_OY)
    m.penhasco.update(caverna)
    poli_mesa = poligono_de_stamp(montar_mesa(MESA_OX, MESA_OY, MESA_W, True), solido_penhasco)
    poli_cav = poligono_de_stamp(caverna, solido_caverna)
    m.obstaculos.append(poli_mesa)
    m.obstaculos.append(poli_cav)
    m.retangulos_bloqueados.append((mesa_x0, MESA_OY * TILE, mesa_x1, (MESA_OY + 9) * TILE))
    m.retangulos_bloqueados.append((CAV_OX * TILE, CAV_OY * TILE, (CAV_OX + 5) * TILE, (CAV_OY + 5) * TILE))

    # muro de pedra isolado (cobertura). Desligado: as pontas da peca de exemplo sao cortes retos de uma parede
    # maior e ficam estranhas soltas na grama (ver USAR_MURO)
    if USAR_MURO:
        MURO_OX, MURO_OY, MURO_W = 11, 17, 7
        muro = montar_muro(MURO_OX, MURO_OY, MURO_W)
        m.penhasco.update(muro)
        m.obstaculos.append(poligono_de_stamp(muro, solido_caverna, passo=2, tol=1.0))
        m.retangulos_bloqueados.append((MURO_OX * TILE, MURO_OY * TILE, (MURO_OX + MURO_W) * TILE, (MURO_OY + 3) * TILE))

    # ---- lagoa: tiles de agua e margem
    lobos = m.lagoa.lobos
    cx0 = int((min(c[0] - c[2] for c in lobos) - 40) // TILE)
    cx1 = int((max(c[0] + c[2] for c in lobos) + 40) // TILE)
    cy0 = int((min(c[1] - c[3] for c in lobos) - 40) // TILE)
    cy1 = int((max(c[1] + c[3] for c in lobos) + 40) // TILE)
    margem_k = 0
    for cy in range(cy0, cy1 + 1):
        for cx in range(cx0, cx1 + 1):
            grade = [m.lagoa.dist(cx * TILE + x + 0.5, cy * TILE + y + 0.5) for y in range(16) for x in range(16)]
            if max(grade) < -3.0:
                m.agua[(cx, cy)] = RNG.choice(AGUA)
            elif min(grade) >= 1.0:
                continue
            else:
                m.tiles_margem.append((grade, RNG.choice(GRAMA), RNG.choice(AGUA)))
                m.agua[(cx, cy)] = (margem_k % 16, 16 + margem_k // 16)
                margem_k += 1
    # brilhos animados sobre a agua aberta (fora do pe do penhasco)
    for cel, t in m.agua.items():
        if t in AGUA and cel not in m.penhasco and RNG.random() < 0.42:
            m.brilho[cel] = (0, RNG.randrange(3))
    # contorno de colisao da agua: 1 px fora da margem visivel
    for anel in contornos(m.lagoa.dist, cx0 * TILE, cy0 * TILE, (cx1 + 1) * TILE, (cy1 + 1) * TILE, 4.0, 1.5):
        anel = simplificar_anel(anel, 1.2)
        if len(anel) >= 3:
            m.obstaculos.append([(round(x, 1), round(y, 1)) for x, y in anel])

    # ---- terra: clareira do acampamento + caminho ate a margem leste da lagoa
    def dentro_forma(x, y):
        v = math.hypot((x - 548) / 118.0, (y - 172) / 78.0)
        if v <= 1.0 + (ruido(x, y, 40.0, 11) - 0.5) * 0.35:
            return True
        trilha = [(520, 225), (530, 300), (545, 372)]
        return min(dist_segmento((x, y), trilha[i], trilha[i + 1]) for i in range(len(trilha) - 1)) <= 24.0

    proibido = set()
    for cy in range(-40, 60):
        for cx in range(-40, 90):
            px, py = cx * TILE + 8, cy * TILE + 8
            if m.na_agua(px, py, 34.0) or m.em_bloqueado(px, py, 24.0):
                proibido.add((cx, cy))
    S = {(cx, cy) for cy in range(-40, 60) for cx in range(-40, 90)
         if (cx, cy) not in proibido and dentro_forma(cx * TILE + 8, cy * TILE + 8)}
    S = regularizar_terra(S, proibido)
    m.terra = tiles_terra(S)

    # ---- chao de grama (mesmas dimensoes do terreno antigo) com flores esparsas
    for cy in range(-33, 51):
        for cx in range(-36, 78):
            px, py = cx * TILE + 8, cy * TILE + 8
            perto_camp = math.hypot(px - ACAMPAMENTO[0], py - ACAMPAMENTO[1]) < 110.0
            if not perto_camp and RNG.random() < 0.04 and dist_assinada((px, py), m.poli) > 0:
                m.chao[(cx, cy)] = RNG.choice(FLORES)
            else:
                m.chao[(cx, cy)] = RNG.choice(GRAMA)
    return m


# ---------------------------------------------------------------- pecas soltas (sprites e tiles de detalhe)
EVERGREEN_VERAO = P.carregar(os.path.join(RAIZ, "Tiles", "23.05a - Arctic Woodland 1.1", "evergreen trees",
                                          "evergreen trees (summer) 80x112.png"))
ARCTIC_V1 = P.carregar(os.path.join(RAIZ, "Tiles", "23.05a - Arctic Woodland 1.1", "arctic woodland v1.png"))

# regioes na folha sazonal (px): (x, y, larg, alt), deslocamento do sprite (origem na base) e retangulo de colisao
# manual (relativo a regiao) para as pecas cujo corpo e verde como a grama
CARVALHO = {"regiao": (176, 0, 80, 112), "offset": (-40, -111)}
ARBUSTO_M = {"regiao": (16, 128, 16, 32), "offset": (-8, -31), "colisao": (3, 23, 13, 31)}
ARBUSTO_G = {"regiao": (32, 128, 32, 32), "offset": (-16, -31), "colisao": (3, 23, 29, 31)}
ABETO = {"regiao": (96, 245, 48, 86), "offset": (-24, -85), "tex": "Atlas_n_1_2"}
ROCHAS = [(4, 6), (4, 7), (4, 8), (4, 9)]
PLANTAS = [(0, 8), (0, 9)]


def retangulo_rocha(tile):
    xs, ys = [], []
    for y in range(16):
        for x in range(16):
            px = VERAO.pix(tile[0], tile[1], x, y)
            if px[3] > 0 and not _grama_like(px) and not (px[0] < 110 and px[1] < 110 and px[2] < 90 and px[1] >= px[0] - 4):
                xs.append(x)
                ys.append(y)
    return (min(xs), max(ys) - 8 + 1, max(xs) + 1, max(ys) + 1)


def poligono_retangulo(x0, y0, x1, y1):
    return [(round(x0, 1), round(y0, 1)), (round(x1, 1), round(y0, 1)), (round(x1, 1), round(y1, 1)), (round(x0, 1), round(y1, 1))]


def ler_props_base(base):
    """Sprites do grupo Objetos3D do terreno antigo: nome, bloco, posicao, offset, regiao e imagem para medir."""
    props = []
    for n in base.nos:
        if n["pai"] != "Objetos3D":
            continue
        b = n["bloco"]
        pos = [float(v) for v in re.search(r"position = Vector2\(([^)]*)\)", b).group(1).split(",")]
        off = [float(v) for v in re.search(r"offset = Vector2\(([^)]*)\)", b).group(1).split(",")]
        tex = re.search(r'texture = SubResource\("([^"]+)"\)', b).group(1)
        sub = base.sub[tex]
        regiao = [float(v) for v in re.search(r"region = Rect2\(([^)]*)\)", sub).group(1).split(",")]
        atlas = re.search(r'atlas = ExtResource\("([^"]+)"\)', sub).group(1)
        props.append({"nome": n["nome"], "bloco": b, "pos": pos, "off": off, "regiao": regiao, "atlas": atlas, "tex": tex})
    return props


def colisao_de_prop(p, base):
    """Retangulo de colisao (mundo) medido pelos pixels da folha; None se o objeto nao bloqueia."""
    nome = p["nome"]
    if nome.startswith(("Arbusto", "ItemAcampamento")):
        return None
    caminho = re.search(r'path="([^"]+)"', base.ext[p["atlas"]]).group(1)
    if "evergreen trees" in caminho:
        # Arvores (colunas 0..3 da folha) usam o tronco; tocos e troncos caidos (colunas 4+) o corpo opaco
        coluna_folha = int(p["regiao"][0] // 80)
        if coluna_folha <= 3:
            r = medir_base_arvore(EVERGREEN_VERAO, p["regiao"])
        else:
            r = medir_opaco(EVERGREEN_VERAO, p["regiao"], 8)
            if r is None:
                return None
    else:
        r = medir_opaco(ARCTIC_V1, p["regiao"], 8)
        if r is None:
            return None
    bx = p["pos"][0] + p["off"][0]
    y1 = p["pos"][1]
    altura = min(8.0, r[3] - r[1])
    return (bx + r[0], y1 - altura, bx + r[2], y1)


def popular(m):
    base = m.base
    props = ler_props_base(base)
    mantidos = []
    for p in props:
        x, y = p["pos"]
        if m.na_agua(x, y, 14.0) or m.em_bloqueado(x, y, 14.0):
            print("  descartado (conflita com lagoa/penhasco):", p["nome"], p["pos"])
            continue
        mantidos.append(p)
        if dist_assinada((x, y), m.poli) > -60:
            m.ocupados.append((x, y, 38.0 if "Solo" in p["nome"] else 22.0))
    m.props_mantidos = mantidos

    # colisoes das arvores e props antigos (so as que estao dentro ou rente a arena)
    for p in mantidos:
        ret = colisao_de_prop(p, base)
        if ret is None:
            continue
        cx, cy = (ret[0] + ret[2]) / 2, (ret[1] + ret[3]) / 2
        if dist_assinada((cx, cy), m.poli) < -40:
            continue
        m.obstaculos.append(poligono_retangulo(*ret))

    # dois abetos de cada lado da caverna escondem as laterais cortadas da pedra
    r_abeto = medir_base_arvore(EVERGREEN_VERAO, ABETO["regiao"])
    for i, (x, y) in enumerate(((222, -112), (306, -116))):
        m.sprites_novos.append({"nome": "AbetoCaverna%d" % (i + 1), "x": x, "y": y, "tipo": "abeto"})
        bx = x + ABETO["offset"][0]
        m.obstaculos.append(poligono_retangulo(bx + r_abeto[0], y - 8, bx + r_abeto[2], y))
    # carvalhos grandes da folha sazonal
    for i, (x, y) in enumerate(m.espalhar(9, 66.0, margem_borda=64.0)):
        m.sprites_novos.append({"nome": "Carvalho%02d" % (i + 1), "x": x, "y": y, "tipo": "carvalho"})
        r = medir_base_arvore(VERAO.img, CARVALHO["regiao"])
        bx = x + CARVALHO["offset"][0]
        m.obstaculos.append(poligono_retangulo(bx + r[0], y - 8, bx + r[2], y))
    # arbustos medio e grande
    for i, (x, y) in enumerate(m.espalhar(8, 26.0, margem_borda=34.0)):
        tipo = "arbusto_g" if i % 2 == 0 else "arbusto_m"
        m.sprites_novos.append({"nome": "ArbustoSazonal%02d" % (i + 1), "x": x, "y": y, "tipo": tipo})
        cfg = ARBUSTO_G if tipo == "arbusto_g" else ARBUSTO_M
        ox, oy = cfg["offset"]
        c = cfg["colisao"]
        m.obstaculos.append(poligono_retangulo(x + ox + c[0], y + oy + c[1], x + ox + c[2], y + oy + c[3]))
    # pedras (tiles com grama de fundo) e plantinhas pequenas: camada Detalhes
    celulas_usadas = set()
    for (x, y) in m.espalhar(10, 20.0, margem_borda=30.0):
        cel = (int(x // TILE), int(y // TILE))
        if cel in celulas_usadas:
            continue
        celulas_usadas.add(cel)
        t = RNG.choice(ROCHAS)
        m.detalhes[cel] = t
        r = retangulo_rocha(t)
        m.obstaculos.append(poligono_retangulo(cel[0] * TILE + r[0], cel[1] * TILE + r[1], cel[0] * TILE + r[2], cel[1] * TILE + r[3]))
    for (x, y) in m.espalhar(16, 14.0, margem_borda=26.0):
        cel = (int(x // TILE), int(y // TILE))
        if cel in celulas_usadas:
            continue
        celulas_usadas.add(cel)
        m.detalhes[cel] = RNG.choice(PLANTAS)


# ---------------------------------------------------------------- escrita da cena
def bloco_camada(nome, celulas, tile_set_id, z=-1000):
    dados = [(x, y, 0, t[0], t[1], 0) for (x, y), t in sorted(celulas.items(), key=lambda kv: (kv[0][1], kv[0][0]))]
    return ('[node name="%s" type="TileMapLayer" parent="."]\ntexture_filter = 1\nz_index = %d\n'
            'tile_map_data = %s\ntile_set = SubResource("%s")\n') % (nome, z, T.codificar_tiles(dados), tile_set_id)


def adicionar_cabecalho(bloco, extra):
    """Acrescenta propriedades logo abaixo da linha [node ...] (ex.: resource_name em sub_resource)."""
    linhas = bloco.split("\n")
    return "\n".join([linhas[0], extra] + linhas[1:])


def bloco_sprite(nome, x, y, textura_id, offset, grupos=None):
    cab = '[node name="%s" type="Sprite2D" parent="Objetos3D"%s]' % (
        nome, (' groups=[%s]' % ", ".join('"%s"' % g for g in grupos)) if grupos else "")
    return "%s\nposition = Vector2(%s, %s)\ntexture = SubResource(\"%s\")\ncentered = false\noffset = Vector2(%s, %s)\n" % (
        cab, T.fmt(x), T.fmt(y), textura_id, T.fmt(offset[0]), T.fmt(offset[1]))


def escrever_cena(m):
    base = m.base
    blocos_nos = []
    kept_nos = []
    por_nome_removivel = ("Chao", "Terra", "Gelo", "Objetos")
    mantidos = {p["nome"]: p for p in m.props_mantidos}
    sprites_novos_emitidos = False

    def emitir_sprites_novos():
        out = []
        for s in m.sprites_novos:
            if s["tipo"] == "carvalho":
                out.append(bloco_sprite(s["nome"], s["x"], s["y"], "Atlas_carvalho", CARVALHO["offset"]))
            elif s["tipo"] == "abeto":
                out.append(bloco_sprite(s["nome"], s["x"], s["y"], ABETO["tex"], ABETO["offset"]))
            elif s["tipo"] == "arbusto_g":
                out.append(bloco_sprite(s["nome"], s["x"], s["y"], "Atlas_arbusto_g", ARBUSTO_G["offset"]))
            else:
                out.append(bloco_sprite(s["nome"], s["x"], s["y"], "Atlas_arbusto_m", ARBUSTO_M["offset"]))
        return out

    ids_inicio_obstaculos = None
    for n in base.nos:
        c = n["caminho"]
        raiz_c = c.split("/")[0]
        if c == "Terrains":
            blocos_nos.append(n["bloco"])
            kept_nos.append(n["bloco"])
            # camadas novas logo apos a raiz
            blocos_nos.append(bloco_camada("Chao", m.chao, "TileSet_arena"))
            blocos_nos.append(bloco_camada("Terra", m.terra, "TileSet_arena"))
            blocos_nos.append(bloco_camada("Agua", m.agua, "TileSet_arena"))
            blocos_nos.append(bloco_camada("Brilho", m.brilho, "TileSet_brilho"))
            blocos_nos.append(bloco_camada("Penhasco", m.penhasco, "TileSet_arena"))
            blocos_nos.append(bloco_camada("Detalhes", m.detalhes, "TileSet_arena"))
            continue
        if raiz_c in por_nome_removivel:
            continue
        if raiz_c == "Objetos3D":
            if n["pai"] == "Objetos3D":
                if n["nome"] not in mantidos:
                    continue
                b = n["bloco"]
                if n["nome"] == "BonecoDeNeve":
                    b = b.replace('parent="Objetos3D"]', 'parent="Objetos3D" groups=["so_inverno"]]', 1)
                elif n["nome"].startswith("Arbusto"):
                    b = b.replace('parent="Objetos3D"]', 'parent="Objetos3D" groups=["nao_inverno"]]', 1)
                blocos_nos.append(b)
                kept_nos.append(b)
            else:
                blocos_nos.append(n["bloco"])
                kept_nos.append(n["bloco"])
            continue
        # fim do grupo Objetos3D: antes do proximo no que nao e filho dele, anexa os sprites novos
        if not sprites_novos_emitidos and raiz_c != "Objetos3D" and any(
                x["caminho"] == "Objetos3D" for x in base.nos[:base.nos.index(n)]):
            novos = emitir_sprites_novos()
            blocos_nos.extend(novos)
            kept_nos.extend(novos)
            sprites_novos_emitidos = True
        if raiz_c == "Obstaculos":
            if n["caminho"] == "Obstaculos":
                blocos_nos.append(n["bloco"])
                for i, poli in enumerate(m.obstaculos):
                    blocos_nos.append('[node name="Obstaculo%d" type="CollisionPolygon2D" parent="Obstaculos"]\npolygon = %s\n'
                                      % (i + 1, T.poligono(poli)))
            continue
        blocos_nos.append(n["bloco"])
        kept_nos.append(n["bloco"])
    # passagem para a fazenda (boca da caverna): so entre ondas, aviso F/Y (Codigos/Logicas/passagem.gd), e o
    # ponto onde o jogador reaparece ao voltar da fazenda
    blocos_nos.append('[node name="PassagemCaverna" type="Area2D" parent="."]\nposition = Vector2(%s, %s)\n'
                      'script = ExtResource("passagem_script")\ncena_destino = "res://cenas/fazenda.tscn"\n'
                      'ponto_chegada = "caverna"\ndeslocamento_aviso = Vector2(0, -38)\n' % (
                          T.fmt(PASSAGEM_CAVERNA[0]), T.fmt(PASSAGEM_CAVERNA[1])))
    blocos_nos.append('[node name="Forma" type="CollisionShape2D" parent="PassagemCaverna"]\nshape = SubResource("Forma_passagem")\n')
    blocos_nos.append('[node name="Chegada_caverna" type="Marker2D" parent="." groups=["chegada"]]\nposition = Vector2(%s, %s)\n' % (
        T.fmt(CHEGADA_CAVERNA[0]), T.fmt(CHEGADA_CAVERNA[1])))
    blocos_nos.append('[node name="Estacoes" type="Node" parent="."]\nscript = ExtResource("estacoes_script")\n'
                      'estacao_inicial = %d\n' % ESTACAO_INICIAL)

    # ---- recursos: o que os nos mantidos usam + os novos
    precisa = set()
    for b in kept_nos:
        precisa |= refs(b)
    pendente = list(precisa)
    while pendente:
        r = pendente.pop()
        if r in base.sub:
            for q in refs(base.sub[r]):
                if q not in precisa:
                    precisa.add(q)
                    pendente.append(q)
    ext_out = [b for i, b in base.ext.items() if i in precisa]
    ext_out.append('[ext_resource type="Texture2D" path="res://Tiles/Seasonal Forest/arena/%s.png" id="arena_folha"]'
                   % ESTACOES[ESTACAO_INICIAL])
    ext_out.append('[ext_resource type="Texture2D" path="res://Tiles/Seasonal Forest/seasonal water animations/%s" id="brilho_folha"]'
                   % BRILHO_ARQUIVOS[ESTACAO_INICIAL])
    ext_out.append('[ext_resource type="Script" path="res://Codigos/Design/estacoes.gd" id="estacoes_script"]')
    ext_out.append('[ext_resource type="Script" path="res://Codigos/Logicas/passagem.gd" id="passagem_script"]')

    sub_out = []
    for i, b in base.sub.items():
        if i not in precisa:
            continue
        if i.startswith("Atlas_n_"):
            b = adicionar_cabecalho(b, 'resource_name = "arvore"')
        elif i.startswith("Atlas_o_"):
            b = adicionar_cabecalho(b, 'resource_name = "arvore_var"')
        sub_out.append(b)

    # tileset unico com a folha sazonal + tiles de margem
    fonte = ['[sub_resource type="TileSetAtlasSource" id="TileSetAtlasSource_arena"]', 'texture = ExtResource("arena_folha")']
    for tx, ty in TILES_USADOS:
        fonte.append("%d:%d/0 = 0" % (tx, ty))
    for k in range(len(m.tiles_margem)):
        fonte.append("%d:%d/0 = 0" % (k % 16, 16 + k // 16))
    sub_out.append("\n".join(fonte) + "\n")
    sub_out.append('[sub_resource type="TileSet" id="TileSet_arena"]\nsources/0 = SubResource("TileSetAtlasSource_arena")\n')
    brilho = ['[sub_resource type="TileSetAtlasSource" id="TileSetAtlasSource_brilho"]', 'texture = ExtResource("brilho_folha")']
    for r in range(3):
        brilho.append("0:%d/animation_columns = 4" % r)
        for f in range(4):
            brilho.append("0:%d/animation_frame_%d/duration = 0.3" % (r, f))
        brilho.append("0:%d/0 = 0" % r)
    sub_out.append("\n".join(brilho) + "\n")
    sub_out.append('[sub_resource type="RectangleShape2D" id="Forma_passagem"]\nsize = Vector2(56, 24)\n')
    sub_out.append('[sub_resource type="TileSet" id="TileSet_brilho"]\nsources/0 = SubResource("TileSetAtlasSource_brilho")\n')
    for ident, cfg in (("Atlas_carvalho", CARVALHO), ("Atlas_arbusto_g", ARBUSTO_G), ("Atlas_arbusto_m", ARBUSTO_M)):
        r = cfg["regiao"]
        sub_out.append('[sub_resource type="AtlasTexture" id="%s"]\nresource_name = "amostra"\natlas = ExtResource("arena_folha")\n'
                       'region = Rect2(%d, %d, %d, %d)\n' % (ident, r[0], r[1], r[2], r[3]))

    passos = len(ext_out) + len(sub_out) + 1
    cab = '[gd_scene load_steps=%d format=3 uid="uid://dtphjwfloo87l"]\n' % passos
    partes = [cab] + [b.rstrip("\n") + "\n" for b in ext_out]
    partes.append("")
    partes += [b.rstrip("\n") + "\n" for b in sub_out]
    partes += [b.rstrip("\n") + "\n" for b in blocos_nos]
    return "\n".join(partes)


def _cruza(a, b, c, d):
    def o(p, q, r):
        return (q[0] - p[0]) * (r[1] - p[1]) - (q[1] - p[1]) * (r[0] - p[0])
    return o(a, b, c) * o(a, b, d) < 0 and o(c, d, a) * o(c, d, b) < 0


def auto_intersecao(poli):
    n = len(poli)
    for i in range(n):
        for j in range(i + 2, n):
            if i == 0 and j == n - 1:
                continue
            if _cruza(poli[i], poli[(i + 1) % n], poli[j], poli[(j + 1) % n]):
                return True
    return False


def validar(m):
    """Confere os poligonos de colisao (sem auto-intersecao) e os spawns: fora de qualquer obstaculo e com folga."""
    problemas = []
    for i, poli in enumerate(m.obstaculos):
        if len(poli) < 3:
            problemas.append("Obstaculo%d com menos de 3 pontos" % (i + 1))
        elif auto_intersecao(poli):
            problemas.append("Obstaculo%d se auto-intersecta" % (i + 1))
    for sx, sy in SPAWNS:
        for i, poli in enumerate(m.obstaculos):
            if ponto_em_poligono((sx, sy), poli):
                problemas.append("spawn (%.0f,%.0f) dentro do Obstaculo%d" % (sx, sy, i + 1))
            else:
                d = dist_borda((sx, sy), poli)
                if d < 41.0:  # 28 px do sorteio de deslocamento (+-20 em x e y) + 14 px do raio do agente
                    problemas.append("spawn (%.0f,%.0f) a %.1f px do Obstaculo%d" % (sx, sy, d, i + 1))
    return problemas


def main():
    base = Base(BASE)
    m = construir(base)
    popular(m)
    for e in ESTACOES:
        caminho = gerar_folha_estacao(e, m.tiles_margem)
        print("folha:", os.path.relpath(caminho, RAIZ))
    texto = escrever_cena(m)
    open(SAIDA, "w", encoding="utf-8").write(texto)
    print("cena:", os.path.relpath(SAIDA, RAIZ), "(%d bytes)" % len(texto))
    print("camadas: chao=%d terra=%d agua=%d (margens=%d) penhasco=%d detalhes=%d | sprites novos=%d | obstaculos=%d"
          % (len(m.chao), len(m.terra), len(m.agua), len(m.tiles_margem), len(m.penhasco), len(m.detalhes),
             len(m.sprites_novos), len(m.obstaculos)))
    for p in validar(m):
        print("PROBLEMA:", p)


if __name__ == "__main__":
    main()
