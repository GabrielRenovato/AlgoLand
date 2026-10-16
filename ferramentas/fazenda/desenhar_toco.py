#!/usr/bin/env python3
"""Toco do carvalho cortado, um por estacao: as raizes e o pe do tronco do proprio carvalho da folha sazonal
(Seasonal Forest/arena, a mesma que o jogo usa), so os pixels de madeira (sem a grama nem a sombra da copa), cortados na
altura CORTE, com o topo do corte desenhado por cima: anel de casca, madeira clara e aneis. O contorno sai do verao (a
madeira ligada ao tronco; no outono e na primavera folhas e flores no chao tambem parecem madeira) e vale para as outras
estacoes, cada uma com as proprias cores.
Saida: assets/cenario/fazenda/toco/<estacao>.png (52 x 26; a base do carvalho e a ultima linha, com o tronco no x 24)
Uso: python3 ferramentas/fazenda/desenhar_toco.py  (e depois o --import do Godot)"""
import math
import os
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(AQUI, "..", "arena"))
import gerar_arena as G  # noqa: E402
import png_puro as P  # noqa: E402

SAIDA = os.path.join(G.RAIZ, "assets/cenario/fazenda/toco")
NOMES = {"spring": "primavera", "summer": "verao", "autumn": "outono", "winter": "inverno"}
X0, Y0, LARG, ALT = 192, 86, 52, 26      # recorte na folha (a base do carvalho e a linha 111)
CORTE = 92                               # linha da folha onde o tronco foi cortado
TRONCO = (208, 223)                      # colunas do tronco na altura do corte
CASCA = (92, 60, 34, 255)
MADEIRA = (226, 196, 128, 255)
MADEIRA_CLARA = (240, 214, 150, 255)
ANEL = (176, 140, 72, 255)


def molde():
    """Pixels de madeira do verao ligados ao tronco (preenchimento a partir do meio do tronco)"""
    verao = P.carregar(os.path.join(G.PASTA_FOLHAS, "summer.png"))
    madeira = {(x, y) for y in range(ALT) for x in range(LARG)
               if Y0 + y >= CORTE and G._classe_madeira(verao.pixel(X0 + x, Y0 + y))}
    inicio = ((TRONCO[0] + TRONCO[1]) // 2 - X0, CORTE - Y0 + 2)
    ligados, pilha = {inicio}, [inicio]
    while pilha:
        x, y = pilha.pop()
        for v in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if v in madeira and v not in ligados:
                ligados.add(v)
                pilha.append(v)
    return ligados


def toco(folha, pixels):
    dados = bytearray(LARG * ALT * 4)

    def pinta(x, y, cor):
        if 0 <= x < LARG and 0 <= y < ALT:
            i = (y * LARG + x) * 4
            dados[i:i + 4] = bytes(cor)

    for y in range(ALT):
        for x in range(LARG):
            if (x, y) in pixels:
                pinta(x, y, folha.pixel(X0 + x, Y0 + y))
    # topo do corte: elipse da largura do tronco
    cx = (TRONCO[0] + TRONCO[1] + 1) / 2 - X0
    cy = CORTE - Y0
    rx, ry = (TRONCO[1] - TRONCO[0] + 1) / 2, 3.0
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            d = ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2
            if d > 1.0:
                continue
            if d > 0.62:
                pinta(x, y, CASCA)
            else:
                anel = ((x + 0.5 - cx) / (rx * 0.55)) ** 2 + ((y + 0.5 - cy) / (ry * 0.55)) ** 2
                cor = MADEIRA_CLARA if y + 0.5 < cy else MADEIRA
                if 0.55 < anel < 1.05 or anel < 0.12:
                    cor = ANEL
                pinta(x, y, cor)
    return P.Imagem(LARG, ALT, dados)


def main():
    os.makedirs(SAIDA, exist_ok=True)
    pixels = molde()
    for estacao, nome in NOMES.items():
        folha = P.carregar(os.path.join(G.PASTA_FOLHAS, estacao + ".png"))
        P.salvar(toco(folha, pixels), os.path.join(SAIDA, nome + ".png"))
    print("tocos em", os.path.relpath(SAIDA, G.RAIZ))


if __name__ == "__main__":
    main()
