#!/usr/bin/env python3
"""Monta painéis de revisão a partir das capturas reais do Godot; não altera os assets."""
from pathlib import Path
import json
import subprocess
from PIL import Image, ImageDraw, ImageFont
RAIZ=Path(__file__).resolve().parents[2]
PASTA=RAIZ/'arte/previas/fenda/jornada'
try:
 caminho_fonte=subprocess.check_output(['fc-match','-f','%{file}','sans'],text=True).strip()
 fonte=ImageFont.truetype(caminho_fonte,20)
 pequena=ImageFont.truetype(caminho_fonte,14)
except (OSError,subprocess.SubprocessError):
 fonte=ImageFont.load_default(size=20)
 pequena=ImageFont.load_default(size=14)
plantas=[json.loads(p.read_text()) for p in sorted((RAIZ/'codigo/fendas/plantas').glob('*.json'))]
board=Image.new('RGB',(1440,1820),'#182522')
d=ImageDraw.Draw(board)
for i,p in enumerate(plantas[1:]):
 x=(i%2)*720;y=(i//2)*364
 d.text((x+12,y+9),f'{p["andar"]:02} — {p["nome"]}',font=fonte,fill='#f4d6a0')
 im=Image.open(PASTA/f'terreno_{p["andar"]:02}_estacao_0.png').convert('RGB')
 im.thumbnail((704,320))
 board.paste(im,(x+(720-im.width)//2,y+42+(320-im.height)//2))
board.save(PASTA/'dez_mapas_no_godot.png')
board=Image.new('RGB',(1440,1892),'#182522');d=ImageDraw.Draw(board)
for i,p in enumerate(plantas):
 for e in range(4):
  x=e*360;y=i*172
  d.text((x+8,y+4),f'{p["andar"]:02} · '+['Primavera','Verao','Outono','Inverno'][e],font=pequena,fill='#f4d6a0')
  im=Image.open(PASTA/f'terreno_{p["andar"]:02}_estacao_{e}.png').convert('RGB')
  im.thumbnail((352,145));board.paste(im,(x+(360-im.width)//2,y+25+(145-im.height)//2))
board.save(PASTA/'revisao_quatro_estacoes.png')
print('Paineis montados a partir de 44 capturas reais.')

# Detalhes em escala de uso: a captura 2× volta para 1× por nearest, sem suavização.
selecionados=[3,4,5,6,7,8,10,11]
board=Image.new('RGB',(1152,4*364),'#182522');d=ImageDraw.Draw(board)
for i,n in enumerate(selecionados):
 p=plantas[n-1];x=i%2*576;y=i//2*364
 d.text((x+12,y+8),f'{n:02} - {p["nome"]}',font=fonte,fill='#f4d6a0')
 im=Image.open(PASTA/f'detalhe_{n:02}.png').convert('RGB').resize((576,324),Image.Resampling.NEAREST)
 board.paste(im,(x,y+40))
board.save(PASTA/'biomas_detalhados_no_godot.png')

# Comparação de continuidade: mapa inteiro e detalhe real, sem esconder as ramificações.
board=Image.new('RGB',(1280,3*370),'#182522');d=ImageDraw.Draw(board)
for i,n in enumerate([4,7,11]):
 y=i*370
 d.text((12,y+8),f'{n:02} - {plantas[n-1]["nome"]} | capturas do Godot',font=fonte,fill='#f4d6a0')
 geral=Image.open(PASTA/f'terreno_{n:02}_estacao_0.png').convert('RGB')
 geral.thumbnail((680,324),Image.Resampling.NEAREST)
 board.paste(geral,((680-geral.width)//2,y+40+(324-geral.height)//2))
 detalhe=Image.open(PASTA/f'detalhe_{n:02}.png').convert('RGB').resize((576,324),Image.Resampling.NEAREST)
 board.paste(detalhe,(696,y+40))
board.save(PASTA/'cavernas_corrigidas.png')
