#!/usr/bin/env python3
"""Monta prévias das capturas reais sem alterar os recursos do personagem."""
import json
from pathlib import Path
from PIL import Image, ImageDraw

RAIZ = Path(__file__).resolve().parents[3]
SAIDA = RAIZ / 'arte/previas/personagens/base_3d/low_poly'
FUNDO = '#66745b'
LARGURA, ALTURA = 300, 320


def recorte(nome):
    imagem = Image.open(SAIDA / f'{nome}.png').convert('RGBA')
    # Câmera e pivô comuns: mesmo corte em coordenadas de mundo, sem
    # recentralizar quadros pelo contorno do personagem.
    fator = imagem.width / 640
    imagem = imagem.crop(tuple(round(v * fator) for v in (170, 155, 470, 475)))
    return imagem.resize((LARGURA, ALTURA), Image.Resampling.NEAREST if fator < 1 else Image.Resampling.LANCZOS)


def exportar(direcoes=(0,2,4,6), sufixo=""):
    comparacao = Image.new('RGB', (LARGURA * len(direcoes), (ALTURA + 30) * 2), FUNDO)
    desenho = ImageDraw.Draw(comparacao)
    for linha, modo in enumerate(('antes', 'low_poly')):
        desenho.text((18, linha * (ALTURA + 30) + 8), 'ANTES' if linha == 0 else 'LOW POLY + PINTURA', fill='white')
        for coluna, direcao in enumerate(direcoes):
            parte = recorte(f'{modo}_{direcao}')
            comparacao.paste(parte, (coluna * LARGURA, linha * (ALTURA + 30) + 26), parte)
    comparacao.save(SAIDA / f'comparacao{sufixo}.png')

    tempos = json.loads((SAIDA / 'tempos.json').read_text())
    for acao, tempo in tempos.items():
        quadros = []
        contato = Image.new('RGB', (LARGURA * 8, ALTURA * len(direcoes) * 2), FUNDO)
        for quadro in range(16):
            imagem = Image.new('RGB', (LARGURA * len(direcoes), ALTURA + 30), FUNDO)
            texto = ImageDraw.Draw(imagem)
            texto.text((16, 8), f'{acao.upper()} | {quadro + 1}/16', fill='white')
            for coluna, direcao in enumerate(direcoes):
                parte = recorte(f'{acao}_{direcao}_{quadro:02d}')
                imagem.paste(parte, (coluna * LARGURA, 26), parte)
                contato.paste(parte, ((quadro % 8) * LARGURA, (coluna * 2 + quadro // 8) * ALTURA), parte)
            quadros.append(imagem)
        # GIF trabalha em centésimos: distribuir o arredondamento ao longo
        # do ciclo conserva o tempo físico, em vez de acelerar todas as poses.
        duracoes = [10 * (round((q + 1) * tempo * 100 / 16) - round(q * tempo * 100 / 16)) for q in range(16)]
        quadros[0].save(SAIDA / f'{acao}{sufixo}.gif', save_all=True, append_images=quadros[1:], duration=duracoes, loop=0)
        contato.save(SAIDA / f'quadros_{acao}{sufixo}.png')


if __name__ == '__main__':
    exportar()
