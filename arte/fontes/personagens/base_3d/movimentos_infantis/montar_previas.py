"""Monta contatos e GIF dos mesmos quadros capturados no Godot, sem editar sprites."""
import argparse
import json
from pathlib import Path
from PIL import Image, ImageDraw

parser=argparse.ArgumentParser()
parser.add_argument('capturas',type=Path)
args=parser.parse_args()
saida=Path(__file__).resolve().parents[4]/'previas/npcs/criancas_primeira_raiz'
saida.mkdir(parents=True,exist_ok=True)
ids=['teo','bia','nina']
quadros={(id,d,q):Image.open(args.capturas/f'infantil_{id}_{d}_{q:02d}.png').convert('RGBA') for id in ids for d in range(4) for q in range(12)}
boxes=[im.getbbox() for im in quadros.values()]
b=(min(r[0] for r in boxes)-4,min(r[1] for r in boxes)-4,max(r[2] for r in boxes)+4,max(r[3] for r in boxes)+4)
w,h=(b[2]-b[0])*3,(b[3]-b[1])*3

def celula(id,d,q):return quadros[id,d,q].crop(b).resize((w,h),Image.Resampling.NEAREST)
for id in ids:
 contato=Image.new('RGB',(12*w,4*h),'#293c36')
 for d in range(4):
  for q in range(12):
   im=celula(id,d,q);contato.paste(im,(q*w,d*h),im)
 contato.save(saida/f'{id}_quadros.png')
frames=[]
for q in range(12):
 im=Image.new('RGB',(3*w,h+28),'#293c36');draw=ImageDraw.Draw(im)
 for i,id in enumerate(ids):
  c=celula(id,0,q);im.paste(c,(i*w,20),c);draw.text((i*w+12,6),['Téo','Bia','Nina'][i],fill='#f6dfac')
 frames.append(im)
tempos=[(round((q+1)*103.333333/12)-round(q*103.333333/12))*10 for q in range(12)]
frames[0].save(saida/'caminhada.gif',save_all=True,append_images=frames[1:],duration=tempos,loop=0,disposal=2)
frames[0].save(saida/'criancas.png')
for nome in ['crianca_dialogo_576x324','crianca_dialogo_288x512','crianca_dialogo_320x324','cidade_15_moradores']:
 f=args.capturas/(nome+'.png')
 if f.exists():Image.open(f).save(saida/(nome+'.png'))
(saida/'revisao.json').write_text(json.dumps({'origem':str(args.capturas),'quadros_por_ciclo':12,'duracao_motor_segundos':1.03333330154419,'duracao_gif_ms':sum(tempos),'metodo':'Capturas reais, caixa/pivô comuns e ampliação inteira sem filtro; sprites não editados.','direcoes':['frente','direita','costas','esquerda'],'rotinas':'07h ajuda;10h descobertas;14h brincadeira;18h volta;20h em casa.','limite_moradores':15},ensure_ascii=False,indent=2)+'\n')
print(saida)
