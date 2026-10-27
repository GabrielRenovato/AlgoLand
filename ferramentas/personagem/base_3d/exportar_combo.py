"""Organiza capturas reais do Godot; não altera poses, paleta ou pivô."""
from pathlib import Path
import json
import sys
from PIL import Image, ImageDraw
RAIZ = Path(__file__).resolve().parents[3]
lanca = '--lanca' in sys.argv
montante = '--montante' in sys.argv
cima = '--cima' in sys.argv
PASTA = RAIZ / ('arte/previas/personagens/base_3d/combo_montante' if montante else ('arte/previas/personagens/base_3d/combo_lanca' if lanca else 'arte/previas/personagens/base_3d/combo_espada'))
tempos = json.loads((PASTA / 'tempos.json').read_text())
nomes = ['ESTOCADA 1', 'ESTOCADA 2', 'ESTOCADA FINAL'] if lanca else ['GOLPE 1', 'GOLPE 2', 'FINALIZADOR']
contato = Image.new('RGB', (1600, 1032), '#45434d')
desenho = ImageDraw.Draw(contato)
for direcao in range(4):
    for golpe in range(3):
        x0 = direcao % 2 * 800
        y0 = (direcao // 2 * 3 + golpe) * 172
        desenho.text((x0 + 8, y0 + 4), f'DIRECAO {direcao} / {nomes[golpe]}', fill='white')
        for coluna, q in enumerate(range(0,24,5)):
            im = Image.open(PASTA / f'combo_{direcao}_{golpe}_{q:02d}.png').convert('RGBA')
            contato.paste(im, (x0 + coluna * 160, y0 + 12), im)
contato.save(PASTA / 'quadros.png')
quadros, duracoes = [], []
for golpe in range(3):
    for q in range(24):
        painel = Image.new('RGB', (640, 344), '#45434d')
        desenho = ImageDraw.Draw(painel)
        for coluna, direcao in enumerate([2,1] if cima else [0,1]):
            im = Image.open(PASTA / f'combo_{direcao}_{golpe}_{q:02d}.png').convert('RGBA').resize((320,320),Image.Resampling.NEAREST)
            painel.paste(im, (coluna*320,24), im)
            rotulo = (["BAIXO", "DIREITA", "CIMA", "ESQUERDA"][direcao]+" / " if cima else "")+nomes[golpe]
            desenho.text((coluna*320+12,8), rotulo, fill='white')
        quadros.append(painel)
        # GIF usa centésimos: distribuir o arredondamento preserva o tempo total.
        duracoes.append((round((q+1)*tempos['duracoes'][golpe]*100/24)-round(q*tempos['duracoes'][golpe]*100/24))*10)
# Pausa de leitura só após o combo; os golpes respeitam os tempos do motor.
quadros.extend([quadros[-1]]*8)
duracoes.extend([50]*8)
quadros[0].save(PASTA / ('combo_cima.gif' if cima else 'combo.gif'), save_all=True, append_images=quadros[1:], duration=duracoes, loop=0)
print('288 capturas organizadas; tempos do controlador:', tempos['duracoes'])
