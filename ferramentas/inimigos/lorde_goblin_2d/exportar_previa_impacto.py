"""Exporta GIF e contatos das capturas reais do Godot, sem redesenhar a arte."""
from pathlib import Path
import argparse
import json
from PIL import Image, ImageDraw

RAIZ=Path(__file__).resolve().parents[3]
PREVIAS=RAIZ/'arte/previas/inimigos/lorde_goblin_2d'

def exportar(direcao='cima'):
    revisao=json.loads((PREVIAS/f'revisao_{direcao}_godot.json').read_text())
    ficha=json.loads((RAIZ/f'arte/fontes/inimigos/lorde_goblin_2d/registro_martelada_{direcao}.json').read_text())
    if not revisao.get('efeitos'): raise ValueError('Revisao sem efeitos')
    pasta=Path(revisao['capturas'])
    quadros=[Image.open(pasta/f'efeito_{i:03d}.png').convert('RGB') for i in range(60)]
    amostras=Image.new('RGB',(640,640))
    for j,i in enumerate(range(0,60,4)):
        amostras.paste(quadros[i].resize((160,160)),(j%4*160,j//4*160))
    paleta=amostras.quantize(colors=256,method=Image.Quantize.MEDIANCUT)
    gif=[q.quantize(palette=paleta,dither=Image.Dither.NONE) for q in quadros]
    gif[0].save(PREVIAS/f'martelada_{direcao}_escombros_cores_revisadas.gif',
                save_all=True,append_images=gif[1:],duration=[30]*59+[430],
                loop=0,disposal=2,optimize=False)
    contato=Image.new('RGB',(1280,704),'#293435')
    contato_passo=ficha['impacto_ms']//30
    for j,i in enumerate([contato_passo+d for d in [-1,0,2,5,8,12,18,25]]):
        x,y=j%4*320,j//4*352
        contato.paste(quadros[i].resize((320,320)),(x,y+32))
        ImageDraw.Draw(contato).text((x+10,y+10),f'{i*30} ms',fill='#eee7d2')
    contato.save(PREVIAS/f'martelada_{direcao}_efeito_contato.png')
    quantidade=revisao['quadros']
    colunas=4 if quantidade==8 else 3
    linhas=(quantidade+colunas-1)//colunas
    cores=Image.new('RGB',(colunas*320,linhas*352),'#293435')
    for i in range(quantidade):
        x,y=i%colunas*320,i//colunas*352
        q=Image.open(pasta/f'quadro_{i:02d}.png').convert('RGB')
        cores.paste(q.resize((320,320)),(x,y+32))
        ImageDraw.Draw(cores).text((x+10,y+10),f'{i+1:02d}',fill='#eee7d2')
    cores.save(PREVIAS/f'martelada_{direcao}_cores_revisadas_contato.png')
    quadros[contato_passo+5].save(PREVIAS/f'martelada_{direcao}_escombros_apice.png')
    registro={'capturas':str(pasta),'quadros_amostrados':60,'passo_ms':30,
              'direcao':direcao,'poses_revisadas':quantidade,
              'contato_ms':ficha['impacto_ms'],'efeito_ms':900,'pausa_gif_ms':400,
              'dano_implementado':False,'escopo':'Previa solicitada pelo usuario',
              'correcao_cor':'Ganhos por material/quadro em shader, sem substituir as fontes raster.'}
    (PREVIAS/f'registro_previa_escombros_{direcao}.json').write_text(json.dumps(registro,indent=2,ensure_ascii=False)+'\n')
    print(f'GIF {direcao} exportado com escombros e {quantidade} poses revisadas.')

if __name__=='__main__':
    argumentos=argparse.ArgumentParser()
    argumentos.add_argument('direcao',nargs='?',default='cima',choices=['cima','baixo','direita'])
    exportar(argumentos.parse_args().direcao)
