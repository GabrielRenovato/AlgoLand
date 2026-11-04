#!/usr/bin/env python3
"""Prepara o atlas do cenário aprovado, sem redimensionar a arte de origem."""
from pathlib import Path
from PIL import Image
import json
RAIZ=Path(__file__).resolve().parents[2]
ESTACOES=['primavera','verao','outono','inverno']

def main():
    for estacao in ESTACOES:
        fonte=RAIZ/'arte/fontes/campanha/clareiras_conceito'/f'{estacao}.png'
        imagem=Image.open(fonte).convert('RGB')
        if imagem.size!=(1536,1024):raise ValueError(f'{estacao}: tamanho inesperado {imagem.size}; preservar a grade aprovada')
        pasta=RAIZ/'assets/cenario/campanha/clareiras_conceito'/estacao
        pasta.mkdir(parents=True,exist_ok=True)
        imagem.save(pasta/'terreno.png')
    linhas=['[gd_resource type="TileSet" load_steps=3 format=3]',
        '[ext_resource type="Texture2D" path="res://assets/cenario/campanha/clareiras_conceito/primavera/terreno.png" id="1"]',
        '[sub_resource type="TileSetAtlasSource" id="Atlas"]',
        'resource_name = "CLAREIRAS • COMPOSICAO APROVADA"',
        'texture = ExtResource("1")','texture_region_size = Vector2i(32, 32)']
    linhas += [f'{x}:{y}/0 = 0' for y in range(32) for x in range(48)]
    linhas += ['[resource]','tile_size = Vector2i(32, 32)','sources/0 = SubResource("Atlas")']
    (RAIZ/'assets/cenario/campanha/clareiras_conceito/tileset.tres').write_text('\n'.join(linhas)+'\n')
    manifesto={'referencia' :'arte/conceitos/campanha/clareiras_chegada_v1.png','atlas':[1536,1024],'grade':[48,32],'tile_fonte':[32,32],'tile_mundo':[16,16],'densidade':2,'ampliacao_artificial':False,'estacoes':ESTACOES,'camadas':['piso em TileMapLayer','recortes de copas e arco por profundidade'],'geometria':'codigo/campanha/regioes_iniciais.json','integracao':'codigo/campanha/clareiras_chegada.gd'}
    (RAIZ/'assets/cenario/campanha/clareiras_conceito/tiles.json').write_text(json.dumps(manifesto,ensure_ascii=False,indent=2)+'\n')

if __name__=='__main__':main()
