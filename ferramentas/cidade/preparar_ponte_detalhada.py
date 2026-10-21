"""Recorta o kit pintado, preserva o encaixe e prepara as quatro estações.

O original e o pedido ficam em arte/fontes/cidade/ponte_detalhada.
Geometria e colisão: codigo/cidade/ponte_cidade.gd (unidades lógicas).
"""
from pathlib import Path
import json
from PIL import Image
from preparar_complementos import ESTACOES, salvar, sazonal

RAIZ = Path(__file__).resolve().parents[2]
FONTE = RAIZ / 'arte/fontes/cidade/ponte_detalhada/kit_margens_estacas.png'
SAIDA = RAIZ / 'assets/cenario/cidade/ponte_detalhada'


def cabeceiras(im, estacao):
    """Continua a pedra da rua na mesma escala e fase espacial do shader."""
    pedra = Image.open(RAIZ / f'assets/cenario/cidade/chao_detalhado/pedra_{estacao}.png').convert('RGB')
    im = im.copy()
    for y in range(160):
        for x in [*range(67), *range(252, 320)]:
            r, g, b = pedra.getpixel(((636 * 4 + x) % 512, (252 * 4 + y) % 512))
            im.putpixel((x, y), (r, g, b, im.getpixel((x, y))[3]))
    return im


def preparar():
    original = Image.open(FONTE).convert('RGBA')
    # Separação pelos intervalos transparentes do original; a mesma peça serve
    # às quatro estações e aos dois corrimãos, sem variar pivô nem comprimento.
    contatos = []
    for nome, faixa, tamanho in [
        ('piso', (0, 125, 1536, 360), (320, 176)),
        ('corrimao', (0, 395, 1536, 555), (320, 48)),
        ('apoios', (0, 595, 1536, 985), (176, 120)),
    ]:
        im = original.crop(faixa)
        alpha = im.getchannel('A')
        im = im.crop(alpha.point(lambda a: 255 if a > 127 else 0).getbbox())
        # Descarta somente o resíduo transparente do recorte gerado, mantendo
        # as bordas suavizadas da pintura e os vãos reais entre as travessas.
        im.putalpha(im.getchannel('A').point(lambda a: 0 if a < 32 else a))
        im = im.resize(tamanho, Image.Resampling.LANCZOS)
        if nome == 'apoios':
            # Ajusta a espessura dos dois pilares à escala lógica, preservando
            # a viga e as mãos francesas do desenho. As pontas continuam na
            # mesma linha de água, com quatro pixels e meio de madeira maciça.
            for x0, x1 in [(25, 35), (141, 151)]:
                pilar = im.crop((x0, 0, x1, im.height)).resize((21, im.height), Image.Resampling.LANCZOS)
                im.paste((0, 0, 0, 0), (x0, 0, x1, im.height))
                im.alpha_composite(pilar, (x0 - 6, 0))
            # O intervalo entre pilares coincide com os dois postes internos
            # do corrimão, em vez de deixar o guarda-corpo sem apoio alinhado.
            im = im.resize((152, 120), Image.Resampling.LANCZOS)
            # A água encontra os dois pilares reais da imagem, sem usar os
            # extremos da viga nem presumir que o desenho chega aos cantos.
            y = im.height - 6
            trechos = []
            for x in range(im.width):
                if im.getpixel((x, y))[3] < 160:
                    continue
                if not trechos or x > trechos[-1][-1] + 1:
                    trechos.append([x])
                else:
                    trechos[-1].append(x)
            assert len(trechos) == 2, 'A linha de água deve cortar duas estacas.'
            contatos = [[round((t[0] + t[-1]) / 8, 3), y / 4] for t in trechos]
            # Só a ponta imersa perde opacidade, sem esconder nem encurtar as
            # estacas. A ondulação de contato é renderizada abaixo da madeira.
            alpha = im.getchannel('A')
            for yy in range(im.height - 6, im.height):
                for xx in range(im.width):
                    alpha.putpixel((xx, yy), round(alpha.getpixel((xx, yy)) * (im.height - yy) / 6))
            im.putalpha(alpha)
        for indice, estacao in enumerate(ESTACOES):
            variante = sazonal(im, indice)
            if nome == 'piso':
                variante = cabeceiras(variante, estacao)
            if nome == 'apoios' and estacao == 'inverno':
                # Madeira e algas junto à água ficam frias e úmidas, sem
                # converter o limo submerso em manchas de neve branca.
                for y in range(20, im.height):
                    for x in range(im.width):
                        r, g, b, a = im.getpixel((x, y))
                        variante.putpixel((x, y), (round(r * .93), round(g * .96), min(255, round(b * 1.02)), a))
            salvar(variante, SAIDA / estacao / (nome + '.png'))
    (SAIDA / 'geometria.json').write_text(json.dumps({'contatos_apoios': contatos}, indent=2) + '\n')


if __name__ == '__main__':
    preparar()
