#!/usr/bin/env python3
"""Substitui a arte legada dos onze andares sem regenerar células ou colisões.

As máscaras guardam somente a distribuição de água/terra das margens. Nenhuma
cor Gentle/Mana é usada no atlas final. Peças e água RPGW são preservadas.
"""
from pathlib import Path
import json
import re
import sys
from PIL import Image

RAIZ=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(RAIZ/'ferramentas/cenario'),str(RAIZ/'ferramentas/arena')]
import gerar_natureza_original as N
import gerar_arena as G

ESTACOES=['spring','summer','autumn','winter']
FLORESTAS={1:'01',2:'02',5:'02',8:'03'}
CAVERNAS={3,4,7,11}
SAIDA=RAIZ/'assets/cenario/substitutos/fendas'
MASCARAS=RAIZ/'arte/fontes/cenario/andares_originais/margens'


def salvar(im,p):
    p.parent.mkdir(parents=True,exist_ok=True)
    im.save(p)


def mascara_existente(andar,im):
    """Recupera margens pela geometria da lagoa e pelas células reais do mapa."""
    p=MASCARAS/f'andar_{andar:02}.png'
    if p.exists():return Image.open(p).convert('L')
    from tscn import decodificar_tiles
    planta=json.loads((RAIZ/f'codigo/fendas/plantas/andar_{andar:02}.json').read_text())
    lagoa=G.Lagoa();lagoa.lobos=planta['lago']['lobos'];lagoa.pe=None
    texto=(RAIZ/f'cenas/fendas/terreno_{andar:02}.tscn').read_text()
    camada=next(b for b in re.split(r'\n(?=\[)',texto) if b.startswith('[node name="Agua"'))
    dados=re.search(r'tile_map_data = (PackedByteArray\([^\n]+\))',camada)
    mascara=Image.new('L',(im.width,max(1,im.height-256)))
    if dados:
        for cx,cy,_,ax,ay,_ in decodificar_tiles(dados[1]):
            if ay<16:continue
            for y in range(16):
                for x in range(16):
                    d=lagoa.dist(cx*16+x+.5,cy*16+y+.5)
                    mascara.putpixel((ax*16+x,(ay-16)*16+y),0 if d>=0 else 1 if d>=-3 else 255)
    salvar(mascara,p)
    return mascara


def guardar_margens(andar,grades):
    """Geradores novos fornecem a geometria diretamente, sem classificar imagens."""
    m=Image.new('L',(256,max(1,((len(grades)+15)//16)*16)))
    for k,(grade,_,_) in enumerate(grades):
        for i,d in enumerate(grade):
            m.putpixel((k%16*16+i%16,k//16*16+i//16),0 if d>=0 else 1 if d>=-3 else 255)
    salvar(m,MASCARAS/f'andar_{andar:02}.png')
    return m


def plato_proprio(out,e,origem):
    # Preserva a silhueta e a linha de base do stamp; reaproveita somente alfa.
    from preparar_penhasco import montar
    p=MASCARAS.parent/'silhueta_plato.png'
    if not p.exists():salvar(origem.crop((80,128,176,256)).getchannel('A'),p)
    parede=montar(e,N.material('grama',e))
    parede.putalpha(Image.open(p).convert('L'))
    out.paste(parede,(80,128))


def atlas(andar,e,origem):
    out=N.atlas_compativel(origem.size,e,G)
    if andar not in CAVERNAS:
        if andar in FLORESTAS:plato_proprio(out,e,origem)
        # Arbustos rejeitados continuam vazios; só plantas e pedras próprias.
        out.paste((0,0,0,0),(0,160,32,192))
        m=mascara_existente(andar,origem)
        agua=N.material('agua',e)
        for y in range(256,out.height):
            for x in range(out.width):
                v=m.getpixel((x,y-256))
                out.putpixel((x,y),agua.getpixel((x%16,y%16)) if v==255 else N.cores(e,'agua')[0] if v==1 else (0,0,0,0))
    elif andar in CAVERNAS:
        # Esta parte foi exportada exclusivamente do RPGW; mantém seus pixels.
        if origem.height>256:out.paste(origem.crop((0,256,origem.width,origem.height)),(0,256))
        for x,y in G.AGUA:out.paste(origem.crop((x*16,y*16,x*16+16,y*16+16)),(x*16,y*16))
    return out


def objetos(e):
    folha=Image.new('RGBA',(256,256))
    for ident in [8,9,10,11,13]:
        parte=N.planta(e) if ident==10 else N.pedra(e,16 if ident==13 else 32,ident%4)
        caixa=parte.getbbox()
        if not caixa:continue
        parte=parte.crop(caixa)
        folha.alpha_composite(parte,(ident%4*64+32-parte.width//2,ident//4*64+60-parte.height))
    return folha


def preparar(andares=None):
    andares=list(andares or range(1,12))
    for andar in andares:
        for e,nome in enumerate(ESTACOES):
            origem=Image.open(RAIZ/f'assets/cenario/fendas/andar_{andar:02}/{nome}.png').convert('RGBA')
            salvar(atlas(andar,e,origem),SAIDA/f'andar_{andar:02}/{nome}.png')
            if andar in FLORESTAS:salvar(objetos(e),SAIDA/f'florestas/objetos_{nome}.png')
        p=RAIZ/f'cenas/fendas/terreno_{andar:02}.tscn'
        s=p.read_text()
        for nome in ESTACOES:
            s=s.replace(f'res://assets/cenario/fendas/andar_{andar:02}/{nome}.png',f'res://assets/cenario/substitutos/fendas/andar_{andar:02}/{nome}.png')
        if andar in FLORESTAS:
            paleta=FLORESTAS[andar]
            for nome in ESTACOES:
                s=s.replace(f'res://assets/cenario/fendas/gentle_forest/v{paleta}/arvores_{nome}.png',f'res://assets/cenario/substitutos/arvores_florestas/v{paleta}/{nome}.png')
                s=s.replace(f'res://assets/cenario/fendas/gentle_forest/v{paleta}/objetos_{nome}.png',f'res://assets/cenario/substitutos/fendas/florestas/objetos_{nome}.png')
            s=s.replace(f'res://assets/cenario/fendas/gentle_forest/v{paleta}/brilho.png','res://assets/cenario/substitutos/natureza/brilho_spring.png')
            # Quatro estações, com nossos quatro quadros em cada animação.
            s=re.sub(r'brilhos_personalizados = Array\[Texture2D\]\([^\n]+\)\n','',s)
        # Saída de geradores antigos: brilhos, árvores e seus pivôs já saem
        # normalizados, inclusive antes de executar o substituidor geral.
        for i,nome in enumerate(ESTACOES):
            s=s.replace('res://assets/cenario/Seasonal Forest/seasonal water animations/'+G.BRILHO_ARQUIVOS[i],f'res://assets/cenario/substitutos/natureza/brilho_{nome}.png')
        blocos=re.split(r'\n(?=\[)',s)
        arvores=[]
        for i,b in enumerate(blocos):
            if b.startswith('[sub_resource type="AtlasTexture" id="Atlas_arbusto_m"'):
                # O adaptador antigo mudava o recorte, deixando a base física
                # fora do alcance do removedor de arbustos rejeitados.
                blocos[i]=b=b.replace('region = Rect2(0, 160, 32, 32)','region = Rect2(16, 128, 16, 32)')
            if b.startswith('[sub_resource type="AtlasTexture"') and ('resource_name = "arvore"' in b or 'resource_name = "arvore_var"' in b):
                ident=re.search(r'id="([^"]+)"',b)[1]
                arvores.append(ident)
                blocos[i]=re.sub(r'region = Rect2\([^)]*\)','region = Rect2(0, 0, 128, 128)',b)
        for i,b in enumerate(blocos):
            if b.startswith('[node ') and any(f'texture = SubResource("{ident}")' in b for ident in arvores):
                blocos[i]=re.sub(r'offset = Vector2\([^)]*\)','offset = Vector2(-64, -127)',b)
        from remover_arbustos_rejeitados import remover
        s=remover('\n'.join(blocos))
        p.write_text(s)
    manifesto={'origem':'Recursos próprios existentes do AlgoLand; sem geração nova.',
       'andares':andares,'estacoes':ESTACOES,'grade':16,
       'materiais':['grama_tufos','terra_natural','penhasco','nitidez/pedras','arvores_nitidas_v2'],
       'preservado':'Geometria, colisões, navegação, entradas, combate e peças RPGW.',
       'margens':'Máscaras pela geometria da lagoa e células reais: água/terra, sem classificação cromática. O platô preserva apenas a silhueta alfa do stamp, sem copiar RGB.',
       'regenerar':'python ferramentas/fendas/preparar_arte_original.py'}
    p=RAIZ/'arte/fontes/cenario/andares_originais/manifesto.json';p.parent.mkdir(parents=True,exist_ok=True)
    p.write_text(json.dumps(manifesto,ensure_ascii=False,indent=2)+'\n')
    print('Arte própria integrada aos andares:',','.join(map(str,andares)))
    from preparar_relevo_original import preparar as preparar_relevos
    preparar_relevos(andares)


if __name__=='__main__':preparar()
