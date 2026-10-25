from PIL import Image,ImageDraw
from pathlib import Path
import json
r=Path(__file__).resolve().parents[3];p=r/'arte/fontes/personagens/raven_cartoon/corrida_frente_4';w,h=512,896
# Pontos marcados a partir das quatro poses sem fase aérea do Mana Seed.
poses=[
 {'braco_esquerdo':[[170,315],[148,395],[170,495]],'braco_direito':[[342,315],[390,362],[368,325]],'perna_esquerda':[[224,515],[204,675],[205,815]],'perna_direita':[[288,515],[312,645],[300,760]]},
 {'braco_esquerdo':[[170,315],[155,390],[180,472]],'braco_direito':[[342,315],[363,390],[332,472]],'perna_esquerda':[[224,515],[224,675],[225,815]],'perna_direita':[[288,515],[311,661],[293,790]]},
 {'braco_esquerdo':[[170,315],[122,362],[144,325]],'braco_direito':[[342,315],[364,395],[342,495]],'perna_esquerda':[[224,515],[200,645],[212,760]],'perna_direita':[[288,515],[308,675],[307,815]]},
 {'braco_esquerdo':[[170,315],[149,390],[180,472]],'braco_direito':[[342,315],[357,390],[332,472]],'perna_esquerda':[[224,515],[201,661],[219,790]],'perna_direita':[[288,515],[288,675],[287,815]]}
]
im=Image.new('RGB',(w*2,h*2),(239,240,234));d=ImageDraw.Draw(im)
for q,g in enumerate(poses):
 ox=(q%2)*w;oy=(q//2)*h
 for nome,c in [('braco_esquerdo','#a77834'),('braco_direito','#375f85'),('perna_esquerda','#a77834'),('perna_direita','#375f85')]:
  pts=[(x+ox,y+oy) for x,y in g[nome]];d.line(pts,fill=c,width=14)
  for x,y in pts:d.ellipse((x-10,y-10,x+10,y+10),fill=c)
 d.ellipse((ox+156,oy+60,ox+356,oy+280),outline='#4f565b',width=8)
 d.line([(ox+256,oy+280),(ox+256,oy+515)],fill='#4f565b',width=24)
 d.line([(ox+170,oy+315),(ox+342,oy+315)],fill='#4f565b',width=12)
 d.line([(ox+224,oy+515),(ox+288,oy+515)],fill='#4f565b',width=12)
 d.line([(ox+20,oy+835),(ox+492,oy+835)],fill='#9ba4a0',width=3)
 d.text((ox+20,oy+15),str(q+1),fill='#30383c')
im.save(p/'guia_quatro_poses_sem_salto.png')
j={'canônico':'../corpo_base_cartoon_v1.png','referencia_mana_seed':'arte/pacotes/Jogador/Base/20.01a - Character Base 2.5c/char_a_p1/char_a_p1_0bas_humn_v01.png','colunas_referencia':[0,1,3,4],'linha_referencia':4,'acao':'corrida_frente','quadros':4,'grade':[2,2],'celula_planejada':[512,896],'pivo_planejado':[256,835],'duracoes_ms':[100,100,100,100],'salto':False,'aereo':False,'cabeca_alinhada':True,'alternancia':'braço direito e perna esquerda; passagem; braço esquerdo e perna direita; passagem','guia_poses':poses,'estado':'producao'}
(p/'contrato.json').write_text(json.dumps(j,ensure_ascii=False,indent=2)+'\n')
old=r/'arte/fontes/personagens/raven_cartoon/corrida/contrato.json';j=json.loads(old.read_text());j['estado']='rejeitado: usuário pediu retirar salto, limitar a quatro quadros e focar somente na frente';old.write_text(json.dumps(j,ensure_ascii=False,indent=2)+'\n')
