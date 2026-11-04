"""Empacota poses desenhadas, sem deformar corpo ou fabricar movimento."""
from pathlib import Path
import json
import shutil
import sys
from PIL import Image, ImageDraw

RAIZ = Path(__file__).resolve().parents[3]
FONTES = RAIZ/'arte/fontes/inimigos/lorde_goblin_2d'
ASSETS = RAIZ/'assets/inimigos/lorde_goblin_2d'
PREVIAS = RAIZ/'arte/previas/inimigos/lorde_goblin_2d'
TEMPOS = [100,150,180,50,80,110,160,170]
# Registro manual pelo ponto médio dos apoios das botas; nunca pelo contorno da pose.
RAIZES = [(228,417),(234,418),(235,418),(229,418),(194,421),(193,420),(198,421),(213,421)]
CELULA = 512
PIVO = (256,450)

def preparar():
    for pasta in [ASSETS,PREVIAS]: pasta.mkdir(parents=True,exist_ok=True)
    fonte=Image.open(FONTES/'martelada_direita_v3_pegada_fechada.png').convert('RGBA')
    atlas=Image.new('RGBA',(CELULA*4,CELULA*2))
    poses=[]
    registro={'celula':[CELULA,CELULA],'pivo':list(PIVO),'escala':0.2,
              'fonte':'martelada_direita_v3_pegada_fechada.png',
              'resolucao_fonte':list(fonte.size),'grade':[4,2],
              'duracoes_ms':TEMPOS,'loop':False,'impacto_quadro':4,'impacto_ms':sum(TEMPOS[:4]),
              'limiar_alfa':64,'raizes_fonte':RAIZES,'direcoes':['direita'],
              'registro':'Translacao pelo apoio fisico dos pes; escala identica em todos os quadros.'}
    for i,raiz in enumerate(RAIZES):
        caixa=(round(i%4*fonte.width/4),round(i//4*fonte.height/2),
               round((i%4+1)*fonte.width/4),round((i//4+1)*fonte.height/2))
        pose=fonte.crop(caixa)
        # Apenas saneamento de alfa da exportação, igual ao importador dos goblins.
        pose.putalpha(pose.getchannel('A').point(lambda a:0 if a<=64 else a))
        celula=Image.new('RGBA',(CELULA,CELULA))
        celula.alpha_composite(pose,(PIVO[0]-raiz[0],PIVO[1]-raiz[1]))
        atlas.alpha_composite(celula,(i%4*CELULA,i//4*CELULA))
        poses.append(celula)
    atlas.save(ASSETS/'martelada_direita.png')
    linhas=['[gd_resource type="SpriteFrames" load_steps=10 format=3]','',
            '[ext_resource type="Texture2D" path="res://assets/inimigos/lorde_goblin_2d/martelada_direita.png" id="1"]','']
    for i in range(8):
        linhas.extend([f'[sub_resource type="AtlasTexture" id="Quadro_{i}"]',
                       'atlas = ExtResource("1")',
                       f'region = Rect2({i%4*CELULA},{i//4*CELULA},{CELULA},{CELULA})',''])
    frames=','.join('{"duration":'+str(t/10.0)+',"texture":SubResource("Quadro_'+str(i)+'")}' for i,t in enumerate(TEMPOS))
    linhas.extend(['[resource]', 'animations = [{"frames":['+frames+'],"loop":false,"name":&"martelada_direita","speed":100.0},',
                   '{"frames":[{"duration":10.0,"texture":SubResource("Quadro_0")}],"loop":true,"name":&"parado_direita","speed":100.0}]',''])
    (ASSETS/'animacoes.tres').write_text('\n'.join(linhas))
    (ASSETS/'registro_animacoes.json').write_text(json.dumps(registro,indent=2,ensure_ascii=False)+'\n')
    contato=Image.new('RGB',(1280,704),'#293435')
    quadros=[]
    fases=['GUARDA','CARREGAR','ELEVAR','DESCER','IMPACTO','ABSORVER','RECUPERAR','GUARDA']
    for i,pose in enumerate(poses):
        fundo=Image.new('RGB',(320,352),'#293435')
        d=ImageDraw.Draw(fundo)
        d.text((12,10),f'{i+1:02d} {fases[i]} / {TEMPOS[i]} ms',fill='#eee7d2')
        p=pose.resize((320,320),Image.Resampling.NEAREST)
        fundo.paste(p,(0,32),p)
        contato.paste(fundo,(i%4*320,i//4*352))
        quadros.append(fundo)
    contato.save(PREVIAS/'martelada_direita_contato.png')
    paleta=contato.quantize(colors=255,method=Image.Quantize.MEDIANCUT)
    gif=[p.quantize(palette=paleta,dither=Image.Dither.NONE) for p in quadros]
    # A pausa adicional pertence só à demonstração; o ataque no motor não repete.
    gif[0].save(PREVIAS/'martelada_direita.gif',save_all=True,append_images=gif[1:],
                duration=TEMPOS[:-1]+[TEMPOS[-1]+500],loop=0,disposal=2,optimize=False)
    print('LORDE_2D: oito quadros, 1000ms, impacto480ms, raiz256/450, pegada fechada.')

def montar_motor():
    pasta=Path('/tmp/algoland-lorde2d-revisao/capturas')
    dados=json.loads((pasta/'reproducao.json').read_text())
    imagens=[Image.open(pasta/f'motor_{i:03d}.png').convert('RGB') for i in range(len(dados['quadros']))]
    indices=[dados['quadros'].index(i) for i in range(8)]
    contato=Image.new('RGB',(imagens[0].width*4,imagens[0].height*2))
    for i,indice in enumerate(indices): contato.paste(imagens[indice],(i%4*imagens[0].width,i//4*imagens[0].height))
    contato.save(PREVIAS/'motor_contato.png')
    paleta=contato.quantize(colors=255,method=Image.Quantize.MEDIANCUT)
    quadros=[im.quantize(palette=paleta,dither=Image.Dither.NONE) for im in imagens]
    acumulados=[round(t*100)*10 for t in dados['instantes_s']]
    tempos=[max(10,b-a) for a,b in zip(acumulados,acumulados[1:])]+[20]
    quadros[0].save(PREVIAS/'martelada_no_motor.gif',save_all=True,append_images=quadros[1:],duration=tempos,loop=0,disposal=2,optimize=False)
    shutil.copyfile(pasta/'no_mapa.png',PREVIAS/'no_mapa.png')
    shutil.copyfile(pasta/'reproducao.json',PREVIAS/'reproducao_motor.json')
    print('LORDE_2D_MOTOR:',len(imagens),'capturas; oito poses observadas; dois ataques.')

if __name__=='__main__':
    if '--motor' in sys.argv: montar_motor()
    else: preparar()
