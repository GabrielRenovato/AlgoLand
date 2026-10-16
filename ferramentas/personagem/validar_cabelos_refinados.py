#!/usr/bin/env python3
"""Confere os sete penteados e a cobertura de todas as suas poses."""
import json
from pathlib import Path
from PIL import Image, ImageChops

RAIZ = Path(__file__).resolve().parents[2]

def validar():
    dados = json.loads((RAIZ/'assets/personagens/refinado/cabelos/manifesto.json').read_text())
    erros = []
    if len(dados) != 77 or {d['indice'] for d in dados.values()} != set(range(7)):
        erros.append('O cadastro precisa conter sete penteados nas onze páginas.')
    for nome, item in dados.items():
        nova = Image.open(RAIZ/item['folha'].removeprefix('res://')).convert('RGBA')
        nativa = Image.open(RAIZ/item['molde'].removeprefix('res://')).convert('RGBA')
        if nova.size != (1024,1024) or item['escala'] != 0.5:
            erros.append(f'Resolução/escala: {nome}')
            continue
        alfa = nova.getchannel('A')
        if set(alfa.get_flattened_data()) - {0,255}:
            erros.append(f'Transparência intermediária: {nome}')
        molde = nativa.getchannel('A').point(lambda a: 255 if a >= 128 else 0).resize(nova.size,Image.Resampling.NEAREST)
        if ImageChops.difference(alfa,molde).getbbox():
            erros.append(f'Cabelo invade ou deixa a cabeça descoberta: {nome}')
        pixels = nova.load()
        for y in range(512):
            for x in range(512):
                original = nativa.getpixel((x,y))
                if original == (24,24,24,255):
                    if any(max(pixels[x*2+sx,y*2+sy][:3]) > 35 for sx in range(2) for sy in range(2)):
                        erros.append(f'Contorno apagado: {nome}/{x},{y}')
    print(f'{len(dados)} folhas, {len(dados)*64} quadros; falhas: {len(erros)}')
    for erro in erros[:20]:
        print('FALHA:',erro)
    return len(erros)

if __name__ == '__main__':
    raise SystemExit(validar())
