#!/usr/bin/env python3
"""Recorta as ações de 80 px sem alterar pixels, para o limite de textura do WebGL."""
import json
from pathlib import Path
from PIL import Image

RAIZ = Path(__file__).resolve().parents[2] / 'assets/personagens/raven_fantasy'

def preparar():
    acoes = json.loads((RAIZ / 'camadas/acoes.json').read_text())
    quantidade = 0
    for atlas in (RAIZ / 'camadas').glob('*.png'):
        imagem = Image.open(atlas).convert('RGBA')
        destino = RAIZ / 'web' / atlas.stem
        destino.mkdir(parents=True, exist_ok=True)
        for i, acao in enumerate(acoes):
            imagem.crop((0, i * 320, 320, (i + 1) * 320)).save(destino / f'{acao}.png')
            quantidade += 1
    print(f'Raven Web: {quantidade} páginas de 320 × 320, sem alteração de pixels.')

if __name__ == '__main__':
    preparar()
