"""Cavernas RPGW originais: peças32px subdivididas em grade16, sem escala.

As paredes são recuperadas dos arranjos originais completos com transparência,
sem classificar efeitos ou vegetação de imagens de demonstração.
"""
from pathlib import Path
from collections import Counter
import math,json
from PIL import Image,ImageFilter,ImageDraw,ImageChops
RAIZ=Path(__file__).resolve().parents[2]
FONTE=RAIZ/'arte/fontes/fendas/rpgw_caves'
DESTINO=RAIZ/'assets/cenario/fendas/rpgw_caves'
_CACHE=None

def tipo_pixel(p):
 r,g,b,a=p
 if a<128:return 'F'
 if r<18 and g<18 and b<18:return 'V'
 return 'R'

def preparar():
 global _CACHE
 if _CACHE:return _CACHE
 im=Image.open(FONTE/'MainLev2.0.png').convert('RGBA');pecas=[];unicos={};grid={}
 for y in range(9):
  for x in range(25):
   parte=im.crop((x*32,416+y*32,x*32+32,448+y*32));cont=Counter(tipo_pixel(px) for px in parte.getdata())
   tipo='F' if cont['F']>512 else 'V' if cont['V']>615 else 'R';grid[x,y]=tipo
   k=parte.tobytes()
   if k not in unicos:unicos[k]=len(pecas);pecas.append({'imagem':parte,'contagem':cont,'tipo':tipo,'locais':[],'origem':[x*32,416+y*32]})
   pecas[unicos[k]]['locais'].append((x,y))
 for variante in range(16):
  pecas.append({'imagem':Image.new('RGBA',(32,32)), 'contagem':Counter({'F':1024}),'tipo':'F','locais':[], 'origem':[-1,-1], 'variante':variante})
 for p in pecas:p['contextos']=[tuple(grid.get((x+dx,y+dy),'F') for dy in range(-2,3) for dx in range(-2,3)) for x,y in p['locais']] or [tuple(['F']*25)]
 DESTINO.mkdir(parents=True,exist_ok=True)
 base_piso=im.crop((64,880,96,912))
 # Fonte nativa de cada chão; as coordenadas são registradas no manifesto.
 pisos=[base_piso,im.crop((96,1120,128,1152)),im.crop((544,1072,576,1104)),im.crop((1312,1072,1344,1104))]
 # Um atlas por material de chão, todos com exatamente as mesmas peças e colisão.
 for andar,material in [(3,3),(4,0),(7,2),(9,0),(11,1)]:
  atlas=Image.new('RGBA',(512,math.ceil(len(pecas)/16)*32),(10,9,9,255))
  for i,p in enumerate(pecas):
   bloco=pisos[material].copy()
   if 'variante' in p:
    v=p['variante'];bloco=ImageChops.offset(bloco,(v%4)*8,(v//4)*8)
    if v%2:bloco=bloco.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
   if p['tipo']=='V':bloco=Image.new('RGBA',(32,32),(10,9,9,255))
   else:bloco.alpha_composite(p['imagem'])
   atlas.paste(bloco,(i%16*32,i//16*32))
  atlas.save(DESTINO/f'andar_{andar:02}.png')
 # Props mantêm os quadros64 e pivô(32,60) já usados pelo sistema de profundidade.
 decor=Image.open(FONTE/'decorative.png').convert('RGBA')
 props=Image.new('RGBA',(256,256))
 # Limites completos medidos na folha original; nenhum objeto é reduzido ou fatiado.
 recortes_objetos={
  0:(235,77,284,128),1:(303,80,343,128),2:(355,103,381,128),3:(100,205,149,256),
  4:(235,77,284,128),5:(303,80,343,128),6:(41,208,81,256),7:(100,205,149,256),
  8:(98,771,125,794),9:(104,750,128,768),10:(65,610,96,637),11:(100,205,149,256),
  12:(189,610,220,637),13:(98,771,125,794),14:(65,610,96,637),15:(355,103,381,128),
 }
 for ident,box in recortes_objetos.items():
  parte=decor.crop(box)
  assert parte.width<=56 and parte.height<=56, f'Objeto {ident} não cabe inteiro no quadro'
  x=ident%4*64;y=ident//4*64
  props.alpha_composite(parte,(x+32-parte.width//2,y+60-parte.height))
 props.save(DESTINO/'objetos.png')
 for estacao,tom in [('spring',(1,1,1)),('summer',(1.04,1,.94)),('autumn',(1,.95,.90)),('winter',(.94,.99,1.08))]:
  variante=props.copy();variante.putdata([(min(255,round(r*tom[0])),min(255,round(g*tom[1])),min(255,round(b*tom[2])),a) for r,g,b,a in props.getdata()])
  variante.save(DESTINO/f'objetos_{estacao}.png')
 (FONTE/'objetos_completos.json').write_text(json.dumps({'fonte':'decorative.png','quadro':[64,64],'pivo':[32,60],'escala':1,'recortes':recortes_objetos},ensure_ascii=False,indent=2)+'\n')
 dados={'origem':'RPGW_Caves_v2.1','grade_original':32,'grade_godot':16,'escala':1,'paredes':[p['origem'] for p in pecas],'pisos':[[64,880,32,32],[96,1120,32,32],[544,1072,32,32],[1312,1072,32,32]],'estacoes':'material protegido com quatro tons; precipitação bloqueada'}
 (FONTE/'recortes.json').write_text(json.dumps(dados,ensure_ascii=False,indent=2)+'\n')
 _CACHE=(pecas,grid,im);return _CACHE

def encaixar_paredes(pecas,grade,x0,y0,x1,y1,andar,piso_original):
 """Minimiza em conjunto as quatro costuras; peças de borda não são piso puro."""
 n=len(pecas)
 lados=[]
 for p in pecas:
  im=p['imagem'];lados.append([[im.getpixel(pos) for pos in linha] for linha in
   [[(0,z) for z in range(32)],[(z,0) for z in range(32)],[(31,z) for z in range(32)],[(z,31) for z in range(32)]]])
 custos=[]
 for lado,oposto in [(0,2),(1,3),(2,0),(3,1)]:
  matriz=[]
  for a in lados:
   linha=[]
   for b in lados:
    nota=0
    for aa,bb in zip(a[lado],b[oposto]):
     ta,tb=tipo_pixel(aa),tipo_pixel(bb)
     nota+=(320 if (ta=='F')!=(tb=='F') else 12) if ta!=tb else 0
     if ta!='F' and tb!='F':nota+=sum(abs(aa[k]-bb[k]) for k in range(3))/48
    linha.append(nota/32)
   matriz.append(linha)
  custos.append(matriz)
 candidatos={
  'F':[i for i,p in enumerate(pecas) if p['contagem']['F']==1024],
  'V':[i for i,p in enumerate(pecas) if p['contagem']['V']>=1000],
  'R':list(range(n-16)),
 }
 escolhas={};notas={};deltas=[(-1,0),(0,-1),(1,0),(0,1)]
 for y in range(y0,y1):
  for x in range(x0,x1):
   tipo=grade.get((x,y),'V');op=candidatos[tipo]
   if tipo=='F':
    escolhas[x,y]=n-16+(((x*73856093)^(y*19349663)^andar)&15);continue
   if tipo=='V':escolhas[x,y]=int(op[0]);continue
   ctx=tuple('F' if (x+dx,y+dy) in piso_original else 'V' for dy in range(-2,3) for dx in range(-2,3))
   # Contexto orienta a parede; continuidade de pixels tem prioridade.
   unary=[min(sum(a!=('F' if b=='F' else 'V') for a,b in zip(ctx,c)) for c in pecas[i]['contextos']) + 12*abs(pecas[i]['contagem']['F']/1024-int((x,y) in piso_original)) for i in op]
   notas[x,y]=unary;escolhas[x,y]=op[min(range(len(op)),key=unary.__getitem__)]
 pontos=list(notas)
 for passo in range(24):
  mudancas=0
  for x,y in (pontos if passo%2==0 else reversed(pontos)):
   op=candidatos['R'];custo=notas[x,y].copy()
   for lado,(dx,dy) in enumerate(deltas):
    vizinho=escolhas.get((x+dx,y+dy))
    if vizinho is not None:custo=[v+custos[lado][i][vizinho] for v,i in zip(custo,op)]
   melhor=op[min(range(len(op)),key=custo.__getitem__)]
   if melhor!=escolhas[x,y]:escolhas[x,y]=melhor;mudancas+=1
  if not mudancas:break
 # Relaxação em pares evita mínimos locais: duas quinas podem precisar trocar juntas.
 def opcoes(ponto,ignorar):
  x,y=ponto;op=candidatos['R'];valores=[]
  for k,i in enumerate(op):
   valor=notas[ponto][k]
   for lado,(dx,dy) in enumerate(deltas):
    viz=(x+dx,y+dy)
    if viz!=ignorar and viz in escolhas:valor+=custos[lado][i][escolhas[viz]]
   valores.append((valor,i))
  return sorted(valores)[:12]
 for passo in range(6):
  mudancas=0
  for ponto in (pontos if passo%2==0 else reversed(pontos)):
   x,y=ponto
   for lado,(dx,dy) in [(2,(1,0)),(3,(0,1))]:
    viz=(x+dx,y+dy)
    if viz not in notas:continue
    aa=opcoes(ponto,viz);bb=opcoes(viz,ponto)
    _,a,b=min((va+vb+custos[lado][a][b],a,b) for va,a in aa for vb,b in bb)
    if a!=escolhas[ponto] or b!=escolhas[viz]:
     escolhas[ponto]=a;escolhas[viz]=b;mudancas+=1
  if not mudancas:break
 return escolhas

def construir_geometria(m,p,B,G,T):
 import construir_cavernas as C
 pecas,_,_=preparar();x0=min(x for x,y in m.chao)//2*2;y0=min(y for x,y in m.chao)//2*2
 x1=(max(x for x,y in m.chao)//2+1)*2;y1=(max(y for x,y in m.chao)//2+1)*2
 grade={}
 for y in range(y0//2,y1//2):
  for x in range(x0//2,x1//2):
   if C.distancia_ambiente(p,B,(x//2)*64+32,(y//2)*64+32)<0:grade[x,y]='F'
 piso_original=set(grade)
 # A faixa de acabamento ocupa também a primeira célula do piso: as quinas nativas
 # precisam desse espaço para fechar a curva, em vez de serem cortadas pelo preenchimento.
 for y in range(y0//2,y1//2):
  for x in range(x0//2,x1//2):
   vizinhos=[(x+dx,y+dy) in piso_original for dy in range(-1,2) for dx in range(-1,2)]
   if any(vizinhos) and not all(vizinhos):grade[x,y]='R'
   elif (x,y) not in piso_original and any((x+dx,y+dy) in piso_original for dx in (-1,0,1) for dy in (2,3)):grade[x,y]='R'
 origem=(x0*16,y0*16);mascara=Image.new('L',((x1-x0)*16,(y1-y0)*16));celulas=[]
 escolhas=encaixar_paredes(pecas,grade,x0//2,y0//2,x1//2,y1//2,p['andar'],piso_original)
 for (x,y),indice in escolhas.items():
   tipo=grade.get((x,y),'V');t=pecas[indice]
   for dy in range(2):
    for dx in range(2):celulas.append((x*2+dx,y*2+dy,0,(indice%16)*2+dx,(indice//16)*2+dy,0))
   parte=Image.new('L',(32,32));parte.putdata([255 if px[3]<128 else 0 for px in t['imagem'].getdata()])
   if tipo=='F':parte=Image.new('L',(32,32),255)
   mascara.paste(parte,(x*32-origem[0],y*32-origem[1]))
 mascara=mascara.filter(ImageFilter.MaxFilter(7)).filter(ImageFilter.MinFilter(7))
 d=ImageDraw.Draw(mascara)
 for cx,cy,rx,ry in p['lago']['lobos']:d.ellipse((cx-rx-origem[0],cy-ry-origem[1],cx+rx-origem[0],cy+ry-origem[1]),fill=0)
 m.tiles_caverna=celulas;m.mascara_piso=mascara;m.origem_piso=origem
 aneis=G.contornos(lambda x,y:-1 if C.piso_em(m,x,y) else 1,origem[0],origem[1],x1*16,y1*16,4)
 aneis=[G.simplificar_anel(a,.8) for a in aneis if B.area(a)>64];aneis.sort(key=B.area,reverse=True)
 m.poli=aneis[0];m.obstaculos=aneis[1:]
 for no in m.base.nos:
  if no['caminho']=='LimiteArena/Contorno':no['bloco']='[node name="Contorno" type="CollisionPolygon2D" parent="LimiteArena"]\nbuild_mode = 1\npolygon = %s\n'%T.poligono(m.poli)
 print(f'RPGW {p["andar"]}: {len(pecas)} peças nativas, {len(celulas)} células16',flush=True)
