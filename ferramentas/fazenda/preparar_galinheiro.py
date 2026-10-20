"""Integra construções próprias geradas e as galinhas/ícones nativos Tiny RPG."""
from pathlib import Path
from PIL import Image
import json
import shutil

RAIZ = Path(__file__).resolve().parents[2]
PACOTE = Path.home() / 'Downloads/Farm RPG - Tiny Asset Pack - (All in One)'
FONTE = RAIZ / 'arte/fontes/fazenda/galinheiro'
DESTINO = RAIZ / 'assets/cenario/fazenda/galinheiro'
ESTACOES = ['primavera', 'verao', 'outono', 'inverno']

def original(caminho):
    fonte = PACOTE / caminho
    salvo = FONTE / 'originais' / caminho
    salvo.parent.mkdir(parents=True, exist_ok=True)
    if fonte.exists(): shutil.copy2(fonte, salvo)
    return Image.open(salvo).convert('RGBA')

def material(imagem, estacao):
    fatores = [(1,1,1),(1.04,1.02,.98),(.93,.90,.91),(.91,.97,1.04)][estacao]
    copia = imagem.copy()
    copia.putdata([tuple(min(255,round(c*f)) for c,f in zip(p[:3],fatores))+(p[3],) for p in imagem.getdata()])
    return copia

def preparar():
    DESTINO.mkdir(parents=True,exist_ok=True)
    # Recortes fixos das folhas geradas: mesma geometria nas quatro estações.
    recortes = [(80,80,528,576),(584,72,1248,576),(0,624,692,1148)]
    portas = [(320,556),(916,556),(356,1132)]
    dimensoes = []
    for nivel,(caixa,porta) in enumerate(zip(recortes,portas),1):
        dimensoes.append([(caixa[2]-caixa[0])//4,(caixa[3]-caixa[1])//4])
        for estacao in ESTACOES:
            folha = Image.open(FONTE/'gerados'/f'{estacao}.png').convert('RGBA')
            base = folha.crop(caixa).resize(tuple(dimensoes[-1]),Image.Resampling.NEAREST)
            tela = Image.new('RGBA',(224,160))
            tela.alpha_composite(base,(112-(porta[0]-caixa[0])//4,144-(porta[1]-caixa[1])//4))
            tela.save(DESTINO/f'nivel_{nivel}_{estacao}.png')
    preparar_interiores()
    fonte_comida = Image.open(FONTE/'gerados/primavera.png').convert('RGBA')
    fonte_comida.crop((688,696,1236,1140)).resize((192,144),Image.Resampling.NEAREST).save(DESTINO/'interior_1.png')
    for cor in ['White','Brown White','Black']:
        original('Animals/Farm/Chicken/Chicken '+cor+'.png').save(DESTINO/('galinha_'+cor.lower().replace(' ','_')+'.png'))
    original('Animals/Farm/Chicken/Chicken Brown Black.png').save(DESTINO/'galo.png')
    original('Animals/Farm/Chicken/Baby Chicken Yellow.png').save(DESTINO/'pintinho.png')
    for nome,arquivo in [('Chicken Egg','ovo'),('Omelet','omelete'),('Animal Feed','racao')]:
        original('Icons/Food Icons/'+nome+'.png').save(DESTINO/(arquivo+'.png'))
    manifesto = {'origem_construcao':'imagegen, geração própria com referência casa Bento',
                 'referencia':'assets/cenario/cidade/casas/exterior/casa_bento.png',
                 'interior':{'fonte':'gerados/interior_revisado.png','dimensoes':[[192,144],[256,160],[320,192]],'ninhos':'dois para coleta e um para incubacao; centros y34, deslocados com a ampliacao','ovos':'primeiro quadro16x16 do atlas Tiny, sem reduzir a folha inteira','estacoes':ESTACOES,'comedouro':'vazio no fundo, feno dinamico com borda frontal preservada'},
                 'grade':16,'tela_exterior':[224,160], 'pivo_porta':[112,144],
                 'recortes':recortes, 'portas_fonte':portas,
                 'aberturas_galinhas':[[133,117,10,11],[133,117,10,11],[134,116,10,11]],
                 'niveis':[{'nivel':i+1,'capacidade':n,'dimensoes':dimensoes[i]} for i,n in enumerate([4,8,12])],
                 'galinhas':{'origem':'Tiny RPG','quadro':[16,16],'grade':[4,7],'galo':'Chicken Brown Black.png','pintinho':'Baby Chicken Yellow.png'},
                 'estacoes':ESTACOES,
                 'contrato':'Telhado de palha e madeira, três ampliações próprias, base alinhada. Interior abrigado com piso ampliável. Portinha lateral com rampa e trânsito de aves.'}
    FONTE.mkdir(parents=True,exist_ok=True)
    (FONTE/'manifesto.json').write_text(json.dumps(manifesto,ensure_ascii=False,indent=2)+'\n')

def preparar_interiores():
    # Sala vazia: alimento é uma camada de estado, nunca parte do cenário fixo.
    folha = Image.open(FONTE/'gerados/interior_revisado.png').convert('RGBA')
    base = folha.resize((192,144),Image.Resampling.NEAREST)
    for nivel,(w,h) in enumerate([(192,144),(256,160),(320,192)],1):
        dx,dy=w-192,h-144
        sala=Image.new('RGBA',(w,h))
        for y in range(h):
            sy=y if y<82 else 82+(y-82)%8 if y<82+dy else y-dy
            for x in range(w):
                # Inserção passa pelo vão livre após a janela, nunca pelo comedouro.
                inserido = 100 <= x < 100+dx
                sx=x if x<100 else (50+(x-100)%24 if sy<25 else 70+(x-100)%16) if inserido else x-dx
                amostra_y = 50+(sy-25)%16 if inserido and 25 <= sy < 50 else sy
                # Porta e postes frontais permanecem com sua largura nativa.
                if sy >= 98:
                    esquerda=(w-64)//2
                    if x<64: sx=x
                    elif x<esquerda: sx=32+(x-64)%16
                    elif x<esquerda+64: sx=64+x-esquerda
                    elif x<w-64: sx=144+(x-esquerda-64)%16
                    else: sx=128+x-(w-64)
                    amostra_y=sy
                sala.putpixel((x,y),base.getpixel((sx,amostra_y)))
        # O piso ampliado usa módulos de tábuas completos; a inserção de
        # faixas de oito pixels repetia juntas e criava uma grade no centro.
        if nivel > 1:
            piso=base.crop((40,56,104,88))
            # A iluminação da ilustração não pode repetir uma faixa escura
            # a cada módulo. Iguala as extremidades sem mudar a grade.
            for py in range(piso.height):
                inicio=piso.getpixel((0,py))
                fim=piso.getpixel((piso.width-1,py))
                for px in range(piso.width):
                    cor=piso.getpixel((px,py))
                    piso.putpixel((px,py),tuple(max(0,min(255,round(cor[c]+(inicio[c]-fim[c])*px/(piso.width-1)))) for c in range(3))+(cor[3],))
            fundo=sala.copy()
            for y in range(48,h-46):
                for x in range(10,w-10):
                    sala.putpixel((x,y),piso.getpixel(((x-10)%64,(y-48)%32)))
            # Poleiro e depósito mantêm o recorte e a base física originais.
            sala.paste(fundo.crop((w-52,48,w-12,74)),(w-52,48))
        sala.save(DESTINO/f'interior_vazio_{nivel}.png')
        for estacao,nome in enumerate(ESTACOES):
            material(sala,estacao).save(DESTINO/f'interior_vazio_{nivel}_{nome}.png')

if __name__ == '__main__':
    import sys
    preparar_interiores() if '--somente-interior' in sys.argv else preparar()
