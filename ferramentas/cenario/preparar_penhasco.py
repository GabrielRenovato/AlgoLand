#!/usr/bin/env python3
"""Integra o paredão gerado na grade original, sem tocar em células/colisões."""
from pathlib import Path
from PIL import Image
import json

RAIZ=Path(__file__).resolve().parents[2]
FONTE=RAIZ/'arte/fontes/cenario/penhasco'
ESTACOES=['spring','summer','autumn','winter']

def montar(estacao,grama):
    origem=Image.open(FONTE/'quatro_estacoes.png').convert('RGBA')
    w,h=origem.width//2,origem.height//2
    x,y=estacao%2*w,estacao//2*h
    painel=origem.crop((x,y,x+w,y+h)).resize((96,64),Image.Resampling.NEAREST)
    # O consumidor repete duas colunas16px; o módulo mantém a mesma fase em todas as estações.
    modulo=painel.crop((63,0,95,64))
    parede=Image.new('RGBA',(96,128))
    for x in range(0,96,16):
        for y in range(0,128,16):parede.paste(grama,(x,y))
    for x in range(0,96,32):parede.paste(modulo,(x,64))
    # A base termina no chão do mapa, sem retângulo de grama de outra paleta.
    for x in range(96):
        for y in range(124,128):parede.putpixel((x,y),grama.getpixel((x%16,y%16)))
    # Só a silhueta geométrica do platô antigo; nenhum pixel de sua arte é copiado.
    mascara=Image.open(RAIZ/'assets/cenario/Seasonal Forest/arena/spring.png').convert('RGBA').crop((80,0,176,128)).getchannel('A')
    parede.putalpha(mascara)
    return parede

def aplicar(atlas,estacao,grama):
    parede=montar(estacao,grama)
    atlas.paste(parede,(80,0))
    # Rodapé próprio para os platôs que terminam na água; preserva geometria original.
    for linha in [11,12]:
        for x in range(6):
            atlas.paste(parede.crop((x*16,96+(linha-11)*16,x*16+16,112+(linha-11)*16)),((5+x)*16,linha*16))
    return atlas

def preparar_faixas():
    import gerar_natureza_original as N
    origem=Image.open(FONTE/'quatro_estacoes.png').convert('RGBA')
    saida=RAIZ/'assets/cenario/substitutos/penhasco'
    saida.mkdir(exist_ok=True)
    for indice,nome in enumerate(ESTACOES):
        grama=N.material('grama',indice)
        w,h=origem.width//2,origem.height//2
        x,y=indice%2*w,indice//2*h
        faixa=origem.crop((x,y,x+w,y+h)).resize((96,64),Image.Resampling.NEAREST)
        for px in range(96):
            for py in range(60,64):faixa.putpixel((px,py),grama.getpixel((px%16,py%16)))
        faixa.save(saida/(nome+'.png'))

def preparar():
    import gerar_natureza_original as N
    preparar_faixas()
    pasta=RAIZ/'assets/cenario/substitutos'
    total=0
    for indice,nome in enumerate(ESTACOES):
        grama=N.material('grama',indice)
        for relativo in ['natureza','fenda_bosque','fendas/andar_06','fendas/andar_10']:
            p=pasta/relativo/(nome+'.png')
            if not p.exists():continue
            atlas=Image.open(p).convert('RGBA');aplicar(atlas,indice,grama).save(p);total+=1
    print(f'Penhasco original integrado em {total} atlas sazonais.')

if __name__=='__main__':preparar()
