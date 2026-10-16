#!/usr/bin/env python3
"""Recortes nativos da folha ortogonal criada no PixelLab Workbench.

Reutiliza a madeira e a cadeira do sampler Mana Seed já presente no projeto.
Não reamostra, não quantiza e não altera os sprites antigos.
"""
from pathlib import Path
from PIL import Image

RAIZ = Path(__file__).resolve().parents[2]
FONTE = RAIZ / 'arte/fontes/cenario/vila_pixel/moveis_topdown.png'
SAIDA = RAIZ / 'assets/cenario/cidade/decoracao/mobiliario/topdown'
RECORTES = {
    'mesa_grande': (0, 0, 64, 40),
    'mesa_media': (72, 0, 120, 32),
    'mesa_pequena': (128, 0, 160, 28),
    'banco': (0, 48, 48, 76),
    'banco_horizontal': (56, 48, 88, 64),
    'banqueta': (96, 48, 112, 64),
    'cadeira': (120, 48, 136, 80),
    'cama': (168, 0, 200, 64),
}


def main():
    fonte = Image.open(FONTE).convert('RGBA')
    SAIDA.mkdir(parents=True, exist_ok=True)
    for nome, caixa in RECORTES.items():
        fonte.crop(caixa).save(SAIDA / (nome + '.png'))
    inverno = FONTE.with_name('moveis_topdown_inverno.png')
    if inverno.exists():
        Image.open(inverno).convert('RGBA').crop(RECORTES['banco']).save(SAIDA / 'banco_inverno.png')
    print('8 móveis ortogonais recortados sem mudança de resolução.')


if __name__ == '__main__':
    main()
