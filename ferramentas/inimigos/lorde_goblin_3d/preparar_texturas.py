"""Separa as oito células do atlas gerado sem redesenhar ou redimensionar."""
from pathlib import Path
from PIL import Image

RAIZ = Path(__file__).resolve().parents[3]
origem = RAIZ / 'arte/fontes/inimigos/lorde_goblin_3d/atlas_materiais.png'
destino = RAIZ / 'assets/inimigos/lorde_goblin_3d'
destino.mkdir(parents=True, exist_ok=True)
imagem = Image.open(origem)
largura, altura = imagem.size
for indice, nome in enumerate(['pele', 'ferro', 'couro', 'manto', 'pedra', 'marfim', 'madeira', 'corda']):
    x, y = indice % 4, indice // 4
    imagem.crop((x*largura//4, y*altura//2, (x+1)*largura//4, (y+1)*altura//2)).save(destino / (nome+'.png'))
