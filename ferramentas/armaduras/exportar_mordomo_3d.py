#!/usr/bin/env python3
"""Monta prévias dos pixels renderizados, sem redesenhar as fontes."""
import json
import sys
import subprocess
from pathlib import Path
from PIL import Image
RAIZ=Path(__file__).resolve().parents[2]
CONJUNTO=sys.argv[1] if len(sys.argv)>1 else 'mordomo'
assert CONJUNTO in ['mordomo','carrasco','rubro']
PASTA=RAIZ/f'arte/previas/armaduras/{CONJUNTO}_3d'
def ff(*args):
    subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y',*map(str,args)],check=True)
def main():
    tempos=json.loads((PASTA/'tempos.json').read_text())
    total=0
    for acao in tempos:
        for direcao in (0,2,4,6):
            for quadro in range(12):
                p=PASTA/f'{acao}_{direcao}_{quadro:02d}.png'
                with Image.open(p) as img:
                    assert img.size==(160,160),p.name
                    box=img.getchannel('A').getbbox()
                    assert box and min(box[:2])>0 and max(box[2:])<160,(p.name,box)
                total+=1
    with Image.open(PASTA/'parado_0.png') as img:
        faixa=sum(1 for r,g,b,a in img.crop((45,15,115,65)).get_flattened_data() if a>0 and r>g*1.6 and b>g*1.2 and r>b*1.2)
    if CONJUNTO=='mordomo':
        assert faixa>=5,'Faixa vinho deve aparecer na cartola'
    for acao in ['correr','espada','fazenda_picareta','fazenda_machado']:
        for direcao in [0,4]:
            taxa=12/tempos[acao]
            entrada=PASTA/f'{acao}_{direcao}_%02d.png'
            ff('-framerate',taxa,'-i',entrada,'-vf',
               'crop=120:135:20:5,scale=240:270:flags=neighbor,tile=6x2','-frames:v',1,PASTA/f'quadros_{acao}_{direcao}.png')
            ff('-framerate',taxa,'-i',entrada,'-filter_complex',
               '[0:v]crop=120:135:20:5,scale=360:405:flags=neighbor,split[a][b];[a]palettegen=reserve_transparent=1[p];[b][p]paletteuse=dither=none',
               '-loop',0,PASTA/f'{acao}_{direcao}.gif')
    entradas=[]
    for d in [0,2,4,6]:entradas.extend(['-i',PASTA/f'parado_{d}.png'])
    ff(*entradas,'-filter_complex',
       '[0:v]crop=80:110:40:15[a];[1:v]crop=80:110:40:15[b];[2:v]crop=80:110:40:15[c];[3:v]crop=80:110:40:15[d];[a][b][c][d]hstack=inputs=4,scale=960:330:flags=neighbor[arte];color=c=0x52624f:s=960x330:d=1,format=rgba[fundo];[fundo][arte]overlay=format=rgb',
       '-frames:v',1,PASTA/'quatro_vistas.png')
    (PASTA/'validacao.json').write_text(json.dumps({'quadros_sem_corte':total,'pixels_faixa_vinho':faixa,'duracoes_reais':tempos},indent=2)+'\n')
    print(f'{CONJUNTO}: {total} quadros íntegros; prévias em quatro direções e oito GIFs nos tempos do controlador')
if __name__=='__main__':main()
