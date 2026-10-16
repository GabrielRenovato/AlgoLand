#!/usr/bin/env python3
"""Tiles conectáveis do PixelLab: paleta comum por material e costura explícita dos perímetros Wang.

Preserva ids e os índices NO*8+NE*4+SO*2+SE. As bordas compatíveis recebem a mesma faixa de pixels;
assim nem diferenças de exposição entre gerações nem as estações produzem quadrados escuros.
"""
from pathlib import Path
from PIL import Image, ImageStat
import json

RAIZ = Path(__file__).resolve().parents[2]
FONTES = RAIZ / 'arte/fontes/cenario/terreno_witchbrook'
CALCAMENTO = RAIZ / 'arte/fontes/cenario/calcamento_bordado'
SAIDA = RAIZ / 'assets/cenario/cidade/terreno/witchbrook'
PARES = [('grama_terra', 'grama', 'terra'), ('grama_pedra', 'grama', 'pedra'),
         ('terra_pedra', 'terra', 'pedra'), ('grama_agua', 'grama', 'agua')]
PALETAS = {
    'primavera': {'grama': '#858d4e', 'terra': '#a07660', 'pedra': '#8395a3', 'agua': '#5e7066'},
    'verao': {'grama': '#748547', 'terra': '#aa8066', 'pedra': '#8395a3', 'agua': '#586e64'},
    'outono': {'grama': '#a1954b', 'terra': '#9e7055', 'pedra': '#8395a3', 'agua': '#626e60'},
    'inverno': {'grama': '#dce5df', 'terra': '#876d60', 'pedra': '#b2bec0', 'agua': '#96a7a0'},
}


def hex_rgb(cor):
    return tuple(int(cor[i:i + 2], 16) for i in [1, 3, 5])


def carregar():
    fontes = {}
    for nome, baixo, cima in PARES:
        folha = Image.open(FONTES / f'{nome}.png').convert('RGB')
        dados = json.loads((FONTES / f'{nome}.json').read_text())
        tiles = {}
        for t in dados['tileset_data']['tiles']:
            i = sum((t['corners'][n] == 'upper') << k for n, k in [('NW', 3), ('NE', 2), ('SW', 1), ('SE', 0)])
            r = t['bounding_box']
            tiles[i] = folha.crop((r['x'], r['y'], r['x'] + 16, r['y'] + 16))
        if set(tiles) != set(range(16)):
            raise ValueError(f'{nome}: faltam combinações de cantos')
        fontes[nome] = tiles
    return fontes


def tingir(tiles, baixo, cima, paleta):
    originais = [tiles[0], tiles[15]]
    cores = [set(t.get_flattened_data()) for t in originais]
    medias = [ImageStat.Stat(t).mean for t in originais]
    alvos = [hex_rgb(paleta[n]) for n in [baixo, cima]]
    cache = {}
    saida = {}
    for i, tile in tiles.items():
        nova = Image.new('RGB', (16, 16))
        pixels = []
        for cor in tile.get_flattened_data():
            chave = (cor, 0 if i == 0 else 1 if i == 15 else -1)
            if chave not in cache:
                if i in [0, 15]:
                    grupo = int(i == 15)
                else:
                    dist = [min(sum((a - b) ** 2 for a, b in zip(cor, candidata)) for candidata in p) for p in cores]
                    grupo = int(dist[1] < dist[0])
                contraste = 0.60 if [baixo, cima][grupo] in ['grama', 'terra'] else 0.82
                cache[chave] = tuple(max(0, min(255, round(alvos[grupo][k] + (cor[k] - medias[grupo][k]) * contraste))) for k in range(3))
            pixels.append(cache[chave])
        nova.putdata(pixels)
        saida[i] = nova
    return saida


def materiais_cantos(indice, baixo, cima):
    return tuple(cima if indice & (1 << k) else baixo for k in [3, 2, 1, 0])


def aplicar_calcamento(conjuntos, estacao):
    """Compõe pedras PixelLab e guia PixelLab em quadrantes Wang de 8 px.

    A guia é uma camada própria, não passa pela classificação de cores da
    grama e mantém sua espessura nos cantos, entradas e cruzamentos.
    """
    guia = Image.open(CALCAMENTO / 'guia.png').convert('RGBA')
    pedra = conjuntos['grama_pedra'][15]
    for nome, baixo in [('grama_pedra', 'grama'), ('terra_pedra', 'terra')]:
        base = conjuntos[nome][0]
        for i in range(16):
            tile = base.copy().convert('RGBA')
            for k, (x, y) in zip([3, 2, 1, 0], [(0, 0), (8, 0), (0, 8), (8, 8)]):
                if i & (1 << k):
                    tile.paste(pedra.crop((x, y, x + 8, y + 8)), (x, y))
            borda = guia.crop(((i % 4) * 16, (i // 4) * 16, (i % 4 + 1) * 16, (i // 4 + 1) * 16))
            if estacao == 'inverno':
                # Clareia a mesma guia com o terreno; geometria e contraste permanecem.
                borda.putdata([tuple(min(255, c + 22) for c in pixel[:3]) + (pixel[3],)
                               for pixel in borda.get_flattened_data()])
            tile.alpha_composite(borda)
            conjuntos[nome][i] = tile.convert('RGB')


def costurar(conjuntos, paleta):
    # Perfis compartilhados inclusive entre pares de terrenos diferentes.
    horizontais, verticais = {}, {}
    for nome, baixo, cima in PARES:
        for i, tile in conjuntos[nome].items():
            no, ne, so, se = materiais_cantos(i, baixo, cima)
            for chave, y in [((no, ne), 0), ((so, se), 15)]:
                if chave not in horizontais:
                    faixa = [tile.getpixel((x, y)) for x in range(16)]
                    faixa[0], faixa[-1] = hex_rgb(paleta[chave[0]]), hex_rgb(paleta[chave[1]])
                    horizontais[chave] = faixa
            for chave, x in [((no, so), 0), ((ne, se), 15)]:
                if chave not in verticais:
                    faixa = [tile.getpixel((x, y)) for y in range(16)]
                    faixa[0], faixa[-1] = hex_rgb(paleta[chave[0]]), hex_rgb(paleta[chave[1]])
                    verticais[chave] = faixa
    for nome, baixo, cima in PARES:
        for i, tile in conjuntos[nome].items():
            no, ne, so, se = materiais_cantos(i, baixo, cima)
            for x in range(16):
                tile.putpixel((x, 0), horizontais[(no, ne)][x])
                tile.putpixel((x, 15), horizontais[(so, se)][x])
            for y in range(16):
                tile.putpixel((0, y), verticais[(no, so)][y])
                tile.putpixel((15, y), verticais[(ne, se)][y])
    # O mesmo terreno puro é usado em todos os pares: evita mudar o chão ao se aproximar de outra superfície.
    canonicos = {'grama': conjuntos['grama_terra'][0], 'terra': conjuntos['grama_terra'][15],
                 'pedra': conjuntos['grama_pedra'][15], 'agua': conjuntos['grama_agua'][15]}
    for nome, baixo, cima in PARES:
        conjuntos[nome][0] = canonicos[baixo].copy()
        conjuntos[nome][15] = canonicos[cima].copy()


def validar(conjuntos):
    bordas = {'h': {}, 'v': {}}
    comparacoes = 0
    for nome, baixo, cima in PARES:
        for i, tile in conjuntos[nome].items():
            no, ne, so, se = materiais_cantos(i, baixo, cima)
            for eixo, chave, pontos in [
                ('h', (no, ne), [(x, 0) for x in range(16)]), ('h', (so, se), [(x, 15) for x in range(16)]),
                ('v', (no, so), [(0, y) for y in range(16)]), ('v', (ne, se), [(15, y) for y in range(16)])]:
                faixa = tuple(tile.getpixel(p) for p in pontos)
                anterior = bordas[eixo].setdefault(chave, faixa)
                if faixa != anterior:
                    raise ValueError(f'Emenda incompatível em {nome}, tile {i}, {eixo}, {chave}')
                comparacoes += 1
    return comparacoes


def exportar(conjuntos, pasta):
    pasta.mkdir(parents=True, exist_ok=True)
    for nome, baixo, cima in PARES:
        atlas = Image.new('RGBA', (64, 96))
        for i, tile in conjuntos[nome].items():
            atlas.paste(tile, ((i % 4) * 16, (i // 4) * 16))
        for v in range(4):
            atlas.paste(conjuntos[nome][0], (v * 16, 64))
            atlas.paste(conjuntos[nome][15], (v * 16, 80))
        atlas.save(pasta / f'{nome}.png')


def mascara_agua(fontes):
    tiles = fontes['grama_agua']
    paletas = [set(tiles[i].get_flattened_data()) for i in [0, 15]]
    atlas = Image.new('RGBA', (64, 96), (0, 0, 0, 255))
    for i, tile in tiles.items():
        pixels = []
        for cor in tile.get_flattened_data():
            d = [min(sum((a - b) ** 2 for a, b in zip(cor, candidata)) for candidata in p) for p in paletas]
            agua = i == 15 if i in [0, 15] else d[1] < d[0]
            valor = 255 if agua else 0
            pixels.append((valor, valor, valor, 255))
        mascara = Image.new('RGBA', (16, 16))
        mascara.putdata(pixels)
        atlas.paste(mascara, ((i % 4) * 16, (i // 4) * 16))
    for v in range(4):
        atlas.paste(Image.new('RGBA', (16, 16), (255, 255, 255, 255)), (v * 16, 80))
    atlas.save(SAIDA / 'mascara_agua.png')



def fundo_de_pedras():
    origem = Image.open(RAIZ / 'arte/fontes/cenario/terreno_referencia/agua_pixellab.png').convert('RGB')
    media = ImageStat.Stat(origem).mean
    for estacao, paleta in PALETAS.items():
        alvo = hex_rgb(paleta['agua'])
        imagem = Image.new('RGB', origem.size)
        imagem.putdata([tuple(max(0, min(255, round(alvo[k] + (c[k] - media[k]) * 1.05))) for k in range(3))
                        for c in origem.get_flattened_data()])
        # Costura de três pixels nas extremidades, preservando as pedras do interior e a escala original.
        for eixo in [0, 1]:
            copia = imagem.copy()
            limite = imagem.size[eixo]
            outro = imagem.size[1 - eixo]
            for t in range(outro):
                for d in range(3):
                    p = (d, t) if eixo == 0 else (t, d)
                    q = (limite - 1 - d, t) if eixo == 0 else (t, limite - 1 - d)
                    a, b = copia.getpixel(p), copia.getpixel(q)
                    peso = 0.5 if d == 0 else (3 - d) / 8
                    imagem.putpixel(p, tuple(round(a[k] * (1 - peso) + b[k] * peso) for k in range(3)))
                    imagem.putpixel(q, tuple(round(b[k] * (1 - peso) + a[k] * peso) for k in range(3)))
        assert all(imagem.getpixel((0, y)) == imagem.getpixel((63, y)) for y in range(64)), 'Emenda vertical na água'
        assert all(imagem.getpixel((x, 0)) == imagem.getpixel((x, 63)) for x in range(64)), 'Emenda horizontal na água'
        imagem.convert('RGBA').save(SAIDA / estacao / 'fundo_agua.png')


def main():
    fontes = carregar()
    comparacoes = 0
    for estacao, paleta in PALETAS.items():
        conjuntos = {nome: tingir(fontes[nome], baixo, cima, paleta) for nome, baixo, cima in PARES}
        aplicar_calcamento(conjuntos, estacao)
        costurar(conjuntos, paleta)
        comparacoes += validar(conjuntos)
        exportar(conjuntos, SAIDA / estacao)
    mascara_agua(fontes)
    fundo_de_pedras()
    print(f'{comparacoes} perímetros conferidos pixel a pixel; quatro estações exportadas.')


if __name__ == '__main__':
    main()
