"""Registra a folha escolhida à direita e mede a paleta de cada direção."""
from pathlib import Path
import colorsys
import json
import statistics
from PIL import Image

RAIZ=Path(__file__).resolve().parents[3]
FONTES=RAIZ/'arte/fontes/inimigos/lorde_goblin_2d'

def medir(imagem):
    amostras={'couro':[],'manto':[]}
    for r,g,b,a in imagem.getdata():
        if a<240: continue
        h,s,v=colorsys.rgb_to_hsv(r/255,g/255,b/255)
        if .045<h<.12 and s>.18 and .15<v<.75:
            amostras['couro'].append((r,g,b))
        elif .42<h<.62 and s>.12 and .06<v<.65:
            amostras['manto'].append((r,g,b))
    return {nome:[statistics.median(p[c] for p in valores) for c in range(3)]
            for nome,valores in amostras.items()}

def preparar():
    original=Image.open(FONTES/'martelada_folha_escolhida_usuario.png').convert('RGBA')
    atlas=Image.new('RGBA',(2560,1280))
    for i in range(8):
        x,y=i%4,i//4
        caixa=(round(x*original.width/4),round(y*original.height/2),
               round((x+1)*original.width/4),round((y+1)*original.height/2))
        celula=Image.new('RGBA',(640,640))
        celula.alpha_composite(original.crop(caixa),(98,70))
        celula.putalpha(celula.getchannel('A').point(lambda a:0 if a<=64 else a))
        atlas.alpha_composite(celula,(x*640,y*640))
    atlas.save(FONTES/'martelada_direita_escolhida_atlas.png')
    tempos=[100,150,180,50,80,110,160,170]
    ficha={'direcao':'direita','grade':[4,2],'celula':[640,640],'pivo':[320,500],
           'quantidade_quadros':8,'duracoes_ms':tempos,'impacto_quadro':4,
           'impacto_ms':sum(tempos[:4]),'folha_final':'martelada_direita_escolhida_atlas.png',
           'fonte':'martelada_folha_escolhida_usuario.png',
           'transformacao_comum':{'escala':1,'translacao':[98,70]},
           'escopo':'Previa/GIF da folha escolhida pelo usuario; sem substituir o chefe ativo'}
    (FONTES/'registro_martelada_direita.json').write_text(json.dumps(ficha,indent=2,ensure_ascii=False)+'\n')
    ajustes={'baixo':{'contato':[320,530],'posicao_previa':[320,480]},
             'direita':{'contato':[486,497],'posicao_previa':[250,520]}}
    for direcao,encaixe in ajustes.items():
        registro=json.loads((FONTES/f'registro_martelada_{direcao}.json').read_text())
        imagem=Image.open(FONTES/registro['folha_final']).convert('RGBA')
        colunas=registro['grade'][0]
        cores=[]
        for i in range(len(registro['duracoes_ms'])):
            x,y=i%colunas*640,i//colunas*640
            cores.append(medir(imagem.crop((x,y,x+640,y+640))))
        revisao={'quadros_revisados':list(range(1,len(cores)+1)),
                 'referencia_cor':'Primeiro quadro da mesma direcao; preserva sombras e textura',
                 'medianas_rgb':cores,'ganhos_couro':[],'ganhos_manto':[],**encaixe,
                 'escopo':'Ajuste de renderizacao da previa; fontes raster preservadas'}
        for material in ['couro','manto']:
            for cor in cores:
                revisao['ganhos_'+material].append([
                    round(max(.82,min(1.18,cores[0][material][c]/max(1,cor[material][c]))),3)
                    for c in range(3)])
        (FONTES/f'revisao_paleta_{direcao}.json').write_text(json.dumps(revisao,indent=2,ensure_ascii=False)+'\n')
        print(direcao, 'quadros:',len(cores), 'contato:',registro['impacto_ms'],'ms')

if __name__=='__main__': preparar()
