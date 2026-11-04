#!/usr/bin/env python3
"""Mini-ARPG de masmorra em ASCII, no estilo Diablo: catacumbas, escuridão com luz de tocha, monstros, baús,
poções, escadas e um dragão como chefe. Só biblioteca padrão (curses).

  python3 ferramentas/ascii/diablo_ascii.py            # jogar (terminal com pelo menos 100x34)
  python3 ferramentas/ascii/diablo_ascii.py --demo 120 # piloto automático: imprime quadros de texto e sai

Teclas: setas/WASD/hjkl andam e atacam (ande contra o monstro) | p poção | . esperar | q sair
Legenda: @ herói  ▓ parede  · chão  ≈ água  Ω pilar  ¶ tocha  ▣ baú  ⇩ escada  $ ouro  ! poção
         z zumbi  s esqueleto  g goblin  D dragão (chefe)"""
import argparse
import locale
import random
import sys
from collections import deque

LARG, ALT = 80, 32
RAIO_LUZ = 9
NIVEIS = 3
GLIFO = {"#": "▓", ".": "·", "~": "≈", "O": "Ω", "T": "¶", "B": "▣", ">": "⇩"}
MEMORIA = {"#": "▒"}
MONSTROS = {  # nome: (glifo, hp, dano_min, dano_max, xp)
    "Zumbi": ("z", 12, 2, 4, 6),
    "Esqueleto": ("s", 9, 3, 5, 7),
    "Goblin": ("g", 7, 2, 6, 5),
    "Dragão": ("D", 70, 5, 11, 80)}


class Jogo:
    def __init__(self, semente=None):
        self.rng = random.Random(semente)
        self.nivel = 1
        self.heroi = 1
        self.xp = 0
        self.hp_max = 34
        self.hp = self.hp_max
        self.ouro = 0
        self.pocoes = 2
        self.msgs = ["Você desce às catacumbas. Algo respira no escuro."]
        self.fim = None
        self.passos = 0
        self.gerar()

    # ---------- geração ----------
    def gerar(self):
        r = self.rng
        self.mapa = [["#"] * LARG for _ in range(ALT)]
        salas = []
        for _ in range(200):
            w, h = r.randint(6, 14), r.randint(4, 8)
            x, y = r.randint(1, LARG - w - 2), r.randint(1, ALT - h - 2)
            if any(x < s[0] + s[2] + 2 and s[0] < x + w + 2 and y < s[1] + s[3] + 2 and s[1] < y + h + 2 for s in salas):
                continue
            salas.append((x, y, w, h))
            for yy in range(y, y + h):
                for xx in range(x, x + w):
                    self.mapa[yy][xx] = "."
            if len(salas) >= 11:
                break
        centros = [(x + w // 2, y + h // 2) for x, y, w, h in salas]
        for (x1, y1), (x2, y2) in zip(centros, centros[1:]):
            for x in range(min(x1, x2), max(x1, x2) + 1):
                self.mapa[y1][x] = "."
            for y in range(min(y1, y2), max(y1, y2) + 1):
                self.mapa[y][x2] = "."
        for i, (x, y, w, h) in enumerate(salas):
            if 0 < i < len(salas) - 1:
                if w >= 9 and h >= 6:
                    for px, py in ((x + 2, y + 1), (x + w - 3, y + 1), (x + 2, y + h - 2), (x + w - 3, y + h - 2)):
                        self.mapa[py][px] = "O"
                elif r.random() < 0.35:
                    ax, ay = x + r.randint(1, w - 3), y + r.randint(1, h - 3)
                    for dx in (0, 1):
                        for dy in (0, 1):
                            self.mapa[ay + dy][ax + dx] = "~"
                if r.random() < 0.5:
                    cx, cy = x + r.randint(1, w - 2), y + r.randint(1, h - 2)
                    if self.mapa[cy][cx] == ".":
                        self.mapa[cy][cx] = "B"
            for _ in range(2):
                tx = x + r.randint(0, w - 1)
                if self.mapa[y - 1][tx] == "#":
                    self.mapa[y - 1][tx] = "T"
        self.px, self.py = centros[0]
        self.mapa[centros[-1][1]][centros[-1][0]] = ">"
        self.escada = centros[-1]
        self.salas = salas
        self.chao = {}
        self.monstros = []
        for i, (x, y, w, h) in enumerate(salas[1:], 1):
            for _ in range(r.randint(0, 2) + (1 if self.nivel > 1 else 0)):
                self.criar(r.choice(["Zumbi", "Esqueleto", "Goblin"]), x + r.randint(0, w - 1), y + r.randint(0, h - 1))
        if self.nivel == NIVEIS:
            self.criar("Dragão", self.escada[0] - 2, self.escada[1])
        self.visto = [[False] * LARG for _ in range(ALT)]
        self.atualizar_visao()

    def criar(self, nome, x, y):
        g, hp, dmin, dmax, xp = MONSTROS[nome]
        if self.livre(x, y) and (x, y) != (self.px, self.py):
            esc = 1 + 0.25 * (self.nivel - 1) if nome != "Dragão" else 1
            self.monstros.append({"nome": nome, "g": g, "x": x, "y": y, "hp": int(hp * esc), "dmin": dmin, "dmax": dmax, "xp": xp})

    # ---------- mapa e visão ----------
    def passavel(self, x, y):
        return 0 <= x < LARG and 0 <= y < ALT and self.mapa[y][x] in ".>"

    def livre(self, x, y):
        return self.passavel(x, y) and not self.monstro_em(x, y)

    def monstro_em(self, x, y):
        return next((m for m in self.monstros if m["x"] == x and m["y"] == y), None)

    def linha_livre(self, x0, y0, x1, y1):
        """Linha de visão (Bresenham): paredes, pilares e tochas bloqueiam."""
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
        erro = dx + dy
        x, y = x0, y0
        while (x, y) != (x1, y1):
            e2 = 2 * erro
            if e2 >= dy: erro += dy; x += sx
            if e2 <= dx: erro += dx; y += sy
            if (x, y) != (x1, y1) and self.mapa[y][x] in "#OT":
                return False
        return True

    def atualizar_visao(self):
        self.visivel = set()
        for y in range(max(0, self.py - RAIO_LUZ), min(ALT, self.py + RAIO_LUZ + 1)):
            for x in range(max(0, self.px - RAIO_LUZ), min(LARG, self.px + RAIO_LUZ + 1)):
                if (x - self.px) ** 2 + (y - self.py) ** 2 <= RAIO_LUZ ** 2 and self.linha_livre(self.px, self.py, x, y):
                    self.visivel.add((x, y))
                    self.visto[y][x] = True

    # ---------- ações do herói ----------
    def msg(self, texto):
        self.msgs.append(texto)
        self.msgs = self.msgs[-5:]

    def dano_heroi(self):
        return self.rng.randint(3, 7) + self.heroi

    def agir(self, dx, dy):
        """Move ou ataca. Devolve True se gastou o turno."""
        if self.fim:
            return False
        nx, ny = self.px + dx, self.py + dy
        m = self.monstro_em(nx, ny)
        if m:
            d = self.dano_heroi() + (self.rng.randint(2, 5) if self.rng.random() < 0.12 else 0)
            m["hp"] -= d
            self.msg(f"Você acerta {m['nome']} ({d})")
            if m["hp"] <= 0:
                self.matar(m)
        elif self.passavel(nx, ny):
            self.px, self.py = nx, ny
            if (nx, ny) in self.chao:
                item = self.chao.pop((nx, ny))
                if item == "$":
                    q = self.rng.randint(4, 14) * self.nivel
                    self.ouro += q
                    self.msg(f"Você pega {q} de ouro")
                else:
                    self.pocoes += 1
                    self.msg("Você pega uma poção")
            if self.mapa[ny][nx] == ">":
                if self.nivel == NIVEIS:
                    self.fim = "vitoria"
                    self.msg("A escada final brilha. Você escapou das catacumbas!")
                else:
                    self.nivel += 1
                    self.msg(f"Você desce para o nível {self.nivel}.")
                    self.gerar()
                    return True
        elif self.mapa[ny][nx] == "B":
            self.mapa[ny][nx] = "."
            if self.rng.random() < 0.5:
                self.chao[(nx, ny)] = "!"
                self.msg("O baú range: uma poção rola para fora")
            else:
                self.chao[(nx, ny)] = "$"
                self.msg("O baú range: moedas brilham")
        else:
            return False
        self.passos += 1
        self.turno_monstros()
        self.atualizar_visao()
        return True

    def matar(self, m):
        self.monstros.remove(m)
        self.xp += m["xp"]
        self.msg(f"{m['nome']} cai!")
        r = self.rng.random()
        if m["nome"] == "Dragão":
            self.chao[(m["x"], m["y"])] = "$"
        elif r < 0.35:
            self.chao[(m["x"], m["y"])] = "$"
        elif r < 0.5:
            self.chao[(m["x"], m["y"])] = "!"
        while self.xp >= 20 * self.heroi:
            self.xp -= 20 * self.heroi
            self.heroi += 1
            self.hp_max += 8
            self.hp = self.hp_max
            self.msg(f"Você sobe para o nível {self.heroi}! Vida restaurada.")

    def pocao(self):
        if self.pocoes > 0 and self.hp < self.hp_max and not self.fim:
            self.pocoes -= 1
            self.hp = min(self.hp_max, self.hp + 18)
            self.msg("Você bebe uma poção (+18)")
            self.turno_monstros()
            return True
        return False

    # ---------- monstros ----------
    def turno_monstros(self):
        for m in list(self.monstros):
            dx, dy = self.px - m["x"], self.py - m["y"]
            d = max(abs(dx), abs(dy))
            if d <= 1:
                if self.rng.random() < 0.7:
                    dano = self.rng.randint(m["dmin"], m["dmax"])
                    self.hp -= dano
                    self.msg(f"{m['nome']} te fere ({dano})")
                    if self.hp <= 0:
                        self.hp = 0
                        self.fim = "morte"
                        self.msg("Você tomba nas catacumbas...")
                        return
                else:
                    self.msg(f"{m['nome']} erra o golpe")
            elif d <= 8 and self.linha_livre(m["x"], m["y"], self.px, self.py):
                sx, sy = (dx > 0) - (dx < 0), (dy > 0) - (dy < 0)
                for passo in ((sx, sy), (sx, 0), (0, sy)):
                    nx, ny = m["x"] + passo[0], m["y"] + passo[1]
                    if passo != (0, 0) and self.livre(nx, ny) and (nx, ny) != (self.px, self.py):
                        m["x"], m["y"] = nx, ny
                        break
            elif self.rng.random() < 0.2:
                px, py = self.rng.choice([(1, 0), (-1, 0), (0, 1), (0, -1)])
                if self.livre(m["x"] + px, m["y"] + py) and (m["x"] + px, m["y"] + py) != (self.px, self.py):
                    m["x"] += px
                    m["y"] += py

    # ---------- desenho ----------
    def celula(self, x, y):
        """(glifo, estilo) de um ponto do mapa, ou None se nunca visto."""
        if not self.visto[y][x]:
            return None
        vis = (x, y) in self.visivel
        if (x, y) == (self.px, self.py):
            return "@", "heroi"
        if vis:
            m = self.monstro_em(x, y)
            if m:
                return m["g"], "chefe" if m["nome"] == "Dragão" else "monstro"
            if (x, y) in self.chao:
                return self.chao[(x, y)], "ouro" if self.chao[(x, y)] == "$" else "pocao"
        t = self.mapa[y][x]
        perto = vis and (x - self.px) ** 2 + (y - self.py) ** 2 <= 16
        base = {"#": "parede", ".": "chao", "~": "agua", "O": "pilar", "T": "tocha", "B": "bau", ">": "escada"}[t]
        if not vis:
            return MEMORIA.get(t, GLIFO[t]), "memoria"
        return GLIFO[t], base + ("_perto" if perto and base in ("parede", "chao") else "")

    def painel(self):
        barra = int(12 * self.hp / self.hp_max)
        return [
            f" CATACUMBAS  nível {self.nivel}/{NIVEIS}",
            "",
            f" Herói   Lv {self.heroi}",
            f" Vida    {self.hp}/{self.hp_max}",
            " [" + "█" * barra + "░" * (12 - barra) + "]",
            f" XP      {self.xp}/{20 * self.heroi}",
            f" Ouro    {self.ouro}",
            f" Poções  {self.pocoes}  (p)",
            "",
            " @ herói   z s g monstros",
            " D dragão  ▣ baú  ⇩ escada",
            " $ ouro    ! poção"]


def quadro_texto(jogo, larg=64, alt=20):
    """Janela de texto centrada no herói (sem cor), usada no modo demo."""
    x0 = min(max(0, jogo.px - larg // 2), LARG - larg)
    y0 = min(max(0, jogo.py - alt // 2), ALT - alt)
    linhas = []
    for y in range(y0, y0 + alt):
        linhas.append("".join((jogo.celula(x, y) or (" ", ""))[0] for x in range(x0, x0 + larg)))
    return linhas


# ---------- piloto automático (demo e testes) ----------
def proximo_passo(jogo, alvo):
    ini = (jogo.px, jogo.py)
    fila, veio = deque([ini]), {ini: None}
    while fila:
        atual = fila.popleft()
        if atual == alvo:
            break
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)):
            n = (atual[0] + dx, atual[1] + dy)
            if n not in veio and jogo.passavel(*n) and (not jogo.monstro_em(*n) or n == alvo):
                veio[n] = atual
                fila.append(n)
    if alvo not in veio:
        return None
    n = alvo
    while veio[n] != ini and veio[n] is not None:
        n = veio[n]
    return (n[0] - ini[0], n[1] - ini[1])


def piloto(jogo):
    if jogo.hp < jogo.hp_max * 0.35 and jogo.pocoes > 0:
        return jogo.pocao()
    perto = [m for m in jogo.monstros if (m["x"], m["y"]) in jogo.visivel]
    if perto:
        m = min(perto, key=lambda m: max(abs(m["x"] - jogo.px), abs(m["y"] - jogo.py)))
        passo = proximo_passo(jogo, (m["x"], m["y"]))
    elif jogo.chao:
        alvo = min(jogo.chao, key=lambda p: abs(p[0] - jogo.px) + abs(p[1] - jogo.py))
        passo = proximo_passo(jogo, alvo)
    else:
        passo = proximo_passo(jogo, jogo.escada)
    return jogo.agir(*passo) if passo else False


def demonstracao(n):
    jogo = Jogo(7)
    mostrar = {0, n // 4, n // 2, (3 * n) // 4, n - 1}
    for i in range(n):
        if i in mostrar:
            print(f"\n=== passo {jogo.passos} | nível {jogo.nivel} | vida {jogo.hp}/{jogo.hp_max} | Lv {jogo.heroi} | ouro {jogo.ouro} ===")
            print("\n".join(l.rstrip() for l in quadro_texto(jogo)))
            print(" | ".join(jogo.msgs[-2:]))
        if jogo.fim or not piloto(jogo):
            if jogo.fim:
                break
    print(f"\nFim da demonstração: {jogo.fim or 'em andamento'}; nível {jogo.nivel}, herói Lv {jogo.heroi}, ouro {jogo.ouro}, {jogo.passos} passos")


# ---------- terminal (curses) ----------
def principal(tela):
    import curses
    curses.curs_set(0)
    curses.start_color()
    curses.use_default_colors()
    cores = {"heroi": (226, 1), "parede": (240, 0), "parede_perto": (95, 0), "chao": (237, 0), "chao_perto": (94, 0),
             "agua": (33, 0), "pilar": (250, 0), "tocha": (208, 1), "bau": (172, 1), "escada": (51, 1), "monstro": (196, 0),
             "chefe": (160, 1), "ouro": (220, 1), "pocao": (201, 1), "memoria": (236, 0)}
    atributos = {}
    ok256 = curses.COLORS >= 256
    for i, (nome, (cor, forte)) in enumerate(cores.items(), 1):
        curses.init_pair(i, cor if ok256 else curses.COLOR_WHITE, -1)
        atributos[nome] = curses.color_pair(i) | (curses.A_BOLD if forte else 0)
    jogo = Jogo()
    while True:
        altura, largura = tela.getmaxyx()
        vl, va = max(20, largura - 28), max(10, altura - 8)
        x0 = min(max(0, jogo.px - vl // 2), max(0, LARG - vl))
        y0 = min(max(0, jogo.py - va // 2), max(0, ALT - va))
        tela.erase()
        for y in range(va):
            for x in range(vl):
                mx, my = x0 + x, y0 + y
                if mx < LARG and my < ALT:
                    c = jogo.celula(mx, my)
                    if c:
                        try:
                            tela.addstr(y, x, c[0], atributos[c[1]])
                        except curses.error:
                            pass
        for i, linha in enumerate(jogo.painel()):
            try:
                tela.addstr(i + 1, vl + 2, linha[:24])
            except curses.error:
                pass
        for i, m in enumerate(jogo.msgs[-4:]):
            try:
                tela.addstr(va + 1 + i, 1, m[:largura - 2])
            except curses.error:
                pass
        if jogo.fim:
            texto = " VITÓRIA! " if jogo.fim == "vitoria" else " VOCÊ MORREU "
            tela.addstr(va // 2, max(0, vl // 2 - len(texto) // 2), texto, curses.A_REVERSE | curses.A_BOLD)
        tela.refresh()
        tecla = tela.getch()
        mov = {curses.KEY_UP: (0, -1), curses.KEY_DOWN: (0, 1), curses.KEY_LEFT: (-1, 0), curses.KEY_RIGHT: (1, 0),
               ord("w"): (0, -1), ord("s"): (0, 1), ord("a"): (-1, 0), ord("d"): (1, 0),
               ord("k"): (0, -1), ord("j"): (0, 1), ord("h"): (-1, 0), ord("l"): (1, 0),
               ord("y"): (-1, -1), ord("u"): (1, -1), ord("b"): (-1, 1), ord("n"): (1, 1)}
        if tecla in (ord("q"), 27):
            break
        if tecla in mov:
            jogo.agir(*mov[tecla])
        elif tecla == ord("p"):
            jogo.pocao()
        elif tecla == ord("."):
            jogo.turno_monstros(); jogo.atualizar_visao()
        if jogo.fim:
            tela.getch() if tecla in (ord("q"), 27) else None


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--demo", type=int, metavar="PASSOS", help="piloto automático: imprime alguns quadros e sai")
    a = p.parse_args()
    if a.demo:
        demonstracao(a.demo)
        return
    locale.setlocale(locale.LC_ALL, "")
    import curses
    curses.wrapper(principal)


if __name__ == "__main__":
    main()
