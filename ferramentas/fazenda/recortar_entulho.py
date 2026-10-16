#!/usr/bin/env python3
"""Desenhos do entulho da horta (pedra, mato, arbusto, arvoreta) com fundo transparente, um por estacao.
As pecas da folha sazonal (Seasonal Forest) vem com o chao desenhado junto (grama ou neve): em cima da terra da horta elas
viravam quadrados. O contorno sai do verao, onde o chao e grama bem distinta: toda cor que aparece nos tiles de grama lisa
vira transparente. As outras estacoes usam esse mesmo molde com as proprias cores (no inverno a neve da pedra tem a cor do
chao nevado, e recortar pela paleta dela apagaria a pedra).
Saida: assets/cenario/fazenda/entulho/<estacao>/<peca>.png (estacao: primavera, verao, outono, inverno).
Uso: python3 ferramentas/fazenda/recortar_entulho.py  (e depois o --import do Godot)"""
import os
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(AQUI, "..", "arena"))
import gerar_arena as G  # noqa: E402
import png_puro as P  # noqa: E402

SAIDA = os.path.join(G.RAIZ, "assets/cenario/fazenda/entulho")
NOMES = {"spring": "primavera", "summer": "verao", "autumn": "outono", "winter": "inverno"}
# peca: (x, y, largura, altura) em pixels da folha
PECAS = {"pedra_%d" % i: (t[0] * 16, t[1] * 16, 16, 16) for i, t in enumerate(G.ROCHAS)}
PECAS.update({"mato_%d" % i: (t[0] * 16, t[1] * 16, 16, 16) for i, t in enumerate(G.PLANTAS)})
PECAS["arbusto"] = G.ARBUSTO_M["regiao"]
PECAS["arvoreta"] = G.ARBUSTO_G["regiao"]


def paleta_do_chao(folha):
    cores = set()
    for tx, ty in G.GRAMA:
        for y in range(16):
            for x in range(16):
                cores.add(folha.pix(tx, ty, x, y)[:3])
    return cores


def molde(regiao, chao):
    """Pixels da peca (sem o chao) no verao"""
    x0, y0, w, h = regiao
    return {(x, y) for y in range(h) for x in range(w)
            if G.VERAO.img.pixel(x0 + x, y0 + y)[3] > 0 and G.VERAO.img.pixel(x0 + x, y0 + y)[:3] not in chao}


def recortar(folha, regiao, pixels):
    x0, y0, w, h = regiao
    dados = bytearray()
    for y in range(h):
        for x in range(w):
            r, g, b, a = folha.img.pixel(x0 + x, y0 + y)
            dados += bytes((r, g, b, a if (x, y) in pixels else 0))
    return P.Imagem(w, h, dados)


def main():
    chao = paleta_do_chao(G.VERAO)
    moldes = {nome: molde(regiao, chao) for nome, regiao in PECAS.items()}
    for estacao, folha in G.FOLHAS.items():
        pasta = os.path.join(SAIDA, NOMES[estacao])
        os.makedirs(pasta, exist_ok=True)
        for nome, regiao in PECAS.items():
            P.salvar(recortar(folha, regiao, moldes[nome]), os.path.join(pasta, nome + ".png"))
    print("entulho recortado em", os.path.relpath(SAIDA, G.RAIZ), "-", len(PECAS), "pecas x 4 estacoes")


if __name__ == "__main__":
    main()
