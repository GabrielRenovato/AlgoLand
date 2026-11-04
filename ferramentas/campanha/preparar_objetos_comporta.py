#!/usr/bin/env python3
"""Recorta os atlas gerados preservando grade e pivô comum das variantes."""
import json
import argparse
import re
import subprocess
from pathlib import Path
RAIZ=Path(__file__).resolve().parents[2]
FONTES=RAIZ/'arte/fontes/campanha/dungeon_comporta'
SAIDA=RAIZ/'assets/cenario/campanha/dungeon_comporta'

def magick(*args):
    return subprocess.check_output(['magick',*map(str,args)],text=True).strip()

def preparar(tipos=None):
    SAIDA.mkdir(parents=True,exist_ok=True)
    caminho_manifesto=SAIDA/'manifesto.json'
    manifesto=json.loads(caminho_manifesto.read_text()) if caminho_manifesto.exists() else {'ferramenta':'image_gen builtin','originais':'arte/fontes/campanha/dungeon_comporta','filtro':'nearest','grade_mundo':16,'objetos':{}}
    recursos=[('alavanca','alavanca.png',4,2,64),('comporta','comporta.png',4,2,128),('barricada','barricada_limpa.png',2,2,64),('suprimentos','suprimentos.png',2,2,64),('fogueira_panela','fogueira_panela.png',4,4,64),('mesa','mesa.png',2,2,64),('cadeira','cadeira.png',2,2,32)]
    for tipo,arquivo,colunas,linhas,lado in recursos:
        if tipos and tipo not in tipos:continue
        fonte=FONTES/arquivo
        w,h=map(int,magick('identify','-format','%w %h',fonte).split())
        quadros=[]
        for y in range(linhas):
            for x in range(colunas):
                x0,y0=round(x*w/colunas),round(y*h/linhas)
                x1,y1=round((x+1)*w/colunas),round((y+1)*h/linhas)
                tmp=SAIDA/f'.{tipo}_{x}_{y}.png'
                magick(fonte,'-crop',f'{x1-x0}x{y1-y0}+{x0}+{y0}','+repage',tmp)
                box=magick(tmp,'-alpha','extract','-threshold','60%','-format','%@','info:')
                bw,bh,bx,by=map(int,re.fullmatch(r'(\d+)x(\d+)\+(\d+)\+(\d+)',box).groups())
                quadros.append((x,y,tmp,(bx,by,bx+bw,by+bh)))
        uniao=(min(q[3][0] for q in quadros),min(q[3][1] for q in quadros),max(q[3][2] for q in quadros),max(q[3][3] for q in quadros))
        bx,by,ex,ey=uniao
        animados={}
        for x,y,tmp,_ in quadros:
            mecanismo=tipo in ('alavanca','comporta')
            estado=('_fechada' if y==0 else '_aberta') if mecanismo else ''
            estacao=y if tipo=='fogueira_panela' else x if mecanismo else y*2+x
            nome=f'{tipo}{estado}_{estacao}.png'
            if tipo=='fogueira_panela':nome=f'.fogueira_{estacao}_{x}.png'
            altura=lado-lado//8
            magick(tmp,'-crop',f'{ex-bx}x{ey-by}+{bx}+{by}','+repage','-filter','point','-resize',f'{lado-8}x{altura-4}','-background','none','-gravity','south','-extent',f'{lado}x{altura}','-gravity','north','-extent',f'{lado}x{lado}',SAIDA/nome)
            tmp.unlink()
            if tipo=='fogueira_panela':animados.setdefault(estacao,[]).append(SAIDA/nome)
        for estacao,partes in animados.items():
            magick(*partes,'+append',SAIDA/f'fogueira_panela_{estacao}.png')
            for parte in partes:parte.unlink()
        manifesto['objetos'][tipo]={'fonte':arquivo,'grade_fonte':[colunas,linhas],'recorte_comum':list(uniao),'quadro':[lado,lado],'pivo':[lado//2,lado*7//8],'estacoes':4,'estados':['fechada','aberta'] if tipo in ('alavanca','comporta') else ['estatico']}
        if tipo=='fogueira_panela':manifesto['objetos'][tipo].update(quadros=4,fps=6,loop=True)
    (SAIDA/'manifesto.json').write_text(json.dumps(manifesto,ensure_ascii=False,indent=2)+'\n')
    print('OBJETOS_COMPORTA_OK: recursos independentes, quatro estações, pivôs fixos')
if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--tipos',nargs='+');args=parser.parse_args()
    preparar(args.tipos)
