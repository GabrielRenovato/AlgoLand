#!/usr/bin/env python3
"""Compõe capturas do rig no Godot, com célula/pivô comuns e tempos do controlador."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import json

RAIZ = Path(__file__).resolve().parents[3]
PASTA = RAIZ / 'arte/previas/personagens/base_3d/ferramentas_kaykit'
TEMPOS = {'enxada': .68, 'picareta': .68, 'preparar': .6, 'lancar': .55, 'esperar': 2.333333,
          'beliscar': 1.5, 'recolher': 1.6, 'capturar': 3.233333}
FONT = ImageFont.load_default(size=14)

def compor(nome, q):
    tela = Image.new('RGB', (800, 225), '#58645f')
    for direcao, rotulo in enumerate(['FRENTE', 'DIREITA', 'COSTAS', 'ESQUERDA']):
        im = Image.open(PASTA / f'{nome}_{direcao}_{q:02}.png').convert('RGBA')
        im = im.resize((200, 200), Image.Resampling.NEAREST)
        tela.paste(im, (direcao * 200, 25), im)
        ImageDraw.Draw(tela).text((direcao * 200 + 20, 6), rotulo, font=FONT, fill='white')
    return tela

def main():
    for nome, total in TEMPOS.items():
        quadros = [compor(nome, q) for q in range(24)]
        tempos = [round((q + 1) * total * 100 / 24) * 10 - round(q * total * 100 / 24) * 10 for q in range(24)]
        quadros[0].save(PASTA / f'{nome}.gif', save_all=True, append_images=quadros[1:], duration=tempos, loop=0, disposal=2)
        contato = Image.new('RGB', (1600, 900), '#58645f')
        for linha in range(4):
            for coluna, q in enumerate(range(0, 24, 3)):
                im = Image.open(PASTA / f'{nome}_{linha}_{q:02}.png').convert('RGBA').resize((200,200), Image.Resampling.NEAREST)
                contato.paste(im, (coluna*200, linha*225+25), im)
                ImageDraw.Draw(contato).text((coluna*200+6, linha*225+5), f'{nome} dir{linha} q{q}', font=FONT, fill='white')
        contato.save(PASTA / f'{nome}_contato.png')
    (PASTA / 'tempos.json').write_text(json.dumps(TEMPOS, indent=2) + '\n')
    print('8 prévias; 4 direções; 24 amostras por ação; pivô e tempos preservados.')

if __name__ == '__main__':
    main()
