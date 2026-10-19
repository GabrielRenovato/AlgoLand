"""Integra as três paletas Gentle Forest em grade16, com calendário e árvores nativas.

Mapas1(claro),2(selva),5(selva úmida),8(ao luar). Fonte original preservada.
"""
from pathlib import Path
import colorsys,random,math,re
from PIL import Image
RAIZ=Path(__file__).resolve().parents[2]
FONTE=RAIZ/'arte/fontes/fendas/gentle_forest'
DESTINO=RAIZ/'assets/cenario/fendas/gentle_forest'
PALETAS={1:'01',2:'02',5:'02',8:'03'}
ESTACOES=['spring','summer','autumn','winter']

def sazonal(im,e,paleta,vegetacao=True):
 im=im.convert('RGBA');out=im.copy()
 if e=='spring':return out
 pixels=[]
 for r,g,b,a in im.getdata():
  h,s,v=colorsys.rgb_to_hsv(r/255,g/255,b/255)
  folha=(.16<h<.49 if paleta!='03' else .42<h<.70) and s>.23 and a>0
  if folha and vegetacao:
   if e=='summer':h=max(0,h-.015);v*=.90;s=min(1,s*1.05)
   elif e=='autumn':h=.05+(.04*v) if paleta!='03' else .80+.08*v;s*=.70;v*=.88
   elif e=='winter':h=.56;s=.10 if v>.48 else .28;v=min(1,.43+v*.57)
   rr,gg,bb=colorsys.hsv_to_rgb(h,s,v);r,g,b=round(rr*255),round(gg*255),round(bb*255)
  pixels.append((r,g,b,a))
 out.putdata(pixels);return out

def acabar_copas(im):
 """Fecha a silhueta que encosta nos limites dos quadros80x96 originais.

 Recorta somente pontas de folhas na borda, mantendo pixels, escala e raízes.
 A mesma máscara é aplicada antes das variantes sazonais.
 """
 im=im.convert('RGBA').copy()
 for origem in (0,80):
  for y in range(96):
   for x in range(80):
    cortar=(y==0 or (y<4 and abs(x-40)>[0,5,10,15][y]))
    if x in (0,79):cortar=True
    elif x in (1,78) and not 32<=y<=44:cortar=True
    if cortar:
     r,g,b,a=im.getpixel((origem+x,y));im.putpixel((origem+x,y),(r,g,b,0))
 return im

def tile(im,x,y):return im.crop((x*16,y*16,x*16+16,y*16+16))

def relevo_completo(folha):
 """Platô nativo completo de64x64, centralizado no espaço reservado de96x128.

 A região(112,128,208,256) da fonte é um kit de paredes com centro aberto
 e fragmentos vizinhos; não representa um penhasco inteiro.
 """
 quadro=Image.new('RGBA',(96,128))
 quadro.alpha_composite(folha.crop((0,64,64,128)),(16,32))
 return quadro

def preparar_folha(caminho,p,e,m,G):
 paleta=PALETAS[p['andar']];base=Image.open(FONTE/f'gentle forest v{paleta}.png').convert('RGBA');src=sazonal(base,e,paleta)
 out=Image.new('RGBA',(256,256+math.ceil(len(m.tiles_margem)/16)*16))
 def colar(dest,orig,espelho=None):
  parte=tile(src,*orig)
  if espelho is not None:parte=parte.transpose(espelho)
  out.paste(parte,(dest[0]*16,dest[1]*16))
 for i,d in enumerate(G.GRAMA):colar(d,[(1,5),(2,5),(1,6),(2,6),(1,5)][i],Image.Transpose.FLIP_LEFT_RIGHT if i==4 else None)
 for d in G.FLORES:
  colar(d,(1,5));flor=tile(src,8+(d[0]%3),6);out.paste(flor,(d[0]*16,d[1]*16),flor)
 for d in G.CENTRO_TERRA:colar(d,(1,1))
 for nome,d in G.BORDA_TERRA.items():colar(d,{'NO':(0,0),'N':(1,0),'NE':(3,0),'O':(0,1),'L':(3,1),'SO':(0,3),'S':(1,3),'SE':(3,3)}[nome])
 for nome,d in G.CANTO_INTERNO.items():colar(d,{'SE':(4,0),'SO':(5,0),'NE':(4,1),'NO':(5,1)}[nome])
 for i,d in enumerate(G.AGUA):colar(d,[(1,9),(2,9),(1,10),(2,10),(2,11)][i])
 # Pequenos detalhes e arbustos com base real e tela compatível com o código existente.
 for i,d in enumerate(G.PLANTAS):colar(d,(8+i%3,6))
 plantas=sazonal(Image.open(FONTE/f'gentle 32x32 v{paleta}.png'),e,paleta)
 out.paste(plantas.crop((96,0,128,32)),(0,160))
 for dy in range(2):
  for dx in range(2):colar((2+dx,8+dy),(8+dx,dy))
 out.alpha_composite(relevo_completo(src),(5*16,8*16))
 class Folha:
  def pix(self,tx,ty,x,y):return out.getpixel((tx*16+x,ty*16+y))
 folha=Folha()
 # Cores da própria margem mineral do pacote, sem amostrar regiões de outra folha.
 cores=[src.getpixel((34,116)),src.getpixel((35,116)),src.getpixel((36,116))]
 for k,(grade,vg,va) in enumerate(m.tiles_margem):
  bloco=Image.new('RGBA',(16,16));dados=[]
  for i,d in enumerate(grade):
   x,y=i%16,i//16
   if d>=1:cor=folha.pix(*vg,x,y)
   elif d>=0:cor=G.luminosidade_escura(folha.pix(*vg,x,y))
   elif d>=-3:cor=cores[min(2,int(-d))]
   else:cor=folha.pix(*va,x,y)
   dados.append(cor)
  bloco.putdata(dados);out.paste(bloco,(k%16*16,256+k//16*16))
 out.save(caminho)
 pasta=DESTINO/f'v{paleta}';pasta.mkdir(parents=True,exist_ok=True)
 arvore=acabar_copas(Image.open(FONTE/f'gentle trees 80x96 v{paleta}.png'))
 sazonal(arvore,e,paleta).save(pasta/f'arvores_{e}.png')
 brilho=Image.open(FONTE/f'gentle water sparkles A v{paleta}.png')
 brilho.save(pasta/'brilho.png')
 props=Image.new('RGBA',(256,256))
 # Objetos inteiros; o atlas de terreno inclui grama que não pode tapar outras copas.
 partes={8:plantas.crop((0,0,32,32)),9:src.crop((128,48,176,80)),
         10:plantas.crop((96,0,128,32)),11:plantas.crop((64,0,96,32)),
         13:plantas.crop((96,0,128,32))}
 for ident,parte in partes.items():
  # A máscara vem da paleta clara e é idêntica nas três paletas/quatro estações.
  referencia=Image.open(FONTE/'gentle forest v01.png').convert('RGBA').crop((128,48,176,80)) if ident==9 else None
  if referencia is not None:
   pixels=list(parte.getdata())
   for i,(r,g,b,a) in enumerate(referencia.getdata()):
    h,s,v=colorsys.rgb_to_hsv(r/255,g/255,b/255)
    if .13<h<.49 and s>.23:pixels[i]=(*pixels[i][:3],0)
   parte.putdata(pixels)
  x=ident%4*64;y=ident//4*64
  props.paste((0,0,0,0),(x,y,x+64,y+64));props.alpha_composite(parte,(x+32-parte.width//2,y+60-parte.height))
 props.save(pasta/f'objetos_{e}.png')

def compor(m,p,B,G):
 # Árvores80x96 fora das rotas, com copas afastadas dos centros de combate.
 novos=[]
 for s in m.sprites_novos:
  if s['tipo'] not in ['abeto','carvalho']:novos.append(s);continue
  x,y=s['x'],s['y']
  if B.distancia_caminhavel(x,y)<35 or B.distancia_caminhavel(x,y-58)<8:continue
  novos.append(s)
 m.sprites_novos=novos;m.penhasco={}
 rng=random.Random(1907+p['andar']);x0,y0,w,h=p['limites'];usados=[]
 for _ in range(400):
  x=rng.randrange((x0+16)//16,(x0+w-112)//16);y=rng.randrange((y0+16)//16,(y0+h-144)//16)
  if any(B.distancia_caminhavel(xx,yy)<35 or m.lagoa.dist(xx,yy)<20 for xx in range(x*16,(x+6)*16+1,16) for yy in range(y*16,(y+8)*16+1,16)):continue
  if any(math.hypot(x*16-a,y*16-b)<180 for a,b in usados):continue
  usados.append((x*16,y*16))
  for dy in range(8):
   for dx in range(6):m.penhasco[x+dx,y+dy]=(5+dx,8+dy)
  m.sprites_novos=[s for s in m.sprites_novos if not(x*16-30<s['x']<(x+6)*16+30 and y*16-10<s['y']<(y+8)*16+60)]
  if len(usados)>=(8 if p['andar']==8 else 4):break

def integrar(texto,p):
 paleta=PALETAS[p['andar']]
 ext='[ext_resource type="Script" path="res://codigo/fendas/gentle_sazonal.gd" id="gentle_script"]\n'
 for e in ESTACOES:ext+=f'[ext_resource type="Texture2D" path="res://assets/cenario/fendas/gentle_forest/v{paleta}/arvores_{e}.png" id="gentle_{e}"]\n'
 ext+=f'[ext_resource type="Texture2D" path="res://assets/cenario/fendas/gentle_forest/v{paleta}/brilho.png" id="gentle_brilho"]\n'
 texto=texto.replace('[sub_resource',ext+'[sub_resource',1)
 texto=texto.replace('region = Rect2(16, 128, 16, 32)','region = Rect2(0, 160, 32, 32)')
 sub=''
 for i in range(2):sub+=f'[sub_resource type="AtlasTexture" id="arvore_gentle_{i}"]\nresource_name = "gentle_arvore"\natlas = ExtResource("gentle_spring")\nregion = Rect2({i*80},0,80,96)\n\n'
 texto=texto.replace('[node name="Terrains"',sub+'[node name="Terrains"',1)
 blocos=re.split(r'\n(?=\[)',texto);n=0
 for i,b in enumerate(blocos):
  if b.startswith('[node name="AbetoBorda'):
   b=re.sub(r'texture = SubResource\("[^"]+"\)',f'texture = SubResource("arvore_gentle_{n%2}")',b)
   b=re.sub(r'offset = Vector2\([^)]*\)','offset = Vector2(-40,-95)',b)
   b+='\nmetadata/arvore_gentle = true\n';blocos[i]=b;n+=1
 texto='\n'.join(blocos)
 texto=texto.replace('offset = Vector2(-8, -31)','offset = Vector2(-16, -31)')
 texto=texto.replace('seguir_calendario = true','seguir_calendario = true\nbrilhos_personalizados = Array[Texture2D]([ExtResource("gentle_brilho"),ExtResource("gentle_brilho"),ExtResource("gentle_brilho"),ExtResource("gentle_brilho")])')
 refs=', '.join(f'ExtResource("gentle_{e}")' for e in ESTACOES)
 texto+=f'\n[node name="GentleForest" type="Node" parent="."]\nscript = ExtResource("gentle_script")\nfolhas_arvores = Array[Texture2D]([{refs}])\nbrilho = ExtResource("gentle_brilho")\nmetadata/paleta = "{paleta}"\n'
 blocos=re.split(r'\n(?=\[)',texto)
 for i,b in enumerate(blocos):
  if b.startswith('[sub_resource type="TileSetAtlasSource" id="TileSetAtlasSource_arena"]'):
   for y in range(16):
    for x in range(16):
     linha=f'{x}:{y}/0 = 0'
     if linha not in b.splitlines():b+='\n'+linha+'\n'
   blocos[i]=b
 return '\n'.join(blocos)


def corrigir_relevos_existentes():
 """Atualiza somente o recorte defeituoso, mantendo mapas, caminhos e colisões."""
 for andar,paleta in PALETAS.items():
  fonte=Image.open(FONTE/f'gentle forest v{paleta}.png').convert('RGBA')
  for estacao in ESTACOES:
   caminho=RAIZ/f'assets/cenario/fendas/andar_{andar:02}/{estacao}.png'
   folha=Image.open(caminho).convert('RGBA')
   folha.paste((0,0,0,0),(80,128,176,256))
   folha.alpha_composite(relevo_completo(sazonal(fonte,estacao,paleta)),(80,128))
   folha.save(caminho)
  print(f'OK andar {andar}: relevo nativo completo nas quatro estações')


if __name__=='__main__':
 corrigir_relevos_existentes()
