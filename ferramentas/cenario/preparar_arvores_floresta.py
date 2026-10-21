#!/usr/bin/env python3
"""Modelo próprio de árvores, com raiz comum e sem integrar os estudos da referência."""
from pathlib import Path
import colorsys
from PIL import Image

RAIZ=Path(__file__).resolve().parents[2]
FONTE=RAIZ/'arte/fontes/cenario/arvores_nitidas_v2'
NOMES=['spring','summer','autumn','winter']
PT=['primavera','verao','outono','inverno']

def partes_modelo(nome,faixa):
    im=Image.open(FONTE/(nome+'.png')).convert('RGBA')
    im.putalpha(im.getchannel('A').point(lambda a:255 if a>=192 else 0))
    y0,y1=[(0,580),(580,890),(890,im.height)][faixa]
    alfa=im.getchannel('A')
    contagens=[sum(alfa.getpixel((x,y))>0 for y in range(y0,y1)) for x in range(im.width)]
    cortes=[0]
    for e in range(1,4):
        ideal=round(e*im.width/4)
        corte=min(range(ideal-72,ideal+73),key=lambda x:(contagens[x],abs(x-ideal)))
        assert contagens[corte]==0,('modelos sem margem',nome,faixa,e)
        cortes.append(corte)
    cortes.append(im.width)
    return [im.crop((cortes[e],y0,cortes[e+1],y1)) for e in range(4)]

def partes_folhosa(faixa):return partes_modelo('folhosa',faixa)
def partes_conifera():
    # Folha própria 2×2: um abeto de tronco único, sem reutilizar a folhosa.
    im=Image.open(FONTE/'pinheiro_v3.png').convert('RGBA')
    im.putalpha(im.getchannel('A').point(lambda a:255 if a>=192 else 0))
    largura,altura=im.width//2,im.height//2
    return [im.crop((x*largura,y*altura,(x+1)*largura,(y+1)*altura)) for y in range(2) for x in range(2)]

def paleta_com_casca(im,casca_marrom=False):
    """Reserva tons da casca antes da quantização; folhas não absorvem o tronco."""
    alfa=im.getchannel('A')
    rgb=im.convert('RGB')
    amostras=[rgb.getpixel((x,y)) for y in range(round(im.height*.82),im.height) for x in range(im.width) if alfa.getpixel((x,y))]
    if casca_marrom:
        # As agulhas baixas do abeto entram nesta faixa; reservar somente madeira.
        amostras=[p for p in amostras if p[0]>p[1]*1.12 and p[1]>p[2]*1.1 and p[0]>30]
    assert amostras
    casca=Image.new('RGB',(len(amostras),1));casca.putdata(amostras)
    casca=casca.quantize(colors=6,dither=Image.Dither.NONE)
    visiveis=[rgb.getpixel((x,y)) for y in range(round(im.height*.82)) for x in range(im.width) if alfa.getpixel((x,y))]
    folhas=Image.new('RGB',(len(visiveis),1));folhas.putdata(visiveis)
    folhas=folhas.quantize(colors=12,dither=Image.Dither.NONE)
    cores=folhas.getpalette()[:36]+casca.getpalette()[:18]
    paleta=Image.new('P',(1,1));paleta.putpalette(cores+cores[-3:]*((768-len(cores))//3))
    saida=rgb.quantize(palette=paleta,dither=Image.Dither.NONE).convert('RGBA')
    saida.putalpha(alfa)
    return saida

def preparar_quadros(partes,limite,casca_marrom=False):
    recortes=[];ancoras=[]
    for parte in partes:
        parte.putalpha(parte.getchannel('A').point(lambda a:255 if a>=192 else 0))
        caixa=parte.getbbox();assert caixa
        im=parte.crop(caixa);alfa=im.getchannel('A')
        apoio=[x for y in range(round(im.height*.92),im.height) for x in range(im.width) if alfa.getpixel((x,y))]
        recortes.append(im);ancoras.append(caixa[0]+sum(apoio)/len(apoio))
    # Uma escala por família/estágio e uma âncora estável para todas as estações.
    escala=min(limite[0]/max(i.width for i in recortes),limite[1]/max(i.height for i in recortes))
    quadros=[]
    for parte,im,ancora in zip(partes,recortes,ancoras):
        caixa=parte.getbbox()
        im=im.resize((max(1,round(im.width*escala)),max(1,round(im.height*escala))),Image.Resampling.NEAREST)
        im=paleta_com_casca(im,casca_marrom)
        quadro=Image.new('RGBA',(128,128));quadro.alpha_composite(im,(64-round((ancora-caixa[0])*escala),128-im.height))
        quadros.append(quadro)
    return quadros

def preparar_ciclo():
    raiz=RAIZ/'assets/cenario/algoland_original/ciclo_carvalho'
    for nome,faixa,limite in [('muda',1,(24,42)),('jovem',1,(44,78)),('toco',2,(24,12))]:
        for e,quadro in enumerate(preparar_quadros(partes_folhosa(faixa),limite)):
            pasta=raiz/PT[e];pasta.mkdir(parents=True,exist_ok=True);quadro.save(pasta/(nome+'.png'))
            if nome=='muda':
                pequena=quadro.crop(quadro.getbbox());pequena.thumbnail((32,32),Image.Resampling.NEAREST)
                arvoreta=Image.new('RGBA',(32,32));arvoreta.alpha_composite(pequena,((32-pequena.width)//2,32-pequena.height));arvoreta.save(pasta/'arvoreta.png')
                destino=RAIZ/'assets/cenario/substitutos/entulho'/PT[e]/'arvoreta.png'
                if destino.parent.exists():arvoreta.save(destino)

def preparar():
    raiz=RAIZ/'assets/cenario/substitutos/natureza'
    nativos=RAIZ/'arte/fontes/cenario/algoland_original/revisao_mana/nativos'
    for nome,partes in [('arvore',partes_folhosa(0)),('arvore_var',partes_conifera())]:
        for e,quadro in enumerate(preparar_quadros(partes,(72,104) if nome=='arvore' else (56,108),casca_marrom=nome=='arvore_var')):
            quadro.save(raiz/(nome+'_'+NOMES[e]+'.png'))
            if nome=='arvore':quadro.save(nativos/(nome+'_'+NOMES[e]+'.png'))
    preparar_ciclo()
    exportar_ambientes()
    print('Duas espécies próprias, ciclo e tocos com pivô64,127 exportados nas quatro estações.')

def exportar_ambientes():
    """Adapta os dois modelos às telas existentes, mantendo bases e colisões."""
    import re
    raiz=RAIZ/'assets/cenario/substitutos/natureza'
    familias={}
    for especie,prefixo in [('folhosa','arvore'),('pinheiro','arvore_var')]:
        familias[especie]=[Image.open(raiz/f'{prefixo}_{e}.png').convert('RGBA') for e in NOMES]
        pasta=RAIZ/'assets/cenario/substitutos/arvores_cidade'/especie
        pasta.mkdir(parents=True,exist_ok=True)
        for e,im in enumerate(familias[especie]):
            quadro=Image.new('RGBA',(113,109));quadro.alpha_composite(im,(-8,-19))
            folha=Image.new('RGBA',(452,109))
            for frame in range(4):folha.alpha_composite(quadro,(frame*113,0))
            folha.save(pasta/(NOMES[e]+'.png'))
        sombra=Image.new('RGBA',(128,128),(255,255,255,0))
        sombra.putalpha(familias[especie][1].getchannel('A'))
        sombra.save(RAIZ/f'assets/cenario/cidade/sombras/objetos/arvore_{especie}.png')
        for e,nome in enumerate(NOMES):
            sazonal=Image.new('RGBA',(128,128),(255,255,255,0))
            sazonal.putalpha(familias[especie][e].getchannel('A'))
            sazonal.save(RAIZ/f'assets/cenario/cidade/sombras/objetos/arvore_{especie}_{nome}.png')
    for paleta in ['01','02','03']:
        for e,nome in enumerate(NOMES):
            folha=Image.new('RGBA',(160,96))
            for coluna,especie in enumerate(['folhosa','pinheiro']):
                partes=familias[especie]
                escala=min(68/max(im.getbbox()[2]-im.getbbox()[0] for im in partes),90/max(im.getbbox()[3]-im.getbbox()[1] for im in partes))
                im=partes[e].resize((round(128*escala),round(128*escala)),Image.Resampling.NEAREST)
                folha.alpha_composite(im,(coluna*80+40-round(64*escala),96-round(128*escala)))
            destino=RAIZ/f'assets/cenario/substitutos/arvores_florestas/v{paleta}'
            destino.mkdir(parents=True,exist_ok=True)

            if paleta in ['02','03']:
                pixels=[]
                for r,g,b,a in folha.get_flattened_data():
                    h,s,v=colorsys.rgb_to_hsv(r/255,g/255,b/255)
                    if a and .16<h<.46 and s>.2:
                        if paleta=='03':h=min(.49,h+.13);s*=.78;v*=.78
                        else:s*=.95;v*=.90
                        rr,gg,bb=colorsys.hsv_to_rgb(h,s,v)
                        r,g,b=round(rr*255),round(gg*255),round(bb*255)
                    pixels.append((r,g,b,a))
                folha.putdata(pixels)
            folha.save(destino/(nome+'.png'))
    # O abeto e o carvalho estavam apontando para o mesmo modelo.
    for p in [RAIZ/'cenas/terreno_fazenda.tscn',RAIZ/'cenas/terreno.tscn',RAIZ/'cenas/terreno_fenda.tscn',*sorted((RAIZ/'cenas/fendas').glob('terreno_*.tscn'))]:
        s=p.read_text()
        s=re.sub(r'(\[sub_resource type="AtlasTexture" id="Atlas_abeto"\]\n)resource_name = "arvore"',r'\1resource_name = "arvore_var"',s)
        p.write_text(s)

if __name__=='__main__':preparar()
