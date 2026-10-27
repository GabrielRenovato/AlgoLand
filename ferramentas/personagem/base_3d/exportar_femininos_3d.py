#!/usr/bin/env python3
"""Exporta as capturas reais do Godot, com pivô fixo e tempos dos clipes."""
import json
from pathlib import Path
from PIL import Image, ImageDraw

PASTA = Path(__file__).resolve().parents[3] / 'arte/previas/personagens/base_3d/femininos'
ROTULOS = ['Longo · blusa bufante · saia de pregas', 'Cacheado · casaquinho · saia do campo', 'Curto · blusa bufante · saia do campo']

def compor(acao, quadro):
    saida = Image.new('RGB', (912, 864), '#46514c')
    for conjunto in range(3):
        ImageDraw.Draw(saida).text((12, conjunto * 288 + 8), ROTULOS[conjunto], fill='#fff0cb')
        for direcao in range(4):
            imagem = Image.open(PASTA / f'{acao}_{conjunto}_{direcao}_{quadro:02}.png').convert('RGBA')
            imagem = imagem.crop((42, 30, 118, 118)).resize((228, 264), Image.Resampling.NEAREST)
            saida.paste(imagem, (direcao * 228, conjunto * 288 + 24), imagem)
    return saida

def exportar():
    previa = compor('idle', 0)
    previa.save(PASTA / 'conjuntos.png')
    previa.save(PASTA / 'cabelos_longo_cacheado_curto.png')
    tempos = json.loads((PASTA / 'tempos.json').read_text())
    for acao in ['corrida', 'ataque']:
        quadros = [compor(acao, q) for q in range(12)]
        duracao = tempos[acao]
        duracoes = [round((q + 1) * duracao * 100 / 12) * 10 - round(q * duracao * 100 / 12) * 10 for q in range(12)]
        quadros[0].save(PASTA / f'{acao}.gif', save_all=True, append_images=quadros[1:], duration=duracoes, loop=0, disposal=2)
        contato = Image.new('RGB', (1824, 5184), '#46514c')
        for q, quadro in enumerate(quadros):
            contato.paste(quadro, ((q % 2) * 912, (q // 2) * 864))
        contato.save(PASTA / f'contato_{acao}.png')

if __name__ == '__main__':
    exportar()
