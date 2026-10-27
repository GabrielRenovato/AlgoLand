"""Prévias da textura aplicada, compostas de capturas reais sem retocar pixels."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
R=Path(__file__).resolve().parents[3]
P=R/'arte/previas/personagens/base_3d/cabelo'
F=ImageFont.load_default(size=16)
def exportar():
    poster=Image.new('RGB',(960,570),'#58645f')
    for linha,modo in enumerate(['suave','pixel']):
        for direcao,nome in enumerate(['FRENTE','DIREITA','COSTAS','ESQUERDA']):
            im=Image.open(P/f'{modo}_cabelo_{direcao}.png').convert('RGBA')
            escala=im.width/160
            im=im.crop(tuple(round(v*escala) for v in (56,37,104,85))).resize((240,240),Image.Resampling.NEAREST if modo=='pixel' else Image.Resampling.LANCZOS)
            poster.paste(im,(direcao*240,linha*285+35),im)
            d=ImageDraw.Draw(poster)
            texto=nome+(' / JOGO' if modo=='pixel' else ' / 3D')
            box=d.textbbox((0,0),texto,font=F)
            d.text((direcao*240+(240-box[2])/2,linha*285+10),texto,font=F,fill='white')
    poster.save(P/'cabelo_pintado_quatro_direcoes.png')
    poster.crop((0,285,960,570)).save(P/'cabelo_no_filtro.png')
    print('Cabelo: detalhe nas quatro direções, render suave e filtro real.')
if __name__=='__main__':exportar()
