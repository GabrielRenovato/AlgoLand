"""Empacota a martelada de costas com transformação comum às nove poses."""
from pathlib import Path
import json
from PIL import Image, ImageDraw

RAIZ=Path(__file__).resolve().parents[3]
FONTES=RAIZ/'arte/fontes/inimigos/lorde_goblin_2d'
PREVIAS=RAIZ/'arte/previas/inimigos/lorde_goblin_2d'
TEMPOS=[100,150,180,60,50,80,110,160,170]

def montar():
    original=Image.open(FONTES/'martelada_cima_gerada_v1.png').convert('RGBA')
    correcao=Image.open(FONTES/'cima_dorso_maos_v3.png').convert('RGBA')
    descida=Image.open(FONTES/'cima_descida_impactos_estudo_v4.png').convert('RGBA')
    impactos=Image.open(FONTES/'cima_impacto_entre_pernas_v5.png').convert('RGBA')
    atlas=Image.new('RGBA',(1920,1920))
    contato=Image.new('RGB',(960,1056),'#293435')
    quadros=[]
    margens=[]
    for i in range(9):
        x,y=i%3,i//3
        caixa=(round(x*original.width/3),round(y*original.height/3),
               round((x+1)*original.width/3),round((y+1)*original.height/3))
        desenho=original.crop(caixa).resize((600,600),Image.Resampling.LANCZOS)
        celula=Image.new('RGBA',(640,640))
        celula.alpha_composite(desenho,(20,18))
        if i in (2,3,4):
            j=i-2
            caixa_correcao=(j*correcao.width//3,0,(j+1)*correcao.width//3,correcao.height)
            desenho=correcao.crop(caixa_correcao).resize((584,584),Image.Resampling.LANCZOS)
            celula=Image.new('RGBA',(640,640))
            celula.alpha_composite(desenho,(40,-5))
        celula.putalpha(celula.getchannel('A').point(lambda a:0 if a<=64 else a))
        if i==4:
            desenho=descida.crop((0,0,descida.width//3,descida.height)).resize((470,470),Image.Resampling.LANCZOS)
            celula=Image.new('RGBA',(640,640))
            celula.alpha_composite(desenho,(85,70))
        elif i in (5,6):
            j=i-5
            desenho=impactos.crop((j*impactos.width//2,0,(j+1)*impactos.width//2,impactos.height)).resize((444,444),Image.Resampling.LANCZOS)
            celula=Image.new('RGBA',(640,640))
            celula.alpha_composite(desenho,(98,100))
        celula.putalpha(celula.getchannel('A').point(lambda a:0 if a<=64 else a))
        bbox=celula.getbbox()
        margem=min(bbox[0],bbox[1],640-bbox[2],640-bbox[3])
        if margem<16: raise ValueError(f'Quadro {i+1} sem margem: {bbox}')
        margens.append(margem)
        atlas.alpha_composite(celula,(x*640,y*640))
        quadro=Image.new('RGB',(640,640),'#293435')
        quadro.paste(celula,(0,0),celula)
        quadros.append(quadro)
        contato.paste(quadro.resize((320,320),Image.Resampling.NEAREST),(x*320,y*352+32))
        ImageDraw.Draw(contato).text((x*320+12,y*352+10),f'{i+1:02d} / {TEMPOS[i]}ms',fill='#eee7d2')
    atlas.save(FONTES/'martelada_cima_v5.png')
    atlas.save(PREVIAS/'martelada_cima_folha_9quadros.png')
    atlas.save(PREVIAS/'martelada_cima_folha_impacto_chao.png')
    contato.save(PREVIAS/'martelada_cima_contato.png')
    paleta=contato.quantize(colors=256,method=Image.Quantize.MEDIANCUT)
    gif=[q.quantize(palette=paleta,dither=Image.Dither.NONE) for q in quadros]
    gif[0].save(PREVIAS/'martelada_cima_impacto_chao.gif',save_all=True,append_images=gif[1:],
                duration=TEMPOS[:-1]+[TEMPOS[-1]+500],loop=0,disposal=2,optimize=False)
    registro={'direcao':'cima','grade':[3,3],'celula':[640,640],'pivo':[320,500],
              'quantidade_quadros':9,'ordem':list(range(9)),'duracoes_ms':TEMPOS,
              'pausa_gif_final_ms':500,'impacto_quadro':5,'impacto_ms':sum(TEMPOS[:5]),
              'fonte':'martelada_cima_gerada_v1.png','folha_final':'martelada_cima_v5.png',
              'descida':{'fonte':'cima_descida_impactos_estudo_v4.png','indice':4,'celula_fonte':0,'tamanho':[470,470],'translacao':[85,70]},
              'impactos':{'fonte':'cima_impacto_entre_pernas_v5.png','indices':[5,6],'tamanho':[444,444],'translacao':[98,100]},
              'correcao':{'fonte':'cima_dorso_maos_v3.png','indices':[2,3,4],'celulas_fonte':[0,1,2],'tamanho':[584,584],'translacao':[40,-5]},
              'transformacao_comum':{'tamanho':[600,600],'translacao':[20,18]},
              'margens_px':margens,'escopo':'Estudo da direcao norte; sem substituir o chefe ativo.'}
    (FONTES/'registro_martelada_cima.json').write_text(json.dumps(registro,indent=2,ensure_ascii=False)+'\n')
    print('CIMA: nove quadros; margens:',margens)

if __name__=='__main__': montar()
