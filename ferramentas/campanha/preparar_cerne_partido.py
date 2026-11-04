#!/usr/bin/env python3
"""Registra os desenhos aprovados em atlas, sem ampliar ou recentralizar poses pelo contorno."""
from pathlib import Path
import json
from PIL import Image, ImageChops, ImageFilter

RAIZ=Path(__file__).resolve().parents[2]
FONTES=RAIZ/'arte/fontes/inimigos/cerne_partido/estudo_v1'
DESTINO=RAIZ/'assets/inimigos/cerne_partido'
PREVIAS=RAIZ/'arte/previas/inimigos/cerne_partido'
CELULA=640
PIVO=(320,520)
GRUPOS=['01_combo','02_vistas_movimento','03_especiais','04_pancada_fase2','05_reacao_queda_morte']

def extrair(imagem):
    imagem=imagem.convert('RGBA');alfa=imagem.getchannel('A')
    mini=alfa.copy();mini.thumbnail((400,200));w,h=mini.size
    ativos=bytearray(v>60 for v in mini.tobytes());componentes=[]
    for k in range(len(ativos)):
        if not ativos[k]:continue
        fila=[k];ativos[k]=0;pontos=[]
        while fila:
            n=fila.pop();pontos.append(n)
            for viz in [n-w,n+w,n-1 if n%w else -1,n+1 if n%w<w-1 else -1]:
                if 0<=viz<len(ativos) and ativos[viz]:ativos[viz]=0;fila.append(viz)
        componentes.append(pontos)
    maiores=sorted(componentes,key=len,reverse=True)[:8]
    if len(maiores)!=8:raise ValueError('Esperadas oito silhuetas')
    maiores.sort(key=lambda p:sum(n//w for n in p)/len(p));ordenadas=[]
    for linha in [maiores[:4],maiores[4:]]:
        ordenadas+=sorted(linha,key=lambda p:sum(n%w for n in p)/len(p))
    quadros=[]
    for i,pontos in enumerate(ordenadas):
        dados=bytearray(w*h)
        for n in pontos:dados[n]=255
        mascara=Image.frombytes('L',(w,h),bytes(dados)).resize(imagem.size,Image.Resampling.NEAREST).filter(ImageFilter.MaxFilter(7))
        silhueta=imagem.copy();silhueta.putalpha(ImageChops.multiply(alfa,mascara))
        # Oito células da fonte têm largura fracionária: conservar coordenadas e pivô da grade.
        dx=round(PIVO[0]-(i%4+.5)*imagem.width/4)
        dy=round(PIVO[1]-(i//4+.85)*imagem.height/2)
        caixa=silhueta.getbbox();b=(caixa[0]+dx,caixa[1]+dy,caixa[2]+dx,caixa[3]+dy)
        if min(b[:2])<0 or max(b[2:])>=CELULA:raise ValueError('Pose fora do quadro: '+str(b))
        q=Image.new('RGBA',(CELULA,CELULA));q.paste(silhueta,(dx,dy));quadros.append(q)
    return quadros

def main():
    DESTINO.mkdir(parents=True,exist_ok=True);PREVIAS.mkdir(parents=True,exist_ok=True)
    quadros=[]
    for grupo in GRUPOS:quadros+=extrair(Image.open(FONTES/(grupo+'.png')))
    atlas=Image.new('RGBA',(CELULA*8,CELULA*5))
    for i,q in enumerate(quadros):atlas.paste(q,(i%8*CELULA,i//8*CELULA))
    animacoes={}
    def acao(nome,indices,tempos,loop=False):animacoes[nome]={'quadros':indices,'duracoes':tempos,'loop':loop}
    acao('parado',[8],[1],True)
    acao('andar',list(range(12,16)),[.22]*4,True)
    acao('lado',[9],[1],True);acao('costas',[10],[1],True)
    acao('combo',list(range(8)),[.42,.16,.12,.35,.42,.16,.12,.45])
    acao('investida',list(range(16,20)),[.8,.18,.65,.65])
    acao('conjurar',list(range(20,24)),[.6,.7,3.2,.6])
    acao('pancada',list(range(24,28)),[.65,.25,.2,.9])
    acao('transformar',list(range(28,32)),[.4,.5,.6,.5])
    acao('reagir',[32,33],[.15,.2])
    acao('cair',[34,35],[.4,3.6])
    acao('vulneravel',[35],[1],True)
    acao('morte',list(range(36,40)),[.5,.5,.6,1.4])
    atlas.save(DESTINO/'atlas.png')
    ficha={'quadro':[CELULA,CELULA],'grade':[8,5],'pivo':list(PIVO),'escala':.26,'animacoes':animacoes}
    (DESTINO/'animacoes.json').write_text(json.dumps(ficha,ensure_ascii=False,indent=2)+'\n')
    for nome,a in animacoes.items():
        frames=[]
        for i in a['quadros']:
            q=quadros[i].copy();q.thumbnail((320,320));f=Image.new('RGB',q.size,(46,49,42));f.paste(q,(0,0),q);frames.append(f)
        frames[0].save(PREVIAS/(nome+'.gif'),save_all=True,append_images=frames[1:],duration=[round(t*1000) for t in a['duracoes']],disposal=2,**({'loop':0} if a['loop'] else {}))
    print('Cerne Partido: 40 quadros, atlas 8x5, pivô',PIVO)

if __name__=='__main__':main()
