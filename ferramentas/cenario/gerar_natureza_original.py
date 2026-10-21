#!/usr/bin/env python3
"""Arte do AlgoLand: terrenos16px, atlas Wang e objetos sazonais gerados.

Árvores usam arvores_nitidas_v2/; grama usa tufos desenhados em grama_tufos/.
O penhasco usa fonte própria em penhasco/; pedras em nitidez/.
As receitas mantêm grade e encaixes dos mapas.
"""
from pathlib import Path
import json
import math
import random
import sys
from PIL import Image, ImageDraw

RAIZ = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(RAIZ / 'ferramentas/cidade'))
import preparar_terreno_witchbrook as W

FONTE = RAIZ / 'arte/fontes/cenario/algoland_original'
SAIDA = RAIZ / 'assets/cenario/algoland_original'
ESTACOES = [('spring', 'primavera'), ('summer', 'verao'), ('autumn', 'outono'), ('winter', 'inverno')]
# Rampas escuras -> claras. A posição dos agrupamentos permanece nas estações.
PALETAS = [
    {'grama': ['465537','596b3d','6d7d46','819050','98a361'], 'terra': ['73553e','896748','9e7954','ae8a61','c09b70'],
     'pedra': ['555c58','70796e','899080','a3a690','bcbaa1'], 'agua': ['355c58','416e64','4b7c70','66988a','89b4a0'],
     'folha': ['2e4134','3b5435','506b3a','6b8245','8e9c54','b0b96b']},
    {'grama': ['414e32','526238','657541','77864a','929d58'], 'terra': ['78563a','916b45','a97f52','b98f60','cba26e'],
     'pedra': ['595c52','77796a','919080','aaa58e','c3bca0'], 'agua': ['315b56','3d6a5e','467868','5a917c','82ae93'],
     'folha': ['2a3d30','365333','476b38','638243','849c4d','a9b963']},
    {'grama': ['66583a','7c6d40','91814c','a69257','baa66a'], 'terra': ['70503c','886046','9c7151','ac805d','be936b'],
     'pedra': ['5d5953','7b7567','96907b','afa48b','c5b99c'], 'agua': ['3f5d55','4e6e5f','5a7b69','759784','96b39b'],
     'folha': ['563b31','744535','925538','b16b3d','cc8a4a','e0af64']},
    {'grama': ['889b9a','b2c2bd','cfdbd1','e0e7d9','edf1e5'], 'terra': ['65574c','7c6b58','907d65','a08b73','b59e81'],
     'pedra': ['647779','849591','a8b7ac','cdd7c8','e3e8da'], 'agua': ['789b9b','91b2ad','a8c7bd','bfd9ca','dce8d6'],
     'folha': ['435653','647b70','8da499','b7c9b9','d7e0ce','edf0de']},
]

for e,rampa in enumerate([['356948','4a7a40','4f843b','6aa74b','82be56'],['435936','536d40','647641','949649','a3a650'],['88602d','9e6828','a47a38','c0944a','cca858'],['8f9f99','b9c2ac','d6debf','e1e6cd','eaf0da']]):
    PALETAS[e]['grama']=rampa


def cores(e, material):
    if material == 'terra':
        from preparar_terra_natural import paleta
        return [c+(255,) for c in paleta(e)]
    return [tuple(bytes.fromhex(c)) + (255,) for c in PALETAS[e][material]]

def salvar(im, p):
    p.parent.mkdir(parents=True, exist_ok=True)
    im.save(p)

def material(nome, e, variante=0):
    """Desenha em resolução nativa; agrupamentos, sem ruído por pixel."""
    if nome == 'grama':
        folha=Image.open(FONTE/'revisao_mana/nativos'/f'grama_{ESTACOES[e][0]}.png').convert('RGBA')
        x,y=(variante%2)*16,((variante//2)%2)*16
        return folha.crop((x,y,x+16,y+16))
    if nome == 'terra':
        from preparar_terra_natural import campo_nativo
        campo=campo_nativo(e)
        x,y=(variante%8)*16,((variante//8)%8)*16
        return campo.crop((x,y,x+16,y+16))
    p = cores(e, nome)
    if nome == 'grama':
        p[1]=tuple(round(p[1][k]*.4+p[2][k]*.6) for k in range(4))
        p[3]=tuple(round(p[3][k]*.65+p[2][k]*.35) for k in range(4))
    im = Image.new('RGBA', (16, 16), p[2])
    d = ImageDraw.Draw(im)
    if nome == 'grama':
        for x,y in [(1,2),(9,0),(5,8),(13,11)]:
            x=(x+variante*3)%16; y=(y+variante*5)%16
            d.line([(x,y),((x+1)%16,y)], fill=p[1])
        for x,y in [(4,4),(12,6),(8,13)]:
            x=(x+variante*3)%14; y=(y+variante*5)%14
            d.line([(x,y+1),(x+1,y)], fill=p[3])
            d.point((x+2,y+1), fill=p[1])
        if e == 2:
            for x,y in [(2,10),(12,2)]:
                d.line((x,y,x+1,y),fill=(171,115,62,255))
                d.point((x+1,y+1),fill=(128,88,49,255))
        if e == 3:
            # Crostas baixas e pequenos trechos de capim exposto, sem filtro branco.
            d.line((1,10,4,10),fill=p[3]); d.line((10,3,13,3),fill=p[4])
            d.point((5,8),fill=(126,131,104,255)); d.point((5,7),fill=(148,151,117,255))
    elif nome == 'terra':
        for x,y,w in [(1,3,3),(9,1,2),(7,10,3),(1,14,2),(13,7,2)]:
            d.line((x,y,x+w-1,y),fill=p[1]); d.line((x,y+1,x+w-2,y+1),fill=p[3])
        d.line((4,7,5,7),fill=p[3]); d.point((5,8),fill=p[0])
        if e == 3:
            d.line((0,0,3,0),fill=(193,205,190,255)); d.point((15,15),fill=(193,205,190,255))
    elif nome == 'pedra':
        # Seixos assimétricos; polígonos continuam do outro lado do tile.
        im.paste(p[0],(0,0,16,16)); d=ImageDraw.Draw(im)
        poligonos=[[(0,1),(4,0),(7,3),(6,7),(1,8),(-2,5)],[(9,-2),(14,-1),(18,2),(15,5),(9,5),(8,2)],
                   [(8,7),(13,6),(16,9),(14,14),(9,14),(7,11)],[(0,10),(4,9),(7,12),(5,16),(0,17),(-2,13)]]
        for pontos in poligonos:
            for dx,dy in [(0,0),(-16,0),(16,0),(0,-16),(0,16)]:
                pts=[(x+dx,y+dy) for x,y in pontos]
                d.polygon(pts,fill=p[2]); d.line(pts[:3],fill=p[3])
                d.line(pts[3:]+pts[:1],fill=p[1])
        d.line((2,3,4,3),fill=p[4]); d.line((10,9,12,9),fill=p[3])
        if e == 3:
            d.line((0,1,4,1),fill=p[4]); d.line((9,7,13,7),fill=p[4])
    else:
        for x,y,w in [(0,2,4),(9,5,5),(3,10,5),(12,14,3)]:
            d.line((x,y,x+w-1,y),fill=p[1]); d.line((x+1,y-1,x+w-2,y-1),fill=p[3])
        if e == 3:
            d.line([(1,0),(4,3),(3,6),(6,8)],fill=p[0])
            d.line([(11,9),(13,11),(12,14),(14,15)],fill=p[3])
    return im

def mascara(i):
    """Cantos Wang NO/NE/SO/SE, mesma geometria em todas as estações."""
    c=[int(bool(i & (1<<k))) for k in [3,2,1,0]]
    im=Image.new('L',(16,16))
    for y in range(16):
        for x in range(16):
            u=x/15; v=y/15
            valor=c[0]*(1-u)*(1-v)+c[1]*u*(1-v)+c[2]*(1-u)*v+c[3]*u*v
            im.putpixel((x,y),255 if valor>=.5 else 0)
    return im

def terrenos():
    mascaras={i:mascara(i) for i in range(16)}
    for e,(_,pt) in enumerate(ESTACOES):
        mats={n:material(n,e) for n in ['grama','terra','pedra','agua']}
        conjuntos={}
        for nome,baixo,cima in W.PARES:
            conjuntos[nome]={}
            for i,m in mascaras.items():
                t=Image.composite(mats[cima],mats[baixo],m)
                # Contato da vegetação com solo/água: sombra curta do lado baixo.
                if baixo=='grama' and 0<i<15:
                    for y in range(1,15):
                        for x in range(1,15):
                            if m.getpixel((x,y)) and not m.getpixel((x,y-1)):
                                t.putpixel((x,y),cores(e,cima)[0])
                conjuntos[nome][i]=t.convert('RGB')
        # Mantém o acabamento da vila, que já era arte local do PixelLab.
        W.aplicar_calcamento(conjuntos,pt)
        W.costurar(conjuntos,{n:'#'+PALETAS[e][n][2] for n in mats})
        W.validar(conjuntos)
        W.exportar(conjuntos,SAIDA/pt)
        fundo=Image.new('RGBA',(64,64))
        for y in range(0,64,16):
            for x in range(0,64,16):fundo.paste(mats['pedra'],(x,y))
        salvar(fundo,SAIDA/pt/'fundo_agua.png')
    folha=Image.new('RGBA',(64,96),(0,0,0,255))
    for i,m in mascaras.items():folha.paste(m.convert('RGBA'),(i%4*16,i//4*16))
    folha.paste((255,255,255,255),(0,80,64,96))
    salvar(folha,SAIDA/'mascara_agua.png')
    estudo=Image.new('RGBA',(64,64))
    for e in range(4):
        for i,n in enumerate(['grama','terra','pedra','agua']):estudo.paste(material(n,e),(i*16,e*16))
    salvar(estudo,FONTE/'materiais_nativos.png')

def pedra(e,tamanho=32,variante=0):
    nome=f"pedra_{'grande_' if tamanho==32 else ''}{variante%4}.png"
    return Image.open(SAIDA/'arbustos_pedras'/ESTACOES[e][1]/nome).convert('RGBA')


def copa(im,e,cx,cy,rx,ry,semente):
    """Massas de folhas com luz à esquerda; detalhes em grupos de 2–5 px."""
    d=ImageDraw.Draw(im);p=cores(e,'folha');r=random.Random(semente)
    contorno=[(cx-rx,cy),(cx-rx+2,cy-ry//2),(cx-rx//2,cy-ry+1),(cx+rx//3,cy-ry),
              (cx+rx-2,cy-ry//2),(cx+rx,cy+ry//3),(cx+rx//2,cy+ry),(cx-rx//3,cy+ry),(cx-rx+1,cy+ry//2)]
    d.polygon(contorno,fill=p[0])
    d.ellipse((cx-rx+2,cy-ry+2,cx+rx-3,cy+ry-3),fill=p[2])
    d.pieslice((cx-rx+2,cy-ry+1,cx+rx-4,cy+ry-3),180,320,fill=p[3])
    for _ in range(rx*ry//10):
        x=r.randrange(cx-rx+3,cx+rx-2);y=r.randrange(cy-ry+3,cy+ry-2)
        if ((x-cx)/rx)**2+((y-cy)/ry)**2>.72:continue
        luz=4 if x+y<cx+cy else 1
        d.line((x,y,x+2,y),fill=p[luz]);d.point((x+1,y-1),fill=p[min(luz+1,5)])
    if e==3:
        d.polygon([(cx-rx+4,cy-2),(cx-rx+7,cy-ry+5),(cx,cy-ry+2),(cx+rx-5,cy-ry+5),
                   (cx+rx-2,cy-1),(cx+rx//2,cy+1),(cx,cy-1),(cx-rx//2,cy+2)],fill=p[4])
        d.line((cx-rx+8,cy-ry+5,cx+rx//3,cy-ry+4),fill=p[5])

def arvore(e):
    # Modelo próprio assimétrico exportado por preparar_arvores_floresta.py.
    return Image.open(FONTE/'revisao_mana/nativos'/f'arvore_{ESTACOES[e][0]}.png').convert('RGBA')


def arbusto(e,pequeno=False):
    # Quadros reservados por compatibilidade; arte rejeitada não volta ao mapa.
    return Image.new('RGBA',(16 if pequeno else 32,32))


def planta(e,flor=False,variante=0):
    im=Image.new('RGBA',(16,16));d=ImageDraw.Draw(im);p=cores(e,'folha')
    d.line([(6,14),(7,8),(5,5)],fill=p[1]);d.line([(8,14),(9,9),(12,7)],fill=p[2])
    d.line((4,10,6,11),fill=p[3]);d.line((10,11,12,9),fill=p[4])
    if flor and e!=3:
        cor=[(212,177,169,255),(224,193,111,255),(181,125,80,255)][e]
        for x,y in [(5,5),(12,7)]:
            d.line((x-1,y,x+1,y),fill=cor);d.line((x,y-1,x,y+1),fill=cor);d.point((x,y),fill=(229,205,132,255))
    if e==3:d.line((4,10,6,10),fill=cores(e,'grama')[4]);d.point((11,8),fill=cores(e,'grama')[4])
    return im

def atlas_compativel(tamanho,e,G):
    """Mesmos IDs, regiões e geometrias de colisão dos mapas existentes."""
    out=Image.new('RGBA',tamanho); grama=material('grama',e); terra=material('terra',e); agua=material('agua',e)
    for j,(x,y) in enumerate(G.GRAMA):out.paste(material('grama',e,j),(x*16,y*16))
    for x,y in G.CENTRO_TERRA:out.paste(terra,(x*16,y*16))
    # Nove peças de canteiro com filete orgânico e contatos claros.
    for nome,(tx,ty) in G.BORDA_TERRA.items():
        t=Image.new('RGBA',(16,16));d=ImageDraw.Draw(t)
        x0=4 if 'O' in nome else 0; x1=11 if 'L' in nome or 'E' in nome else 15
        y0=4 if 'N' in nome else 0; y1=11 if 'S' in nome else 15
        if nome=='O':x0=4
        if nome=='L':x1=11
        perfil=[0,0,1,1,0,-1,0,1,0,0,-1,-1,0,1,0,0]
        for y in range(16):
            for x in range(16):
                distancias=[]
                if x0:distancias.append(x-x0-perfil[y])
                if x1<15:distancias.append(x1-x+perfil[y])
                if y0:distancias.append(y-y0-perfil[x])
                if y1<15:distancias.append(y1-y+perfil[x])
                distancia=min(distancias)
                if distancia>=0:
                    cor=terra.getpixel((x,y))
                    if distancia==0:cor=cores(e,'terra')[0]
                    if distancia==1 and (x+y)%4!=0:cor=cores(e,'terra')[1]
                    t.putpixel((x,y),cor)
                elif distancia==-1 and (x+y)%3:
                    t.putpixel((x,y),cores(e,'grama')[3])
                elif distancia==-2 and (x*3+y)%7==0:
                    t.putpixel((x,y),cores(e,'grama')[4])
        out.paste(t,(tx*16,ty*16))
    for nome,(tx,ty) in G.CANTO_INTERNO.items():
        t=terra.copy();x=12 if 'E' in nome else 0;y=12 if 'S' in nome else 0
        t.paste((0,0,0,0),(x,y,x+4,y+4));out.paste(t,(tx*16,ty*16))
    for x,y in G.AGUA:out.paste(agua,(x*16,y*16))
    for j,(x,y) in enumerate(G.FLORES):
        t=material('grama',e,j);t.alpha_composite(planta(e,True,j));out.paste(t,(x*16,y*16))
    for x,y in G.PLANTAS:out.paste(planta(e),(x*16,y*16))
    for variante,(x,y) in enumerate(G.ROCHAS):out.paste(pedra(e,16,variante),(x*16,y*16))
    out.paste(arbusto(e),(32,128));out.paste(arbusto(e,pequeno=True),(16,128))
    pequena=arvore(e)
    pequena=pequena.crop(pequena.getbbox());pequena.thumbnail((80,96),Image.Resampling.NEAREST)
    quadro=Image.new('RGBA',(80,96));quadro.paste(pequena,((80-pequena.width)//2,96-pequena.height))
    out.paste(quadro,(176,16))
    # Paredão original com rochas volumosas; mesma grade/ids do consumidor.
    from preparar_penhasco import aplicar as aplicar_penhasco
    aplicar_penhasco(out,e,grama)
    p=cores(e,'pedra')
    # Muro 3x3 e caverna 5x5 ocupam regiões próprias, fora do platô.
    for y in range(10,13):
        for x in range(2,5):out.paste(material('pedra',e),(x*16,y*16))
    d=ImageDraw.Draw(out)
    d.line((32,160,79,160),fill=p[4],width=2);d.line((32,207,79,207),fill=p[0],width=2)
    d.rounded_rectangle((178,114,253,190),radius=24,fill=p[0])
    d.rounded_rectangle((182,118,249,190),radius=22,fill=p[2])
    d.rounded_rectangle((193,133,238,191),radius=18,fill=(33,36,31,255))
    d.line([(183,143),(189,126),(202,119),(227,119)],fill=p[3],width=3)
    for y in range(256,tamanho[1]):
        for x in range(tamanho[0]):out.putpixel((x,y),grama.getpixel((x%16,y%16)))
    return out

def main():
    from preparar_revisao_mana import preparar
    from preparar_arbustos_pedras import main as preparar_objetos
    preparar()
    preparar_objetos()
    from preparar_penhasco import preparar_faixas
    preparar_faixas()
    from grama_do_topo import exportar_bancos
    exportar_bancos(sys.modules[__name__])
    from preparar_terra_natural import exportar_bancos as exportar_terra
    exportar_terra(sys.modules[__name__])
    # As junções Wang usam o fundo real da grama, sem pontos de outra paleta.
    for e,(en,_) in enumerate(ESTACOES):
        im=Image.open(FONTE/'revisao_mana/nativos'/f'grama_{en}.png').convert('RGB')
        frequencias=sorted(im.getcolors(1024),reverse=True)
        fundo=frequencias[0][1]
        tons=sorted([cor for _,cor in frequencias],key=lambda cor:sum(cor))
        rampa=[tons[0],tons[0],fundo,tons[-2],tons[-1]]
        PALETAS[e]['grama']=[''.join(f'{v:02x}' for v in cor) for cor in rampa]
    terrenos()
    manifesto={'origem':'image_gen: árvores em arvores_nitidas_v2/, paredão em penhasco/ e pedras em nitidez/; grama desenhada em grama_tufos/',
               'receita':'ferramentas/cenario/gerar_natureza_original.py','grade':16,'estacoes':[p for _,p in ESTACOES],
               'arte_preservada':'Guia do calçamento local PixelLab. Mana Seed usado como referência nos prompts; árvores usam arvores_nitidas_v2/; grama usa grama_tufos/; pedras usam nitidez/; paredão usa penhasco/; arbustos rejeitados foram removidos.',
               'estudo_nao_usado_como_tile':'direcao_materiais.png'}
    (FONTE/'manifesto.json').write_text(json.dumps(manifesto,ensure_ascii=False,indent=2)+'\n')
    print('16 atlas Wang originais, máscara de água e materiais nativos gerados.')

if __name__=='__main__':main()
