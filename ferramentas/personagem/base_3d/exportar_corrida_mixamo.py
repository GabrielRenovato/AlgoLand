#!/usr/bin/env python3
"""Prévia da corrida real do rig, sem recortar ou recentralizar poses por quadro."""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont

PASTA = Path(__file__).resolve().parents[3] / 'arte/previas/personagens/base_3d/mixamo'
FONTE = ImageFont.load_default(size=14)

def compor():
    tempos = json.loads((PASTA / 'tempos.json').read_text())
    for grupo, direcoes in [('cardinais', [0, 2, 4, 6]), ('diagonais', [1, 3, 5, 7])]:
        contato = Image.new('RGB', (1600, 900), '#58645f')
        quadros = []
        for q in range(24):
            quadro = Image.new('RGB', (800, 225), '#58645f')
            for linha, direcao in enumerate(direcoes):
                im = Image.open(PASTA / f'corrida_{direcao}_{q:02}.png').convert('RGBA').resize((200, 200), Image.Resampling.NEAREST)
                quadro.paste(im, (linha * 200, 25), im)
                rotulo = ['FRENTE', 'FRENTE/DIREITA', 'DIREITA', 'COSTAS/DIREITA', 'COSTAS', 'COSTAS/ESQUERDA', 'ESQUERDA', 'FRENTE/ESQUERDA'][direcao]
                ImageDraw.Draw(quadro).text((linha*200+8, 6), rotulo, font=FONTE, fill='white')
                if q % 3 == 0:
                    contato.paste(im, (q//3*200, linha*225+25), im)
                    ImageDraw.Draw(contato).text((q//3*200+6, linha*225+6), f'DIR {direcao} | QUADRO {q}', font=FONTE, fill='white')
            quadros.append(quadro)
        total = tempos['ciclo_no_jogo']
        duracoes = [round((q+1)*total*100/24)*10-round(q*total*100/24)*10 for q in range(24)]
        quadros[0].save(PASTA / f'corrida_{grupo}.gif', save_all=True, append_images=quadros[1:], duration=duracoes, loop=0, disposal=2)
        contato.save(PASTA / f'contato_{grupo}.png')
    print('Corrida Mixamo: GIFs e contatos das oito direções, com a duração usada no jogo.')

if __name__ == '__main__':
    compor()
