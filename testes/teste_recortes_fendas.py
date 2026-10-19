#!/usr/bin/env python3
"""Rejeita plantas fatiadas e costuras retas de piso atravessando paredes RPGW."""
import json
import re
import sys
from pathlib import Path
from PIL import Image

RAIZ = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(RAIZ / 'ferramentas/arena'))
from tscn import decodificar_tiles

fonte = RAIZ / 'arte/fontes/fendas'
principal = Image.open(fonte / 'rpgw_caves/MainLev2.0.png').convert('RGBA')
recortes = json.loads((fonte / 'rpgw_caves/recortes.json').read_text())['paredes']
mascaras = [principal.crop((x,y,x+32,y+32)).getchannel('A') if x >= 0 else Image.new('L',(32,32)) for x,y in recortes]
for andar in (3,4,7,9,11):
    texto = (RAIZ / f'cenas/fendas/terreno_{andar:02}.tscn').read_text()
    bloco = texto.split('[node name="'+('Pedreira' if andar==9 else 'Caverna')+'"')[1].split('\n[node')[0]
    celulas = decodificar_tiles(re.search(r'tile_map_data = (.*)', bloco)[1])
    tiles = {(x//2,y//2): ay//2*16+ax//2 for x,y,_,ax,ay,_ in celulas if x%2 == y%2 == 0}
    maior = 0
    for (x,y),indice in tiles.items():
        for dx,dy in ((1,0),(0,1)):
            vizinho = tiles.get((x+dx,y+dy))
            if vizinho is None:
                continue
            sequencia = 0
            for z in range(32):
                a = mascaras[indice].getpixel((31,z) if dx else (z,31)) < 128
                b = mascaras[vizinho].getpixel((0,z) if dx else (z,0)) < 128
                sequencia = sequencia+1 if a != b else 0
                maior = max(maior, sequencia)
                assert sequencia <= 8, f'Andar {andar}: corte reto em ({x},{y}), direção ({dx},{dy})'
    print(f'OK andar {andar}: sem costura longa de piso/parede; maior desencontro {maior}px')

for andar,paleta in ((1,'01'),(2,'02'),(5,'02'),(8,'03')):
    texto = (RAIZ / f'cenas/fendas/terreno_{andar:02}.tscn').read_text()
    recurso = texto.split('[sub_resource type="AtlasTexture" id="Atlas_arbusto_m"]')[1].split('\n[')[0]
    assert 'Rect2(0, 160, 32, 32)' in recurso, f'Andar {andar}: região corta a planta nativa'
    original = Image.open(fonte / f'gentle_forest/gentle 32x32 v{paleta}.png').convert('RGBA').crop((96,0,128,32)).getchannel('A').tobytes()
    grama = Image.open(fonte / f'gentle_forest/gentle forest v{paleta}.png').convert('RGBA')
    # A grama não pode trazer cores da madeira de um objeto vizinho no atlas.
    cores_grama = set(grama.crop((16,80,48,112)).getdata())
    for estacao in ('spring','summer','autumn','winter'):
        folha = Image.open(RAIZ / f'assets/cenario/fendas/andar_{andar:02}/{estacao}.png').convert('RGBA')
        if estacao == 'spring':
            for linha in range(1,6):
                assert set(folha.crop((0,linha*16,16,linha*16+16)).getdata()) <= cores_grama, f'Andar {andar}: fragmento de objeto na grama'
        assert folha.crop((0,160,32,192)).getchannel('A').tobytes() == original, f'Andar {andar}, {estacao}: perdeu parte da planta'
    print(f'OK andar {andar}: silhueta inteira da planta nas quatro estações')

# Nenhum andar pode reintroduzir os atlas ilustrados das tentativas rejeitadas.
for andar in range(1,12):
    texto = (RAIZ / f'cenas/fendas/terreno_{andar:02}.tscn').read_text()
    for caminho in re.findall(r'path="(res://[^"\n]+\.png)"',texto):
        assert not any(trecho in caminho for trecho in ('fendas/decoracao/','fendas/cavernas/','fendas/pedreiras/','materiais/rocha','materiais/solo')), f'Andar {andar}: recurso antigo {caminho}'
print('OK onze andares sem sprites gerados das tentativas antigas')

# Cada objeto RPGW é comparado pixel a pixel com o recorte completo da fonte.
decor = Image.open(fonte / 'rpgw_caves/decorative.png').convert('RGBA')
contrato = json.loads((fonte / 'rpgw_caves/objetos_completos.json').read_text())
atlas = Image.open(RAIZ / 'assets/cenario/fendas/rpgw_caves/objetos.png').convert('RGBA')
for ident,caixa in contrato['recortes'].items():
    i=int(ident);original=decor.crop(caixa);quadro=Image.new('RGBA',(64,64))
    quadro.alpha_composite(original,(32-original.width//2,60-original.height))
    assert atlas.crop((i%4*64,i//4*64,i%4*64+64,i//4*64+64)).tobytes()==quadro.tobytes(), f'Objeto {i}: corte ou alteração do original'
print('OK dezesseis objetos RPGW completos, em escala nativa, sem restos do atlas gerado')
