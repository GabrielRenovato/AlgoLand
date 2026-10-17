#!/usr/bin/env python3
"""Extrai quadros de mesma tela, sem recorte independente ou filtro suave."""
from pathlib import Path
from PIL import Image
RAIZ=Path(__file__).resolve().parents[2]
ESTACOES=['primavera','verao','outono','inverno']

def extrair(fonte,destino,tamanho):
    folha=Image.open(RAIZ/fonte).convert('RGBA')
    pasta=RAIZ/destino
    pasta.mkdir(parents=True,exist_ok=True)
    for i,estacao in enumerate(ESTACOES):
        quadro=folha.crop((i*folha.width//4,0,(i+1)*folha.width//4,folha.height))
        quadro.resize(tamanho,Image.Resampling.NEAREST).save(pasta/f'{estacao}.png')

if __name__=='__main__':
    extrair('arte/fontes/cenario/placas/placa_sazonal.png','assets/cenario/cidade/placas',(32,40))
    extrair('arte/fontes/praia/revisao/conchas_sazonais.png','assets/cenario/praia/conchas',(24,24))
    fonte=RAIZ/'arte/fontes/praia/revisao/vaso_sazonal.png'
    if fonte.exists():
        extrair(str(fonte.relative_to(RAIZ)),'assets/cenario/praia/vasos',(16,24))
