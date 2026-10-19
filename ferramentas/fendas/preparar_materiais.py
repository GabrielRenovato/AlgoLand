#!/usr/bin/env python3
"""Prepara materiais pixelados gerados no grid de produção, com amostragem nearest."""
from pathlib import Path
from PIL import Image
RAIZ=Path(__file__).resolve().parents[2]
im=Image.open(RAIZ/'arte/fontes/fendas/materiais_rocha_original.png').convert('RGBA')
for nome,caixa in {'rocha':(0,0,304,1216),'rocha_clara':(632,0,936,1216),'solo':(320,0,624,1216)}.items():
 im.crop(caixa).resize((64,256),Image.Resampling.NEAREST).save(RAIZ/f'assets/cenario/fendas/materiais/{nome}.png')
