#!/usr/bin/env python3
"""Material mineral nativo e quadros fixos; fontes geradas permanecem preservadas."""
from pathlib import Path
from PIL import Image
RAIZ=Path(__file__).resolve().parents[2]
FONTE=RAIZ/'arte/fontes/fendas/mina'
DESTINO=RAIZ/'assets/cenario/fendas/mina'
def preparar():
 DESTINO.mkdir(parents=True,exist_ok=True)
 piso=Image.open(FONTE/'piso_fonte.png').convert('RGB').resize((256,256),Image.Resampling.NEAREST)
 piso=piso.quantize(colors=32,dither=Image.Dither.NONE).convert('RGBA')
 piso.save(DESTINO/'piso.png')
 if (FONTE/'objetos_fonte.png').exists():
  fonte=Image.open(FONTE/'objetos_fonte.png').convert('RGBA');folha=Image.new('RGBA',(128,128))
  for i,(w,h) in enumerate([(48,50),(44,30),(40,28),(44,38)]):
   c,r=i%2,i//2
   parte=fonte.crop((round(c*fonte.width/2),round(r*fonte.height/2),round((c+1)*fonte.width/2),round((r+1)*fonte.height/2)))
   parte.putalpha(parte.getchannel('A').point(lambda a:255 if a>=192 else 0))
   caixa=parte.getbbox()
   if not caixa:raise ValueError(f'Objeto da mina sem silhueta: {i}')
   parte=parte.crop(caixa);parte.thumbnail((w,h),Image.Resampling.NEAREST)
   folha.alpha_composite(parte,(c*64+32-parte.width//2,r*64+60-parte.height))
  folha.save(DESTINO/'objetos.png')
if __name__=='__main__':preparar()
