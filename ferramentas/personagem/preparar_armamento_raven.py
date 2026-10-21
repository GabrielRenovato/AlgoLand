#!/usr/bin/env python3
"""Compõe peças existentes nas pegadas Raven; não redesenha nem escala o corpo."""
from pathlib import Path
from math import atan2
import json
from PIL import Image
from preparar_raven import RAIZ, SAIDA, ACOES, pacote, imagem

ACOES_COMBATE = ['espada', 'espada_2']


def pontos(im):
    return [(x,y) for y in range(im.height) for x in range(im.width) if im.getpixel((x,y))[3]>=128]


def componentes(im):
    livres=set(pontos(im)); grupos=[]
    while livres:
        pilha=[livres.pop()]; grupo=[]
        while pilha:
            x,y=pilha.pop(); grupo.append((x,y))
            for dx,dy in [(1,0),(-1,0),(0,1),(0,-1),(1,1),(-1,-1),(1,-1),(-1,1)]:
                p=(x+dx,y+dy)
                if p in livres:livres.remove(p);pilha.append(p)
        grupos.append(grupo)
    return [g for g in grupos if len(g)>=2]


def centro(ps):return (sum(p[0] for p in ps)/len(ps),sum(p[1] for p in ps)/len(ps))
def distancia(a,b):return (a[0]-b[0])**2+(a[1]-b[1])**2


def pegada(luvas, ferramenta):
    gs=componentes(luvas); ps=pontos(ferramenta)
    assert gs and ps, 'Pose sem mão ou sem referência da arma.'
    # A mão da arma é a luva que encosta no seu desenho original.
    gs.sort(key=lambda g:min(distancia(p,q) for p in g for q in ps))
    mao=centro(gs[0]); livre=centro(gs[-1]) if len(gs)>1 else None
    ponta=max(ps,key=lambda p:distancia(p,mao))
    angulo=atan2(ponta[1]-mao[1],ponta[0]-mao[0])
    return mao,livre,angulo


def preparar():
    base,roupa=pacote('base'),pacote('roupa')
    luvas=imagem(roupa,'Gloves/Leather Gloves.png')
    espada=imagem(base,'Extras/Basic Sword.png')
    frente=imagem(base,'Extras/Shield Above.png');tras=imagem(base,'Extras/Shield back.png')
    tamanho=(320,320*len(ACOES))
    escudo_frente=Image.new('RGBA',tamanho)
    escudo_tras=Image.new('RGBA',tamanho)
    rastros=Image.new('RGBA',tamanho)
    guias={}
    # Poses de guarda e andar conservam as duas partes originais do escudo.
    for nome in ['bloquear','andar_escudo']:
        indice=list(ACOES).index(nome);ex=48+(240 if nome=='andar_escudo' else 0)
        for d in range(4):
            for q in range(4):
                caixa=(ex+d*48,64+q*64,ex+(d+1)*48,128+q*64)
                pos=(q*80+16,indice*320+d*80)
                escudo_tras.alpha_composite(tras.crop(caixa),pos)
                escudo_frente.alpha_composite(frente.crop(caixa),pos)
    for nome in ACOES_COMBATE:
        indice=list(ACOES).index(nome);x,y,_=ACOES[nome];ex=48+(240 if nome=='espada_2' else 0)
        for d in range(4):
            # O andar fornece o escudo na posição de porte, sem o exagero da escudada.
            fr=frente.crop((288+d*48,64,336+d*48,128))
            tr=tras.crop((288+d*48,64,336+d*48,128))
            ref=Image.alpha_composite(tr,fr)
            luva_guarda=luvas.crop((336+d*48,1344,384+d*48,1408))
            gs=componentes(luva_guarda);sp=pontos(ref)
            apoio=centro(min(gs,key=lambda g:min(distancia(a,b) for a in g for b in sp)))
            if d==2:
                # No ataque de costas a mão livre fica à esquerda; o escudo
                # se projeta para fora do braço, em vez de atravessar as costas.
                fr=fr.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
                tr=tr.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
                apoio=(47-apoio[0],apoio[1])
            for q in range(4):
                ferr=espada.crop((ex+d*48,64+q*64,ex+(d+1)*48,128+q*64))
                luva=luvas.crop((x+d*48,y+q*64,x+(d+1)*48,y+(q+1)*64))
                mao,livre,angulo=pegada(luva,ferr)
                guias[f'{nome}:{d}:{q}']={'mao':mao,'livre':livre,'angulo':angulo}
                # A pose de passagem do golpe é o rastro original, sem uma lâmina duplicada.
                if len(pontos(ferr))>60:
                    rastros.alpha_composite(ferr,(q*80+16,indice*320+d*80))
                oculta=livre is None
                if oculta:livre={1:(22,35),2:(17,37),3:(25,35)}.get(d,(30,35))
                if livre is not None:
                    delta=(round(livre[0]-apoio[0]),round(livre[1]-apoio[1]))
                    pos=(q*80+16+delta[0],indice*320+d*80+delta[1])
                    escudo_frente.alpha_composite(fr,pos);escudo_tras.alpha_composite(tr,pos)
    pasta=SAIDA/'camadas'
    escudo_frente.save(pasta/'escudo_frente.png');escudo_tras.save(pasta/'escudo_tras.png')
    rastros.save(pasta/'rastros.png')
    # Porte usa só os objetos e as mãos do Raven adquirido, inclusive correndo.
    for tipo in ['espada','espada_dupla','machado','lanca','arco']:
        ax,ay,arquivo=ACOES[tipo]
        obj=imagem(base,'Extras/'+arquivo)
        largura,altura=(80,80) if tipo=='lanca' else (48,64)
        atlas=Image.new('RGBA',tamanho)
        for d in range(4):
            ex,ey=(16,16) if tipo=='lanca' else (48,64)
            parte=obj.crop((ex+d*largura,ey,ex+(d+1)*largura,ey+altura))
            referencia=luvas.crop((ax+d*largura,ay,ax+(d+1)*largura,ay+altura))
            gs=componentes(referencia);ps=pontos(parte)
            apoio=centro(min(gs,key=lambda g:min(distancia(a,b) for a in g for b in ps)))
            for nome in ['parado','correr','andar_escudo']:
                indice=list(ACOES).index(nome);x,y,_=ACOES[nome]
                for q in range(4):
                    alvo=luvas.crop((x+d*48,y+q*64,x+(d+1)*48,y+(q+1)*64))
                    grupos=componentes(alvo)
                    apoio48=(apoio[0]-(16 if tipo=='lanca' else 0),apoio[1])
                    mao=centro(min(grupos,key=lambda g:distancia(centro(g),apoio48)))
                    dx=round(mao[0]+16-apoio[0]);dy=round(mao[1]-apoio[1])
                    caixa=parte.getbbox()
                    assert 0<=caixa[0]+dx and caixa[2]+dx<=80 and 0<=caixa[1]+dy and caixa[3]+dy<=80,(tipo,nome,d,q,caixa,dx,dy)
                    celula=Image.new('RGBA',(80,80));celula.alpha_composite(parte,(dx,dy))
                    atlas.alpha_composite(celula,(q*80,indice*320+d*80))
        atlas.save(pasta/f'porte_{tipo}.png')
    destino=RAIZ/'arte/fontes/personagens/raven_fantasy/combate'
    (destino/'pegadas.json').write_text(json.dumps(guias,indent=2)+'\n')
    print('Cinco portes Raven e duas camadas de escudo preparados sem alterar o corpo.')


if __name__=='__main__':preparar()
