#!/usr/bin/env python3
"""Recorta as gerações do ciclo sem trocar os pivôs entre as estações."""
from pathlib import Path
from PIL import Image

RAIZ=Path(__file__).resolve().parents[2]
FONTE=RAIZ/'arte/fontes/cenario/ciclo_carvalho'
SAIDA=RAIZ/'assets/cenario/algoland_original/ciclo_carvalho'
ESTACOES=['primavera','verao','outono','inverno']
ESTAGIOS=[('semente',(10,8)),('broto',(16,20)),('muda',(32,42)),('jovem',(64,78))]

def recortar_ciclo():
    """A folha nova tem cinco colunas; detecta as quatro bases em cada coluna.

    As linhas não são uniformes na geração: recortar em quartos corta copas.
    """
    im=Image.open(RAIZ/'arte/fontes/cenario/nitidez/ciclo.png').convert('RGBA')
    im.putalpha(im.getchannel('A').point(lambda a:255 if a>=128 else 0))
    assert im.size==(1402,1122), 'Revisar recortes ao substituir a fonte do ciclo.'
    colunas=[]
    for x0,x1 in [(0,280),(280,500),(500,730),(730,1060),(1060,1402)]:
        alfa=im.getchannel('A')
        indices=[y for y in range(im.height) if sum(alfa.getpixel((x,y))>0 for x in range(x0,x1))>=3]
        grupos=[]
        for y in indices:
            if not grupos or y-grupos[-1][-1]>2:grupos.append([])
            grupos[-1].append(y)
        faixas=[(g[0],g[-1]+1) for g in grupos if len(g)>10]
        assert len(faixas)==4,(x0,faixas)
        partes=[]
        for y0,y1 in faixas:
            parte=im.crop((x0,y0,x1,y1));caixa=parte.getbbox()
            partes.append((parte.crop(caixa),x0+caixa[0]))
        colunas.append(partes)
    return colunas


def preparar_variantes(partes,limite):
    from statistics import median
    escala=min(limite[0]/max(im.width for im,x in partes),limite[1]/max(im.height for im,x in partes))
    ancora=median(x+im.width/2 for im,x in partes)
    resultados=[]
    for im,x0 in partes:
        im=im.resize((max(1,round(im.width*escala)),max(1,round(im.height*escala))),Image.Resampling.NEAREST)
        alfa=im.getchannel('A')
        im=im.convert('RGB').quantize(colors=20,dither=Image.Dither.NONE).convert('RGBA');im.putalpha(alfa)
        quadro=Image.new('RGBA',(128,128))
        quadro.alpha_composite(im,(64-round((ancora-x0)*escala),128-im.height))
        resultados.append(quadro)
    return resultados


def main():
    colunas=recortar_ciclo()
    for coluna,(nome,tamanho) in enumerate(ESTAGIOS+[('toco',(36,17))]):
        quadros=preparar_variantes(colunas[coluna],tamanho)
        for e,estacao in enumerate(ESTACOES):
            pasta=SAIDA/estacao;pasta.mkdir(parents=True,exist_ok=True)
            quadro=quadros[e];quadro.save(pasta/f'{nome}.png')
            if nome=='muda':
                pequena=quadro.crop(quadro.getbbox())
                pequena.thumbnail((32,32),Image.Resampling.NEAREST)
                arvoreta=Image.new('RGBA',(32,32))
                arvoreta.alpha_composite(pequena,((32-pequena.width)//2,32-pequena.height))
                arvoreta.save(pasta/'arvoreta.png')
    from preparar_arvores_floresta import preparar_ciclo
    preparar_ciclo()
    print('20 quadros do ciclo e quatro arvoretas preparados nas quatro estações.')

if __name__=='__main__':main()
