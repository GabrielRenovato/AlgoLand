"""Autoria determinística: receita de pixels para o draw do PixelLab, sem IA.

Paleta, perfis de veios e grupos de cascalho definidos aqui. O PNG é renderizado
no PixelLab; este script só escreve os comandos e a planta da bancada.
"""
from pathlib import Path
import json

RAIZ = Path(__file__).resolve().parents[2]
FONTE = RAIZ/'arte/fontes/fendas/caverna_pixel_manual'
BASE = RAIZ/'assets/cenario/fendas/caverna_pixel_manual'
PALETA = {
 '0':'#000000', '1':'#281b30', '2':'#402238', '3':'#5b2f40',
 '4':'#7a4244', '5':'#955646', '6':'#ad704e', '7':'#c48b59',
 '8':'#d8a76c', '9':'#ecd096', 'a':'#f3dfb0',
 'b':'#34252c', 'c':'#3b292d', 'd':'#46312e', 'e':'#543c32',
 'f':'#624934', 'g':'#75593e', 'h':'#8a704c',
 'i':'#20212d', 'j':'#3e4050', 'k':'#62616a',
}
# Cristas com largura variável, luz à esquerda e ponta escura. Não há ruído
# aleatório: são dois perfis desenhados, repetidos na grade nativa.
VEIOS = [
 (0,5,1,0),(5,4,0,3),(9,6,2,1),(15,3,1,5),(18,5,0,2),
 (23,4,2,6),(27,5,1,1),(32,6,2,4),(38,4,0,0),
 (42,6,1,5),(48,3,2,2),(51,5,0,6),(56,5,1,3),(61,3,2,0),
]
CASCALHO = [(2,3,0),(11,1,1),(23,5,0),(6,12,1),(18,10,2),
 (29,13,0),(2,23,2),(13,21,0),(24,23,1),(18,29,0),(30,30,1),
 (7,29,0),(27,1,0),(16,16,0),(8,6,0),(31,20,0),(20,3,0)]

def piso(x,y,decorado=False):
    x%=32; y%=32
    cor='c'
    # Áreas de terra em pequenos grupos, cores próximas sem degradê.
    if (x,y) in {(3,4),(4,4),(12,2),(13,2),(14,2),(19,10),(20,10),
                 (25,24),(26,24),(6,13),(7,13),(18,30),(19,30)}:
        cor='d'
    for px,py,tipo in CASCALHO:
        dx=(x-px)%32;dy=(y-py)%32
        if tipo==0 and (dx,dy) in [(0,0),(1,0),(1,1)]: cor='d'
        elif tipo==1:
            if (dx,dy) in [(0,1),(1,1),(2,1),(1,2)]:cor='b'
            if (dx,dy) in [(0,0),(1,0),(1,1)]:cor='e'
        elif tipo==2:
            if (dx,dy) in [(0,1),(1,1),(2,1),(1,2),(2,2)]:cor='b'
            if (dx,dy) in [(0,0),(1,0),(2,0),(0,1)]:cor='e'
            if (dx,dy)==(0,0):cor='f'
    return cor

def parede(x,y,d):
    # A faixa representa uma face mineral inteira, não um contorno dourado.
    # d cresce da rocha preta para o solo; as pontas avançam em alturas variadas.
    # Os veios quebram e mudam de direção em pequenos degraus, em vez de
    # formar barras verticais de uma paliçada.
    desvio=[0,0,1,1,2,2,1,1,0,0,-1,-1,-2,-2,-1,0][(y//2+(x//8)*3)%16]
    fase=(x+desvio)%64
    x0,largura,tipo,ponta=next(v for v in VEIOS if v[0]<=fase<v[0]+v[1])
    u=fase-x0
    relevo=[0,1,2,1,-1,-2,-1,0][(fase//2)%8]
    t=(d+14+relevo)/34
    if t<0:return '0'
    if t<.055:return '1'
    if t<.11:return '3' if u else '2'
    fim=.62+ponta*.068
    if t>fim:
        if t<min(fim+.12,1.04):return '2'
        return 'b' if t<min(fim+.19,1.09) else piso(x,y)
    # Reentrâncias entre lâminas e suas terminações em cunha.
    if u==largura-1:return '2' if t>.3 else '4'
    if u==largura-2 and t>.52:return '3'
    deslocamento=int(max(0,t-.26)*(3+tipo))
    quebra=(y+x0//2+ponta)%32
    if 19<=quebra<=20 and u<=largura-3 and t>.2:return '3'
    if quebra==21 and u<2 and t>.2:return '2'
    if quebra in (11,12) and u==largura-3:return '4'
    if u<deslocamento:return '4' if t>.75 else '5'
    if u==deslocamento:
        if t<.18:return '7'
        if t<.38:return '9' if tipo==0 else '8'
        if t<.65:return '7' if tipo!=1 else '6'
        return '6'
    if u==deslocamento+1:
        if .18<t<.3 and tipo==0:return 'a'
        return '7' if t<.5 else ('6' if t<.7 else '5')
    if .31<t<.36 and tipo==1:return '4'
    if .57<t<.62 and tipo==2:return '4'
    return '7' if t<.38 else ('6' if t<.66 else '4')

def celula(m):
    linhas=[]
    for y in range(64):
        linha=[]
        for x in range(64):
            u=x/63;v=y/63
            f=(bool(m&1)*(1-u)*(1-v)+bool(m&2)*u*(1-v)+
               bool(m&4)*(1-u)*v+bool(m&8)*u*v)
            if m==0:cor='0'
            elif m==15:cor=piso(x,y)
            else:
                # Perfil compartilhado entre células; endpoints são idênticos.
                d=(f-.5)*64
                cor=parede(x,y,d)
            linha.append(cor)
        linhas.append(''.join(linha))
    return linhas

def main():
    # Quatorze combinações de cantos; diagonais ambíguas não são usadas.
    mascaras=[[8,12,4,15],[10,15,5,15],[2,3,1,0],[14,13,11,7]]
    pecas={m:celula(m) for m in set(sum(mascaras,[]))}
    receita={'job':{'canvas':[256,256],'frame_count':1,'views':[{'id':'atlas','offset':[0,0]}],
                     'source_bookends_exact':False,'body_palette_exact':False,'overview_scale':3},
             'scene':{'version':1,'template':'layered-drawing-v1','palette':PALETA,
                      'layers':[{'id':'terreno','name':'Body - terreno manual'}],
                      'views':{'atlas':{'nodes':{
                          f'peca_{x}_{y}':{'layer':'terreno','at':[x*64,y*64],
                                          'draw':[{'op':'grid','legend':{k:k for k in PALETA},
                                                   'rows':pecas[mascaras[y][x]]}]}
                          for y in range(4) for x in range(4)}}}}}
    FONTE.mkdir(parents=True,exist_ok=True); BASE.mkdir(parents=True,exist_ok=True)
    (FONTE/'receita.json').write_text(json.dumps(receita,separators=(',',':'))+'\n')
    coords={str(m):[x,y] for y,row in enumerate(mascaras) for x,m in enumerate(row)}
    # A mostra tem duas câmaras ligadas, com reentrância; não salas circulares.
    pontos=set()
    for x0,y0,x1,y1 in [(1,1,4,3),(3,2,6,4)]:
        pontos.update((x,y) for y in range(y0,y1+1) for x in range(x0,x1+1))
    celulas=[];usadas=set()
    for y in range(6):
        for x in range(8):
            m=sum(bit for dx,dy,bit in [(0,0,1),(1,0,2),(0,1,4),(1,1,8)] if (x+dx,y+dy) in pontos)
            assert str(m) in coords
            usadas.add(m)
            ax,ay=coords[str(m)]
            for sy in range(4):
                for sx in range(4):
                    celulas.append([x*4+sx,y*4+sy,ax*4+sx,ay*4+sy])
    dados={'grade':16,'modulo':64,'tamanho':[512,384],'celulas':celulas,
           'mascaras':sorted(usadas),'pecas':coords,'espelhadas':{}}
    (BASE/'bancada.json').write_text(json.dumps(dados,separators=(',',':'))+'\n')
    contrato={'tipo':'Amostra de tiles desenhada por comandos exatos no PixelLab, sem modelos geradores',
              'referencia':'arte/previas/fenda/gruta_nascente/estudo_gaias_navel_v2.png',
              'dimensoes':'Atlas nativo256x256; módulos64 subdivididos em16; sem redução da arte',
              'encaixe':'Pivô(0,0), sem offsets; camada de chão/parede com material explícito',
              'variantes':'Uma versão conforme pedido do usuário',
              'base_fisica':'Bancada visual isolada, sem navegação/colisão, sem substituir campanha',
              'integracao':'Renderização Godot e inspeção nativa/ampliada antes de apresentar',
              'paleta':PALETA,'receita':'receita.json'}
    (FONTE/'contrato.json').write_text(json.dumps(contrato,indent=2,ensure_ascii=False)+'\n')
    print('Receita de atlas256x256 e bancada512x384 preparadas; nenhum PNG gerado localmente.')

if __name__=='__main__':main()
