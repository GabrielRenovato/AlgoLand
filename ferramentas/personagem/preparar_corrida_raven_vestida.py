#!/usr/bin/env python3
"""Encaixa as camadas Raven nas seis poses de corrida das quatro direções, sem escala."""
from pathlib import Path
from PIL import Image, ImageDraw
import json

RAIZ = Path(__file__).resolve().parents[2]
BASE = RAIZ/'assets/personagens/raven_fantasy'
FONTES = RAIZ/'arte/fontes/personagens/raven_corrida_estudo/pixellab'
SAIDA = BASE/'estudo_corrida'
SEQUENCIA = [0,0,1,2,2,3]
TINTAS_CUECA = {(34,51,79,255),(49,77,115,255),(72,107,148,255),(107,145,184,255)}
PELES = {(172,88,70,255),(216,115,94,255),(250,148,127,255),(255,186,172,255)}
ESCUROS = {(172,88,70,255),(216,115,94,255),(34,51,79,255),(49,77,115,255)}
PALETAS = {
    'calca_marrom':[(70,51,41,255),(97,72,55,255)],
    'calca_jeans':[(48,56,59,255),(54,83,87,255)],
    'botas':[(70,51,41,255),(97,72,55,255)],
    'luvas':[(70,51,41,255),(97,72,55,255)],
}

def celula(im, indice):
    cols=im.width//80;x,y=(indice%cols)*80,(indice//cols)*80
    return im.crop((x,y,x+80,y+80))

def fonte(nome, direcao=1):
    im=Image.open(BASE/'camadas'/f'{nome}.png').convert('RGBA')
    y=json.loads((BASE/'camadas/acoes.json').read_text()).index('correr')*320+direcao*80
    return [im.crop((i*80,y,i*80+80,y+80)) for i in SEQUENCIA]

def folha(quadros):
    im=Image.new('RGBA',(480,80))
    for i,q in enumerate(quadros):im.alpha_composite(q,(i*80,0))
    return im

def transformar(origem, fase):
    q=origem.copy(); vazio=(0,0,0,0)
    # Apagar os membros antes de repor qualquer um: as regiões se cruzam no quadril.
    for yy in range(33,42):
        for xx in list(range(30,36))+list(range(44,50)):q.putpixel((xx,yy),vazio)
    for yy in range(40,52):
        for xx in range(32,48):q.putpixel((xx,yy),vazio)
    # Duas pernas com escorço oposto, ancoradas no quadril original.
    for a,b,lado in [(33,40,-1),(40,47,1)]:
        fim=48 if lado==fase else 44
        for yy in range(40,fim+1):
            sy=40+round((yy-40)*6/(fim-40))
            dx=lado if yy>=42 else 0
            for xx in range(a,b):
                cor=origem.getpixel((xx,sy))
                if cor[3]:q.putpixel((xx+dx,yy),cor)
    # Braços separados do tronco, preservando as articulações dos ombros.
    for a,b,lado in [(30,36,-1),(44,50,1)]:
        dy=(1 if lado==fase else -3)
        fim=40+dy
        for yy in range(33,fim+1):
            sy=33+round((yy-33)*7/(fim-33))
            for xx in range(a,b):
                cor=origem.getpixel((xx,sy))
                if cor[3]:q.putpixel((xx,yy),cor)
    return q

def expandir_direcoes(lateral):
    """Mesmo remapeamento de articulações para corpo, tecido e equipamento."""
    frente_costas=Image.open(FONTES/'frames_frente_costas.png').convert('RGBA')
    resultado={}
    for nome,perfil in lateral.items():
        direcoes=[]
        for direcao in range(4):
            if direcao==1:
                direcoes.append(perfil)
                continue
            if direcao==3:
                # A base comprada usa exatamente o mesmo espelhamento nos dois perfis.
                direcoes.append(fonte(nome,3) if nome.startswith('cabelo_') else [q.transpose(Image.Transpose.FLIP_LEFT_RIGHT) for q in perfil])
                continue
            if nome.startswith('corpo_'):
                quadros=[celula(frente_costas,(6 if direcao==2 else 0)+i) for i in range(6)]
                mapa={}
                for a,b in zip(fonte('corpo_0',direcao),fonte(nome,direcao)):
                    for ca,cb in zip(a.get_flattened_data(),b.get_flattened_data()):
                        if ca[3]:mapa[ca]=cb
                for q in quadros:q.putdata([mapa.get(c,c) for c in q.get_flattened_data()])
            elif nome in ['capa_atras','capa_fecho']:
                quadros=fonte('capa',direcao)
                # De costas a capa passa à frente do dorso, com as pernas livres.
                if (direcao==0 and nome=='capa_atras') or (direcao==2 and nome=='capa_fecho'):
                    quadros=[Image.new('RGBA',(80,80)) for _ in range(6)]
            elif nome=='vazio':
                quadros=[Image.new('RGBA',(80,80)) for _ in range(6)]
            else:
                quadros=fonte(nome,direcao)
                if not nome.startswith('cabelo_'):
                    for i in [1,4]:quadros[i]=transformar(quadros[i],-1 if i==1 else 1)
            direcoes.append(quadros)
        resultado[nome]=direcoes
    return resultado


def folha_direcoes(direcoes):
    im=Image.new('RGBA',(480,320))
    for d,quadros in enumerate(direcoes):im.alpha_composite(folha(quadros),(0,d*80))
    return im


def preparar():
    SAIDA.mkdir(parents=True,exist_ok=True)
    bruto=Image.open(FONTES/'frames_bracos_v2.png').convert('RGBA')
    corpos=[celula(bruto,i) for i in range(6)]
    camadas={n:fonte(n) for n in ['camisa_azul','camisa_verde','calca_marrom','calca_jeans','botas','luvas','capa']}
    for i,corpo in enumerate(corpos):
        novo=i in [1,4]
        if novo:
            # Descartar somente as partes de calça e equipamento nas poses antigas.
            for nome in ['calca_marrom','calca_jeans']:
                d=ImageDraw.Draw(camadas[nome][i]);d.rectangle((0,41,79,79),fill=(0,0,0,0))
            camadas['botas'][i]=Image.new('RGBA',(80,80))
            camadas['luvas'][i]=Image.new('RGBA',(80,80))
        # Calça/boots seguem os pixels das pernas, com as rampas originais do pacote.
        # Nos quatro quadros existentes, reparar só os vazios; não recolorir seu desenho.
        for y in range(37,49):
            for x in range(30,52):
                cor=corpo.getpixel((x,y))
                if cor not in PELES | TINTAS_CUECA:continue
                cueca=cor in TINTAS_CUECA
                if not (y>=41 or cueca):continue
                for nome in ['calca_marrom','calca_jeans']:
                    calca=camadas[nome][i];bota=camadas['botas'][i]
                    destino=calca if cueca or y<=42 else bota
                    if novo:
                        # Tecido até o joelho, bota da canela até a ponta do pé.
                        destino=calca if cueca or y<=43 else bota
                    if not novo and (calca.getpixel((x,y))[3] or bota.getpixel((x,y))[3]):continue
                    if destino.getpixel((x,y))[3] and not novo:continue
                    rampa=PALETAS[nome if destino is calca else 'botas']
                    destino.putpixel((x,y),rampa[0 if cor in ESCUROS else 1])
        if novo:
            perto=[(37,32),(34,35),(33,32)] if i==1 else [(37,32),(41,35),(44,32)]
            maos=[(33,32),(47,32)] if i==1 else [(44,32),(35,32)]
            # A camisa é a original; o braço próximo passa à frente dela.
            mascara=Image.new('L',(80,80));d=ImageDraw.Draw(mascara)
            d.line(perto,width=4,fill=255)
            for nome in ['camisa_azul','camisa_verde']:
                camisa=camadas[nome][i]
                for y in range(31,40):
                    for x in range(30,51):
                        if not corpo.getpixel((x,y))[3] or mascara.getpixel((x,y)):
                            camisa.putpixel((x,y),(0,0,0,0))
            for mx,my in maos:
                for y in range(my-1,my+3):
                    for x in range(mx-1,mx+2):
                        cor=corpo.getpixel((x,y))
                        if cor in PELES:
                            camadas['luvas'][i].putpixel((x,y),PALETAS['luvas'][0 if cor in ESCUROS else 1])
    # Capa atrás do corpo e dos braços; só o fecho original fica à frente.
    camadas['capa_atras']=[];camadas['capa_fecho']=[]
    for im in camadas.pop('capa'):
        atras=im.copy();fecho=Image.new('RGBA',(80,80))
        fecho.paste(im.crop((35,30,39,33)),(35,30))
        ImageDraw.Draw(atras).rectangle((35,30,38,32),fill=(0,0,0,0))
        camadas['capa_atras'].append(atras);camadas['capa_fecho'].append(fecho)
    # O cabelo mantém integralmente os pixels e a posição do quadro correspondente.
    for cabelo in range(1,29):camadas[f'cabelo_{cabelo}']=fonte(f'cabelo_{cabelo}')
    original=fonte('corpo_0')
    for pele in range(3):
        alvo=fonte(f'corpo_{pele}');mapa={}
        for a,b in zip(original,alvo):
            for ca,cb in zip(a.get_flattened_data(),b.get_flattened_data()):
                if ca[3]:mapa[ca]=cb
        quadros=[]
        for corpo in corpos:
            q=corpo.copy();q.putdata([mapa.get(c,c) for c in corpo.get_flattened_data()]);quadros.append(q)
        camadas[f'corpo_{pele}']=quadros
    camadas['vazio']=[Image.new('RGBA',(80,80)) for _ in range(6)]
    camadas=expandir_direcoes(camadas)
    for nome,direcoes in camadas.items():folha_direcoes(direcoes).save(SAIDA/f'{nome}.png')
    # Exemplos para revisão, feitos com as mesmas camadas que serão reproduzidas no motor.
    exemplos={
        'azul_sem_capa':['corpo_0','calca_marrom','camisa_azul','botas','luvas','cabelo_1'],
        'verde_com_capa':['capa_atras','corpo_1','calca_jeans','camisa_verde','botas','luvas','capa_fecho','cabelo_28'],
    }
    for nome,pecas in exemplos.items():
        direcoes=[]
        for d in range(4):
            quadros=[]
            for i in range(6):
                q=Image.new('RGBA',(80,80))
                for peca in pecas:q.alpha_composite(camadas[peca][d][i])
                quadros.append(q)
            direcoes.append(quadros)
        folha_direcoes(direcoes).save(SAIDA/f'previa_{nome}.png')
    manifesto={'estado':'estudo_quatro_direcoes_rejeitado_nao_integrado','direcoes':['baixo','direita','cima','esquerda'],'fonte_frente_costas':'1224605e-eac7-48ea-96fd-395cd9cbd9f5','celula':[80,80],'pivo':[40,47],'quadros':6,'velocidade_referencia':114,'ciclo_deslocamento_px':32,'duracoes_ms':[32000/114/6]*6,'sequencia_origem':SEQUENCIA,'cabelos':28,'peles':3,'roupas':['camisa_azul','camisa_verde','calca_marrom','calca_jeans','botas','luvas','capa_atras','capa_fecho'],'exemplos':exemplos,'edicao':'Encaixe e recoloração exatos com paletas originais; sem geração de outro personagem e sem escala.'}
    (SAIDA/'manifesto.json').write_text(json.dumps(manifesto,ensure_ascii=False,indent=2)+'\n')
    print(f'{len(camadas)} camadas exportadas para seis poses em cada uma das quatro direções.')

if __name__=='__main__':preparar()
