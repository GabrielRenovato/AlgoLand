#!/usr/bin/env python3
"""Compõe platôs com o morro próprio nas áreas externas protegidas das rotas."""
from pathlib import Path
import json,math,random,re
import gerar_bosque as B

RAIZ=Path(__file__).resolve().parents[2]
ANDARES=[1,2,5,6,8,10]

def compor(p):
    B.PLANTA=p
    lagoa=B.G.Lagoa();lagoa.lobos=p['lago']['lobos'];lagoa.pe=None
    x0,y0,w,h=p['limites'];passo=32
    cols,linhas=w//passo,h//passo
    seguro=[]
    for y in range(linhas):
        linha=[]
        for x in range(cols):
            px,py=x0+x*passo+16,y0+y*passo+16
            d=B.distancia_caminhavel(px,py)
            agua=lagoa.dist(px,py) if lagoa.lobos else 10000
            linha.append(d>56 and agua>48)
        seguro.append(linha)
    integral=[[0]*(cols+1) for _ in range(linhas+1)]
    for y in range(linhas):
        for x in range(cols):integral[y+1][x+1]=int(not seguro[y][x])+integral[y][x+1]+integral[y+1][x]-integral[y][x]
    rng=random.Random(1921+p['andar']);escolhidos=[]
    # Silhuetas e larguras alternadas compõem encostas, sem carimbar quadrados.
    tamanhos=[(384,128),(288,160),(448,96),(224,192),(320,128),(192,128)]
    for k,(largura,altura) in enumerate(tamanhos):
        cw,ch=math.ceil(largura/passo),math.ceil((altura+64)/passo)
        candidatos=[]
        for cy in range(1,linhas-ch-1):
            for cx in range(1,cols-cw-1):
                total=integral[cy+ch][cx+cw]-integral[cy][cx+cw]-integral[cy+ch][cx]+integral[cy][cx]
                if total:continue
                x,y=x0+cx*passo,y0+cy*passo
                if any(not(x+largura+48<a or a+ww+48<x or y+altura+112<b or b+hh+112<y) for a,b,ww,hh in escolhidos):continue
                d=min(B.distancia_caminhavel(px,py) for px,py in [(x+largura/2,y+altura+64),(x,y+altura/2),(x+largura,y+altura/2)])
                # Relevos próximos do trajeto têm leitura; os distantes viram cenário vazio.
                candidatos.append((abs(d-88)+rng.random()*30,x,y))
        if candidatos:
            _,x,y=min(candidatos)
            escolhidos.append((x,y,largura,altura))
    formas=[]
    for i,(x,y,w,h) in enumerate(escolhidos):
        recuo=32+(i%2)*16
        pontos=[[x+32,y],[x+w-64,y],[x+w-16,y+24],[x+w,y+64],
                [x+w-16,y+h-24],[x+w-recuo,y+h],[x+64,y+h],
                [x+16,y+h-24],[x,y+48],[x+16,y+16]]
        formas.append({'topo':pontos,'altura':64})
    return formas

def preparar(andares=None):
    pasta=RAIZ/'codigo/fendas/relevos';pasta.mkdir(exist_ok=True)
    for andar in ANDARES:
        if andares is not None and andar not in andares:continue
        p=json.loads((RAIZ/f'codigo/fendas/plantas/andar_{andar:02}.json').read_text())
        formas=compor(p)
        assert formas,('sem encostas seguras',andar)
        (pasta/f'andar_{andar:02}.json').write_text(json.dumps({'andar':andar,'formacoes':formas},indent=2)+'\n')
        cena=RAIZ/f'cenas/fendas/terreno_{andar:02}.tscn';s=cena.read_text()
        if 'id="relevo_proprio"' not in s:
            s=s.replace('[sub_resource','[ext_resource type="Script" path="res://codigo/fendas/relevo_original.gd" id="relevo_proprio"]\n\n[sub_resource',1)
            s+=f'\n[node name="RelevoOriginal" type="Node2D" parent="."]\nscript = ExtResource("relevo_proprio")\nandar = {andar}\n'
            s=re.sub(r'load_steps=\d+',f'load_steps={s.count("[ext_resource")+s.count("[sub_resource")+1}',s,count=1)
        # As bases devem existir antes do bake síncrono da navegação.
        bloco=f'[node name="RelevoOriginal" type="Node2D" parent="."]\nscript = ExtResource("relevo_proprio")\nandar = {andar}\n'
        s=s.replace('\n'+bloco,'')
        s=s.replace('[node name="Navegacao"',bloco+'\n[node name="Navegacao"',1)
        cena.write_text(s)
        print('RELEVO',andar,len(formas),'platôs; rotas e lagos protegidos')

if __name__=='__main__':preparar()
