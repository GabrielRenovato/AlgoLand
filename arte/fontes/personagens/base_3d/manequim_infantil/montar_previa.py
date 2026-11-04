"""Monta referências com renders reais do Godot, sem retocar sprites ou poses."""
from pathlib import Path
from PIL import Image, ImageDraw
import shutil
import sys

origem = Path(sys.argv[1])
destino = Path('arte/previas/personagens/manequim_infantil')
destino.mkdir(parents=True, exist_ok=True)
nativos = destino/'quadros_nativos'
nativos.mkdir(exist_ok=True)
for p in origem.glob('*.png'):
    shutil.copy2(p, nativos/p.name)

def caixa(nomes):
    b = [Image.open(origem/(n+'.png')).getbbox() for n in nomes]
    return (min(r[0] for r in b)-3, min(r[1] for r in b)-3,
            max(r[2] for r in b)+3, max(r[3] for r in b)+3)

def imagem(nome, recorte):
    im = Image.open(origem/(nome+'.png')).convert('RGBA').crop(recorte)
    return im.resize((im.width*6, im.height*6), Image.Resampling.NEAREST)

nomes = ['adulto_0', 'crianca_0']
b = caixa(nomes)
w, h = (b[2]-b[0])*6, (b[3]-b[1])*6
out = Image.new('RGB', (w*2+40, h+55), '#263c3b')
draw = ImageDraw.Draw(out)
for i, n in enumerate(nomes):
    im = imagem(n, b)
    out.paste(im, (20+i*w, 35), im)
    draw.text((30+i*w, 12), ['ADULTO', 'MANEQUIM INFANTIL'][i], fill='#f3dfb6')
draw.line((12, 35+(110-b[1])*6, out.width-12, 35+(110-b[1])*6), fill='#58706a')
out.save(destino/'comparacao.png')

nomes = [f'crianca_{d}' for d in [0,2,1,3]]
b = caixa(nomes)
w,h = (b[2]-b[0])*6, (b[3]-b[1])*6
out = Image.new('RGB', (w*4, h+40), '#263c3b')
draw = ImageDraw.Draw(out)
for i,n in enumerate(nomes):
    im = imagem(n, b)
    out.paste(im, (i*w, 30), im)
    draw.text((i*w+12, 9), ['FRENTE', 'COSTAS', 'DIREITA', 'ESQUERDA'][i], fill='#f3dfb6')
out.save(destino/'quatro_vistas.png')

nomes = [f'andar_{d}_{q:02d}' for d in range(4) for q in range(8)]
b = caixa(nomes)
w,h = (b[2]-b[0])*6, (b[3]-b[1])*6
out = Image.new('RGB', (w*8,h*4), '#263c3b')
frames = []
for q in range(8):
    tela = Image.new('RGB', (w*4,h), '#263c3b')
    for i,d in enumerate([0,2,1,3]):
        im = imagem(f'andar_{d}_{q:02d}', b)
        tela.paste(im, (w*i,0), im)
        out.paste(im, (w*q,h*i), im)
    frames.append(tela)
out.save(destino/'caminhada_quadros.png')
frames[0].save(destino/'caminhada.gif', save_all=True, append_images=frames[1:],
               duration=[170,160,170,170,160,170,170,160], loop=0)
