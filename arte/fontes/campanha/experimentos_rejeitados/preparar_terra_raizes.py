#!/usr/bin/env python3
"""Separa os quatro tiles opacos de terra e raízes do atlas sazonal."""
from pathlib import Path
from PIL import Image
RAIZ = Path(__file__).resolve().parents[2]

def main():
    imagem = Image.open(RAIZ / 'arte/fontes/campanha/terra_raizes/atlas.png').convert('RGB')
    largura, altura = imagem.size
    for i, estacao in enumerate(['primavera', 'verao', 'outono', 'inverno']):
        x, y = i % 2, i // 2
        tile = imagem.crop((x*largura//2,y*altura//2,(x+1)*largura//2,(y+1)*altura//2))
        pasta = RAIZ / 'assets/cenario/campanha/clareiras' / estacao
        pasta.mkdir(parents=True,exist_ok=True)
        tile.resize((512,512),Image.Resampling.LANCZOS).save(pasta/'terra_raizes.png')

if __name__ == '__main__': main()
