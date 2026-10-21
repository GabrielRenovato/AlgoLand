#!/usr/bin/env python3
"""Exporta os acessórios próprios e empacota nas pegadas das ferramentas Raven.
Não altera o corpo Raven; todos os quadros preservam a célula80 e o pivô40,47.
"""
from preparar_raven import SAIDA, FONTES
from PIL import Image
from pathlib import Path
import json, shutil, math

def preparar():
 fonte=FONTES/'acessorios/aljava_marreta.png'
 im=Image.open(fonte).convert('RGBA');w,h=im.size
 partes=[]
 for linha in range(2):
  for coluna in range(4):
   cel=im.crop((coluna*w//4,linha*h//2,(coluna+1)*w//4,(linha+1)*h//2))
   cel.putalpha(cel.getchannel('A').point(lambda a:255 if a>=160 else 0))
   cel=cel.crop(cel.getbbox())
   altura=18;largura=max(1,round(cel.width*altura/cel.height))
   cel=cel.resize((largura,altura),Image.Resampling.NEAREST)
   partes.append(cel)
 destino=SAIDA/'icones';destino.mkdir(exist_ok=True)
 partes[1].save(destino/'aljava_basica.png');partes[4].save(destino/'maca.png')
 for nome,origem in [('arco_curvo','arco_curto'),('arco_longo','arco_curto')]:shutil.copyfile(destino/(origem+'.png'),destino/(nome+'.png'))
 # Ícones de peças básicas são os mesmos componentes nativos da roupa.
 for nome,camada in [('armadura_basica','camisa_azul'),('luvas_basicas','luvas'),('botas_basicas','botas')]:
  cel=Image.open(SAIDA/'previas'/(camada+'.png')).crop((0,0,64,64));cel.crop(cel.getbbox()).save(destino/(nome+'.png'))
 elmo=Image.open(SAIDA.parent/'conjuntos/carrasco/elmo/andar.png').crop((0,0,64,64));elmo.crop(elmo.getbbox()).save(destino/'cabeca_basica.png')
 acoes=json.loads((SAIDA/'camadas/acoes.json').read_text())
 tool=Image.open(SAIDA/'camadas/ferramentas.png').convert('RGBA')
 # A picareta fornece a pegada da ferramenta de impacto. A marreta acompanha
 # exatamente o contato e a trajetória; não acrescenta um objeto no centro da célula.
 for acao in ['forjar','espada','espada_2']:
  referencia='picareta' if acao=='forjar' else acao
  idx=acoes.index(referencia)
  if acao=='forjar':tool.paste((0,0,0,0),(0,acoes.index(acao)*320,320,(acoes.index(acao)+1)*320))
  atlas=Image.new('RGBA',tool.size)
  for d in range(4):
   for q in range(4):
    rec=tool.crop((q*80,idx*320+d*80,(q+1)*80,idx*320+(d+1)*80))
    caixa=rec.getbbox()
    if not caixa:continue
    martelo=partes[4+q].copy()
    if d==3:martelo=martelo.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    # Âncora da pegada: parte inferior do cabo, junto à mão da ferramenta nativa.
    # A trajetória preserva o centro da arma original a cada quadro.
    cx=(caixa[0]+caixa[2])//2;cy=(caixa[1]+caixa[3])//2
    atlas.alpha_composite(martelo,(q*80+cx-martelo.width//2,acoes.index(acao)*320+d*80+cy-martelo.height//2))
  atlas.save(SAIDA/'camadas'/('marreta_'+acao+'.png'))
 if True:
  marreta=Image.open(SAIDA/'camadas/marreta_forjar.png');tool.alpha_composite(marreta)
 tool.save(SAIDA/'camadas/ferramentas.png')
 # A aljava é um objeto de costas: direções e base são comuns a todas as poses.
 aljava=Image.new('RGBA',tool.size)
 for i,acao in enumerate(acoes):
  for d in range(4):
   for q in range(4):
    item=partes[[2,1,0,3][d]]
    aljava.alpha_composite(item,(q*80+(35 if d in [0,2] else (31 if d==1 else 42)),i*320+d*80+25))
 aljava.save(SAIDA/'camadas/aljava.png')
 print('Aljava e marreta próprias exportadas; arcos e peças básicas usam ícones Raven.')
if __name__=='__main__':preparar()
