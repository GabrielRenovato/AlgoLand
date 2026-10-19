"""Recupera tiles16px da prévia do autor ampliada2x, sem geração ou pintura.

A grade foi medida por repetição exata: origem(6,10) na imagem nativa.
A escolha de peças compara a vizinhança original de chão/rocha/vazio/água.
"""
from pathlib import Path
from collections import Counter
import json, math
from PIL import Image,ImageDraw,ImageFilter
RAIZ=Path(__file__).resolve().parents[2]
FONTE=RAIZ/'arte/fontes/fendas/caverna_usuario'
_CACHE=None

def classe_pixel(p):
 r,g,b=p[:3]
 if g>r*1.2 and b>r*1.2 and g>=15 and b>=15:return 'W'
 if max(r,g,b)<35:return 'V'
 if r>25 and .78*r<g<r*1.18 and g>b*1.5 and r<115:return 'F'
 return 'R'

def carregar():
 global _CACHE
 if _CACHE:return _CACHE
 im=Image.open(FONTE/'cenario_original.png').convert('RGB')
 im=im.resize((im.width//2,im.height//2),Image.Resampling.NEAREST)
 im.save(FONTE/'cenario_nativo.png')
 cols=(im.width-6)//16;rows=(im.height-10)//16
 grid={};pecas=[];unicos={}
 for y in range(rows):
  for x in range(cols):
   parte=im.crop((6+x*16,10+y*16,22+x*16,26+y*16));cont=Counter(classe_pixel(p) for p in parte.getdata())
   tipo=cont.most_common(1)[0][0];grid[x,y]=tipo
   chave=parte.tobytes()
   if chave not in unicos:unicos[chave]=len(pecas);pecas.append({'imagem':parte,'origem':[6+x*16,10+y*16],'tipo':tipo,'contagem':cont,'locais':[]})
   pecas[unicos[chave]]['locais'].append((x,y))
 atlas=Image.new('RGBA',(256,math.ceil(len(pecas)/16)*16),(0,0,0,255))
 for i,p in enumerate(pecas):
  atlas.paste(p['imagem'],(i%16*16,i//16*16))
  p['contextos']=[tuple(grid.get((x+dx,y+dy),'V') for dy in range(-2,3) for dx in range(-2,3)) for x,y in p['locais']]
 atlas.save(FONTE/'atlas.png')
 (FONTE/'recortes.json').write_text(json.dumps({'autor':'usuário','origem_grade':[6,10],'grade':16,'ampliacao_original':2,'tiles':[{'id':i,'origem':p['origem'],'tipo':p['tipo']} for i,p in enumerate(pecas)]},indent=2,ensure_ascii=False)+'\n')
 _CACHE=(pecas,grid,atlas)
 return _CACHE

def construir_geometria(m,p,B,G,T):
 import construir_cavernas as C
 pecas,_,atlas=carregar()
 x0=min(x for x,y in m.chao);x1=max(x for x,y in m.chao)
 y0=min(y for x,y in m.chao);y1=max(y for x,y in m.chao)
 grade={}
 for y in range(y0,y1+1):
  for x in range(x0,x1+1):
   # A estrutura mantém salões e rotas; o recorte nativo define o pé real da parede.
   xx=(x//4)*64+32;yy=(y//4)*64+32
   if C.distancia_ambiente(p,B,xx,yy)<0:grade[x,y]='W' if m.lagoa.dist(x*16+8,y*16+8)<0 else 'F'
 for y in range(y0,y1+1):
  for x in range(x0,x1+1):
   if (x,y) in grade:continue
   # Face norte alta, bordas laterais e borda frontal baixas, como na fonte.
   if any(grade.get((x+dx,y+dy)) in ['F','W'] for dx,dy in [(-1,0),(1,0),(0,-1),(0,1),(0,2),(0,3)]):grade[x,y]='R'
 margem={cel for cel,tipo in grade.items() if tipo=='F' and any(grade.get((cel[0]+dx,cel[1]+dy))=='W' for dx,dy in [(-1,0),(1,0),(0,-1),(0,1)])}
 for cel in margem:grade[cel]='R'
 # Não propaga a face a partir de outra face: apenas células de piso entram na regra.
 origem=(x0*16,y0*16);mascara=Image.new('L',((x1-x0+1)*16,(y1-y0+1)*16))
 celulas=[];cache={};selecionadas=Counter();escolhas={}
 pesos=[1]*25
 for i in [6,7,8,11,13,16,17,18]:pesos[i]=6
 for i in [7,11,13,17]:pesos[i]=12
 for y in range(y0,y1+1):
  for x in range(x0,x1+1):
   tipo=grade.get((x,y),'V')
   contexto=tuple(grade.get((x+dx,y+dy),'V') for dy in range(-2,3) for dx in range(-2,3))
   beira=(x,y) in margem
   chave=(tipo,contexto,beira)
   if chave not in cache:
    candidatos=[]
    for i,tile in enumerate(pecas):
     if beira:
      if tile['contagem']['W']<8 or tile['contagem']['R']<12:continue
     elif tile['tipo']!=tipo:continue
     if tipo=='V' and tile['contagem']['V']<256:continue
     if tipo in ['R','W'] and any((g>r*1.25 and g>90 and b<g*.7) or min(r,g,b)>150 for r,g,b in tile['imagem'].getdata()):continue
     # O chão usa recortes limpos, sem móveis ou vegetação virando textura repetida.
     if tipo=='F' and tile['contagem']['F']<245:continue
     if tipo=='W' and tile['contagem']['W']<220:continue
     nota=max(sum(w if a==b else -w for w,a,b in zip(pesos,contexto,c)) for c in tile['contextos'])
     candidatos.append((nota,i))
    candidatos.sort(reverse=True)
    melhor=candidatos[0][0];cache[chave]=[(nota,i) for nota,i in candidatos if nota>=melhor-8][:24]
   def nota_encaixe(item):
    nota,i=item;tile=pecas[i];imagem=tile['imagem']
    for deslocamento,vertical in [((-1,0),False),((0,-1),True)]:
     vizinho=escolhas.get((x+deslocamento[0],y+deslocamento[1]))
     if vizinho is None:continue
     outra=pecas[vizinho]['imagem']
     for z in range(16):
      aa=imagem.getpixel((z,0) if vertical else (0,z));bb=outra.getpixel((z,15) if vertical else (15,z))
      # Uma borda com vazio contra piso é um corte visual, não uma variação de textura.
      nota-=8 if (classe_pixel(aa)=='V')!=(classe_pixel(bb)=='V') else 0
      nota-=sum(abs(a-b) for a,b in zip(aa,bb))/150
    return nota
   opcoes=cache[chave]
   if tipo in ['R','V']:indice=max(opcoes,key=nota_encaixe)[1]
   else:indice=opcoes[((x*73856093)^(y*19349663)^p['andar'])%min(4,len(opcoes))][1]
   escolhas[x,y]=indice
   tile=pecas[indice];selecionadas[tipo]+=1
   celulas.append((x,y,0,indice%16,indice//16,0))
   parte=Image.new('L',(16,16))
   parte.putdata([255 if classe_pixel(px)=='F' else 0 for px in tile['imagem'].getdata()])
   if tipo=='F':parte=Image.new('L',(16,16),255)
   mascara.paste(parte,((x-x0)*16,(y-y0)*16))
 mascara=mascara.filter(ImageFilter.MaxFilter(7)).filter(ImageFilter.MinFilter(7))
 m.tiles_caverna=celulas;m.mascara_piso=mascara;m.origem_piso=origem
 aneis=G.contornos(lambda x,y:-1 if C.piso_em(m,x,y) else 1,origem[0],origem[1],(x1+1)*16,(y1+1)*16,4)
 aneis=[G.simplificar_anel(a,.8) for a in aneis if B.area(a)>64];aneis.sort(key=B.area,reverse=True)
 m.poli=aneis[0];m.obstaculos=aneis[1:]
 for no in m.base.nos:
  if no['caminho']=='LimiteArena/Contorno':no['bloco']='[node name="Contorno" type="CollisionPolygon2D" parent="LimiteArena"]\nbuild_mode = 1\npolygon = %s\n'%T.poligono(m.poli)
 # Todo o desenho, inclusive água e cantos, vem deste atlas; evita sobrepor margens antigas.
 m.agua={};m.brilho={};m.detalhes={}
 print(f'Caverna {p["andar"]}: recortes reais do autor {dict(selecionadas)}',flush=True)
