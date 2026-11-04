#!/usr/bin/env python3
"""Separa o atlas sazonal em quadros fixos, preservando as margens entre variantes."""
from pathlib import Path
from PIL import Image
RAIZ = Path(__file__).resolve().parents[2]

def main():
    imagem = Image.open(RAIZ / 'arte/fontes/campanha/clareiras/atlas.png').convert('RGBA')
    largura, altura = imagem.size
    for linha, estacao in enumerate(['primavera', 'verao', 'outono', 'inverno']):
        pasta = RAIZ / 'assets/cenario/campanha/clareiras' / estacao
        pasta.mkdir(parents=True, exist_ok=True)
        for coluna, nome in enumerate(['solo', 'resgate', 'ruina', 'raizes']):
            quadro = imagem.crop((coluna*largura//4, linha*altura//4, (coluna+1)*largura//4, (linha+1)*altura//4))
            quadro.resize((384,384), Image.Resampling.LANCZOS).save(pasta / (nome+'.png'))

if __name__ == '__main__':
    main()
