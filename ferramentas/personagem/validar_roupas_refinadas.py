#!/usr/bin/env python3
"""Valida o catálogo refinado e a cobertura dos moldes de roupa."""
import json
from pathlib import Path
from PIL import Image, ImageChops

RAIZ = Path(__file__).resolve().parents[2]

def validar():
    dados = json.loads((RAIZ/'assets/personagens/refinado/roupas/manifesto.json').read_text())
    erros = []
    if len(dados['roupas']) != 46*11 or {r['indice'] for r in dados['roupas'].values()} != set(range(46)):
        erros.append('Catálogo incompleto ou índices alterados.')
    for fonte, destino in dados['fontes'].items():
        antiga = Image.open(RAIZ/fonte.removeprefix('res://')).convert('RGBA')
        nova = Image.open(RAIZ/destino.removeprefix('res://')).convert('RGBA')
        if nova.size != (1024,1024):
            erros.append(f'Resolução: {destino}')
            continue
        alfa = nova.getchannel('A')
        if set(alfa.get_flattened_data()) - {0,255}:
            erros.append(f'Alfa intermediário: {destino}')
        original = antiga.getchannel('A').point(lambda a: 255 if a >= 128 else 0).resize(nova.size,Image.Resampling.NEAREST)
        if ImageChops.difference(alfa,original).getbbox():
            erros.append(f'Encaixe mudou: {fonte}')
    print(f"{len(dados['roupas'])} entradas, {len(dados['fontes'])} folhas distintas, {len(dados['fontes'])*64} quadros; falhas: {len(erros)}")
    for erro in erros:
        print('FALHA:',erro)
    return len(erros)

if __name__ == '__main__':
    raise SystemExit(validar())
