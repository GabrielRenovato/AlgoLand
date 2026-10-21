"""Compatibilidade geométrica dos quatro bosques; arte própria do AlgoLand.

O nome do módulo permanece para os geradores de plantas existentes.
"""
from pathlib import Path
import random,math,re
from PIL import Image
RAIZ=Path(__file__).resolve().parents[2]
PALETAS={1:'01',2:'02',5:'02',8:'03'}
ESTACOES=['spring','summer','autumn','winter']

def preparar_folha(caminho,p,e,m,G):
 from preparar_arte_original import guardar_margens,atlas,objetos,salvar,SAIDA
 guardar_margens(p['andar'],m.tiles_margem)
 base=Image.open(caminho).convert('RGBA')
 atlas(p['andar'],ESTACOES.index(e),base).save(caminho)
 salvar(objetos(ESTACOES.index(e)),SAIDA/f'florestas/objetos_{e}.png')

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
 for e in ESTACOES:ext+=f'[ext_resource type="Texture2D" path="res://assets/cenario/substitutos/arvores_florestas/v{paleta}/{e}.png" id="gentle_{e}"]\n'
 ext+=f'[ext_resource type="Texture2D" path="res://assets/cenario/substitutos/natureza/brilho_spring.png" id="gentle_brilho"]\n'
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



if __name__=='__main__':
 from preparar_arte_original import preparar
 preparar(PALETAS)
