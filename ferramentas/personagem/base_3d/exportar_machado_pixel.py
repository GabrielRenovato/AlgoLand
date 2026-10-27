#!/usr/bin/env python3
"""Compõe as 41 amostras por vista de teste_machado_pixel_3d.gd (ação de 680 ms)."""
from pathlib import Path
from PIL import Image, ImageDraw

PASTA = Path(__file__).resolve().parents[3] / 'arte/previas/personagens/base_3d/mixamo/machado_pixel'

def compor():
    quadros = []
    costas = []
    for q in range(41):
        quadro = Image.new('RGB', (640, 160), '#46514c')
        for d in range(4):
            fonte = Image.open(PASTA / f'machado_{d}_{q:02}.png').convert('RGBA')
            quadro.paste(fonte, (d * 160, 0), fonte)
            if d == 2:
                fundo = Image.new('RGB', fonte.size, '#46514c')
                fundo.paste(fonte, (0, 0), fonte)
                costas.append(fundo.crop((32, 16, 128, 128)).resize((288, 336), Image.Resampling.NEAREST))
        quadros.append(quadro)
    duracoes = [round((q + 1) * 68 / 41) * 10 - round(q * 68 / 41) * 10 for q in range(41)]
    for nome, imagens in [('machado', quadros), ('costas', costas)]:
        imagens[0].save(PASTA / f'{nome}.gif', save_all=True, append_images=imagens[1:], duration=duracoes, loop=0, disposal=2)
    # Quatro vistas em cada linha de amostra, sem sobrepor as células.
    contato = Image.new('RGB', (1280, 3360), '#46514c')
    for q, quadro in enumerate(quadros):
        x, y = 640 * (q % 2), 160 * (q // 2)
        contato.paste(quadro, (x, y))
        ImageDraw.Draw(contato).text((x + 4, y + 4), str(q), fill='white')
    contato.save(PASTA / 'contato.png')

if __name__ == '__main__':
    compor()
