"""Bases físicas dos sprites finais, sem herdar colisões de objetos removidos.

Pivôs e escalas são os mesmos emitidos pelos compositores. Copas, sombras
semitransparentes e efeitos não fazem parte da base. A geometria é sazonalmente
estável: usa a primavera, com a mesma silhueta das outras três variantes.
"""
from PIL import Image
import gentle_forest as F
import rpgw_caves as R


def envoltoria(pontos):
    pontos = sorted(set(pontos))
    def cruz(a, b, c):
        return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])
    def metade(lista):
        saida = []
        for p in lista:
            while len(saida)>1 and cruz(saida[-2],saida[-1],p)<=0:
                saida.pop()
            saida.append(p)
        return saida
    return metade(pontos)[:-1]+metade(pontos[::-1])[:-1]


def base(imagem, pivo, altura=10):
    """Envoltória dos pixels sólidos junto ao chão, em coordenadas do pivô."""
    limites = imagem.getbbox()
    if limites is None:
        return []
    pontos = []
    for y in range(max(limites[1],limites[3]-altura),limites[3]):
        for x in range(limites[0],limites[2]):
            if imagem.getpixel((x,y))[3]<200:
                continue
            pontos.extend((xx-pivo[0],yy-pivo[1]) for xx,yy in
                          [(x,y),(x+1,y),(x,y+1),(x+1,y+1)])
    return envoltoria(pontos) if pontos else []


def reconstruir(m,p,pontos,B,G):
    rochoso=p['bioma'].startswith('caverna') or p['bioma']=='pedreira'
    # Os ambientadores antigos acrescentavam retângulos genéricos. A lista de
    # terreno foi guardada antes deles; só sprites efetivamente emitidos colidem.
    m.obstaculos=list(m.colisoes_terreno_finais if rochoso else m.obstaculos_terreno)
    m.fontes_colisao={}
    def adicionar(poligono,x,y,nome):
        if len(poligono)<3:
            return
        m.fontes_colisao[len(m.obstaculos)+1]=nome
        m.obstaculos.append([(xx+x,yy+y) for xx,yy in poligono])
    for s in m.sprites_novos:
        tipo=s['tipo'];x,y=s['x'],s['y']
        if tipo in ['abeto','carvalho']:
            # Troncos além da primeira fileira já ficam atrás do limite externo.
            if p['andar'] not in [6,10] and B.distancia_caminhavel(x,y)>70:
                continue
            largura=9 if p['andar'] in F.PALETAS else 7
            adicionar([(-largura,-10),(largura,-10),(largura,0),(-largura,0)],x,y,s['nome'])
        else:
            largura=12 if tipo=='arbusto_g' or p['andar'] in F.PALETAS else 5
            adicionar([(-largura,-8),(largura,-8),(largura,0),(-largura,0)],x,y,s['nome'])
    R.preparar()
    pasta=R.RAIZ/'assets/cenario/substitutos/fendas/florestas' if p['andar'] in F.PALETAS else R.DESTINO
    atlas=Image.open(pasta/'objetos_spring.png').convert('RGBA')
    for i,(x,y,tipo) in enumerate(pontos):
        # Detalhes baixos são transitáveis, como declara o sprite no jogo.
        if tipo==13 or (p['andar'] in F.PALETAS and tipo in [10,11]):
            continue
        imagem=atlas.crop((tipo%4*64,tipo//4*64,tipo%4*64+64,tipo//4*64+64))
        adicionar(base(imagem,(32,60)),x,y,f'Marco{i:03}')


def identificar(texto,m):
    for indice,nome in m.fontes_colisao.items():
        cabecalho=f'[node name="Obstaculo{indice}" type="CollisionPolygon2D" parent="Obstaculos"]'
        texto=texto.replace(cabecalho,cabecalho+f'\nmetadata/sprite_colisao = "{nome}"')
    return texto


def fechar_mata_externa(m,p):
    """Fecha visualmente o limite dos mapas naturais sem cercar salas com ar invisível."""
    x0,y0,w,h=p['limites']
    pontos=[]
    for x in range(x0-32,x0+w+65,40):
        pontos.extend([(x,y0),(x+20,y0-40),(x,y0+h+40),(x+20,y0+h+80)])
    for y in range(y0-40,y0+h+81,40):
        pontos.extend([(x0-8,y),(x0-48,y+20),(x0+w+8,y),(x0+w+48,y+20)])
    for i,(x,y) in enumerate(pontos):
        m.sprites_novos.append({'nome':f'AbetoLimite{i}','tipo':'abeto','x':x,'y':y})
