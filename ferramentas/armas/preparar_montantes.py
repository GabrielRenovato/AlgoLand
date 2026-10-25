#!/usr/bin/env python3
"""Integra o desenho nativo PixelLab ao rig Raven, sem redimensionar a arte.

Somente recorta o atlas e aplica rotações rígidas nas pegadas da espada original.
O quadro de passagem mantém o arco original; nunca exibe duas lâminas.
"""
from pathlib import Path
from math import atan2, cos, sin, pi
import json
from PIL import Image

RAIZ = Path(__file__).resolve().parents[2]
IDS = ['montante_ferro','montante_sentinela','montante_geada','montante_trovao','montante_astral']
CORES_ARCO = [('727c7f','a8b3b0','e0e4cf'),('53694f','91a784','d8dfb0'),('3a6482','83b8ce','dcf4ed'),('36344f','54506f','a5e3e0'),('8a82ab','c8c8df','f4edc9')]
PIVO = (12,23)
COURO = (116,92,66,255)
# No fim do golpe o punho está sob o corpo, fora da máscara visível da lâmina.
PUNHOS_FINAIS = [(44,36),(44,37),(35,40),(36,37)]
PONTAS_FINAIS = [(53,18),(53,20),(20,36),(26,20)]

def pontos(im):
    return [(x,y) for y in range(im.height) for x in range(im.width) if im.getpixel((x,y))[3]>127]

def renderizar(sprite, tamanho, pivo_alvo, angulo, cabo=False):
    """Amostragem inversa de pixels inteiros; mantém dimensão e pegada do original."""
    saida=Image.new('RGBA',tamanho)
    c,s=cos(angulo),sin(angulo)
    for y in range(tamanho[1]):
        for x in range(tamanho[0]):
            dx,dy=x-pivo_alvo[0],y-pivo_alvo[1]
            sx=round(c*dx+s*dy+PIVO[0]);sy=round(-s*dx+c*dy+PIVO[1])
            if 0<=sx<sprite.width and 0<=sy<sprite.height and (not cabo or sy>=21):
                saida.putpixel((x,y),sprite.getpixel((sx,sy)))
    return saida

def preparar():
    fonte=RAIZ/'arte/fontes/armas/linha_montantes/montantes_nativos.png'
    desenhos=Image.open(fonte).convert('RGBA')
    assert desenhos.size==(120,32)
    nativa=Image.open(RAIZ/'assets/personagens/raven_fantasy/web/ferramentas/espada_dupla.png').convert('RGBA')
    contrato={'fonte':str(fonte.relative_to(RAIZ)), 'pixellab_id':'fb3b7ee2-b0b1-4701-b183-0a526d4319b0','grade':[80,80], 'folha':[320,320], 'pivo_desenho':PIVO,'quadros':4,'direcoes':['frente','direita','costas','esquerda'],'modelos':{},'poses':{}}
    for i,tipo in enumerate(IDS):
        pasta=RAIZ/'assets/personagens/armas/montantes'/tipo;pasta.mkdir(parents=True,exist_ok=True)
        sprite=desenhos.crop((i*24,0,i*24+24,32))
        sprite.save(RAIZ/'arte/fontes/armas'/tipo/'sprite_nativo.png')
        sprite.crop(sprite.getbbox()).save(RAIZ/'assets/personagens/raven_fantasy/icones'/f'{tipo}.png')
        atlas=Image.new('RGBA',(320,320))
        for d in range(4):
            for q in range(4):
                celula=nativa.crop((q*80,d*80,q*80+80,d*80+80))
                if q==2:
                    mapa=dict(zip([(164,154,126,255),(201,190,159,255),(241,235,217,255)], [tuple(bytes.fromhex(c))+(255,) for c in CORES_ARCO[i]]))
                    celula.putdata([mapa.get(c,c) for c in celula.getdata()])
                else:
                    ps=pontos(celula)
                    couro=[p for p in ps if celula.getpixel(p)==COURO]
                    if couro:
                        punho=tuple(sum(p[k] for p in couro)/len(couro) for k in (0,1))
                        ponta=max(ps,key=lambda p:sum((p[k]-punho[k])**2 for k in (0,1)))
                    else:punho,ponta=PUNHOS_FINAIS[d],PONTAS_FINAIS[d]
                    angulo=atan2(ponta[1]-punho[1],ponta[0]-punho[0])+pi/2
                    contrato['poses'][f'{d}:{q}']={'punho':punho,'angulo':angulo}
                    celula=renderizar(sprite,(80,80),punho,angulo)
                caixa=celula.getbbox()
                assert caixa and caixa[0]>0 and caixa[1]>0 and caixa[2]<80 and caixa[3]<80,(tipo,d,q,caixa)
                atlas.alpha_composite(celula,(q*80,d*80))
        atlas.save(pasta/'espada_dupla.png')
        # Mesma origem física do retângulo de porte original, com margem para guarda.
        angulo=-2.20032596588135+pi/2
        for cabo in (False,True):
            renderizar(sprite,(40,48),(23,31),angulo,cabo).save(pasta/('cabo.png' if cabo else 'porte.png'))
        contrato['modelos'][tipo]={'sprite':[24,32],'icone':list(sprite.crop(sprite.getbbox()).size),'porte':[40,48]}
    (RAIZ/'arte/fontes/armas/linha_montantes/contrato.json').write_text(json.dumps(contrato,indent=2)+'\n')
    print('Cinco montantes: 80 quadros, cinco portes e cinco máscaras de cabo; sem escala ou alteração da espada original.')

if __name__=='__main__':preparar()
