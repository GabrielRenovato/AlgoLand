"""Folhas e GIFs diagnósticos compostos dos quadros reais do Godot, sem retocar os assets."""
from pathlib import Path
import sys
import shutil
from PIL import Image, ImageDraw

origem = Path(sys.argv[1])
destino = Path('arte/previas/personagens/vestuario_infantil')
destino.mkdir(parents=True, exist_ok=True)
trajes = ['campestre', 'jardineira', 'vestido']
cabelos = ['franjinha', 'chiquinhas', 'cacheado']
nomes_trajes = ['Roupa de brincar', 'Jardineira da vila', 'Vestido de passeio']
nomes_cabelos = ['Franjinha curta', 'Maria-chiquinhas', 'Cachos curtos']
pares = list(zip(trajes, cabelos))
caixas = [Image.open(p).getbbox() for p in origem.glob('*.png')]
caixa = (min(b[0] for b in caixas)-3, min(b[1] for b in caixas)-3,
         max(b[2] for b in caixas)+3, max(b[3] for b in caixas)+3)
w,h = (caixa[2]-caixa[0])*6, (caixa[3]-caixa[1])*6

def figura(nome):
    im = Image.open(origem/(nome+'.png')).convert('RGBA').crop(caixa)
    return im.resize((w,h), Image.Resampling.NEAREST)

def painel(nomes, titulos, colunas):
    linhas = (len(nomes)+colunas-1)//colunas
    out = Image.new('RGB', (w*colunas,(h+32)*linhas), '#263c3b')
    draw = ImageDraw.Draw(out)
    for i,nome in enumerate(nomes):
        x,y = i%colunas*w,i//colunas*(h+32)
        im = figura(nome)
        out.paste(im,(x,y+30),im)
        draw.text((x+14,y+10),titulos[i],fill='#f4dfbb')
    return out

painel([f'{t}_{c}_0' for t,c in pares],nomes_trajes,3).save(destino/'trajes.png')
painel([f'campestre_{c}_{d}' for d in [0,2] for c in cabelos],
       [nome+' - '+vista for vista in ['frente','costas'] for nome in nomes_cabelos],3).save(destino/'cabelos.png')
painel([f'{t}_{c}_0' for t in trajes for c in cabelos],
       [t+' / '+c for t in nomes_trajes for c in nomes_cabelos],3).save(destino/'combinacoes.png')
painel([f'{t}_{c}_{d}' for d in [0,2,1,3] for t,c in pares],
       [t+' - '+vista for vista in ['frente','costas','direita','esquerda'] for t in nomes_trajes],3).save(destino/'quatro_vistas.png')
contato = Image.new('RGB',(w*8,h*12),'#263c3b')
frames = []
for q in range(8):
    tela = Image.new('RGB',(w*3,h),'#263c3b')
    for i,t in enumerate(trajes):
        for j,d in enumerate([0,2,1,3]):
            im = figura(f'andar_{t}_{d}_{q:02d}')
            contato.paste(im,(w*q,(i*4+j)*h),im)
            if d==0:tela.paste(im,(w*i,0),im)
    frames.append(tela)
contato.save(destino/'caminhada_quadros.png')
frames[0].save(destino/'caminhada.gif',save_all=True,append_images=frames[1:],
               duration=[170,160,170,170,160,170,170,160],loop=0)
nativos = destino/'quadros_nativos'
nativos.mkdir(exist_ok=True)
for p in origem.glob('*.png'):shutil.copy2(p,nativos/p.name)
