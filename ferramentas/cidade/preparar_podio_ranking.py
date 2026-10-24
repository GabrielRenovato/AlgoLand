#!/usr/bin/env python3
"""Recorta a folha sazonal preservando o canvas e o pivô comuns, em apresentação4×."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import json
RAIZ = Path(__file__).resolve().parents[2]
FONTE = RAIZ / 'arte/fontes/cidade/podio_ranking/original.png'
DESTINO = RAIZ / 'assets/cenario/cidade/podio_ranking'

def preparar():
    folha = Image.open(FONTE).convert('RGBA')
    assert folha.size == (1774, 887), folha.size
    DESTINO.mkdir(parents=True, exist_ok=True)
    for i, estacao in enumerate(['primavera', 'verao', 'outono', 'inverno']):
        x, y = (i % 2) * 887, (i // 2) * 444
        # O mesmo recorte em todas as variantes: não recentralizar pela neve/flores.
        imagem = folha.crop((x + 10, y + 64, x + 878, y + 390))
        imagem = imagem.resize((768, 288), Image.Resampling.LANCZOS)
        imagem.save(DESTINO / f'{estacao}.png')
    # Recorta os algarismos pelo contorno visível: métricas da linha não centralizam a tinta.
    fonte = ImageFont.truetype(str(RAIZ / 'assets/ui/Planes_ValMore.ttf'), 24)
    for numero in range(1, 4):
        digito = Image.new('RGBA', (96, 96))
        ImageDraw.Draw(digito).text((16, 16), str(numero), font=fonte, fill='white')
        digito.crop(digito.getbbox()).save(DESTINO / f'numero_{numero}.png')
    (DESTINO / 'manifesto.json').write_text(json.dumps({
        'canvas_logico': [192, 72], 'resolucao': 4, 'pivo': [96, 72],
        'pes': [[-54, -43], [0, -57], [56, -35]],
        'medalhoes': [[-54, -20], [0, -27], [56, -17]],
        'colisao': [170, 30],
        'fonte': 'arte/fontes/cidade/podio_ranking/original.png',
    }, indent=2) + '\n')

if __name__ == '__main__':
    preparar()
