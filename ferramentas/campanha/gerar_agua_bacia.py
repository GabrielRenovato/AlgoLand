"""Água por quadros: ondas periódicas, normais, reflexos e espuma em atlas compartilhado."""
from pathlib import Path
from PIL import Image, ImageDraw
import math, json

RAIZ = Path(__file__).resolve().parents[2]
PASTA = RAIZ/'assets/cenario/campanha/agua_bacia'
PREVIA = RAIZ/'arte/previas/campanha/agua_bacia'
PASTA.mkdir(parents=True,exist_ok=True)
PREVIA.mkdir(parents=True,exist_ok=True)
TAMANHO, QUADROS, FPS = 64, 24, 8
TAU = math.tau
PALETAS = {'primavera':(27,102,117),'verao':(25,113,119),'outono':(35,93,106),'inverno':(35,83,112)}
# Ondas com velocidades e direções diferentes deformam os reflexos a cada quadro.
# Frequências espaciais e temporais inteiras fecham as bordas e o ciclo de 3 s.
ONDAS = [(1,2,-1,.32),(3,-1,-2,.17),(2,3,1,.12),(5,2,-3,.055)]
for nome,base in PALETAS.items():
    atlas=Image.new('RGB',(TAMANHO*QUADROS,TAMANHO))
    contato=Image.new('RGB',(6*TAMANHO,4*TAMANHO))
    for frame in range(QUADROS):
        im=Image.new('RGB',(TAMANHO,TAMANHO))
        tempo=frame/QUADROS*TAU
        for y in range(TAMANHO):
            for x in range(TAMANHO):
                u,v=(x//2*2+.5)/TAMANHO*TAU,(y//2*2+.5)/TAMANHO*TAU
                h=dx=dy=0.0
                for kx,ky,vel,amp in ONDAS:
                    fase=kx*u+ky*v+vel*tempo
                    h+=math.sin(fase)*amp
                    dx+=math.cos(fase)*amp*kx
                    dy+=math.cos(fase)*amp*ky
                normal=(-dx*.20,-dy*.20,1.0)
                modulo=math.sqrt(sum(n*n for n in normal))
                normal=tuple(n/modulo for n in normal)
                brilho=max(0.,normal[0]*-.35+normal[1]*-.27+normal[2]*.90)**45
                crista=max(0.,h-.38)**2
                # Caústica estável do fundo, distorcida pelas ondas, sem ruído aleatório.
                fundo=math.sin(u*3+dx*.24)*math.cos(v*2+dy*.24)*.5+.5
                luz=.91+h*.075+fundo*.055
                reflexo=min(.8,brilho*.45+crista*.16)
                # Faixas de cor e cristas estreitas: nada de manchas desfocadas.
                faixa=round((h+.7)*3.0)/3.0
                luz=.78+faixa*.20
                crista_fina=max(0.,1.-abs(h-.29)/.055)
                brilho_fino=max(0.,brilho-.13)*.65
                reflexo=min(.72,crista_fina*.22+brilho_fino)
                cor=tuple(max(0,min(255,round(base[c]*luz*(1-reflexo)+(162,216,222)[c]*reflexo))) for c in range(3))
                im.putpixel((x,y),cor)
        atlas.paste(im,(frame*TAMANHO,0))
        contato.paste(im,((frame%6)*TAMANHO,(frame//6)*TAMANHO))
    atlas.save(PASTA/(nome+'.png'))
    contato.resize((768,512),Image.Resampling.NEAREST).save(PREVIA/(nome+'-quadros.png'))
ficha={'quadro':[64,64],'atlas':[1536,64],'quadros':24,'fps':8,'ciclo_segundos':3,
       'ordem':'esquerda para direita','pixels_logicos':2,'sentido_nativo':'esquerda para direita; shader orienta conforme o canal',
       'encaixe':'ondas periódicas em X/Y e tempo, mesmo relógio e origem mundial em todos os tiles',
       'camadas':'superfície por quadros; espuma, margens, pontes e colisões independentes',
       'estacoes':list(PALETAS),'origem':'geração matemática de ondas e iluminação; sem imagem de mapa completo'}
(PASTA/'animacao.json').write_text(json.dumps(ficha,ensure_ascii=False,indent=2)+'\n')
print('4 atlas; 24 quadros por estação; ciclo de 3 segundos.')
