#!/usr/bin/env python3
"""Importa as 32 poses nativas de pesca Mana Seed em grade compatível com o jogador."""
from pathlib import Path
import json
from PIL import Image

RAIZ = Path(__file__).resolve().parents[2]
PACOTES = RAIZ / 'arte/pacotes/Jogador'
DESTINO = RAIZ / 'assets/personagens/Pesca'
POSES = [[0,1,2,3,4,5,6,7], [24,25,26,27,28,29,30,31],
         [32,33,34,36,42,44,46,47], [48,49,51,53,59,61,62,63]]
manifesto = {'referencia': 'Mana Seed Character Base, página 3', 'grade': [8,8],
             'quadro': [64,64], 'pivo': [32,32], 'direcoes': ['baixo','cima','direita','esquerda'],
             'poses_originais': POSES, 'arquivos': {}}

def importar(origem, destino, vara=False):
    imagem = Image.open(origem).convert('RGBA')
    folha = Image.new('RGBA', (512,512))
    for linha, poses in enumerate(POSES):
        for coluna, pose in enumerate(poses):
            x,y = pose % 8 * 64, pose // 8 * 64
            quadro = imagem.crop((x,y,x+64,y+64))
            if vara:
                # A linha e a boia acompanham a água no jogo, sem recortar seus trechos longos do atlas.
                cores_vara = {(173,75,33), (97,39,22), (198,117,69), (24,24,24)}
                quadro.putdata([c if c[:3] in cores_vara else (0,0,0,0) for c in quadro.get_flattened_data()])
            folha.paste(quadro,(coluna*64,linha*64))
    destino = DESTINO / destino
    destino.parent.mkdir(parents=True, exist_ok=True)
    folha.save(destino)
    manifesto['arquivos'][str(destino.relative_to(RAIZ))] = str(origem.relative_to(RAIZ))

base = PACOTES / 'Base/20.01a - Character Base 2.5c/char_a_p3'
importar(base / 'char_a_p3_0bas_humn_v00.png','corpo.png')
importar(base / '6tla/char_a_p3_6tla_roda_v01.png','vara.png', True)
for f in sorted(PACOTES.rglob('char_a_p3_4har_*_v00.png')):
    importar(f, 'cabelos/' + f.stem.split('_4har_')[1].removesuffix('_v00') + '.png')
for f in sorted(PACOTES.rglob('char_a_p3_1out_*.png')):
    importar(f, 'roupas/' + f.stem.split('_1out_')[1] + '.png')
for tamanho, modelo in [('capal','lnpl'),('capam','mnpl')]:
    for f in sorted(PACOTES.rglob(f'char_a_p3_2clo_{modelo}_*.png')):
        cor = f.stem.rsplit('_',1)[1]
        importar(f, f'roupas/{tamanho}_{cor}.png')
        destino = DESTINO / f'roupas/{tamanho}_{cor}.png'
        capa = Image.open(destino).convert('RGBA')
        cueca = Image.open(DESTINO / 'roupas/boxr_v01.png').convert('RGBA')
        cueca.alpha_composite(capa)
        cueca.save(destino)
(DESTINO / 'manifesto.json').write_text(json.dumps(manifesto, ensure_ascii=False, indent=2)+'\n')
print(f"Importadas {len(manifesto['arquivos'])} folhas de pesca.")
