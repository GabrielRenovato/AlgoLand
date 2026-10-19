#!/usr/bin/env python3
"""Recorta os sprites nativos e alinha a base sem redimensionar seus pixels."""
import json
from pathlib import Path
from PIL import Image

RAIZ = Path(__file__).resolve().parents[2]
FONTE = RAIZ / 'arte/fontes/mineracao_arena'
CONTRATO = json.loads((FONTE / 'manifesto.json').read_text())
DESTINO = RAIZ / 'assets/cenario/arena/minerios'
DESTINO.mkdir(parents=True, exist_ok=True)
for nome, dados in CONTRATO['recortes'].items():
    original = Image.open(FONTE / dados['arquivo']).convert('RGBA')
    sprite = original.crop(tuple(dados['regiao']))
    limites = sprite.getbbox()
    if not limites:
        raise ValueError(f'Sprite vazio: {nome}')
    desenho = sprite.crop(limites)
    if desenho.width > 32 or desenho.height > 28:
        raise ValueError(f'Sprite fora da grade: {nome}')
    tela = Image.new('RGBA', (32, 32))
    tela.alpha_composite(desenho, ((32 - desenho.width) // 2, 28 - desenho.height))
    tela.save(DESTINO / f'ferro_{nome}.png')
    print(f'{nome}: {desenho.width}x{desenho.height}, base y=28')
