#!/usr/bin/env python3
"""Substitui só a grama dos atlas Wang pelos pixels originais do Mana Seed.

Mantém 16 combinações, quatro variações puras, ids, guia, pedra, terra e água.
As máscaras repetem a classificação e a costura do gerador original.
"""
from pathlib import Path
from PIL import Image
import preparar_terreno_witchbrook as origem

RAIZ = Path(__file__).resolve().parents[2]
DESTINO = RAIZ / 'assets/cenario/cidade/terreno/mana_seed'
ESTACOES = dict(zip(origem.PALETAS, ['spring', 'summer', 'autumn', 'winter']))
PARES = ['grama_terra', 'grama_pedra', 'grama_agua']


def mascaras():
    fontes = origem.carregar()
    conjuntos = {}
    for nome, baixo, cima in origem.PARES:
        cores = [set(fontes[nome][i].get_flattened_data()) for i in [0, 15]]
        tiles = {}
        for indice, tile in fontes[nome].items():
            pixels = []
            for cor in tile.get_flattened_data():
                if indice in [0, 15]:
                    grupo = int(indice == 15)
                else:
                    distancias = [min(sum((a-b)**2 for a,b in zip(cor, candidata)) for candidata in paleta) for paleta in cores]
                    grupo = int(distancias[1] < distancias[0])
                pixels.append((0, 0, 0) if [baixo, cima][grupo] == 'grama' else (255, 255, 255))
            mascara = Image.new('RGB', (16, 16))
            mascara.putdata(pixels)
            tiles[indice] = mascara
        conjuntos[nome] = tiles
    # A guia e o calçamento foram compostos por quadrantes, acima da grama.
    guia = Image.open(origem.CALCAMENTO / 'guia.png').convert('RGBA')
    for indice in range(16):
        mascara = Image.new('RGB', (16, 16))
        for y in range(16):
            for x in range(16):
                bit = (3 if y < 8 else 1) - (0 if x < 8 else 1)
                na_guia = guia.getpixel((indice % 4 * 16 + x, indice // 4 * 16 + y))[3] > 0
                if indice & (1 << bit) or na_guia:
                    mascara.putpixel((x, y), (255, 255, 255))
        conjuntos['grama_pedra'][indice] = mascara
    origem.costurar(conjuntos, {'grama': '#000000', 'terra': '#ffffff', 'pedra': '#ffffff', 'agua': '#ffffff'})
    return conjuntos


def main():
    recortes = mascaras()
    conferidos = 0
    for estacao, nome in ESTACOES.items():
        folha = Image.open(RAIZ / f'assets/cenario/Seasonal Forest/seasonal sample ({nome}).png').convert('RGBA')
        grama = folha.crop((0, 16, 16, 32))
        pasta = DESTINO / estacao
        pasta.mkdir(parents=True, exist_ok=True)
        for par in PARES:
            original = Image.open(origem.SAIDA / estacao / f'{par}.png').convert('RGBA')
            nova = original.copy()
            for linha in range(6):
                for coluna in range(4):
                    indice = linha * 4 + coluna if linha < 4 else (0 if linha == 4 else 15)
                    mascara = recortes[par][indice]
                    for y in range(16):
                        for x in range(16):
                            px, py = coluna * 16 + x, linha * 16 + y
                            if mascara.getpixel((x, y))[0] == 0:
                                nova.putpixel((px, py), grama.getpixel((x, y)))
                            else:
                                assert nova.getpixel((px, py)) == original.getpixel((px, py))
            assert nova.crop((0, 64, 16, 80)).tobytes() == grama.tobytes()
            assert nova.getextrema()[3] == (255, 255)
            nova.save(pasta / f'{par}.png')
            conferidos += 1
    print(f'{conferidos} atlas gerados; grama original e materiais preservados nas quatro estações.')


if __name__ == '__main__':
    main()
