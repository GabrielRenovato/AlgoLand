#!/usr/bin/env python3
"""Referência gerada versus captura real, com ampliações da cabeça."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

RAIZ = Path(__file__).resolve().parents[3]
SAIDA = RAIZ / 'arte/previas/personagens/base_3d/pintura_corpo'


def exportar():
    referencia = Image.open(RAIZ / 'arte/fontes/personagens/base_3d/pintura_pixel_nitida/referencia_oito_direcoes_v1.png').convert('RGB')
    centros = [(273,190),(704,190),(1095,190),(1532,190),(253,613),(680,613),(1093,613),(1523,613)]
    nomes = ['FRENTE','DIAGONAL DIREITA','PERFIL DIREITO','COSTAS / DIREITA','COSTAS','COSTAS / ESQUERDA','PERFIL ESQUERDO','DIAGONAL ESQUERDA']
    folha = Image.new('RGB',(1600,650),'#68745a')
    desenho = ImageDraw.Draw(folha)
    caminho = Path('/usr/share/fonts/google-noto/NotoSans-Bold.ttf')
    fonte = ImageFont.truetype(str(caminho),16) if caminho.exists() else ImageFont.load_default(size=16)
    for d,(cx,cy) in enumerate(centros):
        x=(d%4)*400
        y=(d//4)*325
        desenho.text((x+14,y+12),nomes[d],font=fonte,fill='white')
        desenho.text((x+14,y+43),'REFERÊNCIA',font=fonte,fill='white')
        desenho.text((x+214,y+43),'NO GODOT',font=fonte,fill='white')
        origem = referencia.crop((cx-185,cy-185,cx+185,cy+185)).resize((195,195),Image.Resampling.LANCZOS)
        folha.paste(origem,(x+2,y+82))
        jogo = Image.open(SAIDA / f'cabeca_validada_{d}.png').convert('RGBA')
        f=jogo.width/1280
        captura = jogo.crop(tuple(round(v*f) for v in (525,357,738,570))).resize((195,195),Image.Resampling.LANCZOS)
        folha.paste(captura,(x+202,y+82),captura)
    folha.save(SAIDA / 'oito_direcoes_referencia_vs_jogo.png')
    folha.crop((0,0,400,300)).resize((800,600),Image.Resampling.LANCZOS).save(SAIDA / 'rosto_lado_a_lado.png')


if __name__ == '__main__':
    exportar()
