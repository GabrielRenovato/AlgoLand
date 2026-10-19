"""Cavernas RPGW: peças32px originais subdivididas em células16, sem escala.

A pedreira externa conserva seu atlas Wang independente. Cavernas usam
rpgw_caves.py e colisões derivadas da transparência das mesmas peças.
"""
import json
import math
from pathlib import Path
import random
import re
from PIL import Image,ImageFilter

RAIZ=Path(__file__).resolve().parents[2]
FONTE=RAIZ/'arte/fontes/fendas/cavernas'
DESTINO=RAIZ/'assets/cenario/fendas/cavernas'


def carregar():
    dados=json.loads((FONTE/'tileset_32_metadata.json').read_text())
    return dados['tileset_data']['tiles']


def ambientar(m,p,B,G):
    """Formações nas reentrâncias, com colisão na base e área de combate livre."""
    rng=random.Random(30000+p['andar']);pontos=[]
    for setor in p['setores']:
        cx,cy=setor['centro'];rx,ry=setor['raios']
        for i in range(12):
            a=2*math.pi*i/12+.12
            x=round(cx+math.cos(a)*(rx-12));y=round(cy+math.sin(a)*(ry-12))
            # Apoio medido no mesmo piso de onde sai a colisão.
            largura=10 if i%4==1 else 20
            for recuo in range(0,49,8):
                xx=round(x-math.cos(a)*recuo);yy=round(y-math.sin(a)*recuo)
                if all(piso_em(m,xx+ox,yy+oy) for ox in [-largura,0,largura] for oy in [-8,2]):
                    x,y=xx,yy
                    break
            else:continue
            if m.lagoa.dist(x,y)<26:continue
            # Vãos e grupos de combate mantêm passagem de pelo menos duas pessoas.
            if any(G.dist_segmento((x,y),aa,bb)<t['raio']-4 for t in p['trilhas'] for aa,bb in zip(t['pontos'],t['pontos'][1:])):continue
            if setor['id']=='guardiao' and math.hypot(x-cx,y-cy)<132:continue
            if any(math.hypot(x-xx,y-yy)<62 for xx,yy,_ in pontos):continue
            tipo=5
            if i%4==1:tipo=13
            if p['andar']==11 and i%4==3:tipo=12
            if p['andar']==4 and setor['id']=='entrada' and i%3==0:tipo=11
            if tipo!=13 and p['andar']==11:
                protegido=False
                for sala in p['setores']:
                    for g in range(sala['grupos']):
                        angulo=2*math.pi*g/max(sala['grupos'],1)+.5
                        gx=sala['centro'][0]+math.cos(angulo)*60;gy=sala['centro'][1]+math.sin(angulo)*48
                        if math.hypot(x-gx,y-gy)<80:protegido=True
                if protegido:continue
            pontos.append((x,y,tipo))
            if tipo!=13:
                largura=18 if tipo in [5,12] else 22
                m.obstaculos.append(G.poligono_retangulo(x-largura,y-7,x+largura,y+2))
    return pontos


def escolher_tiles(p,m,B,tiles):
    """O contexto 4×4 diferencia parede, topo e cantos com os mesmos quatro vértices."""
    x0=min(x for x,y in m.chao)//2*2;y0=min(y for x,y in m.chao)//2*2
    x1=(max(x for x,y in m.chao)//2+1)*2;y1=(max(y for x,y in m.chao)//2+1)*2
    cols=(x1-x0)//2;linhas=(y1-y0)//2
    # A face ocupa a célula ao sul da borda; recuar o teto preserva o contato com a colisão.
    v=[[1 if distancia_ambiente(p,B,((x0+c*2)//4)*64,((y0+r*2+2)//4)*64)>16 else 0 for c in range(cols+1)] for r in range(linhas+1)]
    for r in range(1,linhas+1):
        for c in range(cols+1):
            if v[r][c]==0 and v[r-1][c]==1:v[r][c]=2
    def vertice(r,c):
        return v[r][c] if 0<=r<=linhas and 0<=c<=cols else -1
    padroes=[]
    for tile in tiles:
        padroes.append([(i,j,w,10 if i in [1,2] and j in [1,2] else 1) for i in range(4) for j,w in enumerate(tile['pattern_4x4'][f'row_{i}']) if w!=255])
    cache={};celulas=[];incompativeis=0
    for r in range(linhas):
        for c in range(cols):
            janela=tuple(vertice(r-1+i,c-1+j) for i in range(4) for j in range(4))
            if janela not in cache:
                notas=[]
                for padrao in padroes:
                    nota=0
                    for i,j,valor,peso in padrao:
                        atual=janela[i*4+j]
                        if atual<0:continue
                        nota+=peso if atual==valor else (-30 if peso==10 else -1)
                    notas.append(nota)
                cache[janela]=max(range(len(tiles)),key=notas.__getitem__)
            tile=tiles[cache[janela]];box=tile['bounding_box']
            centro=[janela[i] for i in [5,6,9,10]]
            if len(set(centro))==1 and centro[0] in [0,1]:
                semente=((x0+c*2)*73856093 ^ (y0+r*2)*19349663 ^ p['andar']*83492791)&0xffffffff
                semente^=semente>>16;semente=(semente*0x7feb352d)&0xffffffff;semente^=semente>>15
                variante=semente&15
                box={'x':128+variante%4*32,'y':(128 if centro[0]==1 else 0)+variante//4*32}
            if any(tile['pattern_4x4'][f'row_{i}'][j] not in [255,janela[i*4+j]] for i,j in [(1,1),(1,2),(2,1),(2,2)]): incompativeis+=1
            for dy in range(2):
                for dx in range(2):
                    x=x0+c*2+dx;y=y0+r*2+dy

                    celulas.append((x,y,0,box['x']//16+dx,box['y']//16+dy,0))
    print(f'Caverna {p["andar"]}: {incompativeis} centros sem encaixe exato',flush=True)
    if incompativeis:raise ValueError('A planta exige cantos sem peca correspondente; corrigir antes de gravar.')
    return celulas


def preparar_margens(caminho,tiles_margem,G,estacao):
    """Margens pela distância real, com água subterrânea protegida nas quatro estações."""
    folha=Image.open(caminho).convert('RGBA')
    base=G.FOLHAS['summer']
    liquido=Image.open(RAIZ/'arte/fontes/fendas/rpgw_caves/MainLev2.0.png').convert('RGBA').crop((1248,1392,1280,1424))
    tons={'spring':(.98,1,1),'summer':(1,.99,.96),'autumn':(1,.97,.96),'winter':(.94,.98,1)}[estacao]
    def agua(pixel):
        return tuple(round(v*t) for v,t in zip(pixel[:3],tons))+(255,)
    for ax,ay in G.AGUA:
        for y in range(16):
            for x in range(16):folha.putpixel((ax*16+x,ay*16+y),agua(liquido.getpixel((x+(ax%2)*16,y+(ay%2)*16))))
    for k,(grid,_,_) in enumerate(tiles_margem):
        ax,ay=G.AGUA[k%len(G.AGUA)];tx=k%16;ty=16+k//16
        for y in range(16):
            for x in range(16):
                d=grid[y*16+x]
                cor=(0,0,0,0)
                if d<0:
                    if d>=-1:cor=(76,70,57,255)
                    elif d>=-2:cor=(46,48,39,255)
                    elif d>=-3:cor=(24,39,33,255)
                    else:cor=agua(liquido.getpixel((x+(ax%2)*16,y+(ay%2)*16)))
                folha.putpixel((tx*16+x,ty*16+y),cor)
    folha.save(caminho)


def integrar(texto,p,m,B,T):
    DESTINO.mkdir(parents=True,exist_ok=True)
    # A arte permanece em pixels nativos. A versão de produção não depende de arte/fontes.
    celulas=m.tiles_caverna
    # O chão antigo fica apenas como suporte das margens de água e do calendário existente.
    blocos=re.split(r'\n(?=\[)',texto)
    for i,b in enumerate(blocos):
        if b.startswith('[node name="Detalhes"') or b.startswith('[node name="Penhasco"'):
            blocos[i]=b.replace('texture_filter = 1','visible = false\ntexture_filter = 1')
    texto='\n'.join(blocos)
    texto=texto.replace('name="Agua" type="TileMapLayer" parent="."]\ntexture_filter = 1\nz_index = -1000','name="Agua" type="TileMapLayer" parent="."]\ntexture_filter = 1\nz_index = -998')
    ext='[ext_resource type="Texture2D" path="res://assets/cenario/fendas/cavernas/calcario.png" id="calcario"]\n[ext_resource type="Script" path="res://codigo/fendas/caverna_sazonal.gd" id="caverna_sazonal"]\n'
    texto=texto.replace('[sub_resource',ext+'[sub_resource',1)
    if p['bioma'].startswith('caverna') or p['bioma']=='pedreira':
        texto=texto.replace('res://assets/cenario/fendas/cavernas/calcario.png',f'res://assets/cenario/fendas/rpgw_caves/andar_{p["andar"]:02}.png')
    im=Image.open(RAIZ/f'assets/cenario/fendas/rpgw_caves/andar_{p["andar"]:02}.png' if p['bioma'].startswith('caverna') or p['bioma']=='pedreira' else FONTE/'tileset_producao.png')
    sub='[sub_resource type="TileSetAtlasSource" id="fonte_calcario"]\ntexture = ExtResource("calcario")\ntexture_region_size = Vector2i(16,16)\n'
    for y in range(im.height//16):
        for x in range(im.width//16):sub+=f'{x}:{y}/0 = 0\n'
    sub+='\n[sub_resource type="TileSet" id="tiles_calcario"]\ntile_size = Vector2i(16,16)\nsources/0 = SubResource("fonte_calcario")\n'
    texto=texto.replace('[node name="Terrains"',sub+'\n[node name="Terrains"',1)
    texto+='\n[node name="Caverna" type="TileMapLayer" parent="."]\nz_index = -999\ntexture_filter = 1\ntile_set = SubResource("tiles_calcario")\ntile_map_data = %s\nscript = ExtResource("caverna_sazonal")\n'%T.codificar_tiles(celulas)
    return texto


def integrar_sombra(texto,p,m):
    """Oclusão contínua no chão, derivada da mesma máscara usada pela colisão."""
    from PIL import ImageChops
    pasta=RAIZ/f'assets/cenario/fendas/andar_{p["andar"]:02}'
    mascara=m.mascara_piso
    interior=mascara.filter(ImageFilter.GaussianBlur(18))
    alpha=ImageChops.multiply(mascara,ImageChops.invert(interior)).point(lambda a:round(a*.90))
    sombra=Image.new('RGBA',mascara.size,(0,0,0,0));sombra.putalpha(alpha)
    sombra.save(pasta/'oclusao.png')
    ext=f'[ext_resource type="Texture2D" path="res://assets/cenario/fendas/andar_{p["andar"]:02}/oclusao.png" id="oclusao"]\n'
    texto=texto.replace('[sub_resource',ext+'[sub_resource',1)
    ox,oy=m.origem_piso
    texto+=f'\n[node name="SombraDasParedes" type="Sprite2D" parent="."]\nposition = Vector2({ox}, {oy})\nz_index = -997\ntexture_filter = 1\ntexture = ExtResource("oclusao")\ncentered = false\n'
    return texto


def piso_em(m,x,y):
    xx=int(x-m.origem_piso[0]);yy=int(y-m.origem_piso[1])
    return 0<=xx<m.mascara_piso.width and 0<=yy<m.mascara_piso.height and m.mascara_piso.getpixel((xx,yy))>0


def construir_geometria(m,p,B,G,T):
    """Uma única máscara de piso orienta desenho, colisão e posicionamento dos objetos."""
    if p["bioma"].startswith("caverna") or p["bioma"]=="pedreira":
        import rpgw_caves as U
        return U.construir_geometria(m,p,B,G,T)
    m.tiles_caverna=escolher_tiles(p,m,B,carregar())
    origem=(min(t[0] for t in m.tiles_caverna)*16,min(t[1] for t in m.tiles_caverna)*16)
    fim=((max(t[0] for t in m.tiles_caverna)+1)*16,(max(t[1] for t in m.tiles_caverna)+1)*16)
    mascara=Image.new('L',(fim[0]-origem[0],fim[1]-origem[1]))
    original=Image.open(FONTE/'tileset_32.png').convert('RGB')
    amostras={}
    for x,y,_,ax,ay,_ in m.tiles_caverna:
        chave=(ax,ay)
        if chave not in amostras:
            if ax>=8:parte=Image.new('L',(16,16),255 if ay<8 else 0)
            else:
                parte=Image.new('L',(16,16))
                parte.putdata([255 if r>145 and g>105 and b<r*.9 else 0 for r,g,b in original.crop((ax*16,ay*16,ax*16+16,ay*16+16)).getdata()])
            amostras[chave]=parte
        mascara.paste(amostras[chave],(x*16-origem[0],y*16-origem[1]))
    # Pedrinhas e manchas de sedimento não criam buracos na navegação.
    mascara=mascara.filter(ImageFilter.MaxFilter(7)).filter(ImageFilter.MinFilter(7))
    # A borda desenhada é transparente; a colisão acompanha a lâmina, não a célula retangular.
    from PIL import ImageDraw
    desenho=ImageDraw.Draw(mascara)
    for cx,cy,rx,ry in p['lago']['lobos']:
        desenho.ellipse((cx-rx-origem[0],cy-ry-origem[1],cx+rx-origem[0],cy+ry-origem[1]),fill=0)
    m.mascara_piso=mascara;m.origem_piso=origem
    def campo(x,y):return -1 if piso_em(m,x,y) else 1
    aneis=G.contornos(campo,origem[0],origem[1],fim[0],fim[1],4)
    aneis=[G.simplificar_anel(a,.8) for a in aneis if B.area(a)>64]
    aneis.sort(key=B.area,reverse=True)
    if not aneis:raise ValueError('Caverna sem piso conectado')
    m.poli=aneis[0];m.obstaculos=aneis[1:]
    for setor in p['setores']:
        if not G.ponto_em_poligono(setor['centro'],m.poli) or any(G.ponto_em_poligono(setor['centro'],a) for a in m.obstaculos):
            raise ValueError(f'Setor desconectado do piso: {setor["id"]}')
    for node in m.base.nos:
        if node['caminho']=='LimiteArena/Contorno':
            node['bloco']='[node name="Contorno" type="CollisionPolygon2D" parent="LimiteArena"]\nbuild_mode = 1\npolygon = %s\n'%T.poligono(m.poli)


def ponto_margem(p,lago):
    cx,cy,rx,ry=lago
    setor=min(p['setores'],key=lambda s:math.hypot(s['centro'][0]-cx,s['centro'][1]-cy))['centro']
    dx,dy=setor[0]-cx,setor[1]-cy
    t=1/max(math.hypot(dx/(rx+32),dy/(ry+32)),.001)
    return setor,(cx+dx*t,cy+dy*t)


def distancia_ambiente(p,B,x,y):
    distancia=B.distancia_caminhavel(x,y)
    # Alcovas e pequenos túneis seguem os lagos já desenhados na planta.
    for lago in p['lago']['lobos']:
        cx,cy,rx,ry=lago
        distancia=min(distancia,(math.hypot((x-cx)/(rx+64),(y-cy)/(ry+64))-1)*min(rx+64,ry+64))
        a,b=ponto_margem(p,lago)
        distancia=min(distancia,B.G.dist_segmento((x,y),a,b)-72)
    return distancia
