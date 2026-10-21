#!/usr/bin/env python3
"""Prepara folhas geradas para os quadros e pivôs já usados nos mapas."""
from pathlib import Path
from statistics import median
from PIL import Image
import json

RAIZ=Path(__file__).resolve().parents[2]
FONTES=RAIZ/'arte/fontes/cenario/arbustos_pedras'
SAIDA=RAIZ/'assets/cenario/algoland_original/arbustos_pedras'
ESTACOES=['primavera','verao','outono','inverno']

def faixas(contagens,minimo,intervalo=10):
    indices=[i for i,n in enumerate(contagens) if n>=minimo]
    grupos=[]
    for i in indices:
        if not grupos or i-grupos[-1][-1]>intervalo:grupos.append([])
        grupos[-1].append(i)
    return [(g[0],g[-1]+1) for g in grupos if len(g)>12]

def recortes(caminho,colunas):
    im=Image.open(caminho).convert('RGBA')
    im.putalpha(im.getchannel('A').point(lambda a:255 if a>=128 else 0))
    alfa=im.getchannel('A')
    linhas=faixas([sum(alfa.getpixel((x,y))>0 for x in range(im.width)) for y in range(im.height)],8)
    assert len(linhas)==4,(caminho,linhas)
    resultados=[]
    for y0,y1 in linhas:
        horizontais=faixas([sum(alfa.getpixel((x,y))>0 for y in range(y0,y1)) for x in range(im.width)],4)
        assert len(horizontais)==colunas,(caminho,horizontais)
        resultados.append([(im.crop((x0,y0,x1,y1)),x0) for x0,x1 in horizontais])
    return resultados

def exportar(conjunto,coluna,nome,quadro,limite,cores,preencher=False):
    partes=[linha[coluna] for linha in conjunto]
    # Escala única por modelo e âncora horizontal comum às quatro estações.
    escala=min(limite[0]/max(im.width for im,x in partes),limite[1]/max(im.height for im,x in partes))
    escala_x=limite[0]/max(im.width for im,x in partes) if preencher else escala
    escala_y=limite[1]/max(im.height for im,x in partes) if preencher else escala
    ancora=median(x+im.width/2 for im,x in partes)
    for e,(im,x0) in enumerate(partes):
        im=im.resize((max(1,round(im.width*escala_x)),max(1,round(im.height*escala_y))),Image.Resampling.NEAREST)
        alfa=im.getchannel('A')
        im=im.convert('RGB').quantize(colors=cores,dither=Image.Dither.NONE).convert('RGBA');im.putalpha(alfa)
        out=Image.new('RGBA',quadro)
        dx=quadro[0]//2-round((ancora-x0)*escala_x)
        out.alpha_composite(im,(dx,quadro[1]-im.height))
        pasta=SAIDA/ESTACOES[e];pasta.mkdir(parents=True,exist_ok=True)
        out.save(pasta/(nome+'.png'))

def main():
    pedras=recortes(RAIZ/'arte/fontes/cenario/nitidez/pedras_v2.png',4)
    for i in range(4):
        exportar(pedras,i,f'pedra_{i}',(16,16),(15,10),10)
        exportar(pedras,i,f'pedra_grande_{i}',(32,32),(30,20),20)
    dados={'gerador':'image_gen integrado; revisão das faces para leitura em16x16, fontes em arte/fontes/cenario/nitidez/',
           'preparador':'ferramentas/cenario/preparar_arbustos_pedras.py',
           'estacoes':ESTACOES,'escala':'fixa por modelo entre estações; alpha rígido e vizinho mais próximo',
           'arbustos':'rejeitados pelo usuário; fontes arquivadas, sem exportação ou uso no jogo',
           'quadros':{'pedras':[16,16],'pedras_grandes':[32,32]},
           'saida':str(SAIDA.relative_to(RAIZ))}
    (FONTES/'manifesto.json').write_text(json.dumps(dados,ensure_ascii=False,indent=2)+'\n')
    print('32 quadros sazonais de pedras preparados; bases e grade preservadas.')

if __name__=='__main__':main()
