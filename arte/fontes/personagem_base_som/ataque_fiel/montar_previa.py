from pathlib import Path
from PIL import Image, ImageOps, ImageDraw, ImageFont
import json
p=Path(__file__).resolve().parent
r=Image.open(p/'base_algoland_direita_fonte.png').convert('RGBA').resize((192,128),Image.Resampling.NEAREST)
vsource=p/'base_vertical_fonte.png'
v=Image.open(vsource).convert('RGBA').resize((192,256),Image.Resampling.NEAREST)
source=Image.open(p/'referencia_usuario.png').convert('RGBA')
def cell(im,i):
 c=im.crop((i%3*64,i//3*64,i%3*64+64,i//3*64+64))
 c.putalpha(c.getchannel('A').point(lambda a:255 if a>=210 else 0))
 return c
R=[cell(r,i) for i in range(5)]
def vert(i):
 c=cell(v,i).resize((57,57),Image.Resampling.NEAREST)
 out=Image.new('RGBA',(64,64));out.alpha_composite(c,(0,-1));return out
D=[vert(i) for i in range(5)];U=[vert(i+6) for i in range(5)]
# A recuperacao usa a mesma mao da preparacao em cada direcao vertical.
D[4]=ImageOps.mirror(D[4]);U[4]=ImageOps.mirror(U[4])
right_blades=[((18,66,35,80),(2,11)),((56,53,71,76),(3,19)),((92,69,110,80),(15,6)),((211,68,234,80),(3,7)),((324,51,342,68),(3,13))]
down_blades=[((20,89,36,116),(2,4)),((61,89,78,114),(2,3)),((103,112,126,128),(16,3)),((191,111,215,128),(2,2)),((278,87,306,108),(3,17))]
up_blades=[((28,19,43,44),(2,22)),((62,18,78,43),(3,21)),((118,28,142,43),(3,9)),((187,0,205,21),(3,18)),((257,9,279,30),(3,4))]
def blade(box):
 c=source.crop(box)
 for y in range(c.height):
  for x in range(c.width):
   red,g,b,a=c.getpixel((x,y))
   if (g>red*1.35 and g>b*1.35) or (red>230 and b>230 and g<60) or (red>=250 and g>=250 and b>=250):c.putpixel((x,y),(0,0,0,0))
 return c
handsR=[(36,39),(35,40),(38,48),(44,40),(44,29)]
handsD=[(25,43),(27,38),(29,51),(28,33),(25,18)]
handsU=[(38,36),(39,31),(40,41),(43,20),(42,8)]
# Estabiliza a linha dos pes nos quadros verticais gerados e acompanha a mao.
for bodies,hands in [(D,handsD),(U,handsU)]:
 for i,c in enumerate(bodies):
  box=c.getbbox();dy=54-box[3]
  positioned=Image.new('RGBA',(64,64));positioned.alpha_composite(c,(0,dy))
  bodies[i]=positioned;hands[i]=(hands[i][0],hands[i][1]+dy)
def compose(bodies,blades,hands,turn=None):
 result=[]
 for i,(body,(box,grip),hand) in enumerate(zip(bodies,blades,hands)):
  c=body.copy();s=blade(box)
  occupied=[(x,y) for y in range(s.height) for x in range(s.width) if s.getpixel((x,y))[3]>200]
  grip=min(occupied,key=lambda q:(q[0]-grip[0])**2+(q[1]-grip[1])**2)
  body_pixels=[(x,y) for y in range(64) for x in range(64) if body.getpixel((x,y))[3]>200]
  hand=min(body_pixels,key=lambda q:(q[0]-hand[0])**2+(q[1]-hand[1])**2)
  if turn=='down':
   grip=(s.height-1-grip[1],grip[0]);s=s.transpose(Image.Transpose.ROTATE_270)
  elif turn=='up':
   grip=(grip[1],s.width-1-grip[0]);s=s.transpose(Image.Transpose.ROTATE_90)
  c.alpha_composite(s,(hand[0]-grip[0],hand[1]-grip[1]))
  result.append(c)
 return result
right=compose(R,right_blades,handsR)
down=compose(D,right_blades,handsD,'down')
up=compose(U,right_blades,handsU,'up')
left=[ImageOps.mirror(c) for c in right]
directions=[('BAIXO',down),('DIREITA',right),('CIMA',up),('ESQUERDA',left)]
sheet=Image.new('RGBA',(320,256))
for j,(_,poses) in enumerate(directions):
 for i,frame in enumerate(poses):sheet.alpha_composite(frame,(i*64,j*64))
sheet.save(p/'ataque_espada_quatro_direcoes_v1.png')
try:font=ImageFont.truetype('/usr/share/fonts/dejavu-sans-fonts/DejaVuSans.ttf',18)
except OSError:font=ImageFont.load_default(size=18)
frames=[]
for i in range(5):
 canvas=Image.new('RGB',(640,640),(30,35,43));draw=ImageDraw.Draw(canvas)
 for j,(name,poses) in enumerate(directions):
  x=j%2*320;y=j//2*320
  draw.text((x+160,y+18),name,font=font,fill=(225,225,220),anchor='mt')
  c=poses[i].resize((256,256),Image.Resampling.NEAREST);canvas.paste(c,(x+32,y+46),c)
 frames.append(canvas)
durations=[260,120,70,70,160]
out=p/'ataque_espada_quatro_direcoes_v1.gif'
frames[0].save(out,save_all=True,append_images=frames[1:],duration=durations,loop=0,disposal=2,optimize=False)
frames[3].save(p/'ataque_espada_quatro_direcoes_detalhe.png')
(p/'animacao_espada.json').write_text(json.dumps({'tipo':'previa sem integracao','grade':[5,4],'quadro':[64,64],'direcoes':[x[0] for x in directions],'duracoes_ms':durations,'espada':'recortes da referencia enviada, ancorados manualmente nas maos','laterais':'direita aprovada; esquerda espelhada','limite':'poses geradas nao sao copia exata das originais'},ensure_ascii=False,indent=2)+'\n')
check=Image.open(out)
assert check.n_frames==5
assert all(check.seek(i) is None and check.size==(640,640) for i in range(5))
print(out)
