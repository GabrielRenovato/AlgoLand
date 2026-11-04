"""Monta a prévia das quatro direções a partir das capturas reais da dungeon."""
from pathlib import Path
import argparse,json
from PIL import Image,ImageDraw

RAIZ=Path(__file__).resolve().parents[3]
PREVIAS=RAIZ/'arte/previas/inimigos/lorde_goblin_2d'

def exportar(capturas,escala_coordenadas=1.0):
    ficha=json.loads((capturas/'lorde-andada-enquadramento.json').read_text())
    x,y=ficha['centro']
    x/=escala_coordenadas;y/=escala_coordenadas
    caixa=(round(x-150),round(y-180),round(x+150),round(y+80))
    quadros=[]
    for i in range(6):
        quadro=Image.new('RGB',(600,568),'#293435')
        for j,d in enumerate(['baixo','cima','direita','esquerda']):
            original=Image.open(capturas/f'lorde-andada-{d}-{i:02d}.png').convert('RGB')
            px,py=j%2*300,j//2*284
            quadro.paste(original.crop(caixa),(px,py+24))
            ImageDraw.Draw(quadro).text((px+12,py+8),d.upper(),fill='#eee7d2')
        quadros.append(quadro)
    amostra=Image.new('RGB',(1800,1136))
    for i,q in enumerate(quadros):amostra.paste(q,(i%3*600,i//3*568))
    paleta=amostra.quantize(colors=256,method=Image.Quantize.MEDIANCUT)
    gif=[q.quantize(palette=paleta,dither=Image.Dither.NONE) for q in quadros]
    gif[0].save(PREVIAS/'boss_andando_quatro_direcoes_no_moinho.gif',save_all=True,
                append_images=gif[1:],duration=[110]*6,loop=0,disposal=2,optimize=False)
    amostra.save(PREVIAS/'boss_andada_seis_quadros_no_moinho.png')
    print('Previa das quatro direcoes exportada das capturas reais do mapa.')

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('capturas',type=Path)
    p.add_argument('--escala-coordenadas',type=float,default=1.0)
    args=p.parse_args()
    exportar(args.capturas,args.escala_coordenadas)
