#!/usr/bin/env python3
"""Recorta os nove ícones da fonte, preservando o original e a grade de inventário."""
from pathlib import Path
import json
from PIL import Image

raiz = Path(__file__).resolve().parents[2]
contrato = json.loads((raiz/'arte/fontes/coletaveis/geracao.json').read_text())
origem = Image.open(raiz/'arte/fontes/coletaveis/icones.png').convert('RGBA')
for i, nome in enumerate(contrato['ordem']):
    x, y = i % 3, i // 3
    imagem = origem.crop((round(x*origem.width/3), round(y*origem.height/3),
                         round((x+1)*origem.width/3), round((y+1)*origem.height/3)))
    usado = imagem.getchannel('A').point(lambda a: 255 if a >= 128 else 0).getbbox()
    imagem = imagem.crop(usado)
    fator = 16/max(imagem.size)
    imagem = imagem.resize((round(imagem.width*fator),round(imagem.height*fator)),Image.Resampling.NEAREST)
    quadro = Image.new('RGBA',(16,16))
    quadro.paste(imagem,((16-imagem.width)//2,(16-imagem.height)//2))
    quadro.save(raiz/f'assets/ui/coletaveis/{nome}.png')
