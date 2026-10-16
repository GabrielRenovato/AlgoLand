#!/usr/bin/env python3
"""Confere dimensões, encaixe e preservação dos efeitos claros das armas/ferramentas."""
import json
from pathlib import Path
from PIL import Image, ImageChops

RAIZ = Path(__file__).resolve().parents[2]

def validar():
    dados = json.loads((RAIZ/'assets/personagens/refinado/objetos/manifesto.json').read_text())
    erros = []
    quadros = 0
    for fonte, item in dados.items():
        antiga = Image.open(RAIZ/fonte.removeprefix('res://')).convert('RGBA')
        nova = Image.open(RAIZ/item['folha'].removeprefix('res://')).convert('RGBA')
        if nova.size != (antiga.width*2, antiga.height*2) or item['escala'] != .5:
            erros.append(f'Resolução/escala: {fonte}')
            continue
        alfa = nova.getchannel('A')
        referencia = antiga.getchannel('A').point(lambda a: 255 if a >= 128 else 0).resize(nova.size,Image.Resampling.NEAREST)
        if set(alfa.get_flattened_data()) - {0,255} or ImageChops.difference(alfa,referencia).getbbox():
            erros.append(f'Encaixe/transparência: {fonte}')
        pixels = nova.load()
        for y in range(antiga.height):
            for x in range(antiga.width):
                pixel = antiga.getpixel((x,y))
                if pixel[3] >= 128 and min(pixel[:3]) >= 230:
                    if any(pixels[x*2+sx,y*2+sy][:3] != pixel[:3] for sx in range(2) for sy in range(2)):
                        erros.append(f'Efeito claro alterado: {fonte}/{x},{y}')
        quadros += item['grade'][0]*item['grade'][1]
    print(f'{len(dados)} folhas, {quadros} quadros; falhas: {len(erros)}')
    for erro in erros[:20]:
        print('FALHA:',erro)
    return len(erros)

if __name__ == '__main__':
    raise SystemExit(validar())
