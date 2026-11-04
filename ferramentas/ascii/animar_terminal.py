#!/usr/bin/env python3
"""Toca no terminal uma animação ASCII (quadro_N.txt) como arte de texto colorida (ANSI). Ctrl+C sai.

  python3 ferramentas/ascii/animar_terminal.py arte/ascii/dragao_anim [--atraso 110] [--uma-vez]
Cada pixel vira um caractere de sombra (% * & : ^ ~ o), com o contorno em # _ \" ; duas linhas de pixel por linha de texto."""
import argparse
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from ascii_para_png import ler  # noqa: E402

SOMBRA = {"R": "%", "H": "*", "r": "&", "O": ":", "o": ";", "Y": "^", "W": "o", "M": "~", "F": "@", "f": "x", "g": "*"}


def quadro_ansi(caminho: Path) -> str:
    paleta, linhas = ler(caminho)
    largura = max(len(l) for l in linhas)
    linhas = [l.ljust(largura, ".") for l in linhas]
    if len(linhas) % 2:
        linhas.append("." * largura)
    saida = []
    for y in range(0, len(linhas), 2):
        texto = ""
        for x in range(largura):
            a, b = linhas[y][x], linhas[y + 1][x]
            if a == "." and b == ".":
                texto += " "
                continue
            if a == "K" and b == "K": ch, cor = "#", "K"
            elif a == "." and b == "K": ch, cor = "_", "K"
            elif a == "K" and b == ".": ch, cor = '"', "K"
            else:
                cor = b if a in ".K" else a
                ch = SOMBRA.get(cor, "#")
                if a == "K": cor = b
                if b == "K": cor = a
            r, g, bl = paleta[cor]
            texto += f"\x1b[38;2;{r};{g};{bl}m{ch}"
        saida.append(texto + "\x1b[0m")
    return "\n".join(saida)


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("pasta", type=Path)
    p.add_argument("--atraso", type=int, default=110)
    p.add_argument("--uma-vez", action="store_true", help="toca um ciclo e sai")
    a = p.parse_args()
    arquivos = sorted(a.pasta.glob("quadro_*.txt"), key=lambda f: int(f.stem.split("_")[1]))
    quadros = [quadro_ansi(f) for f in arquivos]
    sys.stdout.write("\x1b[2J\x1b[?25l")
    try:
        while True:
            for q in quadros:
                sys.stdout.write("\x1b[H" + q + "\n")
                sys.stdout.flush()
                time.sleep(a.atraso / 1000)
            if a.uma_vez:
                break
    except KeyboardInterrupt:
        pass
    finally:
        sys.stdout.write("\x1b[0m\x1b[?25h\n")


if __name__ == "__main__":
    main()
