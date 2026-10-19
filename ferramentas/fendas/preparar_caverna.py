#!/usr/bin/env python3
"""Materiais originais sobre máscaras Wang exatas; sem remontar atlas gerado por IA.

Tiny RPG serve somente como referência da separação topo/face/pé/cantos.
A textura de rocha é própria; peças, grade e máscara física não mudam entre estações.
"""
from pathlib import Path
import json
from PIL import Image,ImageFilter,ImageChops
RAIZ=Path(__file__).resolve().parents[2]
FONTE=RAIZ/'arte/fontes/fendas/cavernas'

def preparar():
 original=Image.open(FONTE/'tileset_32.png').convert('RGB')
 material=Image.open(FONTE/'parede_material_fonte.png').convert('RGB').resize((128,96),Image.Resampling.NEAREST).crop((16,16,48,80))
 material=material.quantize(colors=18,dither=Image.Dither.NONE).convert('RGB')
 # O espelhamento garante que o material encontra a mesma cor em ambas as bordas.
 # É um material de parede, não uma ilustração completa reduzida a um sprite.
 for y in range(64):
  for x in range(16,32):material.putpixel((x,y),material.getpixel((31-x,y)))
 piso=Image.open(RAIZ/'assets/cenario/fendas/mina/piso.png').convert('RGB').resize((128,128),Image.Resampling.NEAREST)
 # Piso legível e discreto: o detalhe não compete com inimigos e itens.
 piso.putdata([tuple(round(c*.28+alvo*.72) for c,alvo in zip(px,(113,99,81))) for px in piso.getdata()])
 piso=piso.quantize(colors=16,dither=Image.Dither.NONE).convert('RGB')
 for y in range(128):
  for x in range(64,128):piso.putpixel((x,y),piso.getpixel((127-x,y)))
 for y in range(64,128):
  for x in range(128):piso.putpixel((x,y),piso.getpixel((x,127-y)))
 cap=Image.new('L',original.size)
 cap.putdata([255 if b>r*1.12 and b>g*1.10 else 0 for r,g,b in original.getdata()])
 cap_interno=cap.filter(ImageFilter.MinFilter(5))
 saida=Image.new('RGBA',(256,256),(0,0,0,255))
 for y in range(256):
  for x in range(128):
   r,g,b=original.getpixel((x,y))
   if r>145 and g>105 and b<r*.9:
    cor=piso.getpixel((x%128,y%128))
   elif cap.getpixel((x,y)):
    cor=(0,0,0) if cap_interno.getpixel((x,y)) else (31,27,24)
   else:
    cor=material.getpixel((x%32,y%64))
   saida.putpixel((x,y),cor+(255,))
 saida.paste(piso,(128,0))
 saida.save(FONTE/'tileset_producao.png')
 material.save(FONTE/'parede_material_nativo.png')
 piso.save(FONTE/'piso_material_nativo.png')

if __name__=='__main__':preparar()
