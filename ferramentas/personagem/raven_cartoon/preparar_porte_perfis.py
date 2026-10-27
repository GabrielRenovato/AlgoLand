#!/usr/bin/env python3
"""Extrai cabo e lâmina dos seis quadros REAIS da corrida Mana Seed, página 1."""
from pathlib import Path
import json
import math
from PIL import Image
RAIZ = Path(__file__).resolve().parents[3]
BASE = Path('arte/pacotes/Jogador/Base/20.01a - Character Base 2.5c/char_a_p1/char_a_p1_0bas_humn_v01.png')
ESPADA = Path('arte/pacotes/Jogador/Combate/21.07b - Sword & Shield Combat 2.3a/optional files (unsupported)/char_a_p1/6tla/char_a_p1_6tla_sw01_v01.png')
COLUNAS = [0, 1, 6, 3, 4, 7]
DURACOES = [100, 60, 140, 100, 60, 140]

def extrair(im, coluna, linha):
    celula = im.crop((coluna*64,linha*64,(coluna+1)*64,(linha+1)*64))
    couro, metal = [], []
    for y in range(64):
        for x in range(64):
            r,g,b,a = celula.getpixel((x,y))
            if a < 128: continue
            if r > g*1.15 and g > b*1.1:
                couro.append((x+.5,y+.5))
            elif min(r,g,b) > 120:
                metal.append((x+.5,y+.5))
    assert couro and metal
    cabo = [sum(p[i] for p in couro)/len(couro) for i in [0,1]]
    ponta = max(metal,key=lambda p:sum((p[i]-cabo[i])**2 for i in [0,1]))
    return {'posicao':[round((cabo[0]-32)*1.1,4),round((cabo[1]-44)*1.1,4)],
            'angulo':round(math.atan2(ponta[1]-cabo[1],ponta[0]-cabo[0])+math.pi/2,7),
            'camada':-1,'coluna':coluna,'linha':linha,'cabo_fonte':cabo,'ponta_fonte':ponta}

def preparar():
    espada=Image.open(RAIZ/ESPADA).convert('RGBA')
    dados={'referencia_corpo':str(BASE),'referencia_espada':str(ESPADA),
           'duracoes_ms':DURACOES,'proporcao_corpo':1.1,'direcoes':{}}
    for lado,linha in [('direita',6),('esquerda',7)]:
        dados['direcoes'][lado]={'parado':[extrair(espada,0,linha-4)],
             'correr':[extrair(espada,c,linha) for c in COLUNAS]}
    (RAIZ/'assets/personagens/raven_cartoon/porte_perfis_mana_seed.json').write_text(json.dumps(dados,ensure_ascii=False,indent=2)+'\n')
    print('Porte: seis quadros reais por perfil; sem trilhas antigas de caminhada.')
if __name__ == '__main__': preparar()
