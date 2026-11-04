"""Diagrama das plantas, gerado dos mesmos retângulos usados no Godot."""
from pathlib import Path
import json
from PIL import Image,ImageDraw,ImageFont
raiz=Path(__file__).resolve().parents[4]
dados=json.loads((raiz/'codigo/cidade/familias/plantas.json').read_text())
pasta=raiz/'arte/previas/cidade/casas_familias'
fonte=Path('/home/alfeim/.local/share/fonts/google-noto/NotoSans-Regular.ttf')
f=lambda n:ImageFont.truetype(str(fonte),n) if fonte.exists() else ImageFont.load_default(size=n)
for id,casa in dados['casas'].items():
 w,h=casa['geometria']['recorte'][2:];escala=2;ox,oy=32,72
 im=Image.new('RGB',((w+64)*escala,(h+120)*escala),'#172e35');d=ImageDraw.Draw(im)
 def caixa(r):return tuple(round(v*escala) for v in (r[0]+ox,r[1]+oy,r[0]+ox+r[2],r[1]+oy+r[3]))
 d.text((im.width/2,28),casa['nome'],font=f(28),fill='#f1e6c9',anchor='mt')
 d.text((im.width/2,72),'Grade de 8 px · portas de 48 px · piso e móveis separados',font=f(17),fill='#c6c2a5',anchor='mt')
 for a in casa['geometria']['areas']:
  passagem=a['nome'] in ['Passagem','Corredor','Saída'];d.rectangle(caixa(a['retangulo']),fill='#375662' if passagem else '#456c70',outline='#c6c2a5',width=3)
 for it in casa['itens']:
  cw,ch=it['col'];d.rounded_rectangle(caixa([it['x']-cw/2,it['y']-ch,cw,ch]),radius=4,fill='#9b9b78')
 for a in casa['geometria']['areas']:
  if a['nome'] in ['Passagem','Corredor','Saída']:continue
  x,y,rw,rh=a['retangulo'];d.text(((x+rw/2+ox)*escala,(y+12+oy)*escala),a['nome'],font=f(22),fill='#fff1cb',anchor='mt')
 d.text((im.width/2,im.height-44),'Entrada ao sul · quartos privativos · bases dos móveis em dourado',font=f(17),fill='#c6c2a5',anchor='mt')
 im.save(pasta/f'planta_{id}.png')
