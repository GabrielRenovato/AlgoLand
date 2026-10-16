#!/usr/bin/env python3
"""Compõe sprites nativos e quadros locais; preserva as imagens originais.

Nada é redimensionado durante o jogo. Madeira e bases permanecem imóveis entre
quadros; só folhas, chamas, bolhas e a galinha mudam. Rode antes dos layouts.
"""
from pathlib import Path
from PIL import Image, ImageDraw
import json

RAIZ = Path(__file__).resolve().parents[2]
SAIDA = RAIZ / 'assets/cenario/cidade/ambientes'
ESTACOES = ['primavera', 'verao', 'outono', 'inverno']
MANIFESTO = {}
MADEIRA = ['#51382d', '#805238', '#b3804b', '#d2a664']
FOLHAS = ['#334535', '#526645', '#829453', '#b1b96b']
MOVEIS_TOPDOWN = RAIZ / 'assets/cenario/cidade/decoracao/mobiliario/topdown'
INTERIORES_TOPDOWN = {
    ('sede', 'mesa_reuniao'): 'mesa_grande',
    ('sede', 'cadeira'): 'cadeira',
    ('pousada', 'mesa'): 'mesa_media',
    ('pousada', 'cama'): 'cama',
    ('casa_bento', 'mesa'): 'mesa_media',
    ('casa_bento', 'cama'): 'cama',
    ('enfermaria', 'mesa'): 'mesa_pequena',
    ('mistica', 'poltrona'): 'cadeira',
}


def carregar(p):
    im = Image.open(p).convert('RGBA')
    im = im.crop(im.getbbox())
    return im


def neve(im):
    """Neve apenas em superfícies expostas, nunca tingindo madeira inteira."""
    nova = im.copy()
    for x in range(1, im.width - 1):
        ys = [y for y in range(im.height) if im.getpixel((x, y))[3] > 200]
        if not ys:
            continue
        y = ys[0]
        for dy in range(2 if x % 7 < 5 else 1):
            if y + dy < im.height:
                nova.putpixel((x, y + dy), (220, 231, 226, 255) if dy == 0 else (163, 186, 188, 255))
    return nova


def folhagem(im, quadro, copa=False):
    nova = im.copy()
    dx = [0, 1, 0, -1][quadro]
    if dx == 0:
        return nova
    # Nunca deslocar uma faixa retangular: ela também contém aro, poste e
    # madeira do vaso. Selecionar pigmentos vegetais acima da base estrutural.
    limite = int(im.height * (.78 if copa else .48))
    vegetacao = set()
    for y in range(limite):
        for x in range(im.width):
            r, g, b, a = im.getpixel((x, y))
            verde = g > r * 1.04 and g > b * 1.12
            petala = r > g * 1.25 and b > g * 1.12
            clara = min(r, g, b) > 180 and max(r, g, b) - min(r, g, b) < 40
            if a and (verde or petala or clara):
                vegetacao.add((x, y))
    mover = []
    for x, y in vegetacao:
        if x == 0 or x == im.width - 1:
            continue
        destino = (x + dx, y)
        # Pixels na extremidade ficam parados. Nada é descartado fora do
        # canvas e nenhuma folha é desenhada por cima de madeira ou vaso.
        if 0 < destino[0] < im.width - 1 and (destino in vegetacao or im.getpixel(destino)[3] == 0):
            mover.append(((x, y), destino))
    for origem, destino in mover:
        nova.putpixel(origem, (0, 0, 0, 0))
    for origem, destino in mover:
        nova.putpixel(destino, im.getpixel(origem))
    return nova


def pigmentos_sazonais(original, estacao, nome):
    """Varia plantas e flores; preserva madeira, ferragens e tecidos dos móveis."""
    nova = original.copy()
    if estacao == 0 or nome in ['mesa_piquenique', 'banco_piquenique_esquerdo', 'banco_piquenique_direito']:
        return nova
    w, h = original.size
    for y in range(h):
        for x in range(w):
            if nome == 'banco' and not (x < w * .18 or y > h * .86):
                continue  # A almofada verde não é vegetação.
            if nome == 'mesa_piquenique' and y >= h * .22:
                continue  # Só o buquê, sem tingir o vaso, a toalha ou a louça.
            r, g, b, a = original.getpixel((x, y))
            if not a:
                continue
            verde = g > r * .98 and g > b * 1.3
            flor = r > g * 1.3 and b > g * 1.15
            if nome == 'mesa_piquenique':
                flor = flor or (r > g * .95 and g > b * 1.6)
            if verde:
                if estacao == 1:
                    cor = (max(0, r - 6), max(0, g - 3), b, a)
                elif estacao == 2:
                    cor = (min(255, g + 15), round(g * .78), round(b * .8), a)
                else:
                    # Vegetação rasteira coberta: não deixar a silhueta de
                    # capim amarelo/verde sobre o terreno nevado.
                    cor = (214, 228, 232, a) if g > 95 else (176, 202, 215, a)
                nova.putpixel((x, y), cor)
            elif flor:
                if estacao == 1:
                    cor = (r, min(255, g + 18), min(255, b + 10), a)
                elif estacao == 2:
                    cor = (round(r * .8), round(r * .5), round(r * .3), a)
                else:
                    cor = (round(r * .65), round(r * .52), round(r * .38), a)
                nova.putpixel((x, y), cor)
    return nova


def canteiro_em_repouso(original):
    """Retira a vegetação sem serrar os postes e a borda superior do caixote."""
    w, h = original.size
    im = Image.new('RGBA', original.size)
    d = ImageDraw.Draw(im)
    # O caixote é visto em perspectiva: o solo e o aro seguem o mesmo
    # losango da marcenaria, sem uma faixa horizontal atravessando a peça.
    fundo = (w // 2, round(h * .38))
    direita = (w - 5, round(h * .55))
    frente = (w // 2, round(h * .77))
    esquerda = (4, round(h * .55))
    mascara = Image.new('L', original.size)
    ImageDraw.Draw(mascara).polygon([fundo, direita, frente, esquerda], fill=255)
    terra = Image.open(RAIZ / 'assets/cenario/cidade/terreno/witchbrook/inverno/grama_terra.png').convert('RGB')
    for y in range(h):
        for x in range(w):
            if mascara.getpixel((x, y)):
                cor = terra.getpixel((x % 16, 80 + y % 16))
                im.putpixel((x, y), tuple(round(c * .72) for c in cor) + (255,))
    d.line([esquerda, fundo, direita], fill=MADEIRA[2], width=2)
    d.line([esquerda, frente, direita], fill=MADEIRA[0])
    for y in range(h):
        for x in range(w):
            # Frente e postes laterais preservam todos os pixels do desenho.
            aro_frontal = round(h * (.55 + .22 * (1 - abs(x - w / 2) / (w / 2))))
            estrutural = y >= aro_frontal or (y >= round(h * .48) and (x < 7 or x >= w - 7))
            if estrutural:
                cor = original.getpixel((x, y))
                r, g, b, a = cor
                if g > r * 1.04 and g > b * 1.12:
                    cor = (max(r, g - 8), max(0, g - 22), b, a)
                im.putpixel((x, y), cor)
    return neve(im)


def planta(d, x, y, estacao, quadro, flor=False):
    dx = [0, 0, 1, 0][quadro]
    if estacao == 3:
        d.line((x, y, x + 1, y - 3), fill='#766447')
        d.point((x + 1, y - 3), fill='#dce5df')
        return
    altura = 3 if estacao == 0 else 5
    d.line((x, y, x + dx, y - altura), fill=FOLHAS[0])
    for lado in [-1, 1]:
        d.polygon([(x, y - 1), (x + lado * 3 + dx, y - altura), (x + lado * 3 + dx, y - 2)], fill=FOLHAS[1])
        d.line((x + lado, y - 2, x + lado * 2 + dx, y - altura + 1), fill=FOLHAS[2])
    if flor:
        cor = ['#dfa5b2', '#dbb963', '#bc8657'][estacao]
        d.rectangle((x - 1 + dx, y - altura - 2, x + 1 + dx, y - altura), fill=cor)
        d.point((x + dx, y - altura - 1), fill='#f4d99a')



def arranjo(im, estacao, quadro, centro=None):
    nova = im.copy()
    d = ImageDraw.Draw(nova)
    x, y = centro or (im.width // 2, max(9, im.height // 3))
    if estacao < 2:
        d.polygon([(x - 3, y - 1), (x + 3, y - 1), (x + 2, y + 4), (x - 2, y + 4)], fill='#946844')
        d.line((x - 2, y, x - 1, y + 3), fill='#c29462')
        planta(d, x, y - 1, estacao, quadro, True)
    elif estacao == 2:
        d.ellipse((x - 4, y - 3, x + 4, y + 3), fill='#925433')
        d.ellipse((x - 3, y - 3, x + 3, y + 2), fill='#c08542')
        d.line((x, y - 2, x, y + 1), fill='#e3a653')
        d.line((x, y - 5, x + 1, y - 3), fill='#526044')
    else:
        d.line((x - 5, y + 3, x + 5, y + 3), fill='#4c6048', width=2)
        d.rectangle((x - 1, y - 3, x + 1, y + 2), fill='#e2c58a')
        d.point((x + [0, 1, 0, -1][quadro], y - 5), fill='#f7df9b')
        d.point((x, y - 4), fill='#ce8950')
    return nova


def chamas(im, quadro, aceso=True):
    nova = im.copy()
    # Só o vão central inferior da lareira, sem tocar tijolos e utensílios.
    for y in range(int(im.height * .53), int(im.height * .91)):
        for x in range(int(im.width * .32), int(im.width * .69)):
            r, g, b, a = im.getpixel((x, y))
            if a > 128 and r > 135 and g > 65 and r > g * 1.1 and g > b * 1.35:
                nova.putpixel((x, y), (65, 43, 35, a))
                if aceso:
                    dy = [0, -1, 0, 1][quadro] if x % 3 else 0
                    nova.putpixel((x, max(0, y + dy)), (r, g, b, a))
    return nova


def galinha(quadro, inverno=False):
    im = Image.new('RGBA', (16, 15)); d = ImageDraw.Draw(im)
    baixo = quadro in [2, 3]
    d.line((6, 12, 6, 14), fill='#bc8546'); d.line((10, 12, 10, 14), fill='#bc8546')
    d.polygon([(3, 6), (1, 3), (2, 10), (6, 12), (11, 12), (13, 8), (10, 5)], fill='#8e8c78')
    d.ellipse((3, 5, 12, 11), fill='#dbd9bd'); d.line((4, 7, 9, 7), fill='#f1e9ce')
    x, y = (12, 10) if baixo else (11, 4)
    d.rectangle((x - 1, y - 1, x + 1, y + 2), fill='#e6dfc4')
    d.point((x + 1, y), fill='#47372f'); d.point((x + 2, y + 1), fill='#d5a24f')
    d.line((x - 1, y - 2, x, y - 2), fill='#a74738')
    return im


def exportar(chave, variantes, escala=1.0, fps=3, **extras):
    pasta = SAIDA / chave
    pasta.mkdir(parents=True, exist_ok=True)
    caminhos = []
    for estacao, quadros in zip(ESTACOES, variantes):
        w, h = quadros[0].size
        assert all(q.size == (w, h) for q in quadros)
        folha = Image.new('RGBA', (w * len(quadros), h))
        for i, quadro in enumerate(quadros):
            folha.paste(quadro, (i * w, 0))
        alvo = pasta / (estacao + '.png'); folha.save(alvo)
        caminhos.append('res://' + str(alvo.relative_to(RAIZ)))
    MANIFESTO[chave] = {'texturas': caminhos, 'quadros': 4, 'fps': fps,
                        'usado': [0, 0, w, h], 'escala_origem': escala, **extras}


def separar_piquenique(base):
    """Mesa separada e banquetas completas, sem reamostrar nenhum pixel.

    O original continua guardado. As partes têm contornos, âncoras e arquivos
    próprios; a mesa não carrega mais os bancos ou o chão pintado entre as pernas.
    """
    # Peças completas e ortogonais; nenhuma lateral inclinada é recortada
    # da mesa antiga. Os originais continuam guardados.
    partes = {}
    for nome, fonte in [('mesa_piquenique', 'mesa_media'),
                        ('banco_piquenique_esquerdo', 'banqueta'),
                        ('banco_piquenique_direito', 'banqueta')]:
        partes[nome] = carregar(MOVEIS_TOPDOWN / (fonte + '.png'))
    return partes


def separar_piquenique_antigo(base):
    """Receita antiga preservada para consultar os recortes de origem."""
    original = Image.open(base / 'mobiliario/mesa_ar_livre.png').convert('RGBA')
    contornos = {
        'mesa_piquenique': [(19, 0), (61, 0), (61, 20), (64, 35), (64, 40), (60, 42),
                            (61, 56), (54, 56), (53, 46), (32, 46), (28, 56),
                            (19, 56), (20, 43), (17, 40), (19, 35)],
    }
    partes = {}
    for nome, poligono in contornos.items():
        mascara = Image.new('L', original.size)
        ImageDraw.Draw(mascara).polygon(poligono, fill=255)
        if nome == 'mesa_piquenique':
            ImageDraw.Draw(mascara).polygon([(29, 49), (53, 49), (53, 63), (27, 63)], fill=0)
        parte = Image.new('RGBA', original.size)
        parte.paste(original, (0, 0), mascara)
        parte = parte.crop(parte.getbbox())
        parte.save(base / 'mobiliario' / (nome + '.png'))
        partes[nome] = parte
    # Os bancos embutidos tinham apoios ocultos pela mesa. Recortá-los deixou
    # peças incompletas. Esta banqueta já tem tampo e pernas inteiros no sprite
    # original da pousada; só retiramos transparência ao redor, sem escala.
    fonte = Image.open(RAIZ / 'assets/cenario/cidade/interiores/pousada/props/mesa.png').convert('RGBA')
    banqueta = fonte.crop((3, 35, 19, 55))
    banqueta = banqueta.crop(banqueta.getbbox())
    for nome, parte in [('banco_piquenique_esquerdo', banqueta),
                        ('banco_piquenique_direito', banqueta.transpose(Image.Transpose.FLIP_LEFT_RIGHT))]:
        parte.save(base / 'mobiliario' / (nome + '.png'))
        partes[nome] = parte
    return partes


def exteriores():
    base = RAIZ / 'assets/cenario/cidade/decoracao'
    exportar('externo/galinha', [[galinha(q) for q in range(4)] for e in range(4)], fps=2)
    for nome in ['banco', 'cerca', 'galinheiro', 'feno', 'lenha', 'mural', 'poste_luz',
                 'placa_encruzilhada', 'correio', 'coreto', 'ponte']:
        categoria = 'construcoes' if nome in ['coreto', 'ponte'] else 'mobiliario'
        fonte = base / categoria / (nome + '.png')
        revisado = base / categoria / 'revisados' / (nome + '.png')
        if nome == 'banco':
            revisado = MOVEIS_TOPDOWN / 'banco.png'
        if revisado.exists():
            fonte = revisado
        original = carregar(fonte)
        im = original.copy()
        variantes = []
        for e in range(4):
            sazonal = pigmentos_sazonais(im, e, nome)
            if e == 3:
                inverno = fonte.with_name(nome + '_inverno.png')
                if revisado.exists() and inverno.exists():
                    # Mesmo recorte e âncora do sprite base; não recortar a
                    # variante pela neve nem redimensionar entre estações.
                    limites = Image.open(fonte).convert('RGBA').getbbox()
                    sazonal = Image.open(inverno).convert('RGBA').crop(limites)
                else:
                    sazonal = neve(sazonal)
            variantes.append([sazonal.copy() for q in range(4)])
        exportar('externo/' + nome, variantes, fps=0,
                 fonte='res://' + str(fonte.relative_to(RAIZ)))
    for nome, im in separar_piquenique(base).items():
        variantes = []
        for e in range(4):
            sazonal = pigmentos_sazonais(im, e, nome)
            if e == 3:
                sazonal = neve(sazonal)
            variantes.append([sazonal.copy() for q in range(4)])
        fonte = 'mesa_media' if nome == 'mesa_piquenique' else 'banqueta'
        exportar('externo/' + nome, variantes, fps=0,
                 fonte='res://' + str((MOVEIS_TOPDOWN / (fonte + '.png')).relative_to(RAIZ)))
    for nome in ['arvore', 'arbusto', 'flores']:
        variantes = []
        for e, estacao in enumerate(ESTACOES):
            caminho = base / 'vegetacao' / (nome + '_' + estacao + '.png')
            if not caminho.exists():
                caminho = base / 'vegetacao' / (nome + '.png')
            im = carregar(caminho)
            # Todas as versões mantêm o mesmo canvas e a mesma âncora.
            variantes.append([folhagem(im, q, copa=nome in ['arvore', 'arbusto']) if e != 3 else im.copy() for q in range(4)])
        w = max(q.width for qs in variantes for q in qs); h = max(q.height for qs in variantes for q in qs)
        alinhadas = []
        for quadros in variantes:
            novos = []
            for im in quadros:
                tela = Image.new('RGBA', (w, h)); tela.alpha_composite(im, ((w - im.width) // 2, h - im.height)); novos.append(tela)
            alinhadas.append(novos)
        exportar('externo/' + nome, alinhadas, fps=2)

    # Mesma resolução e mesmos pixels dos originais: as estações trocam
    # cultivo/flores, nunca o tamanho ou a densidade do desenho.
    for nome in ['horta', 'canteiro']:
        original = carregar(base / 'mobiliario' / (nome + '.png'))
        variantes = []
        for e in range(4):
            im = original.copy()
            if nome == 'horta' and e == 0:
                flores = carregar(base / 'mobiliario/canteiro.png')
                im = Image.new('RGBA', original.size)
                im.alpha_composite(flores, ((im.width - flores.width) // 2, im.height - flores.height))
            elif e in [1, 2]:
                for y in range(im.height):
                    for x in range(im.width):
                        r, g, b, a = original.getpixel((x, y))
                        if nome == 'horta' and e == 1 and r > g * 1.15 and g > b * 1.3 and y < im.height * .7:
                            l = round(r * .55 + g * .36 + b * .09)
                            im.putpixel((x, y), (round(l * .65), round(l * .85), round(l * .4), a))
                        elif nome == 'canteiro' and e == 2 and g > r * 1.08 and g > b * 1.15:
                            im.putpixel((x, y), (min(255, g + 12), max(0, g - 18), b, a))
                        elif nome == 'canteiro' and e == 2 and r > g * 1.3 and b > g * 1.2:
                            im.putpixel((x, y), (round(r * .8), round(r * .5), round(r * .3), a))
                        elif nome == 'canteiro' and e == 1 and r > g * 1.3 and b > g * 1.2:
                            im.putpixel((x, y), (r, round(r * .85), round(r * .4), a))
            if e == 3:
                im = canteiro_em_repouso(im)
            quadros = [im.copy() for q in range(4)]
            if e < 2:
                # Só a folhagem superior balança, sem deslocar a madeira do vaso.
                quadros = [folhagem(im, q) for q in range(4)]
            variantes.append(quadros)
        exportar('externo/' + nome, variantes, fps=2)


def interiores():
    base = RAIZ / 'assets/cenario/cidade/interiores'
    mesas = {'sede': 'mesa_reuniao', 'pousada': 'mesa', 'casa_bento': 'mesa', 'mistica': 'mesa_cristal'}
    for pasta in sorted(base.iterdir()):
        if not pasta.is_dir():
            continue
        for arquivo in sorted((pasta / 'props').glob('*.png')):
            nome = arquivo.stem
            fonte = arquivo
            if (pasta.name, nome) in INTERIORES_TOPDOWN:
                fonte = MOVEIS_TOPDOWN / (INTERIORES_TOPDOWN[(pasta.name, nome)] + '.png')
            original = carregar(fonte)
            escala = 1.0
            im = original.copy()
            variantes = []
            calor = nome == 'lareira' and pasta.name != 'casa_bento'
            for e in range(4):
                quadros = []
                for q in range(4):
                    nova = im.copy()
                    if nome == 'lareira':
                        nova = chamas(nova, q, not calor or e in [2, 3])
                    if nome == mesas.get(pasta.name):
                        nova = arranjo(nova, e, q, (int(im.width * .76), int(im.height * .38)))
                    if nome == 'planta':
                        nova = arranjo(nova, e, q, (im.width // 2, 10))
                    if nome == 'ervas':
                        # Ervas frescas na primavera/verão, feixes secos no frio.
                        if e >= 2:
                            for y in range(nova.height):
                                for x in range(nova.width):
                                    r, g, b, a = nova.getpixel((x, y))
                                    if g > r * 1.08 and g > b * 1.15:
                                        nova.putpixel((x, y), (min(255, g + 12), max(0, g - 18), b, a))
                        nova = folhagem(nova, q)
                    if nome in ['caldeirao', 'mesa_cristal', 'pocoes', 'espelho']:
                        d = ImageDraw.Draw(nova)
                        x = im.width // 2 + [0, 3, -2, 1][q]; y = max(3, im.height // 4 - q)
                        d.point((x, y), fill=['#8ba98f', '#c8d4b5', '#769e96', '#a9c0ba'][q])
                    quadros.append(nova)
                variantes.append(quadros)
            animado = nome in ['lareira', 'planta', 'ervas', 'caldeirao', 'mesa_cristal', 'pocoes', 'espelho', mesas.get(pasta.name)]
            exportar('interior/' + pasta.name + '/' + nome, variantes, escala, fps=4 if nome == 'lareira' else 2 if animado else 0,
                     calor_sazonal=calor, fonte='res://' + str(fonte.relative_to(RAIZ)))

        if pasta.name == 'sede':
            banco = carregar(MOVEIS_TOPDOWN / 'banco_horizontal.png')
            exportar('interior/sede/banco_reuniao', [[banco.copy() for q in range(4)] for e in range(4)], fps=0,
                     fonte='res://' + str((MOVEIS_TOPDOWN / 'banco_horizontal.png').relative_to(RAIZ)))


def fachadas():
    for arquivo in sorted((RAIZ / 'assets/cenario/cidade/casas/exterior').glob('*.png')):
        original = Image.open(arquivo).convert('RGBA')
        variantes = []
        for e in range(4):
            nova = original.copy()
            if arquivo.stem == 'casa_bento' and e != 2:
                # A colheita está embutida na fachada. Preservar sua cobertura
                # original, sem abrir buracos na cerca ou na parede da casa.
                for y in range(90, original.height):
                    for x in range(115, original.width):
                        r, g, b, a = original.getpixel((x, y))
                        if a and r > g * 1.2 and g > b * 1.4:
                            l = round(r * .55 + g * .36 + b * .09)
                            cor = (round(l * .65), round(l * .85), round(l * .4), a)
                            if e == 3:
                                cor = (max(0, l - 12), max(0, l - 16), max(0, l - 30), a)
                            nova.putpixel((x, y), cor)
            if arquivo.stem == 'casa_jogador':
                # Versões alinhadas preparadas com a fachada inicial da fazenda.
                nova = Image.open(RAIZ / 'assets/cenario/fazenda/casa_inicial' / (ESTACOES[e] + '.png')).convert('RGBA')
            elif e == 3:
                nova = neve(nova)
            variantes.append([nova.copy() for q in range(4)])
        exportar('fachada/' + arquivo.stem, variantes, fps=0)


def main():
    exteriores(); interiores(); fachadas()
    (SAIDA / 'manifesto.json').write_text(json.dumps(MANIFESTO, indent=1, ensure_ascii=False) + '\n')
    print(len(MANIFESTO), 'objetos preparados em quatro estações, com quatro quadros e âncoras estáveis.')


if __name__ == '__main__':
    main()
