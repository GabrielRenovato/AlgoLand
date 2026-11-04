#!/usr/bin/env python3
"""Converte um sprite escrito em ASCII (um caractere por pixel) em PNG.

Formato do .txt: linhas '# X=rrggbb' definem a paleta; '.' é transparente; as demais linhas são o desenho.
  python3 ferramentas/ascii/ascii_para_png.py arte/ascii/dragao.txt saida.png [--escala 8]
"""
import argparse
import re
import sys
import struct
import zlib
from pathlib import Path


def ler(caminho: Path):
    paleta, linhas = {}, []
    for bruta in caminho.read_text().splitlines():
        m = re.fullmatch(r"#\s*(\S)\s*=\s*([0-9a-fA-F]{6})\s*", bruta)
        if m:
            paleta[m.group(1)] = tuple(int(m.group(2)[i:i + 2], 16) for i in (0, 2, 4))
        elif bruta.strip() and not bruta.startswith("#"):
            linhas.append(bruta.rstrip("\n"))
    return paleta, linhas


def gravar_png(caminho: Path, largura: int, altura: int, pixels: list):
    """PNG RGBA 8 bits, sem dependências. `pixels` é uma lista de linhas, cada uma com tuplas (r, g, b, a)."""
    bruto = b"".join(b"\x00" + b"".join(bytes(px) for px in linha) for linha in pixels)

    def bloco(tipo: bytes, dados: bytes) -> bytes:
        corpo = tipo + dados
        return struct.pack(">I", len(dados)) + corpo + struct.pack(">I", zlib.crc32(corpo) & 0xFFFFFFFF)

    cabecalho = struct.pack(">IIBBBBB", largura, altura, 8, 6, 0, 0, 0)
    caminho.write_bytes(b"\x89PNG\r\n\x1a\n" + bloco(b"IHDR", cabecalho) + bloco(b"IDAT", zlib.compress(bruto, 9)) + bloco(b"IEND", b""))


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("entrada", type=Path)
    p.add_argument("saida", type=Path)
    p.add_argument("--escala", type=int, default=1, help="ampliação inteira, sem suavizar")
    a = p.parse_args()
    paleta, linhas = ler(a.entrada)
    largura = max(len(l) for l in linhas)
    for y, linha in enumerate(linhas):
        for x, c in enumerate(linha):
            if c != "." and c not in paleta:
                sys.exit(f"caractere '{c}' sem cor na paleta (linha {y + 1}, coluna {x + 1})")
    vazio = (0, 0, 0, 0)
    grade = [[(*paleta[c], 255) if c != "." else vazio for c in linha.ljust(largura, ".")] for linha in linhas]
    e = max(1, a.escala)
    pixels = []
    for linha in grade:
        ampliada = [px for px in linha for _ in range(e)]
        pixels.extend([ampliada] * e)
    gravar_png(a.saida, largura * e, len(linhas) * e, pixels)
    print(f"{a.saida}: {largura}x{len(linhas)} px (x{e})")


if __name__ == "__main__":
    main()
