#!/usr/bin/env python3
"""Extrai poses sem recentralizar, guarda tempos e gera atlas e prévias reproduzíveis."""
from pathlib import Path
import json, math
from PIL import Image, ImageChops, ImageFilter, ImageDraw

RAIZ=Path(__file__).resolve().parents[2]
FONTES=RAIZ/'arte/fontes/inimigos/rebento_raizes'
DESTINO=RAIZ/'assets/inimigos/rebento_raizes'
PREVIAS=RAIZ/'arte/previas/inimigos/rebento_raizes'
GRUPOS=['parado','andar_baixo','andar_lado','andar_cima',
        'golpe_a_baixo','golpe_a_lado','golpe_a_cima',
        'conjurar_baixo','conjurar_lado','conjurar_cima','reagir','morte']
CELULA=1024
PIVO=(512,800)

def extrair(imagem):
    """Componentes separam braços que ultrapassam a grade; todos mantêm o pivô da célula."""
    imagem=imagem.convert('RGBA')
    alfa=imagem.getchannel('A');grade=alfa.copy();grade.thumbnail((256,256))
    w,h=grade.size;ativos=bytearray(v>50 for v in grade.tobytes());componentes=[]
    for inicio in range(len(ativos)):
        if not ativos[inicio]: continue
        fila=[inicio];ativos[inicio]=0;pontos=[]
        while fila:
            k=fila.pop();pontos.append(k)
            for n in [k-w,k+w,k-1 if k%w else -1,k+1 if k%w<w-1 else -1]:
                if 0<=n<len(ativos) and ativos[n]: ativos[n]=0;fila.append(n)
        componentes.append(pontos)
    maiores=sorted(componentes,key=len,reverse=True)[:4]
    if len(maiores)!=4: raise ValueError('Folha sem quatro silhuetas separadas')
    maiores.sort(key=lambda p:sum(k//w for k in p)/len(p))
    ordenadas=[]
    for linha in [maiores[:2],maiores[2:]]:
        ordenadas+=sorted(linha,key=lambda p:sum(k%w for k in p)/len(p))
    quadros=[]
    for i,pontos in enumerate(ordenadas):
        mascara=Image.new('L',(w,h));dados=bytearray(w*h)
        for k in pontos:dados[k]=255
        mascara.frombytes(bytes(dados))
        mascara=mascara.resize(imagem.size,Image.Resampling.NEAREST).filter(ImageFilter.MaxFilter(9))
        silhueta=imagem.copy();silhueta.putalpha(ImageChops.multiply(alfa,mascara))
        quadro=Image.new('RGBA',(CELULA,CELULA))
        cellw,cellh=imagem.width/2,imagem.height/2
        dx=round(PIVO[0]-cellw*.5-i%2*cellw)
        dy=round(PIVO[1]-cellh*.88-i//2*cellh)
        bbox=silhueta.getbbox()
        if bbox is None:raise ValueError('Quadro vazio')
        destino=(bbox[0]+dx,bbox[1]+dy,bbox[2]+dx,bbox[3]+dy)
        if min(destino[:2])<0 or max(destino[2:])>=CELULA:raise ValueError('Pose invade quadro: '+str(destino))
        quadro.paste(silhueta,(dx,dy))
        quadros.append(quadro)
    return quadros

def main():
    DESTINO.mkdir(parents=True,exist_ok=True);PREVIAS.mkdir(parents=True,exist_ok=True)
    atlas=Image.new('RGBA',(CELULA*8,CELULA*6));ficha={'quadro':[CELULA,CELULA],'grade':[8,6],'pivo':list(PIVO),'escala':.1,'animacoes':{}}
    quadros_todos=[]
    for grupo in GRUPOS:
        quadros=extrair(Image.open(FONTES/(grupo+'.png')))
        inicio=len(quadros_todos);quadros_todos+=quadros
        for j,quadro in enumerate(quadros):
            indice=inicio+j;atlas.paste(quadro,(indice%8*CELULA,indice//8*CELULA))
        if grupo=='parado':nome='parado_baixo';duracoes=[.3,.3,.3,.3];loop=True
        else:
            nome=grupo;loop=grupo.startswith('andar')
            duracoes=([.17]*4 if loop else [.32,.18,.12,.3] if grupo.startswith('golpe') else [.45,.35,.48,.42] if grupo.startswith('conjurar') else [.2]*4)
        ficha['animacoes'][nome]={'quadros':list(range(inicio,inicio+4)),'duracoes':duracoes,'loop':loop}
        contato=Image.new('RGB',(1024,256),(44,48,44))
        for j,q in enumerate(quadros):
            mini=q.copy();mini.thumbnail((256,256));contato.paste(mini,(j*256,0),mini)
        contato.save(PREVIAS/(grupo+'.png'))
    for direcao in ['baixo','lado','cima']:
        origem=ficha['animacoes']['conjurar_'+direcao]
        ficha['animacoes']['golpe_b_'+direcao]={'quadros':origem['quadros'],'duracoes':[.32,.18,.12,.41],'loop':False}
        if direcao!='baixo':
            ficha['animacoes']['parado_'+direcao]={'quadros':[ficha['animacoes']['andar_'+direcao]['quadros'][0]],'duracoes':[1.0],'loop':True}
        indice=ficha['animacoes']['reagir']['quadros'][['baixo','lado','cima'].index(direcao)]
        ficha['animacoes']['reagir_'+direcao]={'quadros':[indice],'duracoes':[.24],'loop':False}
    atlas.save(DESTINO/'atlas.png')
    (DESTINO/'animacoes.json').write_text(json.dumps(ficha,ensure_ascii=False,indent=2)+'\n')
    for nome,dados in ficha['animacoes'].items():
        if nome=='reagir':continue
        frames=[]
        for i in dados['quadros']:
            q=quadros_todos[i].copy();q.thumbnail((256,256));fundo=Image.new('RGB',q.size,(44,48,44));fundo.paste(q,(0,0),q);frames.append(fundo)
        repeticao={'loop':0} if dados['loop'] else {}
        frames[0].save(PREVIAS/(nome+'.gif'),save_all=True,append_images=frames[1:],duration=[round(d*1000) for d in dados['duracoes']],disposal=2,**repeticao)
    indices=[];tempos=[]
    for acao in ['golpe_a_baixo','golpe_b_baixo']:
        indices+=ficha['animacoes'][acao]['quadros'];tempos+=ficha['animacoes'][acao]['duracoes']
    demonstracao=[]
    for indice in indices:
        q=quadros_todos[indice].copy();q.thumbnail((320,320));fundo=Image.new('RGB',q.size,(44,48,44));fundo.paste(q,(0,0),q);demonstracao.append(fundo)
    demonstracao[0].save(PREVIAS/'combo.gif',save_all=True,append_images=demonstracao[1:],duration=[round(d*1000) for d in tempos],disposal=2)
    erupcao=extrair(Image.open(FONTES/'erupcao.png'));folha=Image.new('RGBA',(CELULA*4,CELULA))
    for i,q in enumerate(erupcao):folha.paste(q,(i*CELULA,0))
    folha.save(DESTINO/'erupcao.png')

if __name__=='__main__':main()
