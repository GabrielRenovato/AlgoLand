#!/usr/bin/env python3
"""Compõe as capturas do Godot, preservando a célula, o pivô e os tempos."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

PASTA = Path(__file__).resolve().parents[3] / 'arte/previas/personagens/base_3d/mixamo'
FONTE = ImageFont.load_default(size=14)
DIRECOES = ['FRENTE', 'DIREITA', 'COSTAS', 'ESQUERDA']

def quadro(pasta, nome, q):
    im = Image.new('RGB', (960, 268), '#46514c')
    for direcao, rotulo in enumerate(DIRECOES):
        fonte = Image.open(pasta / f'{nome}_{direcao}_{q:02}.png').convert('RGBA')
        fonte = fonte.resize((240, 240), Image.Resampling.NEAREST)
        im.paste(fonte, (direcao*240, 28), fonte)
        ImageDraw.Draw(im).text((direcao*240+12, 8), rotulo, font=FONTE, fill='white')
    return im

def salvar(nome, quadros, duracoes):
    quadros[0].save(PASTA / f'{nome}.gif', save_all=True, append_images=quadros[1:], duration=duracoes, loop=0, disposal=2)


def compor():
    # Captura contínua: dois golpes e retorno, exatamente 96 quadros a 60 fps.
    quadros = [quadro(PASTA / 'espadão', 'combo', q) for q in range(96)]
    duracoes = [round((q+1)*100/60)*10-round(q*100/60)*10 for q in range(96)]
    salvar('combo_espadão', quadros, duracoes)
    contato = Image.new('RGB', (1920, 1072), '#46514c')
    for i, q in enumerate(range(0, 96, 12)):
        contato.paste(quadros[q], ((i%2)*960, (i//2)*268))
    contato.save(PASTA / 'contato_espadão.png')
    # Poses aplicadas pelo controlador; as durações são as usadas nas ações.
    for nome, duracao in [('idle',4.0), ('guarda',1.4), ('arco',1.08), ('machado',.68)]:
        quadros = [quadro(PASTA / 'aplicado', nome, q) for q in range(24)]
        duracoes = [round((q+1)*duracao*100/24)*10-round(q*duracao*100/24)*10 for q in range(24)]
        salvar(nome, quadros, duracoes)
    quadros = []
    duracoes = []
    for golpe, duracao in enumerate([.38,.38,.50], 1):
        quadros.extend(quadro(PASTA / 'aplicado', f'espada_{golpe}', q) for q in range(24))
        duracoes.extend(round((q+1)*duracao*100/24)*10-round(q*duracao*100/24)*10 for q in range(24))
    salvar('combo_espada_escudo', quadros, duracoes)
    print('Mixamo: combo real do espadão e prévias de idle, guarda, arco, machado e espada/escudo.')

if __name__ == '__main__':
    compor()
