#!/usr/bin/env python3
"""Gera os quadros do dragão animado em ASCII (arte/ascii/dragao_anim/quadro_N.txt), um .txt por quadro.
Cada quadro é desenhado com formas e depois escrito como texto: asa batendo, cauda balançando, corpo subindo e
descendo, olho piscando e fogo tremendo. Os .txt podem ser editados à mão e reconvertidos."""
import math
import random
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
SAIDA = RAIZ / "arte/ascii/dragao_anim"
QUADROS = 8
W, H = 84, 48
PALETA = ["# K=1e1216", "# R=c23b2a", "# H=ea6c50", "# r=8c2420", "# O=f0b060", "# o=c58038", "# Y=f4dc8a",
          "# W=f7f1e5", "# M=9c3550", "# F=ffe27a", "# f=ff9a2a", "# g=e5481c"]


class Tela:
    def __init__(self):
        self.g = [["."] * W for _ in range(H)]
        self.dy = 0

    def put(self, x, y, c):
        x, y = int(round(x)), int(round(y + self.dy))
        if 0 <= x < W and 0 <= y < H:
            self.g[y][x] = c

    def poly(self, pts, c, so_sobre=None):
        ys = [p[1] for p in pts]
        for y in range(int(min(ys)), int(max(ys)) + 1):
            xs = []
            for i in range(len(pts)):
                (x0, y0), (x1, y1) = pts[i], pts[(i + 1) % len(pts)]
                if (y0 <= y < y1) or (y1 <= y < y0):
                    xs.append(x0 + (y - y0) * (x1 - x0) / (y1 - y0))
            xs.sort()
            for k in range(0, len(xs) - 1, 2):
                for x in range(int(math.ceil(xs[k])), int(xs[k + 1]) + 1):
                    if so_sobre is None or self.ler(x, y) in so_sobre:
                        self.put(x, y, c)

    def ler(self, x, y):
        y = int(round(y + self.dy))
        return self.g[y][x] if 0 <= x < W and 0 <= y < H else "."

    def elipse(self, cx, cy, rx, ry, c, so_sobre=None, ymin=-99):
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1 and y >= ymin:
                    if so_sobre is None or self.ler(x, y) in so_sobre:
                        self.put(x, y, c)

    def linha(self, x0, y0, x1, y1, c, e0=1, e1=1):
        n = int(max(abs(x1 - x0), abs(y1 - y0))) * 2 + 1
        for i in range(n + 1):
            t = i / n
            x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            e = e0 + (e1 - e0) * t
            for oy in range(-int(e / 2), int(e / 2) + 1):
                for ox in range(-int(e / 2), int(e / 2) + 1):
                    self.put(x + ox, y + oy, c)


def lerp(a, b, t):
    return a + (b - a) * t


def quadro(k):
    fase = k / QUADROS
    t = Tela()
    batida = (1 + math.cos(2 * math.pi * fase)) / 2          # 1 = asa para cima, 0 = para baixo
    t.dy = 6 + round(1.2 * math.sin(2 * math.pi * fase + math.pi))  # corpo sobe quando a asa desce
    # asa (atrás do corpo): interpola entre as poses alta e baixa
    alta = [(21, 17), (9, 6), (14, 11), (17, 3), (22, 10), (30, 5), (27, 17)]
    baixa = [(21, 17), (8, 18), (13, 16), (17, 14), (22, 16), (31, 15), (27, 17)]
    asa = [(lerp(b[0], a[0], batida), lerp(b[1], a[1], batida)) for a, b in zip(alta, baixa)]
    t.poly(asa, "M")
    for ponta in (asa[1], asa[3], asa[5]):
        t.linha(22, 16, ponta[0], ponta[1], "r")
    # cauda: balança em onda
    base = [(14, 25), (8, 28), (4, 26), (3, 21), (5, 17)]
    cauda = [(x + 2.2 * math.sin(2 * math.pi * fase + i * 0.9) * (i / 4), y + 1.4 * math.cos(2 * math.pi * fase + i * 0.9) * (i / 4)) for i, (x, y) in enumerate(base)]
    for i in range(len(cauda) - 1):
        t.linha(*cauda[i], *cauda[i + 1], "R", 7 - i * 2, 6 - i * 2 if i < 3 else 1)
    px, py = cauda[-1]
    t.poly([(px, py - 3), (px + 2, py), (px, py + 3), (px - 2, py)], "R")
    # pernas, corpo e pescoço
    t.poly([(14, 29), (19, 29), (20, 36), (12, 36), (13, 32)], "R")
    t.poly([(27, 29), (32, 29), (33, 36), (26, 36)], "R")
    for x in (12, 14, 16, 18, 26, 28, 30, 32):
        t.put(x, 37, "Y")
    t.elipse(23, 24, 13, 8, "R")
    t.poly([(29, 20), (34, 11), (41, 11), (38, 18), (33, 27), (28, 27)], "R")
    t.elipse(25, 28, 10, 5, "O", so_sobre="R", ymin=27)
    t.linha(36, 17, 31, 26, "O", 2, 2)
    for y in range(27, 32):
        for x in range(14, 34):
            if t.ler(x, y) == "O" and (x + y) % 5 == 0:
                t.put(x, y, "o")
    # cabeça
    t.elipse(41, 10, 6, 5, "R")
    t.poly([(43, 7), (51, 9), (51, 12), (44, 14)], "R")
    boca_aberta = k in (2, 3, 4, 5)
    t.poly([(41, 13), (50, 13 + (2 if boca_aberta else 0)), (49, 15 + (2 if boca_aberta else 0)), (42, 16)], "R")
    t.linha(45, 12, 51, 12 + (1 if boca_aberta else 0), "K")
    for x in (46, 48, 50):
        t.put(x, 13 + (1 if boca_aberta else 0), "W")
    t.put(50, 9, "K")
    if k == 6:   # piscada
        t.put(40, 8, "K"); t.put(41, 8, "K"); t.put(42, 8, "K")
    else:
        for xy in ((40, 7), (41, 7), (40, 8)):
            t.put(*xy, "W")
        t.put(41, 8, "K")
    # chifres e espinhos
    t.linha(38, 6, 34, 2, "Y", 2, 1)
    t.linha(41, 5, 39, 1, "Y", 2, 1)
    for x in range(13, 34, 4):
        topo = min((y for y in range(H) if t.g[y][x] in "RM"), default=None)
        if topo is not None:
            t.g[topo - 1][x] = "Y"; t.g[topo - 2][x] = "Y"
    # realce e sombra
    g = t.g
    for y in range(H):
        for x in range(W):
            if g[y][x] == "R":
                acima = g[y - 1][x] if y > 0 else "."
                abaixo = g[y + 1][x] if y < H - 1 else "."
                if acima in ".M":
                    g[y][x] = "H"
                elif abaixo in ".O":
                    g[y][x] = "r"
    # contorno
    saida = [row[:] for row in g]
    for y in range(H):
        for x in range(W):
            if g[y][x] == ".":
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < W and 0 <= ny < H and g[ny][nx] != ".":
                        saida[y][x] = "K"
                        break
    # fogo (sem contorno): só quando a boca está aberta, tremendo de quadro a quadro
    if boca_aberta:
        rng = random.Random(100 + k)
        cx, cy = 53, 12 + t.dy + 1
        comprimento = 18 + rng.randint(-2, 4)
        for i in range(comprimento):
            u = i / comprimento
            x = cx + i
            y = cy + rng.uniform(-1.2, 1.2) * u * 3 + math.sin(i * 0.7 + k) * u * 2
            raio = 1.2 + 4.2 * math.sin(math.pi * min(1, u * 1.1)) * (1 - u * 0.4)
            for yy in range(int(y - raio) - 1, int(y + raio) + 2):
                for xx in range(int(x - 1), int(x + 2)):
                    d = abs(yy - y) / max(raio, 0.1)
                    if d <= 1 and 0 <= xx < W and 0 <= yy < H:
                        saida[yy][xx] = "F" if d < 0.35 else ("f" if d < 0.72 else "g")
    return ["".join(r) for r in saida]


def main():
    todos = [quadro(k) for k in range(QUADROS)]
    # recorte único para todos os quadros (a animação não "anda" na tela)
    ocupadas = [i for q in todos for i, l in enumerate(q) if set(l) != {"."}]
    cols = [i for q in todos for l in q for i, c in enumerate(l) if c != "."]
    y0, y1, x0, x1 = min(ocupadas), max(ocupadas), min(cols), max(cols)
    SAIDA.mkdir(parents=True, exist_ok=True)
    for k, q in enumerate(todos):
        corpo = [l[x0:x1 + 1] for l in q[y0:y1 + 1]]
        (SAIDA / f"quadro_{k}.txt").write_text("\n".join(PALETA + corpo) + "\n")
    print(f"{QUADROS} quadros de {x1 - x0 + 1}x{y1 - y0 + 1} px em {SAIDA.relative_to(RAIZ)}")


if __name__ == "__main__":
    main()
