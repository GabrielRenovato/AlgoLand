from PIL import Image
from pathlib import Path
import json
src='arte/pacotes/Jogador/Base/20.01a - Character Base 2.5c/char_a_p1/char_a_p1_0bas_humn_v01.png'
im=Image.open(src).convert('RGBA');cols=[0,1,6,3,4,7];ds=[0,2,1,3];out=[]
# Pontos dos membros observados no ciclo original, antes da margem fixa8,2.
frente=[
 [[[27,28],[26,31],[27,35]],[[35,28],[37,30],[36,28]],[[29,35],[28,39],[28,44]],[[33,35],[34,38],[34,40]]],
 [[[27,27],[26,30],[27,33]],[[35,27],[37,30],[35,33]],[[29,35],[29,39],[29,44]],[[33,35],[34,38],[34,42]]],
 [[[28,25],[26,28],[28,31]],[[36,25],[39,27],[39,25]],[[30,32],[27,34],[27,37]],[[34,32],[36,34],[35,37]]],
 [[[28,28],[26,30],[27,28]],[[36,28],[38,31],[37,35]],[[30,35],[29,38],[29,40]],[[34,35],[35,39],[35,44]]],
 [[[28,27],[26,30],[28,33]],[[36,27],[38,30],[36,33]],[[30,35],[29,38],[29,42]],[[34,35],[34,39],[34,44]]],
 [[[27,25],[24,27],[24,25]],[[35,25],[38,28],[36,31]],[[29,32],[27,34],[28,37]],[[33,32],[36,34],[36,37]]],
]
perfil=[
 [[[32,28],[35,32],[36,30]],[[32,28],[29,31],[27,33]],[[31,35],[29,39],[27,43]],[[33,35],[35,36],[35,40]]],
 [[[32,28],[34,31],[33,33]],[[32,28],[31,31],[29,33]],[[31,35],[31,39],[31,43]],[[33,35],[35,38],[36,40]]],
 [[[33,25],[28,27],[25,27]],[[34,25],[38,28],[39,26]],[[32,32],[36,34],[40,37]],[[32,32],[27,35],[23,36]]],
 [[[32,28],[29,31],[27,32]],[[32,28],[35,31],[37,33]],[[32,35],[35,39],[37,43]],[[32,35],[29,36],[28,39]]],
 [[[32,28],[30,31],[31,33]],[[32,28],[33,31],[35,33]],[[32,35],[32,39],[33,43]],[[32,35],[29,38],[26,40]]],
 [[[31,25],[36,28],[39,26]],[[32,25],[28,27],[25,27]],[[32,32],[27,35],[23,36]],[[32,32],[36,34],[40,37]]],
]
for d,sd in enumerate(ds):
 frames=[]
 for q,col in enumerate(cols):
  cell=im.crop((col*64,(4+sd)*64,col*64+64,(5+sd)*64));top=cell.getbbox()[1];xs=[x for y in range(top+3,top+7) for x in range(64) if cell.getpixel((x,y))[3]];hx=round(sum(xs)/len(xs));hy=top+5
  membros=json.loads(json.dumps(perfil[q] if d in [1,3] else frente[q]))
  if d==3:
   for membro in membros:
    for ponto in membro:ponto[0]=64-ponto[0]
  # O branco também aparece no rosto. O quadril é a origem anatômica das
  # duas coxas do guia, nunca o centro dos pixels de uma determinada cor.
  hip=[round((membros[2][0][e]+membros[3][0][e])/2) for e in range(2)]
  guia={'cabeca':[hx+8,hy+2],'pescoco':[hx+8,hy+8],'quadril':[hip[0]+8,hip[1]+2]}
  for nome,pts in zip(['braco_esquerdo','braco_direito','perna_esquerda','perna_direita'],membros):guia[nome]=[[p[0]+8,p[1]+2] for p in pts]
  frames.append(guia)
 out.append(frames)
contrato={'referencia':src,'amostra':'guides/timing sample gifs/running sample.gif','colunas_origem':cols,'linhas_origem':ds,'margem_fixa':[8,2],'celula':[80,80],'pivo':[40,47],'quadros':6,'duracoes_ms':[100,60,140,100,60,140],'metodo':'Máscara de movimento do Mana Seed com anatomia marcada; cores, sombras, roupa e peças amostradas juntas nos pixels nativos Raven. Cabeça preservada sem escala e short neutro. Capa de comprimento fixo com fecho independente e ordem por direção.','guias':out}
Path('arte/fontes/personagens/corrida_mana_seed_raven/contrato.json').write_text(json.dumps(contrato,ensure_ascii=False,indent=2)+'\n')
