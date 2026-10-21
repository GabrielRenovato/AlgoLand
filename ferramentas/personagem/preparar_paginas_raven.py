#!/usr/bin/env python3
"""Empacota vistas Raven em páginas de compatibilidade de 64px, sem mudar os pixels.

Os nós de gameplay conservam seus índices; menus antigos usam estas páginas.
O jogador usa diretamente as folhas nativas de80px com direções B/D/C/E.
"""
from preparar_raven import SAIDA
from PIL import Image
import json

PAGINAS = {'andar':'correr','fazenda':'enxada','forja':'forjar','sentado':'sentado',
 'espada':'espada','lanca':'lanca','reacao_um_mao':'ferido','reacao_lanca':'ferido',
 'reacao_arco':'ferido','arco_p2':'parado','arco_p3':'arco','pesca':'pescar'}

def preparar():
 acoes=json.loads((SAIDA/'camadas/acoes.json').read_text())
 for p in (SAIDA/'camadas').glob('*.png'):
  origem=Image.open(p).convert('RGBA')
  for pagina,acao in PAGINAS.items():
   folha=Image.new('RGBA',(512,512));idx=acoes.index(acao)
   for d in range(4):
    for q in range(8):
     recorte=origem.crop(((q%4)*80+8,idx*320+d*80+4,(q%4)*80+72,idx*320+d*80+68))
     linha=[0,2,1,3][d]
     for bloco in [0,4]:folha.alpha_composite(recorte,(q*64,(linha+bloco)*64))
   pasta=SAIDA/'paginas'/p.stem;pasta.mkdir(parents=True,exist_ok=True)
   folha.save(pasta/(pagina+'.png'))
 print('Páginas Raven: quatro direções, mesma translação fixa para todas as camadas.')
if __name__=='__main__':preparar()
