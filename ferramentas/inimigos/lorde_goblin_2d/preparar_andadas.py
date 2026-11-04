"""Registra as seis poses de cada caminhada no mesmo pivô dos ataques."""
from pathlib import Path
import json
from PIL import Image,ImageDraw
from preparar_previas_direcionais import medir

RAIZ=Path(__file__).resolve().parents[3]
FONTES=RAIZ/'arte/fontes/inimigos/lorde_goblin_2d'
ASSETS=RAIZ/'assets/inimigos/lorde_goblin_2d'
PREVIAS=RAIZ/'arte/previas/inimigos/lorde_goblin_2d'
TRANSFORMACOES={'direita':(432,104,116),'baixo':(394,123,130),'cima':(430,105,118)}

def preparar():
    for direcao,(lado,dx,dy) in TRANSFORMACOES.items():
        fonte=Image.open(FONTES/f'andada_{direcao}_fonte_v1.png').convert('RGBA')
        ataque=json.loads((FONTES/f'registro_martelada_{direcao}.json').read_text())
        modelo=Image.open(FONTES/ataque['folha_final']).convert('RGBA').crop((0,0,640,640))
        alvo=medir(modelo)
        atlas=Image.new('RGBA',(1920,1280))
        contato=Image.new('RGB',(960,704),'#293435')
        cores=[];margens=[]
        for i in range(6):
            x,y=i%3,i//3
            caixa=(round(x*fonte.width/3),round(y*fonte.height/2),round((x+1)*fonte.width/3),round((y+1)*fonte.height/2))
            desenho=fonte.crop(caixa).resize((lado,lado),Image.Resampling.LANCZOS)
            celula=Image.new('RGBA',(640,640));celula.alpha_composite(desenho,(dx,dy))
            celula.putalpha(celula.getchannel('A').point(lambda a:0 if a<=64 else a))
            bbox=celula.getbbox();margem=min(bbox[0],bbox[1],640-bbox[2],640-bbox[3])
            if margem<24:raise ValueError((direcao,i,bbox))
            margens.append(margem);cores.append(medir(celula))
            atlas.alpha_composite(celula,(x*640,y*640))
            q=Image.new('RGB',(640,640),'#293435');q.paste(celula,(0,0),celula)
            contato.paste(q.resize((320,320)),(x*320,y*352+32))
            ImageDraw.Draw(contato).text((x*320+10,y*352+10),f'{i+1:02d} / 110ms',fill='#eee7d2')
        destino=f'andada_boss_{direcao}.png'
        atlas.save(ASSETS/destino);atlas.save(PREVIAS/f'andada_{direcao}_folha.png')
        contato.save(PREVIAS/f'andada_{direcao}_contato.png')
        ficha={'fonte':f'andada_{direcao}_fonte_v1.png','textura':f'res://assets/inimigos/lorde_goblin_2d/{destino}',
               'colunas':3,'tempos_ms':[110]*6,'pivo':[320,500],
               'transformacao_comum':{'tamanho':[lado,lado],'translacao':[dx,dy]},'margens_px':margens,
               'medianas_rgb':cores,'referencia_rgb':alvo}
        for material in ['couro','manto']:
            ficha['ganhos_'+material]=[[round(max(.8,min(1.2,alvo[material][c]/max(1,cor[material][c]))),3) for c in range(3)] for cor in cores]
        (FONTES/f'andada_{direcao}_registro.json').write_text(json.dumps(ficha,indent=2,ensure_ascii=False)+'\n')
        print(direcao,'seis poses; margens:',margens)

if __name__=='__main__':preparar()
