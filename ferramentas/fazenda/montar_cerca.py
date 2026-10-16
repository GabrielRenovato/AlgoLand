#!/usr/bin/env python3
"""Pecas da cerca da fazenda montadas da cerca no padrao Mana Seed (arte/fontes/cenario/decoracao_mana/cerca.png, gerada
no PixelLab com o pack de referencia): 4 postes de 8 px e duas travessas. Nada e desenhado novo, so recombinado:
  horizontal.png (16 x 23): um poste e as travessas ate o proximo; repetida lado a lado forma a cerca de leste a oeste
  poste.png      (8 x 23) : o poste sozinho, para fechar a ponta de uma cerca horizontal
  vertical.png   (8 x 47) : o poste com a travessa vista de lado (uma tabua fina que desce do poste de cima ate ele),
                            para a cerca de norte a sul; uma a cada ESPACO_VERTICAL px, a base na ultima linha
Cada peca sai nas quatro estacoes (codigo/cenario/cerca_sazonal.gd troca): primavera e verao com a madeira como esta;
outono com folhas secas caidas no pe; inverno com neve em cima de postes e tabuas e a madeira um pouco apagada.
Saida: assets/cenario/fazenda/cerca/<estacao>/. Uso: python3 ferramentas/fazenda/montar_cerca.py (e depois o --import do Godot)"""
import os
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(AQUI, "..", "arena"))
import png_puro as P  # noqa: E402

RAIZ = os.path.abspath(os.path.join(AQUI, "..", ".."))
FONTE = os.path.join(RAIZ, "arte/fontes/cenario/decoracao_mana/cerca.png")
SAIDA = os.path.join(RAIZ, "assets/cenario/fazenda/cerca")
TOPO, BASE = 11, 33            # linhas da cerca na fonte
POSTE = (6, 13)                # colunas do primeiro poste
TRAVESSA = (14, 21)            # colunas de travessa entre o primeiro e o segundo poste
LINHA_TRAVESSA = 18            # linha do meio da travessa de cima (as cores da tabua vista de lado)
ESPACO_VERTICAL = 24           # distancia entre os postes da cerca de norte a sul (com 16 eles se encostavam)


def recorte(img, x0, x1, y0, y1):
    dados = bytearray()
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            dados += bytes(img.pixel(x, y))
    return P.Imagem(x1 - x0 + 1, y1 - y0 + 1, dados)


def colar(destino, origem, dx, dy):
    for y in range(origem.h):
        for x in range(origem.w):
            px = origem.pixel(x, y)
            if px[3] > 0 and 0 <= dx + x < destino.w and 0 <= dy + y < destino.h:
                i = ((dy + y) * destino.w + dx + x) * 4
                destino.dados[i:i + 4] = bytes(px)


NEVE = (236, 240, 248, 255)
NEVE_SOMBRA = (196, 206, 226, 255)
FOLHAS = [(200, 112, 48, 255), (168, 72, 40, 255), (224, 160, 64, 255)]


def copia(img):
    return P.Imagem(img.w, img.h, bytearray(img.dados))


def inverno(img):
    """Neve sobre toda superficie de cima (pixel opaco com vazio acima) e madeira mais apagada"""
    nova = copia(img)
    for y in range(img.h):
        for x in range(img.w):
            r, g, b, a = img.pixel(x, y)
            if a == 0:
                continue
            i = (y * img.w + x) * 4
            cinza = (r + g + b) // 3
            nova.dados[i:i + 3] = bytes(((r * 3 + cinza) // 4, (g * 3 + cinza) // 4, (b * 3 + cinza) // 4))
            if y == 0 or img.alfa(x, y - 1) == 0:
                nova.dados[i:i + 4] = bytes(NEVE_SOMBRA)
                if y > 0:
                    j = ((y - 1) * img.w + x) * 4
                    nova.dados[j:j + 4] = bytes(NEVE)
    return nova


def outono(img, semente):
    """Algumas folhas secas nas ultimas linhas, perto da base dos postes"""
    nova = copia(img)
    for x in range(img.w):
        if (x * 7 + semente) % 5 < 2:
            y = img.h - 1 - ((x + semente) % 2)
            i = (y * img.w + x) * 4
            nova.dados[i:i + 4] = bytes(FOLHAS[(x + semente) % len(FOLHAS)])
    return nova


def salvar_estacoes(img, nome):
    variantes = {"primavera": img, "verao": img, "outono": outono(img, len(nome)), "inverno": inverno(img)}
    for estacao, versao in variantes.items():
        pasta = os.path.join(SAIDA, estacao)
        os.makedirs(pasta, exist_ok=True)
        P.salvar(versao, os.path.join(pasta, nome + ".png"))


def main():
    os.makedirs(SAIDA, exist_ok=True)
    fonte = P.carregar(FONTE)
    altura = BASE - TOPO + 1
    poste = recorte(fonte, POSTE[0], POSTE[1], TOPO, BASE)
    salvar_estacoes(poste, "poste")
    horizontal = P.Imagem(16, altura, bytearray(16 * altura * 4))
    colar(horizontal, poste, 0, 0)
    colar(horizontal, recorte(fonte, TRAVESSA[0], TRAVESSA[1], TOPO, BASE), 8, 0)
    salvar_estacoes(horizontal, "horizontal")
    # Vertical: a tabua vista de lado tem 4 px (as cores da travessa de cima, da luz para a sombra) e desce do meio do
    # poste de cima (ESPACO_VERTICAL px acima) ate o meio deste
    total = altura + ESPACO_VERTICAL
    vertical = P.Imagem(8, total, bytearray(8 * total * 4))
    cores = [fonte.pixel(TRAVESSA[0] + 2, LINHA_TRAVESSA + k) for k in (-1, 0, 1, 2)]
    for y in range(8, ESPACO_VERTICAL + 12):
        for k, cor in enumerate(cores):
            i = (y * 8 + 2 + k) * 4
            vertical.dados[i:i + 4] = bytes(cor)
    colar(vertical, poste, 0, ESPACO_VERTICAL)
    salvar_estacoes(vertical, "vertical")
    print("cerca em", os.path.relpath(SAIDA, RAIZ))


if __name__ == "__main__":
    main()
