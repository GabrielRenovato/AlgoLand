#!/usr/bin/env python3
"""Icones 16x16 dos drops da machadinha e da picareta (ainda nao usados no jogo): assets/ui/fazenda/drops.png, lado a lado
(coluna 0 = madeira, coluna 1 = pedra), e cada um solto em assets/ui/fazenda/drop_<nome>.png.
  madeira: tora deitada desenhada pixel a pixel, com a paleta do toco (desenhar_toco.py): casca, madeira clara e aneis
  pedra  : pedra arredondada desenhada pixel a pixel, nos cinzas das pedras da folha sazonal
Uso: python3 ferramentas/fazenda/desenhar_drops.py  (e depois o --import do Godot)"""
import os
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(AQUI, "..", "arena"))
import png_puro as P  # noqa: E402

RAIZ = os.path.abspath(os.path.join(AQUI, "..", ".."))
SAIDA = os.path.join(RAIZ, "assets/ui/fazenda")
LADO = 16
# Paleta (a mesma do toco) e o desenho da tora: cada letra e um pixel ("." = vazio)
CORES = {"C": (60, 38, 24), "c": (92, 60, 34), "b": (128, 86, 48), "B": (160, 112, 62),
         "a": (176, 140, 72), "m": (226, 196, 128), "M": (240, 214, 150),
         "K": (52, 50, 62), "k": (92, 90, 104), "g": (132, 130, 140), "G": (170, 168, 172), "W": (208, 204, 200)}
TORA = [
    "................",
    "................",
    "................",
    "................",
    ".........CCC....",
    "..CCCCCCCcaaC...",
    ".CBBBBBBcammaC..",
    ".CbBBbBBcamMac..",
    ".CbbbbbbcamMac..",
    ".CcbcbbccammaC..",
    "..CCCCCCCcaaC...",
    ".........CCC....",
    "................",
    "................",
    "................",
    "................",
]
PEDRA = [
    "................",
    "................",
    "................",
    "......KKKK......",
    "....KKGWWGKK....",
    "...KGWWWGGgK....",
    "..KgGWGGGggkK...",
    "..KgGGGgggkkK...",
    "..KggGgggkkkK...",
    "..KkgggggkkkK...",
    "...KkkggkkkK....",
    "....KKkkkKK.....",
    "......KKKK......",
    "................",
    "................",
    "................",
]


def desenho(linhas):
    dados = bytearray()
    for linha in linhas:
        for ch in linha:
            dados += bytes(CORES[ch] + (255,)) if ch in CORES else bytes(4)
    return P.Imagem(LADO, LADO, dados)


def main():
    madeira = desenho(TORA)
    pedra = desenho(PEDRA)
    folha = bytearray()
    for y in range(LADO):
        for img in (madeira, pedra):
            folha += img.dados[y * LADO * 4:(y + 1) * LADO * 4]
    P.salvar(P.Imagem(LADO * 2, LADO, folha), os.path.join(SAIDA, "drops.png"))
    P.salvar(madeira, os.path.join(SAIDA, "drop_madeira.png"))
    P.salvar(pedra, os.path.join(SAIDA, "drop_pedra.png"))
    print("drops em", os.path.relpath(SAIDA, RAIZ))


if __name__ == "__main__":
    main()
