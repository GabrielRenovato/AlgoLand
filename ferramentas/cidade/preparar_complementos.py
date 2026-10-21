#!/usr/bin/env python3
"""Peças de cerca conectáveis, placas, portal e galinha canônica da vila."""
from pathlib import Path
from PIL import Image, ImageDraw
import json
import math

RAIZ = Path(__file__).resolve().parents[2]
FONTES = RAIZ/'arte/fontes/cidade/enfeites_detalhados'
SAIDA = RAIZ/'assets/cenario/cidade/complementos'
ESTACOES = ['primavera','verao','outono','inverno']


def salvar(im, p, mip=True):
    p.parent.mkdir(parents=True, exist_ok=True)
    im.save(p)
    imp=p.with_suffix('.png.import')
    if imp.exists():
        s=imp.read_text().replace('mipmaps/generate=false','mipmaps/generate=true') if mip else imp.read_text()
    else:
        s='[remap]\nimporter="texture"\ntype="CompressedTexture2D"\n\n[deps]\nsource_file="res://'+str(p.relative_to(RAIZ))+'"\n\n[params]\nmipmaps/generate='+str(mip).lower()+'\n'
    imp.write_text(s)


def recortar(p):
    im=Image.open(p).convert('RGBA')
    return im.crop(im.getchannel('A').point(lambda a:255 if a>127 else 0).getbbox())


def sazonal(im, e):
    im=im.copy()
    if e:
        cores=[]
        for r,g,b,a in im.get_flattened_data():
            if a and g>r*1.06 and g>b*1.15:
                if e==2:r,g,b=min(255,g+15),round(g*.77),round(b*.8)
                elif e==3:r,g,b=180,198,199
            if e==1:r,g,b=min(255,round(r*1.015)),min(255,round(g*1.01)),b
            elif e==2:r,g,b=round(r*.97),round(g*.965),round(b*.96)
            cores.append((r,g,b,a))
        im.putdata(cores)
    if e==3:
        pixels=im.load()
        for x in range(im.width):
            for y in range(im.height):
                if pixels[x,y][3]<180:continue
                for dy in range(5):
                    if y+dy<im.height and pixels[x,y+dy][3]>128:pixels[x,y+dy]=(227,238,241,pixels[x,y+dy][3]) if dy<3 else (173,196,207,pixels[x,y+dy][3])
                break
    return im


def cercas():
    original=Image.open(FONTES/'cerca.png').convert('RGBA')
    # Um mesmo poste e as mesmas travessas do original maior. Grade, base
    # e espaçamento coincidem com os trechos físicos existentes.
    pontos=[(740,209),(820,209),(858,228),(878,315),(878,372),(876,392),(874,474),(866,479),(862,605),(866,615),(871,699),(857,709),(854,755),(835,765),(721,765),(701,749),(700,700),(691,690),(693,619),(701,608),(701,477),(690,465),(692,385),(700,373),(700,312),(720,233)]
    mascara=Image.new('L',original.size);ImageDraw.Draw(mascara).polygon(pontos,fill=255)
    post=Image.new('RGBA',original.size);post.paste(original,(0,0),mascara)
    post=post.crop((680,200,890,770)).resize((32,92),Image.Resampling.LANCZOS)
    alto=original.crop((285,352,680,474)).resize((64,17),Image.Resampling.LANCZOS)
    baixo=original.crop((285,569,680,698)).resize((64,17),Image.Resampling.LANCZOS)
    horizontal=Image.new('RGBA',(64,92))
    horizontal.alpha_composite(alto,(16,26));horizontal.alpha_composite(baixo,(16,62));horizontal.alpha_composite(post)
    vertical=Image.new('RGBA',(32,188))
    lateral=alto.rotate(90,expand=True).resize((9,119),Image.Resampling.LANCZOS)
    vertical.alpha_composite(lateral,(12,33));vertical.alpha_composite(post,(0,96))
    for e,n in enumerate(ESTACOES):
        for tipo,im in [('poste',post),('horizontal',horizontal),('vertical',vertical)]:salvar(sazonal(im,e),SAIDA/'cercas'/n/(tipo+'.png'))


def portal(im, q):
    original=im.copy();pixels=original.load();saida=im.copy();destino=saida.load()
    # Somente a superfície mágica gira; pilares e pés permanecem fixos.
    a=q*math.tau/9;ca,sa=math.cos(a),math.sin(a)
    cx,cy,rx,ry=96,136,51,82
    for y in range(30,224):
        for x in range(36,156):
            r,g,b,al=pixels[x,y]
            if al<128 or b<r*1.08 or b<g*1.04:continue
            u,v=(x-cx)/rx,(y-cy)/ry
            if u*u+v*v>1:continue
            xx,yy=round(cx+(u*ca-v*sa)*rx),round(cy+(u*sa+v*ca)*ry)
            if 0<=xx<im.width and 0<=yy<im.height:
                rr,gg,bb,aa=pixels[xx,yy]
                if aa>128 and bb>rr*1.05 and bb>gg*.98:destino[x,y]=(rr,gg,bb,al)
    return saida


def main():
    cercas();manifesto={}
    for nome,tamanho,base,quadros in [('placa_saida',(128,152),152,1),('portal',(192,256),232,9)]:
        origem=recortar(FONTES/(nome+'.png'))
        origem.thumbnail((tamanho[0]-8,base-8),Image.Resampling.LANCZOS)
        im=Image.new('RGBA',tamanho);im.alpha_composite(origem,((tamanho[0]-origem.width)//2,base-origem.height))
        caminhos=[]
        for e,n in enumerate(ESTACOES):
            estacao=sazonal(im,e);folha=Image.new('RGBA',(tamanho[0]*quadros,tamanho[1]))
            for q in range(quadros):folha.alpha_composite(portal(estacao,q) if nome=='portal' else estacao,(q*tamanho[0],0))
            p=SAIDA/nome/(n+'.png');salvar(folha,p);caminhos.append('res://'+str(p.relative_to(RAIZ)))
        manifesto[nome]={'texturas':caminhos,'resolucao':4,'quadros':quadros,'fps':8 if quadros>1 else 0}
        if nome=='portal':
            sombra=Image.new('RGBA',im.size,(255,255,255,0));sombra.putalpha(im.getchannel('A'));salvar(sombra,RAIZ/'assets/cenario/cidade/sombras/objetos/portal.png')
    # A animação canônica mantém corpo, patas e fases de bicar, com pivô fixo.
    ave=Image.open(RAIZ/'assets/cenario/fazenda/galinheiro/galinha_white.png').convert('RGBA').crop((0,33,64,48))
    p=SAIDA/'aves/galinha_bento.png';salvar(ave,p,False)
    manifesto['mobiliario/galinha']={'texturas':['res://'+str(p.relative_to(RAIZ))]*4,'resolucao':1,'quadros':4,'fps':3.57,'fonte':'res://assets/cenario/fazenda/galinheiro/galinha_white.png'}
    (SAIDA/'manifesto.json').write_text(json.dumps(manifesto,indent=2)+'\n')
    print('Complementos: cercas/placas/portal4x, quatro estações, ave canônica.')


if __name__=='__main__':main()
