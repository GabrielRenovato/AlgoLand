#!/usr/bin/env python3
"""Prepara atlas compatíveis com arte original AlgoLand e interiores PixelLab locais.

Preserva as fontes Mana Seed; remove as colisões dos arbustos rejeitados. Execute novamente
após regenerar cenas antigas: python3 ferramentas/cenario/substituir_mana_seed.py.
As máscaras de margens existentes guardam só a geometria, sem arte comercial.
"""
from pathlib import Path
import json
import re
import sys
from PIL import Image

RAIZ = Path(__file__).resolve().parents[2]
sys.path[:0] = [str(RAIZ/'ferramentas/fendas'), str(RAIZ/'ferramentas/arena')]
import gerar_natureza_original as N
import gerar_arena as G

SAIDA = RAIZ/'assets/cenario/substitutos'
ESTACOES = [('spring','primavera'),('summer','verao'),('autumn','outono'),('winter','inverno')]


def abrir(p): return Image.open(p).convert('RGBA')
def tile(im,x,y): return im.crop((x*16,y*16,x*16+16,y*16+16))
def salvar(im,p):
    p.parent.mkdir(parents=True,exist_ok=True)
    im.save(p)


def preparar_natureza():
    N.main()
    pastas=['assets/cenario/Seasonal Forest/arena','assets/cenario/fenda_bosque']
    pastas += [f'assets/cenario/fendas/andar_{i:02}' for i in (6,10)]
    trocas={}
    for pasta in pastas:
        relativo='natureza' if 'Seasonal Forest' in pasta else pasta.removeprefix('assets/cenario/')
        mascara=abrir(N.FONTE/'mascaras_margens'/f"{relativo.replace('/', '_')}.png").convert('L')
        for indice,(e,_) in enumerate(ESTACOES):
            p=RAIZ/pasta/f'{e}.png'
            if not p.exists():continue
            # Apenas dimensões da folha anterior; o desenho é inteiramente novo.
            tamanho=Image.open(p).size
            im=N.atlas_compativel(tamanho,indice,G)
            agua=N.material('agua',indice)
            for y in range(256,tamanho[1]):
                for x in range(tamanho[0]):
                    valor=mascara.getpixel((x,y-256))
                    cor=agua.getpixel((x%16,y%16)) if valor==255 else (0,0,0,0)
                    if valor==255 and any(0<=x+dx<mascara.width and 0<=y-256+dy<mascara.height and mascara.getpixel((x+dx,y-256+dy))==1 for dx,dy in [(0,-1),(0,1),(-1,0),(1,0)]):
                        cor=N.cores(indice,'agua')[0]
                    im.putpixel((x,y),cor)
            destino=SAIDA/relativo/f'{e}.png'
            salvar(im,destino)
            trocas['res://'+str(p.relative_to(RAIZ))]='res://'+str(destino.relative_to(RAIZ))
    from PIL import ImageDraw
    for indice,(e,pt) in enumerate(ESTACOES):
        salvar(N.arvore(indice),SAIDA/f'natureza/arvore_{e}.png')
        brilho=Image.new('RGBA',(64,48)); d=ImageDraw.Draw(brilho)
        for y in range(3):
            for x in range(4):
                px=x*16+3+y*2;py=y*16+7
                d.line((px,py,px+2+x%2,py),fill=N.cores(indice,'agua')[4])
                if x%2:d.point((px+5,py-2),fill=N.cores(indice,'agua')[3])
        salvar(brilho,SAIDA/f'natureza/brilho_{e}.png')
        for p in (RAIZ/'assets/cenario/fazenda/entulho'/pt).glob('*.png'):
            tamanho=Image.open(p).size
            parte=N.pedra(indice,16,int(p.stem.rsplit('_',1)[1])) if p.stem.startswith('pedra') else N.arbusto(indice,pequeno=True) if p.stem=='arbusto' else abrir(RAIZ/f'assets/cenario/algoland_original/ciclo_carvalho/{pt}/arvoreta.png') if p.stem=='arvoreta' else N.planta(indice)
            if parte.width>tamanho[0] or parte.height>tamanho[1]:parte.thumbnail(tamanho,Image.Resampling.NEAREST)
            quadro=Image.new('RGBA',tamanho)
            quadro.paste(parte,((tamanho[0]-parte.width)//2,tamanho[1]-parte.height))
            salvar(quadro,SAIDA/'entulho'/pt/p.name)
    for i,nome in enumerate(G.BRILHO_ARQUIVOS):
        trocas['res://assets/cenario/Seasonal Forest/seasonal water animations/'+nome]='res://assets/cenario/substitutos/natureza/brilho_'+ESTACOES[i][0]+'.png'
    from preparar_terra_natural import exportar_bancos
    exportar_bancos(N)
    from preparar_terra_mascarada import preparar as preparar_mascaras
    preparar_mascaras()
    return trocas


def preparar_madeira():
    """Madeira dos interiores locais PixelLab, sem fonte de pacote externo."""
    fonte=abrir(RAIZ/'arte/fontes/cenario/interiores/casa_bento_mana/sala.png')
    out=Image.new('RGBA',(512,256))
    for y in range(16):
        for x in range(32):
            out.paste(fonte.crop((64+(x%4)*16,96+(y%2)*16,80+(x%4)*16,112+(y%2)*16)),(x*16,y*16))
    for ys,fator in [([2],.70),([5,6],.85),([9,10],1.0)]:
        for y in ys:
            for x in range(5):
                parte=fonte.crop((64+(x%4)*16,96,80+(x%4)*16,112))
                parte.putdata([(round(r*fator),round(g*fator),round(b*fator),a) for r,g,b,a in parte.get_flattened_data()])
                out.paste(parte,(x*16,y*16))
    for x in range(17,22):
        out.paste(fonte.crop((96,32,112,64)),(x*16,224))
    for x,y in [(7,2),(6,2),(8,2),(7,1),(8,1),(6,1)]:
        out.paste((24,22,27,255),(x*16,y*16,x*16+16,y*16+16))
    # Vigas em regiões próprias: não repetir a faixa de reboco nas laterais.
    viga=fonte.crop((64,96,80,112))
    viga.putdata([(round(r*.55),round(g*.55),round(b*.55),a) for r,g,b,a in viga.get_flattened_data()])
    for x in range(400,480,16):out.paste(viga.crop((0,0,16,8)),(x,224))
    out.paste(viga.crop((0,0,8,16)),(496,224))
    # Janela inteira com parede ao redor, no plano da face da sala.
    out.paste(fonte.crop((64,32,96,64)),(384,16))
    salvar(out,SAIDA/'interiores/madeira.png')
    return {'res://assets/cenario/Starter Pack/home interiors, timber roof.png':'res://assets/cenario/substitutos/interiores/madeira.png'}


def preparar_moveis():
    out=Image.new('RGBA',(256,96))
    top=RAIZ/'assets/cenario/cidade/decoracao/mobiliario/topdown'
    recortes=[(top/'cama.png',(208,6,32,58)),
              (top/'cadeira.png',(1,21,13,26)),
              (top/'mesa_media.png',(39,5,34,42)),
              (RAIZ/'arte/fontes/cenario/interiores/venda_mana/bau.png',(96,32,32,26)),
              (RAIZ/'arte/fontes/cenario/interiores/venda_mana/prateleira.png',(128,0,32,48))]
    for fonte,(x,y,w,h) in recortes:
        im=abrir(fonte);im=im.crop(im.getbbox())
        im.thumbnail((w,h),Image.Resampling.NEAREST)
        out.paste(im,(x+(w-im.width)//2,y+h-im.height))
    cafe=abrir(top/'mesa_grande.png').crop((43,10,53,18))
    out.paste(cafe,(177,68))
    salvar(out,SAIDA/'interiores/moveis.png')
    return {'res://assets/cenario/Starter Pack/cozy furnishings sampler.png':'res://assets/cenario/substitutos/interiores/moveis.png'}


def integrar(trocas):
    alterados=[]
    for pasta in ['codigo','cenas','recursos']:
        for p in (RAIZ/pasta).rglob('*'):
            if p.suffix not in ['.gd','.tscn','.tres']:continue
            texto=p.read_text();novo=texto
            for antes,depois in trocas.items():novo=novo.replace(antes,depois)
            if p == RAIZ/'cenas/casa.tscn':
                blocos=re.split(r'\n(?=\[)',novo)
                for i,b in enumerate(blocos):
                    if b.startswith('[node name="Cafe_'):
                        blocos[i]=b.replace(', -22)',', -15)')
                    elif b.startswith('[sub_resource type="AtlasTexture" id="Atlas_Bau"'):
                        blocos[i]=re.sub(r'region = Rect2\([^)]*\)','region = Rect2(96, 32, 32, 26)',b)
                    elif b.startswith('[node name="Bau"'):
                        blocos[i]=re.sub(r'offset = Vector2\([^)]*\)','offset = Vector2(-16, -26)',b)
                novo='\n'.join(blocos)
            # O atlas Arctic também continha plantas; não tratá-las como árvores.
            if 'id="Atlas_flor_0_14"' in novo:
                novo=re.sub(r'(\[ext_resource[^\n]*path=")[^"]+(" id="1_quwo3"\])',r'\1res://assets/cenario/substitutos/natureza/spring.png\2',novo)
                blocos=re.split(r'\n(?=\[)',novo)
                for i,b in enumerate(blocos):
                    if b.startswith('[sub_resource type="AtlasTexture" id="Atlas_flor_'):
                        n=int(re.search(r'Atlas_flor_0_(\d+)',b).group(1))
                        b=re.sub(r'region = Rect2\([^)]*\)',f'region = Rect2(0, {128 if n%2 else 144}, 16, 16)',b)
                        if 'resource_name' not in b:b=b.replace('atlas =','resource_name = "amostra"\natlas =')
                        blocos[i]=b
                    elif b.startswith('[sub_resource type="AtlasTexture" id="Atlas_boneco"'):
                        b=re.sub(r'region = Rect2\([^)]*\)','region = Rect2(32, 128, 32, 32)',b)
                        if 'resource_name' not in b:b=b.replace('atlas =','resource_name = "amostra"\natlas =')
                        blocos[i]=b
                    elif b.startswith('[node ') and 'texture = SubResource("Atlas_flor_' in b:
                        blocos[i]=re.sub(r'offset = Vector2\([^)]*\)','offset = Vector2(0, -15)',b)
                    elif b.startswith('[node ') and 'texture = SubResource("Atlas_boneco")' in b:
                        blocos[i]=re.sub(r'offset = Vector2\([^)]*\)','offset = Vector2(-16, -31)',b)
                novo='\n'.join(blocos)
            # Carvalhos cortáveis usam a mesma árvore adulta do ciclo, com
            # tronco e pivô iguais aos do toco e das fases menores.
            if p.name == 'terreno_fazenda.tscn':
                arvore_id=re.search(r'path="res://assets/cenario/substitutos/natureza/arvore_[^"]+" id="([^"]+)"',novo)
                if arvore_id:
                    novo=re.sub(r'(\[sub_resource type="AtlasTexture" id="Atlas_carvalho"\]\n)[\s\S]*?(?=\n\[)',lambda m:m[1]+f'resource_name = "arvore"\natlas = ExtResource("{arvore_id[1]}")\nregion = Rect2(0, 0, 128, 128)\n',novo,count=1)
            # As árvores da família anterior passam a usar o quadro nativo
            # original com margem fixa; base e posição no mundo não mudam.
            ids=[]
            for linha in novo.splitlines():
                if linha.startswith('[ext_resource') and ('assets/cenario/23.05a - Arctic Woodland' in linha or 'assets/cenario/substitutos/natureza/arvore_' in linha):
                    ident=re.search(r' id="([^"]+)"',linha).group(1);ids.append(ident)
                    e=next((e for e,_ in ESTACOES if e in linha),'winter')
                    repl=re.sub(r'uid="[^"]+" ','',linha)
                    repl=re.sub(r'path="[^"]+"',f'path="res://assets/cenario/substitutos/natureza/arvore_{e}.png"',repl)
                    novo=novo.replace(linha,repl)
            if ids:
                blocos=re.split(r'\n(?=\[)',novo);atlas_ids=[]
                for i,b in enumerate(blocos):
                    if b.startswith('[sub_resource type="AtlasTexture"') and any(f'atlas = ExtResource("{ident}")' in b for ident in ids):
                        atlas_ids.append(re.search(r'id="([^"]+)"',b).group(1))
                        blocos[i]=re.sub(r'region = Rect2\([^)]*\)','region = Rect2(0, 0, 128, 128)',b)
                for i,b in enumerate(blocos):
                    if b.startswith('[node ') and any(f'texture = SubResource("{ident}")' in b for ident in atlas_ids):
                        blocos[i]=re.sub(r'offset = Vector2\([^)]*\)','offset = Vector2(-64, -127)',b)
                novo='\n'.join(blocos)
            if p.name=='estacoes.gd':
                novo=re.sub(r'res://assets/cenario/23.05a - Arctic Woodland 1.1/evergreen trees/evergreen trees \((spring|summer|autumn|winter)[^"]+\.png',r'res://assets/cenario/substitutos/natureza/arvore_\1.png',novo)
            novo=re.sub(r'(\[sub_resource type="AtlasTexture" id="Atlas_abeto"\]\n)resource_name = "arvore"',r'\1resource_name = "arvore_var"',novo)
            if p.suffix == '.tscn':
                from remover_arbustos_rejeitados import remover
                novo=remover(novo)
            if novo!=texto:p.write_text(novo);alterados.append(str(p.relative_to(RAIZ)))
    return alterados


def main():
    from preparar_ciclo_carvalho import main as preparar_ciclo
    preparar_ciclo()
    SAIDA.mkdir(parents=True,exist_ok=True)
    trocas=preparar_natureza()|preparar_madeira()|preparar_moveis()
    trocas['res://assets/cenario/fazenda/entulho/']='res://assets/cenario/substitutos/entulho/'
    alterados=integrar(trocas)
    manifesto={'origens':['AlgoLand original: ferramentas/cenario/gerar_natureza_original.py','PixelLab local: sala da casa Bento','PixelLab local: mobiliário','image_gen: arte/fontes/cenario/arbustos_pedras/'], 'grade':16,'escala_no_motor':1,'adaptacoes':{'arvores':'128x128; desenho112x112 e pivô64,127','pedras':'quatro formas baixas e largas; quadros16x16, desenho15x10, base alinhada','arbustos':'rejeitados pelo usuário; retirados junto das colisões'},'estacoes':[p for _,p in ESTACOES],'preservar':['ids','células','pivôs','colisões','recursos de outras origens'],'substituicoes':trocas}
    (RAIZ/'arte/fontes/cenario/substituicao_mana/manifesto.json').write_text(json.dumps(manifesto,ensure_ascii=False,indent=2)+'\n')
    print(f'{len(trocas)} texturas substituídas; {len(alterados)} consumidores atualizados.')

if __name__=='__main__':main()
