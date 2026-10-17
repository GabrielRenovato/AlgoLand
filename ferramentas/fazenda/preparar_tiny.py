"""Recorta o pacote Tiny original para a comparação da fazenda (sem gerar desenhos).

Preserva células, posições e pivôs do mapa. Execute da raiz: python3 ferramentas/fazenda/preparar_tiny.py
"""
from pathlib import Path
import json
import shutil
import subprocess
import tempfile
from PIL import Image

RAIZ = Path(__file__).resolve().parents[2]
FONTE = RAIZ / 'arte/fontes/fazenda/tiny'
DESTINO = RAIZ / 'assets/cenario/fazenda/tiny'
PACOTE = 'Farm RPG - Tiny Asset Pack - (All in One)'
ESTACOES = [('primavera', 'Spring'), ('verao', 'Summer'), ('outono', 'Fall'), ('inverno', 'Winter')]


def recortar(imagem, x, y, w=16, h=16):
    return imagem.crop((x, y, x + w, y + h))


def tela(peca, tamanho, pos):
    imagem = Image.new('RGBA', tamanho)
    imagem.alpha_composite(peca, pos)
    return imagem


def material_sazonal(peca, indice):
    """Material exposto: seco no verão, úmido no outono, frio no inverno."""
    resultado = peca.copy()
    fatores = [(1, 1, 1), (1.04, 1.02, .98), (.91, .91, .96), (.91, .97, 1.07)][indice]
    for y in range(resultado.height):
        for x in range(resultado.width):
            r, g, b, a = resultado.getpixel((x, y))
            if a:
                resultado.putpixel((x, y), tuple(min(255, round(c * f)) for c, f in zip((r, g, b), fatores)) + (a,))
    return resultado


def preparar():
    usados = ['Tileset/ALL props seasons.png', 'Tileset/Tilled Soil and wet soil.png',
              'Tileset/Water tile.png', 'Objects/Tree/Common/No Shadow/Pine Tree.png',
              'Objects/Tree/Common/No Shadow/Maple Tree.png',
              'Objects/Exterior/Houses/3.png', 'Objects/Exterior/Houses/1.png',
              'Objects/Exterior/Fence and Bridge/Fence Wood.png']
    usados += ['Tileset/Tileset Grass %s.png' % e for _, e in ESTACOES]
    usados += ['Tileset/Tileset Grass Cliff Tileset %s.png' % e for _, e in ESTACOES]
    with tempfile.TemporaryDirectory(prefix='algoland-tiny-') as tmp:
        subprocess.run(['unrar', 'x', '-o+', '-idq', str(RAIZ / 'arte/pacotes/_zips_originais' / (PACOTE + '.rar')),
                        *[PACOTE + '/' + p for p in usados], tmp + '/'], check=True)
        for p in usados:
            destino = FONTE / 'originais' / p
            destino.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(Path(tmp) / PACOTE / p, destino)

    def abrir(p):
        return Image.open(FONTE / 'originais' / p).convert('RGBA')

    props = abrir('Tileset/ALL props seasons.png')
    pine = abrir('Objects/Tree/Common/No Shadow/Pine Tree.png')
    maple = abrir('Objects/Tree/Common/No Shadow/Maple Tree.png')
    cerca = abrir('Objects/Exterior/Fence and Bridge/Fence Wood.png')
    arado = abrir('Tileset/Tilled Soil and wet soil.png')
    # Coordenadas antigas -> recortes Tiny. Centros e cantos internos separados.
    terra = {(1, 0): (8, 8), (2, 0): (10, 8), (3, 0): (11, 8),
             (1, 1): (8, 9), (3, 1): (11, 10),
             (1, 2): (8, 11), (2, 2): (9, 11), (3, 2): (11, 11),
             (1, 3): (6, 10), (2, 3): (5, 10), (1, 4): (6, 9), (2, 4): (5, 9)}
    for p in [(2, 1), (4, 0), (4, 1), (4, 2), (4, 3), (4, 4)]:
        terra[p] = (9, 10)

    for i, (estacao, ingles) in enumerate(ESTACOES):
        pasta = DESTINO / estacao
        pasta.mkdir(parents=True, exist_ok=True)
        grama = abrir('Tileset/Tileset Grass %s.png' % ingles)
        cliff = abrir('Tileset/Tileset Grass Cliff Tileset %s.png' % ingles)
        chao = recortar(grama, 9 * 16, 2 * 16)
        atlas = Image.new('RGBA', (256, 256))
        for y in range(1, 6):
            atlas.paste(chao, (0, y * 16))
        linha_props = [0, 1, 2, 3][i]
        for y in (6, 7):
            for x in range(4):
                flor = chao.copy()
                flor.alpha_composite(recortar(props, (x + (0 if y == 6 else 4)) * 16, linha_props * 16))
                atlas.paste(flor, (x * 16, y * 16))
        for antigo, novo in terra.items():
            atlas.paste(recortar(grama, novo[0] * 16, novo[1] * 16), (antigo[0] * 16, antigo[1] * 16))
        # Platô norte: mantém as oito linhas do mapa, com face Tiny estendida por tiles inteiros.
        for x in range(5, 11):
            for y in range(8):
                tile = chao.copy()
                if y == 4:
                    tile = recortar(cliff, 5 * 16, 3 * 16)
                elif y in (5, 6):
                    tile = recortar(cliff, (12 + (x % 2)) * 16, 3 * 16)
                elif y == 7:
                    tile = recortar(cliff, 5 * 16, 5 * 16)
                    # O rodapé do penhasco é fornecido sobre água: troca só os pixels azuis por grama.
                    for py in range(16):
                        for px in range(16):
                            r, g, b, a = tile.getpixel((px, py))
                            if a == 0 or (b > r * 1.25 and b > g * 1.05):
                                tile.putpixel((px, py), chao.getpixel((px, py)))
                atlas.paste(tile, (x * 16, y * 16))
        for y in (8, 9):
            atlas.paste(recortar(props, (0 if y == 8 else 2) * 16, linha_props * 16), (0, y * 16))
        # Pedras são props transparentes, com a base na mesma célula da pedreira.
        for n in range(4):
            pedra = recortar(props, (6 + n) * 16, 5 * 16)
            if i == 3:
                neve = recortar(props, (8 + n) * 16, 3 * 16)
                pedra = neve if n < 2 else pedra
            pedra = material_sazonal(pedra, i)
            atlas.paste(pedra, (4 * 16, (6 + n) * 16))
            pedra.save(pasta / ('pedra_%d.png' % n))
        atlas.save(pasta / 'terreno.png')
        # Pixels nativos, sem reduzir nem ampliar as árvores do pacote.
        arvore = recortar(maple, [0, 32, 64, 96][i], 48, 32, 48)
        pinheiro = recortar(pine, 128 if i == 3 else 96, 0, 32, 48)
        if i == 0:  # brotos mais claros; verão conserva o verde profundo original.
            pinheiro = pinheiro.copy()
            for py in range(48):
                for px in range(32):
                    r, g, b, a = pinheiro.getpixel((px, py))
                    if g > r * 1.5 and a:
                        pinheiro.putpixel((px, py), (min(r + 9, 255), min(g + 12, 255), b, a))
        elif i == 2:
            pinheiro = pinheiro.copy()
            for py in range(48):
                for px in range(32):
                    r, g, b, a = pinheiro.getpixel((px, py))
                    if g > r * 1.5 and a:
                        pinheiro.putpixel((px, py), (min(r + 10, 255), max(g - 9, 0), b, a))
        tela(pinheiro, (48, 86), (8, 38)).save(pasta / 'abeto.png')
        tela(arvore, (80, 112), (24, 64)).save(pasta / 'carvalho.png')
        # Arbustos e arvoretas usam as peças vegetais originais de cada estação.
        arbusto = recortar(props, 0, linha_props * 16, 16, 16)
        tela(arbusto, (16, 32), (0, 16)).save(pasta / 'arbusto_m.png')
        recortar(maple, [64, 96, 128, 160][i], 16, 32, 32).save(pasta / 'arvoreta.png')
        grande = Image.new('RGBA', (32, 32))
        grande.alpha_composite(arbusto, (0, 16))
        grande.alpha_composite(recortar(props, 16, linha_props * 16), (16, 16))
        grande.save(pasta / 'arbusto_g.png')
        # Toco alinhado ao tronco do carvalho (x=24 em DESENHO_TOCO).
        tela(material_sazonal(recortar(maple, 64 if i == 3 else 0, 120, 32, 24), i), (48, 26), (8, 1)).save(pasta / 'toco.png')
        for n in range(9):
            recortar(props, (4 + n % 4) * 16, linha_props * 16).save(pasta / ('mato_%d.png' % n))
        # A cerca mantém os espaçamentos existentes (16 horizontal / 24 vertical).
        cy = 80 if i == 3 else 0
        horizontal = recortar(cerca, 4, cy + 32, 16, 16)
        poste = recortar(cerca, 4, cy, 8, 16)
        vertical = Image.new('RGBA', (8, 48))
        for yy in (0, 16, 32):
            vertical.alpha_composite(recortar(cerca, 4, cy + 16, 8, 16), (0, yy))
        vertical.alpha_composite(poste, (0, 0))
        vertical.alpha_composite(poste, (0, 24))
        # Materiais expostos: leve mudança de madeira só fora do inverno, sem tingir a cena inteira.
        if i in (1, 2):
            for im in (horizontal, poste, vertical):
                for py in range(im.height):
                    for px in range(im.width):
                        r, g, b, a = im.getpixel((px, py))
                        if a:
                            im.putpixel((px, py), (max(0, min(255, r + (5 if i == 1 else -4))), max(0, g - (0 if i == 1 else 4)), b, a))
        tela(horizontal, (16, 24), (0, 8)).save(pasta / 'horizontal.png')
        tela(poste, (8, 24), (0, 8)).save(pasta / 'poste.png')
        vertical.save(pasta / 'vertical.png')
        casa = abrir('Objects/Exterior/Houses/3.png')
        if i == 3:
            # O telhado nevado tem a mesma projeção, mas a fachada do exemplo 1 troca a porta.
            # Preserva a fachada normal abaixo do beiral para não deslocar a entrada no inverno.
            inverno = abrir('Objects/Exterior/Houses/1.png')
            casa.paste(inverno.crop((0, 0, 128, 80)), (0, 0))
        if i in (1, 2):
            # Tratamento da madeira/telha exposta, mantendo máscara e geometria.
            for py in range(casa.height):
                for px in range(casa.width):
                    r, g, b, a = casa.getpixel((px, py))
                    if a and r > g * 1.25:
                        casa.putpixel((px, py), (max(0, min(255, r + (4 if i == 1 else -5))), max(0, g - (0 if i == 1 else 3)), b, a))
        casa.save(pasta / 'casa.png')
        agua = Image.new('RGBA', (48, 16))
        for x in range(3):
            # Tile de água independente do pacote (as folhas de grama não contêm água).
            tile = abrir('Tileset/Water tile.png')
            if i == 3:
                tile = Image.blend(tile, Image.new('RGBA', (16, 16), '#bccafa'), .65)
            elif i == 2:
                tile = Image.blend(tile, Image.new('RGBA', (16, 16), '#a2a0cc'), .12)
            elif i == 1:
                tile = Image.blend(tile, Image.new('RGBA', (16, 16), '#379cd2'), .08)
            agua.paste(tile, (x * 16, 0))
        agua.save(pasta / 'agua.png')
        for molhado in (False, True):
            # Metade direita = solo molhado; metade inferior = solo de inverno.
            recortar(arado, 336 if molhado else 144, 96 if i == 3 else 32).save(pasta / ('arado_molhado.png' if molhado else 'arado_seco.png'))

    manifesto = {'pacote': PACOTE, 'grade': 16, 'escala': 1,
                 'uso': 'Comparação reversível no F3, mesma planta e dados da fazenda.',
                 'originais': usados, 'estacoes': [e for e, _ in ESTACOES],
                 'pivos': 'Posições existentes; árvores em telas compatíveis, casa com porta em (44, 100).',
                 'integracao': 'codigo/cenario/fazenda_tiny.gd',
                 'adaptacoes': 'Atlas compatível; face norte estendida; cerca recomposta; tons sazonais dos materiais e água.'}
    (FONTE / 'manifesto.json').write_text(json.dumps(manifesto, ensure_ascii=False, indent=2) + '\n')
    print('Tiny: quatro estações preparadas em', DESTINO)


if __name__ == '__main__':
    preparar()
