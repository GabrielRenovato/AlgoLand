"""Compõe capturas reais do Godot, confere paleta e conserva o tempo da corrida."""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont
R=Path(__file__).resolve().parents[3]
P=R/'arte/previas/personagens/base_3d/catalogo_roupas'
dados=json.loads((P/'catalogo.json').read_text())
try:
    font=ImageFont.truetype('/home/alfeim/.local/share/fonts/google-noto/NotoSans-Regular.ttf',15)
except OSError:
    font=ImageFont.load_default(size=15)
cores={tuple(bytes.fromhex(c[1:])) for c in json.loads((R/'arte/fontes/personagens/base_3d/paleta_pixel_art.json').read_text())['cores']}
pngs=list(P.glob('pixel_*.png'))+list(P.glob('corrida_*.png'))
for p in pngs:
    im=Image.open(p).convert('RGBA')
    for _,c in im.getcolors(im.width*im.height):
        assert c[3] in (0,255),(p,c)
        assert c[3]==0 or c[:3] in cores,(p,c)

def recorte(nome,escala=3):
    im=Image.open(P/nome).convert('RGBA')
    fator=im.width/160
    im=im.crop(tuple(round(v*fator) for v in (40,38,120,118)))
    return im.resize((80*escala,80*escala),Image.Resampling.NEAREST if fator==1 else Image.Resampling.LANCZOS)

for modo in ['pixel','suave']:
    poster=Image.new('RGB',(960,858),'#45434d');d=ImageDraw.Draw(poster)
    for linha,categoria in enumerate(['camisa','calca','calcado']):
        modelos=[m for m in dados['modelos'] if m['categoria']==categoria]
        for col,m in enumerate(modelos):
            im=recorte(f'{modo}_{m["id"]}_0.png')
            poster.paste(im,(col*240,linha*286+34),im)
            d.text((col*240+12,linha*286+12),m['nome'],font=font,fill='white')
    poster.save(P/f'catalogo_{modo}.png')
frames=[]
for q in range(12):
    painel=Image.new('RGB',(480,520),'#45434d')
    for conjunto in range(4):
        im=recorte(f'corrida_{conjunto}_1_{q:02d}.png')
        painel.paste(im,(conjunto%2*240,conjunto//2*260+20),im)
    frames.append(painel)
# PASSADA=60, velocidade de referência=100 pixels/s: um ciclo a cada 600ms.
frames[0].save(P/'combinacoes_correndo.gif',save_all=True,append_images=frames[1:],duration=50,loop=0,disposal=2)
print(f'Catálogo: {len(pngs)} capturas com paleta/alfa válidos; 10 peças, quatro combinações em movimento.')
