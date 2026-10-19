#!/usr/bin/env python3
"""Monta a planta08 escolhendo exclusivamente blocos16 nativos do estudo.

Não redesenha nem deforma a parede. O campo da planta orienta a escolha de peças;
o custo de junção e a vizinhança original mantêm trechos completos de arte.
Dependências de preparação: numpy e Pillow, preferencialmente em venv temporário.
"""
import json
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

RAIZ=Path(__file__).resolve().parents[2]
BASE=RAIZ/'assets/cenario/fendas/caverna_recortada'
FONTE=RAIZ/'arte/previas/fenda/gruta_nascente/estudo_gaias_navel_v2.png'
PLANTA=RAIZ/'codigo/fendas/plantas/andar_08.json'


def distancia(p,x,y):
    d=np.full(np.broadcast_shapes(x.shape,y.shape),1e9,dtype=np.float32)
    for setor in p['setores']:
        cx,cy=setor['centro'];rx,ry=setor['raios']
        d=np.minimum(d,(np.hypot((x-cx)/rx,(y-cy)/ry)-1)*min(rx,ry))
    for trilha in p['trilhas']:
        for a,b in zip(trilha['pontos'],trilha['pontos'][1:]):
            vx,vy=b[0]-a[0],b[1]-a[1]
            t=np.clip(((x-a[0])*vx+(y-a[1])*vy)/(vx*vx+vy*vy),0,1)
            d=np.minimum(d,np.hypot(x-a[0]-t*vx,y-a[1]-t*vy)-trilha['raio'])
    return d


def features(labels):
    h,w=labels.shape;nr,nc=h//4,w//4
    blocos=labels.reshape(nr,4,nc,4).transpose(0,2,1,3).reshape(-1,16)
    feat=np.stack([(blocos==i).astype(np.float32) for i in range(3)],axis=-1).reshape(-1,48)
    media=feat.reshape(nr,nc,16,3).mean(axis=2)
    padded=np.pad(media,((1,1),(1,1),(0,0)),constant_values=0)
    padded[0,:,0]=1;padded[-1,:,0]=1;padded[:,0,0]=1;padded[:,-1,0]=1
    contexto=np.concatenate([padded[dy:dy+nr,dx:dx+nc] for dy in range(3) for dx in range(3)],axis=-1).reshape(-1,27)
    return feat,contexto,media.reshape(-1,3)


def preparar():
    dados=json.loads((BASE/'mapa.json').read_text())
    p=json.loads(PLANTA.read_text())
    original=Image.open(FONTE).convert('RGBA')
    imagem=Image.new('RGBA',tuple(dados['tamanho']),(0,0,0,255));imagem.paste(original,(0,0))
    rgb=np.asarray(imagem)[...,:3].astype(np.int16)
    brilho=(rgb[...,0]>135)&(rgb[...,1]>80)&(rgb[...,2]<150)
    dilatado=np.asarray(Image.fromarray((brilho*255).astype(np.uint8)).filter(ImageFilter.MaxFilter(9)))>0
    vazio=rgb.max(axis=2)<28
    liquido=(rgb[...,1]>rgb[...,0]*1.25)&(rgb[...,1]>rgb[...,2]*1.05)
    labels=np.where(vazio,0,np.where(dilatado,1,2)).astype(np.uint8)
    labels[liquido]=3
    # Semântica4px orienta o encaixe; os pixels da arte não são modificados.
    sub=labels.reshape(imagem.height//4,4,imagem.width//4,4).transpose(0,2,1,3)
    coarse=np.stack([(sub==i).sum(axis=(2,3)) for i in range(4)],axis=-1).argmax(axis=-1).astype(np.uint8)
    sf,sc,sm=features(coarse)
    linhas_fonte=imagem.height//16;colunas_fonte=imagem.width//16
    pixels=np.asarray(imagem).reshape(linhas_fonte,16,colunas_fonte,16,4).transpose(0,2,1,3,4).reshape(-1,16,16,4)
    bordas=np.stack([pixels[:,0,:,:3],pixels[:,-1,:,:3],pixels[:,:,0,:3],pixels[:,:,-1,:3]],axis=1).astype(np.float32)
    candidatos=np.flatnonzero((sm[:,1]>.015)&(np.mean(coarse.reshape(linhas_fonte,4,colunas_fonte,4).transpose(0,2,1,3).reshape(-1,16)==3,axis=1)<.01))
    # Degraus são módulos inteiros; não podem aparecer como fragmentos de parede.
    escadas=[(544,496,656,624),(1032,400,1144,528),(720,960,832,1088)]
    candidatos=np.array([i for i in candidatos if not any(
        i%colunas_fonte*16<b[2] and i%colunas_fonte*16+16>b[0]
        and i//colunas_fonte*16<b[3] and i//colunas_fonte*16+16>b[1]
        for b in escadas)],dtype=np.int32)
    x0,y0,w,h=p['limites'];x0=(x0//16)*16;y0=(y0//16)*16
    w=int(np.ceil((p['limites'][0]+w-x0)/16))*16;h=int(np.ceil(h/16))*16
    xx=np.arange(w//4,dtype=np.float32)[None,:]*4+x0+2
    yy=np.arange(h//4,dtype=np.float32)[:,None]*4+y0+2
    dist=distancia(p,xx,yy)
    gy,gx=np.gradient(dist,4)
    largura=np.sqrt((gx*28)**2+(gy*64)**2)/np.maximum(.01,np.hypot(gx,gy))
    alvo=np.where(dist<=0,2,np.where(dist<largura,1,0)).astype(np.uint8)
    tf,tc,tm=features(alvo)
    nr,nc=h//16,w//16
    muro=np.flatnonzero((tm[:,1]>.001)|((tm[:,0]>.001)&(tm[:,2]>.001)))
    escolhas=np.zeros(nr*nc,dtype=np.int32)
    for i in np.flatnonzero(tm[:,2]>.999):
        y,x=divmod(int(i),nc)
        escolhas[i]=(54+y%4)*colunas_fonte+47+x%4
    top=np.empty((len(muro),20),dtype=np.int32)
    for inicio in range(0,len(muro),96):
        ids=muro[inicio:inicio+96]
        erro=np.abs(tf[ids,None,:]-sf[candidatos][None,:,:]).mean(axis=2)*45
        erro+=np.abs(tc[ids,None,:]-sc[candidatos][None,:,:]).mean(axis=2)*6
        ordem=np.argsort(erro,axis=1)[:,:20]
        top[inicio:inicio+len(ids)]=candidatos[ordem]
        escolhas[ids]=candidatos[ordem[:,0]]
    indices={int(ponto):i for i,ponto in enumerate(muro)}
    def unary(ponto,op):
        return np.abs(sf[op]-tf[ponto]).mean(axis=1)*45+np.abs(sc[op]-tc[ponto]).mean(axis=1)*6
    conjunto=set(map(int,candidatos))
    for passo in range(8):
        mudancas=0
        for ponto in (muro if passo%2==0 else muro[::-1]):
            ponto=int(ponto);y,x=divmod(ponto,nc)
            vizinhos=[]
            for dx,dy,lado,oposto,delta_src in [(-1,0,2,3,1),(1,0,3,2,-1),(0,-1,0,1,colunas_fonte),(0,1,1,0,-colunas_fonte)]:
                if 0<=x+dx<nc and 0<=y+dy<nr:
                    vizinhos.append((int(escolhas[(y+dy)*nc+x+dx]),lado,oposto,delta_src))
            op=top[indices[ponto]].tolist()
            op.extend(v+delta for v,_,_,delta in vizinhos if v+delta in conjunto)
            op=np.unique(op)
            custo=unary(ponto,op)
            for viz,lado,oposto,delta_src in vizinhos:
                custo+=np.abs(bordas[op,lado]-bordas[viz,oposto]).mean(axis=(1,2))/32
                custo-=(op==viz+delta_src)*.75
            melhor=int(op[np.argmin(custo)])
            if melhor!=escolhas[ponto]:escolhas[ponto]=melhor;mudancas+=1
        print('Encaixe nativo',passo+1,'trocas',mudancas,flush=True)
        if not mudancas:break
    atlas_ids=np.zeros(linhas_fonte*colunas_fonte,dtype=np.int32)
    for sx,sy,id_atlas in dados['celulas']:atlas_ids[sy*colunas_fonte+sx]=id_atlas
    celulas=[[i%nc+x0//16,i//nc+y0//16,int(atlas_ids[orig])] for i,orig in enumerate(escolhas)]
    semantica=labels.reshape(linhas_fonte,16,colunas_fonte,16).transpose(0,2,1,3).reshape(-1,16,16)
    livres=set()
    for i,orig in enumerate(escolhas):
        ty,tx=divmod(i,nc)
        for dy in range(2):
            for dx in range(2):
                cx=x0+tx*16+dx*8+4;cy=y0+ty*16+dy*8+4
                solo=(semantica[orig,dy*8:dy*8+8,dx*8:dx*8+8]==2).mean()
                if solo>=.85 and float(distancia(p,np.array(cx),np.array(cy)))<=-4:
                    livres.add((cx//8,cy//8))
    inicio=tuple(v//8 for v in p['entrada']);fila=deque([inicio]);conectados=set()
    while fila:
        c=fila.popleft()
        if c not in livres or c in conectados:continue
        conectados.add(c);x,y=c
        fila.extend([(x-1,y),(x+1,y),(x,y-1),(x,y+1)])
    for setor in p['setores']:
        centro=tuple(v//8 for v in setor['centro'])
        assert centro in conectados,'Sala sem passagem: '+setor['id']
    # Mesma planta e coordenadas; a prévia não altera o andar08 da campanha.
    out={'andar':8,'nome':'Prévia de caverna da planta08','limites':[x0,y0,w,h],
         'grade':16,'celulas':celulas,'setores':p['setores'],'trilhas':p['trilhas'],
         'entrada':p['entrada'],'guardiao':p['guardiao'],
         'fonte':'res://assets/cenario/fendas/caverna_recortada/caverna.tres',
         'pixel_fiel':True,'alterou_planta':False,'livres':[list(c) for c in sorted(conectados)]}
    (BASE/'andar_08.json').write_text(json.dumps(out,separators=(',',':'))+'\n')
    # Artefato de inspeção, antes da conferência obrigatória no Godot.
    saida=Image.new('RGBA',(w,h),(0,0,0,255))
    for i,orig in enumerate(escolhas):
        y,x=divmod(i,nc)
        saida.paste(Image.fromarray(pixels[orig]),(x*16,y*16))
    saida.save('/tmp/algoland-caverna-08-composicao.png')
    print('PLANTA08:',len(celulas),'células; todas são recortes16 intactos do atlas escolhido')


if __name__=='__main__':preparar()
