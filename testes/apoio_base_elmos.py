"""Projeta somente as remoções aprovadas no editor exato do PixelLab."""
from pathlib import Path
from PIL import Image
import json

RAIZ=Path(__file__).resolve().parents[1]

def revisar_base(id, imagem):
    pasta=RAIZ/'arte/fontes/armaduras'/id
    config=json.loads((RAIZ/'ferramentas/armaduras/em_preparacao'/id/'manifesto.json').read_text())
    revisada=RAIZ/config['arte_base_elmo'].removeprefix('res://')
    if not revisada.exists():return imagem.copy()
    original=Image.open(pasta/'elmos_originais/elmos_nativos.png').convert('RGBA')
    atual=Image.open(revisada).convert('RGBA')
    saida=imagem.copy()
    for d,coluna in [(0,0),(2,1)]:
        fonte=original.crop((coluna*24,0,(coluna+1)*24,24))
        nova=atual.crop((coluna*24,0,(coluna+1)*24,24))
        caixa=fonte.getbbox()
        for q in range(6):
            alvo=imagem.crop((q*80,d*80,(q+1)*80,(d+1)*80)).getbbox()
            for y in range(24):
                for x in range(24):
                    if fonte.getpixel((x,y))!=nova.getpixel((x,y)):
                        assert fonte.getpixel((x,y))[3]==255 and nova.getpixel((x,y))[3]==0
                        pos=(q*80+alvo[0]+x-caixa[0],d*80+alvo[1]+y-caixa[1])
                        if saida.getpixel(pos)[3]:saida.putpixel(pos,(255,255,255,0))
    return saida
