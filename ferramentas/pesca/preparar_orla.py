#!/usr/bin/env python3
"""Reutiliza os cantos/guia da cidade com fundo transparente sobre a areia da praia."""
from pathlib import Path
import sys
from PIL import Image
RAIZ = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(RAIZ / 'ferramentas/cidade'))
from preparar_grama_mana_seed import mascaras


def preparar():
    recortes = mascaras()['grama_pedra']
    for estacao in ['primavera', 'verao', 'outono', 'inverno']:
        origem = Image.open(RAIZ / f'assets/cenario/algoland_original/{estacao}/grama_pedra.png').convert('RGBA')
        for y in range(96):
            for x in range(64):
                linha, coluna = y // 16, x // 16
                indice = linha * 4 + coluna if linha < 4 else (0 if linha == 4 else 15)
                if recortes[indice].getpixel((x % 16, y % 16))[0] == 0:
                    origem.putpixel((x, y), (0, 0, 0, 0))
        destino = RAIZ / f'assets/cenario/praia/orla/{estacao}.png'
        destino.parent.mkdir(parents=True, exist_ok=True)
        origem.save(destino)

def preparar_vegetacao():
    """Recorta a grama nativa; cantos e juncoes deixam a areia aparecer por baixo."""
    recortes = mascaras()['grama_terra']
    for estacao in ['primavera', 'verao', 'outono', 'inverno']:
        origem = Image.open(RAIZ / f'assets/cenario/algoland_original/{estacao}/grama_terra.png').convert('RGBA')
        for y in range(96):
            for x in range(64):
                linha, coluna = y // 16, x // 16
                indice = linha * 4 + coluna if linha < 4 else (0 if linha == 4 else 15)
                if recortes[indice].getpixel((x % 16, y % 16))[0] != 0:
                    origem.putpixel((x, y), (0, 0, 0, 0))
        destino = RAIZ / f'assets/cenario/praia/vegetacao_orla/{estacao}.png'
        destino.parent.mkdir(parents=True, exist_ok=True)
        origem.save(destino)


if __name__ == '__main__':
    preparar()
    preparar_vegetacao()
