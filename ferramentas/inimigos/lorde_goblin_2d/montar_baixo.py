"""Monta o estudo frontal preservando a folha e as correções localizadas."""
from pathlib import Path
import json
from PIL import Image, ImageDraw

RAIZ=Path(__file__).resolve().parents[3]
FONTES=RAIZ/'arte/fontes/inimigos/lorde_goblin_2d'
PREVIAS=RAIZ/'arte/previas/inimigos/lorde_goblin_2d'
TEMPOS=[100,150,180,60,50,80,110,160,170]

def montar():
    original=Image.open(FONTES/'martelada_baixo_v5.png').convert('RGBA')
    poses=[original.crop((i%4*640,i//4*640,(i%4+1)*640,(i//4+1)*640)) for i in range(8)]
    elevacao=Image.open(FONTES/'baixo_intermediario_marreta_vertical.png').convert('RGBA')
    elevacao=elevacao.resize((627,627),Image.Resampling.LANCZOS)
    nova=Image.new('RGBA',(640,640))
    nova.alpha_composite(elevacao,(7,5))
    nova.putalpha(nova.getchannel('A').point(lambda a:0 if a<=64 else a))
    poses.insert(3,nova)
    atlas=Image.new('RGBA',(1920,1920))
    margens=[]
    for i,celula in enumerate(poses):
        bbox=celula.getbbox()
        margem=min(bbox[0],bbox[1],640-bbox[2],640-bbox[3])
        if margem<16: raise ValueError(f'Quadro {i+1} sem margem suficiente: {bbox}')
        margens.append(margem)
        atlas.alpha_composite(celula,(i%3*640,i//3*640))
    atlas.save(PREVIAS/'martelada_baixo_folha.png')
    atlas.save(PREVIAS/'martelada_baixo_folha_9quadros.png')
    atlas.save(FONTES/'martelada_baixo_v6.png')
    nova.save(PREVIAS/'quadro04_marreta_vertical.png')
    contato=Image.new('RGB',(960,1056),'#293435')
    quadros=[]
    for i,pose in enumerate(poses):
        quadro=Image.new('RGB',(640,640),'#293435')
        quadro.paste(pose,(0,0),pose)
        quadros.append(quadro)
        p=quadro.resize((320,320),Image.Resampling.NEAREST)
        contato.paste(p,(i%3*320,i//3*352+32))
        ImageDraw.Draw(contato).text((i%3*320+12,i//3*352+10),f'{i+1:02d} / {TEMPOS[i]}ms',fill='#eee7d2')
    contato.save(PREVIAS/'martelada_baixo_contato.png')
    paleta=contato.quantize(colors=256,method=Image.Quantize.MEDIANCUT)
    gif=[q.quantize(palette=paleta,dither=Image.Dither.NONE) for q in quadros]
    tempos=TEMPOS[:-1]+[TEMPOS[-1]+500]
    gif[0].save(PREVIAS/'martelada_baixo.gif',save_all=True,append_images=gif[1:],
                duration=tempos,loop=0,disposal=2,optimize=False)
    (PREVIAS/'martelada_baixo_9quadros.gif').write_bytes((PREVIAS/'martelada_baixo.gif').read_bytes())
    registro={'grade':[3,3],'celula':[640,640],'pivo':[320,500],
              'quantidade_quadros':9,'ordem':list(range(9)),'duracoes_ms':TEMPOS,'pausa_gif_final_ms':500,
              'base_preservada':'martelada_baixo_v5.png','folha_final':'martelada_baixo_v6.png',
              'impacto_quadro':5,'impacto_ms':sum(TEMPOS[:5]),
              'quadro_inserido':{'indice':3,'fonte':'baixo_intermediario_marreta_vertical.png','tamanho':[627,627],'translacao':[7,5]},
              'margens_px':margens,'escopo':'GIF e atlas do estudo frontal; sem substituir o chefe ativo.'}
    (FONTES/'registro_martelada_baixo.json').write_text(json.dumps(registro,indent=2,ensure_ascii=False)+'\n')
    print('BAIXO: nove quadros, intermediario vertical inserido, margens:',margens)

if __name__=='__main__': montar()
