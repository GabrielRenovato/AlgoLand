"""Piso ilustrado em camada estática, recortado pela planta física do subterrâneo.

Referência de composição: arte/fontes/fendas/mina/conceito_andar_03.png.
Escala nativa, objetos e paredes permanecem separados da pintura de chão.
"""
from pathlib import Path
import math
from PIL import Image,ImageDraw,ImageFilter,ImageChops

RAIZ=Path(__file__).resolve().parents[2]


def pontos_suaves(pontos):
    """Arredonda as curvas dos trilhos sem mudar as ligações entre salas."""
    saida=[pontos[0]]
    for a,b,c in zip(pontos,pontos[1:],pontos[2:]):
        def aproximar(p,q):
            d=math.dist(p,q);f=min(48/d,.25)
            return (p[0]+(q[0]-p[0])*f,p[1]+(q[1]-p[1])*f)
        antes=aproximar(b,a);depois=aproximar(b,c)
        saida.append(antes)
        for i in range(1,17):
            t=i/16;u=1-t
            saida.append((u*u*antes[0]+2*u*t*b[0]+t*t*depois[0],u*u*antes[1]+2*u*t*b[1]+t*t*depois[1]))
    saida.append(pontos[-1])
    return saida


def trilhos(im,pontos,origem,mascara):
    camada=Image.new('RGBA',im.size);desenho=ImageDraw.Draw(camada)
    pontos=[(x-origem[0],y-origem[1]) for x,y in pontos_suaves(pontos)]
    lados=[[],[]];acumulado=0
    for i,(x,y) in enumerate(pontos):
        a=pontos[max(0,i-1)];b=pontos[min(len(pontos)-1,i+1)]
        dx,dy=b[0]-a[0],b[1]-a[1];d=max(1,math.hypot(dx,dy));nx,ny=-dy/d,dx/d
        for lado,sinal in enumerate([-1,1]):lados[lado].append((round(x+nx*7*sinal),round(y+ny*7*sinal)))
        if i==len(pontos)-1:continue
        bx,by=pontos[i+1];comprimento=math.hypot(bx-x,by-y)
        passo=14-acumulado
        while passo<comprimento:
            f=passo/max(1,comprimento);cx=x+(bx-x)*f;cy=y+(by-y)*f
            desenho.line([(round(cx-nx*11),round(cy-ny*11)),(round(cx+nx*11),round(cy+ny*11))],fill=(49,38,29,255),width=4)
            desenho.line([(round(cx-nx*10),round(cy-ny*10-1)),(round(cx+nx*10),round(cy+ny*10-1))],fill=(101,76,49,255),width=2)
            passo+=14
        acumulado=(acumulado+comprimento)%14
    for lado in lados:
        desenho.line([(x+1,y+2) for x,y in lado],fill=(29,27,25,255),width=4)
        desenho.line(lado,fill=(65,66,62,255),width=3)
        desenho.line([(x,y-1) for x,y in lado],fill=(156,150,125,255),width=1)
    camada.putalpha(ImageChops.multiply(camada.getchannel('A'),mascara))
    im.alpha_composite(camada)


def integrar(texto,p,m,objetos):
    fonte=Image.open(RAIZ/'assets/cenario/fendas/mina/piso.png').convert('RGBA')
    piso=Image.new('RGBA',m.mascara_piso.size)
    ox,oy=m.origem_piso
    # A origem global mantém as emendas no mesmo lugar ao regenerar o mapa.
    for y in range(-(oy%fonte.height),piso.height,fonte.height):
        for x in range(-(ox%fonte.width),piso.width,fonte.width):
            parte=fonte
            if ((x+ox)//fonte.width)%2:parte=parte.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
            if ((y+oy)//fonte.height)%2:parte=parte.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
            piso.paste(parte,(x,y))
    piso.putalpha(m.mascara_piso)
    if p['bioma']=='caverna_mina':
        por_id={s['id']:s['centro'] for s in p['setores']}
        trilhos(piso,[por_id[k] for k in ['entrada','area_1','area_3','area_4','guardiao']],m.origem_piso,m.mascara_piso)
        trilhos(piso,[por_id[k] for k in ['area_1','area_2','area_5']],m.origem_piso,m.mascara_piso)
    pasta=RAIZ/f'assets/cenario/fendas/andar_{p["andar"]:02}'
    piso.save(pasta/'piso_subterraneo.png')
    ext=f'[ext_resource type="Texture2D" path="res://assets/cenario/fendas/andar_{p["andar"]:02}/piso_subterraneo.png" id="piso_subterraneo"]\n'
    texto=texto.replace('[sub_resource',ext+'[sub_resource',1)
    texto+=f'\n[node name="PisoSubterraneo" type="Sprite2D" parent="."]\nposition = Vector2({ox}, {oy})\nz_index = -998\ntexture_filter = 1\ntexture = ExtResource("piso_subterraneo")\ncentered = false\nscript = ExtResource("caverna_sazonal")\n'
    return texto
