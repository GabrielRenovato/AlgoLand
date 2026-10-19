"""Composição ambiental por bioma; peças nativas e objetos com bases fora das rotas."""
import math
import random
from pathlib import Path
from PIL import Image

RAIZ = Path(__file__).resolve().parents[2]
ESTACOES = ['spring','summer','autumn','winter']
# IDs do atlas ambiental, em ordem de leitura. A escala permanece nativa.
TEMAS = {
    1: [8,9], 2:[8,9,10], 3:[4,6,7,15], 4:[5,11,13], 5:[8,9,10,13],
    6:[8,9,13], 7:[5,6,7,12,13], 8:[8,9,11,13],
    9:[4,5,6,7,15], 10:[8,9,13], 11:[5,12,13,14],
}


def relevo_nativo(m,p,B,G):
    """Mesas sazonais completas, com topo, cantos e pé, em terreno não caminhável."""
    if p['bioma']=='ruinas':
        fundacoes(m,p,B,G)
        return
    if p['andar'] not in [2,3,8,9]: return
    rng=random.Random(1400+p['andar'])
    x0,y0,w,h=p['limites']
    usados=[]
    for _ in range(250):
        ox=rng.randrange((x0+32)//16,(x0+w-176)//16)
        oy=rng.randrange((y0+16)//16,(y0+h-160)//16)
        largura=rng.choice([6,8,10])
        # O stamp inteiro fica além da colisão do contorno. Nada sobre passagens/água.
        if any(B.distancia_caminhavel(x,y)<26 or m.lagoa.dist(x,y)<24
               for x in range(ox*16,(ox+largura)*16+1,16)
               for y in range(oy*16,(oy+8)*16+1,16)): continue
        cx,cy=(ox+largura/2)*16,(oy+4)*16
        if any(math.hypot(cx-x,cy-y)<210 for x,y in usados): continue
        usados.append((cx,cy))
        m.penhasco.update(G.montar_mesa(ox,oy,largura,False))
        # Árvores não atravessam o topo ou a face da mesa.
        m.sprites_novos=[s for s in m.sprites_novos if not (ox*16-24<s['x']<(ox+largura)*16+24 and oy*16-8<s['y']<(oy+8)*16+64)]
        if len(usados)>= (4 if p['andar']<8 else 8): break


def objetos(p,B,m):
    rng=random.Random(8800+p['andar'])
    pontos=[]
    tipos=TEMAS[p['andar']]
    # Composição ao redor de cada sala, em vez de um sorteio uniforme pelo retângulo.
    for setor in p['setores']:
        cx,cy=setor['centro'];rx,ry=setor['raios']
        for i in range(14):
            a=2*math.pi*i/14
            if setor.get('formato')=='patio':
                r=min(rx/max(abs(math.cos(a)),.001),ry/max(abs(math.sin(a)),.001))+28
                x=round((cx+math.cos(a)*r)/4)*4
                y=round((cy+math.sin(a)*r)/4)*4
            else:
                x=round((cx+math.cos(a)*(rx+24))/4)*4
                y=round((cy+math.sin(a)*(ry+24))/4)*4
            d=B.distancia_caminhavel(x,y)
            if not 8<d<65 or m.lagoa.dist(x,y)<16: continue
            if any(math.hypot(x-a,y-b)<58 for a,b,_ in pontos): continue
            # A base de 48×12 fica inteiramente além do limite físico existente.
            if any(B.distancia_caminhavel(x+dx,y+dy)<3 for dx in [-24,0,24] for dy in [-10,0]): continue
            tipo=tipos[(i+len(pontos))%len(tipos)]
            pontos.append((x,y,tipo))
    # Detalhes de margem nas trilhas, respeitando bases e guardião.
    for t in p['trilhas']:
        for a,b in zip(t['pontos'],t['pontos'][1:]):
            dx,dy=b[0]-a[0],b[1]-a[1];dist=math.hypot(dx,dy)
            for i in range(1,int(dist//100)):
                f=i/(int(dist//100))
                lado=rng.choice([-1,1]);r=t['raio']+28
                x=round((a[0]+dx*f-dy/dist*r*lado)/4)*4
                y=round((a[1]+dy*f+dx/dist*r*lado)/4)*4
                if not 16<B.distancia_caminhavel(x,y)<65 or m.lagoa.dist(x,y)<16: continue
                if any(math.hypot(x-aa,y-bb)<64 for aa,bb,_ in pontos): continue
                if any(B.distancia_caminhavel(x+ox,y+oy)<3 for ox in [-24,0,24] for oy in [-10,0]): continue
                pontos.append((x,y,rng.choice(tipos)))
    # Junco acompanha a água, inclusive em margens afastadas das salas.
    if p['bioma'] in ['brejo','bosque']:
        for cx,cy,rx,ry in p['lago']['lobos']:
            for i in range(10):
                a=2*math.pi*i/10;x=round(cx+math.cos(a)*(rx+10));y=round(cy+math.sin(a)*(ry+10))
                if B.distancia_caminhavel(x,y)<12: continue
                if any(math.hypot(x-aa,y-bb)<38 for aa,bb,_ in pontos):continue
                pontos.append((x,y,10))
    # Elimina copas imediatamente sobre as estruturas para sua leitura.
    if p['bioma'] in ['ruinas','brejo']:
        m.sprites_novos=[s for s in m.sprites_novos if not any(abs(s['x']-x)<48 and abs(s['y']-y)<58 for x,y,_ in pontos)]
    return pontos


def integrar_objetos(texto,p,pontos):
    import rpgw_caves as R
    R.preparar()
    ext='[ext_resource type="Script" path="res://codigo/fendas/decoracao_sazonal.gd" id="decoracao_script"]\n'
    for e in ESTACOES:
        import gentle_forest as F
        caminho=f'res://assets/cenario/fendas/gentle_forest/v{F.PALETAS[p["andar"]]}/objetos_{e}.png' if p['andar'] in F.PALETAS else f'res://assets/cenario/fendas/rpgw_caves/objetos_{e}.png'
        ext+=f'[ext_resource type="Texture2D" path="{caminho}" id="decoracao_{e}"]\n'
    texto=texto.replace('[sub_resource',ext+'\n[sub_resource',1)
    # Um único controlador troca atlas compartilhado, sem sinais/processamento por objeto.
    sub=''
    for tipo in sorted({t for _,_,t in pontos}):
        sub+=f'[sub_resource type="AtlasTexture" id="decoracao_{tipo}"]\natlas = ExtResource("decoracao_spring")\nregion = Rect2({tipo%4*64}, {tipo//4*64}, 64, 64)\n\n'
    texto=texto.replace('[node name="Terrains"',sub+'[node name="Terrains"',1)
    refs=', '.join(f'ExtResource("decoracao_{e}")' for e in ESTACOES)
    texto+='\n[node name="DecoracaoBioma" type="Node" parent="."]\nscript = ExtResource("decoracao_script")\nfolhas = Array[Texture2D](['+refs+'])\n'
    if p['bioma'].startswith('caverna'):
        texto=texto.replace('script = ExtResource("decoracao_script")','script = ExtResource("decoracao_script")\nprotegida = true')
    for i,(x,y,tipo) in enumerate(pontos):
        z=max(-992,min(992,math.floor(y/8)*8))
        passavel=tipo==13 or (p['andar'] in F.PALETAS and tipo in [10,11])
        texto+=f'\n[node name="Marco{i:03}" type="Sprite2D" parent="Objetos3D"]\nposition = Vector2({x}, {y})\nz_index = {z}\nz_as_relative = false\ntexture = SubResource("decoracao_{tipo}")\ncentered = false\noffset = Vector2(-32, -60)\nmetadata/decoracao_fenda = true\nmetadata/base_externa = {str(not (p["bioma"].startswith("caverna") or p["bioma"]=="pedreira")).lower()}\nmetadata/passavel = {str(passavel).lower()}\n'
    return texto


def paredes(p,B):
    """Faces minerais de 32px, recortadas pelo mesmo campo de distância da colisão.

    O topo continua fora da área de jogo. A face só aparece onde há chão ao sul;
    não pinta linhas horizontais através de salas, água ou ilhas de navegação.
    """
    if p['bioma'] not in ['caverna','caverna_agua','pedreira','ruinas']: return None
    x0,y0,w,h=p['limites']
    passo=4
    # Campo compartilhado entre estações; a face ocupa somente o lado não caminhável.
    campo=[[B.distancia_caminhavel(x+.5,y+.5) for x in range(x0,x0+w,passo)]
           for y in range(y0,y0+h,passo)]
    faces=[]
    for cx in range(w//passo):
        distancia=1000
        for cy in range(h//passo-1,-1,-1):
            if campo[cy][cx]<=0: distancia=0
            else:
                distancia+=passo
                if distancia<=48: faces.append((cx*passo,cy*passo,48-distancia))
    if p['bioma']=='ruinas':
        # Alvenaria contínua identifica também as laterais e o limite sul dos pátios.
        faces.extend((cx*passo,cy*passo,16) for cy,linha in enumerate(campo) for cx,d in enumerate(linha) if 0<d<12)
    recortes=[]
    for x,y,_ in faces:
        if min(B.distancia_caminhavel(x0+x+dx+.5,y0+y+dy+.5) for dx,dy in [(0,0),(3,0),(0,3),(3,3)])<5:
            recortes.extend((x+dx,y+dy) for dx in range(passo) for dy in range(passo) if B.distancia_caminhavel(x0+x+dx+.5,y0+y+dy+.5)<=0)
    destino=RAIZ/f'assets/cenario/fendas/andar_{p["andar"]:02}/paredes'
    destino.mkdir(parents=True,exist_ok=True)
    for e in ESTACOES:
        ref=Image.open(RAIZ/f'assets/cenario/Seasonal Forest/seasonal sample ({e}).png').convert('RGBA')
        # Só face de pedra, sem o topo gramado ou o rodapé verde da folha.
        amostra=ref.crop((112,64,144,112))
        if p['bioma']=='ruinas':
            tijolo=ref.crop((48,176,64,192))
            amostra=Image.new('RGBA',(32,48))
            for xx in [0,16]:
                for yy in [0,16,32]: amostra.paste(tijolo,(xx,yy))
        if p['bioma'].startswith('caverna'):
            # Interiores usam pedra protegida, refletindo a luz de cada estação.
            amostra=Image.open(RAIZ/'assets/cenario/Seasonal Forest/seasonal sample (summer).png').convert('RGBA').crop((112,64,144,112))
            tons={'spring':(.69,.76,.81),'summer':(.78,.77,.85),'autumn':(.77,.70,.78),'winter':(.65,.73,.88)}[e]
            canais=list(amostra.split())
            for i,t in enumerate(tons): canais[i]=canais[i].point(lambda v,t=t:round(v*t))
            amostra=Image.merge('RGBA',canais)
        out=Image.new('RGBA',(w,h))
        for x,y,profundidade in faces:
            out.paste(amostra.crop((x%32,profundidade,x%32+passo,profundidade+passo)),(x,y))
        for ponto in recortes: out.putpixel(ponto,(0,0,0,0))
        out.save(destino/f'{e}.png')
    return (x0,y0)


def integrar_paredes(texto,p,origem):
    if origem is None:return texto
    ext=''
    for e in ESTACOES:
        ext+=f'[ext_resource type="Texture2D" path="res://assets/cenario/fendas/andar_{p["andar"]:02}/paredes/{e}.png" id="parede_{e}"]\n'
    texto=texto.replace('[sub_resource',ext+'[sub_resource',1)
    refs=', '.join(f'ExtResource("parede_{e}")' for e in ESTACOES)
    texto+='\n[node name="FacesMinerais" type="Sprite2D" parent="."]\nz_index = -998\nposition = Vector2(%s, %s)\ncentered = false\ntexture = ExtResource("parede_spring")\nmetadata/parede_fenda = true\n'%origem
    # O mesmo controlador troca as faces e os props, uma vez por estação.
    texto=texto.replace('script = ExtResource("decoracao_script")','script = ExtResource("decoracao_script")\nparedes = Array[Texture2D](['+refs+'])')
    return texto


def preparar_piso(caminho,p,estacao):
    """Reutiliza os agrupamentos de pixels do chão nativo, em material mineral.

    Sem trocar desenho, grade ou bordas: só os tiles de miolo usados nas galerias.
    Interiores não expõem a terra sazonal com neve. As pedras soltas ficam em alpha.
    """
    import colorsys
    folha=Image.open(caminho).convert('RGBA')
    base=Image.open(RAIZ/'assets/cenario/Seasonal Forest/seasonal sample (summer).png').convert('RGBA')
    interior=p['bioma'].startswith('caverna')
    temperaturas={'spring':(.94,.99,1.0),'summer':(1.,.98,.93),'autumn':(.99,.94,.93),'winter':(.88,.94,1.)}
    tom=temperaturas[estacao]
    def mineral(pixel):
        r,g,b,a=pixel
        _,lum,_=colorsys.rgb_to_hls(r/255,g/255,b/255)
        if interior:
            # Ardósia nos andares úmidos; basalto mais escuro no abismo.
            intensidade=.68 if p['andar']==11 else .85
            v=lum*intensidade
            cor=(v*.88,v*.94,v)
        else:
            v=lum*.94;cor=(v*1.07,v*.99,v*.84)
        return tuple(max(0,min(255,round(c*255*t))) for c,t in zip(cor,tom))+(a,)
    for tx,ty in [(2,1)]+[(4,y) for y in range(5)]:
        for y in range(16):
            for x in range(16):folha.putpixel((tx*16+x,ty*16+y),mineral(base.getpixel((tx*16+x,ty*16+y))))
    # Pedras pequenas da mesma folha: retirar só a grama do fundo, conservando o agrupamento original.
    for ty in range(6,10):
        for y in range(16):
            for x in range(16):
                px=base.getpixel((64+x,ty*16+y));r,g,b,a=px
                chao=(g>r*1.02 and g>b*1.05) or a==0
                folha.putpixel((64+x,ty*16+y),(0,0,0,0) if chao else mineral(px))
    if interior:
        # Margens geradas pela arena partem de grama; nas grutas o contato é mineral.
        for y in range(256,folha.height):
            for x in range(folha.width):
                px=folha.getpixel((x,y));r,g,b,a=px
                if a and g>r*1.08 and g>b*.85: folha.putpixel((x,y),mineral(px))
    folha.save(caminho)


def fragmentos(m,p,B,G):
    rng=random.Random(7100+p['andar'])
    for x,y in sorted(m.chao):
        px,py=x*16+8,y*16+8
        if B.distancia_caminhavel(px,py)>-32 or m.lagoa.dist(px,py)<24:continue
        if any(math.hypot(px-c[0],py-c[1])<90 for c in [p['entrada'],p['guardiao']]):continue
        if rng.random()<.018:m.detalhes[x,y]=(4,rng.randrange(6,10))


def fundacoes(m,p,B,G):
    """Fragmentos compridos da alvenaria nativa delimitam os antigos pátios.

    Trechos interrompidos respeitam as entradas da planta; o pé inteiro permanece
    fora do campo caminhável. Cada setor tem fragmentos, sem criar um muro fechado.
    """
    for i,setor in enumerate(p['setores']):
        cx,cy=setor['centro'];rx,ry=setor['raios']
        candidatos=[(cx-rx-32,cy-ry-64,6),(cx+16,cy-ry-64,7),
                    (cx-rx-48,cy+ry+24,7),(cx+32,cy+ry+24,6)]
        for j,(x,y,largura) in enumerate(candidatos):
            ox,oy=round(x/16),round(y/16)
            if any(B.distancia_caminhavel(xx,yy)<12 or m.lagoa.dist(xx,yy)<16
                   for xx in range(ox*16,(ox+largura)*16+1,8)
                   for yy in range(oy*16,(oy+3)*16+1,8)):continue
            m.penhasco.update(G.montar_muro(ox,oy,largura))
            # Não esconder fundações em copas ou bases de árvores.
            m.sprites_novos=[s for s in m.sprites_novos if not (ox*16-16<s['x']<(ox+largura)*16+16 and oy*16-8<s['y']<(oy+3)*16+64)]
