"""Recorta o kit pintado, preserva o encaixe e prepara as quatro estações.

O original e o pedido ficam em arte/fontes/cidade/ponte_detalhada.
Geometria e colisão: codigo/cidade/ponte_cidade.gd (unidades lógicas).
"""
from pathlib import Path
from PIL import Image
from preparar_complementos import ESTACOES, salvar, sazonal

RAIZ = Path(__file__).resolve().parents[2]
FONTE = RAIZ / 'arte/fontes/cidade/ponte_detalhada/kit.png'
SAIDA = RAIZ / 'assets/cenario/cidade/ponte_detalhada'


def preparar():
    original = Image.open(FONTE).convert('RGBA')
    # Separação pelos intervalos transparentes do original; a mesma peça serve
    # às quatro estações e aos dois corrimãos, sem variar pivô nem comprimento.
    for nome, faixa, tamanho in [
        ('piso', (0, 100, 1536, 360), (320, 108)),
        ('corrimao', (0, 400, 1536, 660), (320, 48)),
        ('apoios', (0, 700, 1536, 970), (320, 60)),
    ]:
        im = original.crop(faixa)
        alpha = im.getchannel('A')
        im = im.crop(alpha.point(lambda a: 255 if a > 127 else 0).getbbox())
        # Descarta somente o resíduo transparente do recorte gerado, mantendo
        # as bordas suavizadas da pintura e os vãos reais entre as travessas.
        im.putalpha(im.getchannel('A').point(lambda a: 0 if a < 32 else a))
        im = im.resize(tamanho, Image.Resampling.LANCZOS)
        for indice, estacao in enumerate(ESTACOES):
            salvar(sazonal(im, indice), SAIDA / estacao / (nome + '.png'))


if __name__ == '__main__':
    preparar()
