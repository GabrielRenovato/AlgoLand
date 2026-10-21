#!/usr/bin/env python3
"""Prepara arte 4x da fazenda; conserva grade, bases e máscaras físicas originais."""
from pathlib import Path
import sys
import colorsys
import json
from PIL import Image

RAIZ = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(RAIZ/'ferramentas/cidade'))
from preparar_chao_detalhado import periodizar

FONTES = RAIZ/'arte/fontes/fazenda/natureza_atual'
SAIDA = RAIZ/'assets/cenario/fazenda/natureza_detalhada'
ESTACOES = ['primavera', 'verao', 'outono', 'inverno']


def salvar(im, nome, e):
    p=SAIDA/ESTACOES[e]/(nome+'.png')
    p.parent.mkdir(parents=True,exist_ok=True)
    im.save(p)
    imp=p.with_suffix('.png.import')
    s=imp.read_text().replace('mipmaps/generate=false','mipmaps/generate=true') if imp.exists() else '[remap]\nimporter="texture"\ntype="CompressedTexture2D"\n\n[deps]\nsource_file="res://'+str(p.relative_to(RAIZ))+'"\n\n[params]\nmipmaps/generate=true\n'
    imp.write_text(s)


def estacao(im,e,especie=''):
    im=im.convert('RGBA').copy()
    if not e: return im
    cores=[]
    for r,g,b,a in im.get_flattened_data():
        verde=g>r*1.04 and g>b*1.15
        if verde and e==1:r,g,b=round(r*.86),round(g*.94),round(b*.87)
        elif verde and e==2 and especie!='pinheiro':
            h,s,v=colorsys.rgb_to_hsv(r/255,g/255,b/255)
            r,g,b=[round(c*255) for c in colorsys.hsv_to_rgb(.065+(h-.16)*.13,min(.86,s*.95),v*.98)]
        elif e==3:
            r,g,b=round(r*.88),round(g*.92),min(255,round(b*1.07))
        elif e==2:r,g,b=round(r*.96),round(g*.955),round(b*.94)
        cores.append((r,g,b,a))
    im.putdata(cores)
    return im


def neve_apoios(im,profundidade=6):
    """Neve só nas superfícies expostas de cada segmento, nunca na face inteira."""
    im=im.convert('RGBA').copy();p=im.load()
    original=im.copy().load()
    for x in range(im.width):
        for y in range(im.height):
            if original[x,y][3]<180:continue
            acima=original[x,y-1][3] if y else 0
            if acima>80:continue
            for dy in range(profundidade):
                if y+dy>=im.height:break
                r,g,b,a=original[x,y+dy]
                if a<128:break
                t=.94 if dy<profundidade*.6 else .55
                p[x,y+dy]=tuple(round(c*(1-t)+n*t) for c,n in zip((r,g,b),(225,236,240)))+(a,)
    return im


def arvore(nome):
    origem=Image.open(FONTES/(nome+'.png')).convert('RGBA')
    caixa=origem.getchannel('A').point(lambda a:255 if a>127 else 0).getbbox()
    recorte=origem.crop(caixa)
    escala=min((72 if nome=='carvalho' else 56)*4/recorte.width,(104 if nome=='carvalho' else 108)*4/recorte.height)
    tamanho=(round(recorte.width*escala),round(recorte.height*escala))
    for e in range(4):
        im=estacao(recorte,e,nome)
        if nome=='carvalho' and e==3:
            # A edição conserva o canvas e as raízes; mesmo recorte e escala da primavera.
            im=Image.open(FONTES/'carvalho_inverno.png').convert('RGBA').crop(caixa)
        im=im.resize(tamanho,Image.Resampling.LANCZOS)
        if nome=='pinheiro' and e==3:im=neve_apoios(im,8)
        quadro=Image.new('RGBA',(512,512));quadro.alpha_composite(im,(256-im.width//2,508-im.height))
        salvar(quadro,nome,e)
        if nome=='carvalho':
            for estagio,fator in [('muda',.40),('jovem',.75)]:
                jovem=im.resize((round(im.width*fator),round(im.height*fator)),Image.Resampling.LANCZOS)
                tela=Image.new('RGBA',(512,512));tela.alpha_composite(jovem,(256-jovem.width//2,508-jovem.height));salvar(tela,estagio,e)
            pequena=im.copy();pequena.thumbnail((96,120),Image.Resampling.LANCZOS)
            tela=Image.new('RGBA',(128,128));tela.alpha_composite(pequena,((128-pequena.width)//2,128-pequena.height));salvar(tela,'arvoreta',e)


def main():
    arvore('carvalho');arvore('pinheiro')
    pedra=Image.open(FONTES/'pedra.png').convert('RGBA');pedra=pedra.crop(pedra.getchannel('A').point(lambda a:255 if a>127 else 0).getbbox())
    for e in range(4):
        terra=periodizar(Image.open(FONTES/'terra.png').resize((512,512),Image.Resampling.LANCZOS)).convert('RGBA')
        salvar(estacao(terra,e),'terra',e)
        parede=Image.open(FONTES/'barranco.png').convert('RGB').resize((768,256),Image.Resampling.LANCZOS)
        # Periodizar apenas horizontalmente; não ligar a grama do topo ao pé da rocha.
        p=parede.load()
        for y in range(parede.height):
            a,b=p[0,y],p[parede.width-1,y]
            for x in range(16):
                t=.5*(1-x/16)**2
                for lado,sinal in [(x,1),(parede.width-1-x,-1)]:
                    p[lado,y]=tuple(max(0,min(255,round(c+sinal*(bb-aa)*t))) for c,aa,bb in zip(p[lado,y],a,b))
        parede=estacao(parede,e)
        if e==3:
            pixels=parede.load()
            for y in range(22):
                for x in range(parede.width):
                    r,g,b,a=pixels[x,y]
                    if g>r*.90 and g>b*1.15:
                        pixels[x,y]=(218,230,234,a)
        salvar(parede,'barranco',e)
        for v in range(4):
            antigo=Image.open(RAIZ/f'assets/cenario/substitutos/entulho/primavera/pedra_{v}.png').convert('RGBA')
            caixa=antigo.getbbox();assert caixa
            rocha=pedra.transpose(Image.Transpose.FLIP_LEFT_RIGHT) if v%2 else pedra.copy()
            rocha=rocha.resize(((caixa[2]-caixa[0])*4,(caixa[3]-caixa[1])*4),Image.Resampling.LANCZOS)
            rocha=estacao(rocha,e)
            if e==3:rocha=neve_apoios(rocha,5)
            tela=Image.new('RGBA',(64,64));tela.alpha_composite(rocha,(caixa[0]*4,caixa[1]*4));salvar(tela,f'pedra_{v}',e)
    (SAIDA/'manifesto.json').write_text(json.dumps({'resolucao':4,'estacoes':ESTACOES,'canvas_arvore':[512,512],'pivo_arvore':[256,508],'grade_fisica':16},indent=2)+'\n')
    print('Natureza detalhada: barranco, terra, duas árvores, crescimento e quatro pedras; quatro estações.')


if __name__=='__main__':main()
