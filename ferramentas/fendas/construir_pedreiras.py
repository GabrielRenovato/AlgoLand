"""Pedreira externa: encaixes minerais contínuos e equipamento apoiado no piso.

Reutiliza a topologia Wang validada das cavernas, sem o teto subterrâneo.
Grade 16px, atlas 256×256, quatro estações com a mesma máscara física.
"""
from pathlib import Path
import math
from PIL import Image

RAIZ=Path(__file__).resolve().parents[2]
DESTINO=RAIZ/'assets/cenario/fendas/pedreiras'


def preparar():
    """A pedreira usa exclusivamente as peças completas RPGW fornecidas."""
    import rpgw_caves as R
    R.preparar()


def ambientar(m,p,B,G):
    from construir_cavernas import piso_em
    pontos=[]
    for setor in p['setores']:
        cx,cy=setor['centro'];rx,ry=setor['raios']
        for i in range(10):
            a=math.tau*i/10+.18
            for recuo in range(20,100,8):
                x=round(cx+math.cos(a)*(rx-recuo));y=round(cy+math.sin(a)*(ry-recuo))
                if all(piso_em(m,x+dx,y+dy) for dx in [-24,0,24] for dy in [-10,0,3]):break
            else:continue
            if any(G.dist_segmento((x,y),aa,bb)<t['raio']+8 for t in p['trilhas'] for aa,bb in zip(t['pontos'],t['pontos'][1:])):continue
            if setor['id']=='guardiao' and math.hypot(x-cx,y-cy)<140:continue
            if any(math.hypot(x-xx,y-yy)<90 for xx,yy,_ in pontos):continue
            tipo=([6,7,6,15,7] if p['bioma']=='caverna_mina' else [4,7,6,4,15])[i%5]
            pontos.append((x,y,tipo))
            m.obstaculos.append(G.poligono_retangulo(x-23,y-10,x+23,y+3))
    return pontos


def integrar(texto,p,m,B,T,C):
    return C.integrar(texto,p,m,B,T).replace('name="Caverna"','name="Pedreira"')
