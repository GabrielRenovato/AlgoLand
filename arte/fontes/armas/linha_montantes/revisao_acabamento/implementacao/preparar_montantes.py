#!/usr/bin/env python3
"""Integra desenhos de montantes ao rig Raven, preservando pegada e detalhe.

Desenho com densidade 2: 48x64 pixels, exibido em 24x32 unidades do mundo.
Amostra cada pose uma vez. O porte não volta a ser rotacionado pelo motor.
"""
from pathlib import Path
from math import atan2, cos, sin, pi
import json
from PIL import Image

RAIZ = Path(__file__).resolve().parents[2]
IDS = ['montante_ferro','montante_sentinela','montante_geada','montante_trovao','montante_astral']
CORES_ARCO = [('727c7f','a8b3b0','e0e4cf'),('53694f','91a784','d8dfb0'),('3a6482','83b8ce','dcf4ed'),('36344f','54506f','a5e3e0'),('8a82ab','c8c8df','f4edc9')]
DENSIDADE=2
CELULA=160
PIVO=(24,48)
COURO=(116,92,66,255)
PUNHOS_FINAIS=[(44,36),(44,37),(35,40),(36,37)]
PONTAS_FINAIS=[(53,18),(53,20),(20,36),(26,20)]
FONTES=RAIZ/'arte/fontes/armas/linha_montantes'

def pontos(im):
    return [(x,y) for y in range(im.height) for x in range(im.width) if im.getpixel((x,y))[3]>127]

def renderizar(sprite,tamanho,pivo_alvo,angulo,cabo=False):
    """Amostragem inversa mantém a grade detalhada, sem duas rotações consecutivas."""
    saida=Image.new('RGBA',tamanho);c,s=cos(angulo),sin(angulo)
    for y in range(tamanho[1]):
        for x in range(tamanho[0]):
            dx,dy=x-pivo_alvo[0],y-pivo_alvo[1]
            sx=round(c*dx+s*dy+PIVO[0]);sy=round(-s*dx+c*dy+PIVO[1])
            if 0<=sx<sprite.width and 0<=sy<sprite.height and (not cabo or sy>=44):
                saida.putpixel((x,y),sprite.getpixel((sx,sy)))
    return saida

def preparar():
    desenhos=Image.open(FONTES/'montantes_nativos.png').convert('RGBA')
    nativa=Image.open(RAIZ/'assets/personagens/raven_fantasy/web/ferramentas/espada_dupla.png').convert('RGBA')
    poses_porte=json.loads((RAIZ/'assets/personagens/raven_fantasy/porte_costas.json').read_text())['armas']['espada_dupla']
    contrato={'fonte':'arte/fontes/armas/linha_montantes/revisao_acabamento','densidade':DENSIDADE,'grade':[160,160],'folha':[640,640],'pivo_desenho':PIVO,'quadros':4,'direcoes':['frente','direita','costas','esquerda'],'rotacoes_por_pose':1,'modelos':{},'poses':{}}
    for i,tipo in enumerate(IDS):
        fonte=FONTES/'revisao_acabamento'/f'{tipo}.png'
        if fonte.exists():sprite=Image.open(fonte).convert('RGBA')
        else:
            sprite=Image.new('RGBA',(48,64));sprite.alpha_composite(desenhos.crop((i*24,0,i*24+24,31)).resize((48,62),Image.Resampling.NEAREST),(0,2))
        assert sprite.size==(48,64)
        pasta=RAIZ/'assets/personagens/armas/montantes'/tipo;pasta.mkdir(parents=True,exist_ok=True)
        sprite.save(RAIZ/'arte/fontes/armas'/tipo/'sprite_nativo.png')
        sprite.crop(sprite.getbbox()).save(RAIZ/'assets/personagens/raven_fantasy/icones'/f'{tipo}.png')
        atlas=Image.new('RGBA',(640,640))
        for d in range(4):
            for q in range(4):
                celula=nativa.crop((q*80,d*80,q*80+80,d*80+80))
                if q==2:
                    mapa=dict(zip([(164,154,126,255),(201,190,159,255),(241,235,217,255)],[tuple(bytes.fromhex(c))+(255,) for c in CORES_ARCO[i]]))
                    celula.putdata([mapa.get(c,c) for c in celula.getdata()]);celula=celula.resize((160,160),Image.Resampling.NEAREST)
                else:
                    ps=pontos(celula);couro=[p for p in ps if celula.getpixel(p)==COURO]
                    if couro:
                        punho=tuple(sum(p[k] for p in couro)/len(couro) for k in (0,1))
                        ponta=max(ps,key=lambda p:sum((p[k]-punho[k])**2 for k in (0,1)))
                    else:punho,ponta=PUNHOS_FINAIS[d],PONTAS_FINAIS[d]
                    angulo=atan2(ponta[1]-punho[1],ponta[0]-punho[0])+pi/2
                    contrato['poses'][f'{d}:{q}']={'punho':punho,'angulo':angulo}
                    celula=renderizar(sprite,(160,160),tuple(v*2 for v in punho),angulo)
                caixa=celula.getbbox();assert caixa and min(caixa[:2])>0 and max(caixa[2:])<160
                atlas.alpha_composite(celula,(q*160,d*160))
        atlas.save(pasta/'espada_dupla.png')
        for acao,quadros in [('parado',4),('correr',6)]:
            inteira=Image.new('RGBA',(160*quadros,640));cabos=Image.new('RGBA',inteira.size)
            for d in range(4):
                for q in range(quadros):
                    pose=poses_porte['running'][d][q] if acao=='correr' else poses_porte['idle'][d][0]
                    rot=pose['rotacao'];c,s=cos(rot),sin(rot)
                    # O punho fica 3px à direita e 7px abaixo do centro do porte antigo.
                    px,py=pose['posicao'];pivo=(80+2*(px+c*3-s*7),80+2*(py+s*3+c*7))
                    angulo=rot+poses_porte['angulo_nativo']+pi/2
                    for cabo,destino in [(False,inteira),(True,cabos)]:
                        celula=renderizar(sprite,(160,160),pivo,angulo,cabo)
                        caixa=celula.getbbox();assert caixa and min(caixa[:2])>0 and max(caixa[2:])<160,(tipo,acao,d,q,caixa)
                        destino.alpha_composite(celula,(q*160,d*160))
            sufixo='_correr' if acao=='correr' else ''
            inteira.save(pasta/f'porte{sufixo}.png');cabos.save(pasta/f'cabo{sufixo}.png')
        contrato['modelos'][tipo]={'sprite':[48,64],'icone':list(sprite.crop(sprite.getbbox()).size),'porte_parado':[640,640],'porte_correr':[960,640]}
    (FONTES/'contrato.json').write_text(json.dumps(contrato,indent=2)+'\n')
    print('Cinco montantes: detalhe 2x, 80 golpes e 120 poses de corrida, com uma única rotação por pose.')

if __name__=='__main__':preparar()
