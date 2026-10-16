#!/usr/bin/env python3
"""Tileset do terreno da vila e utilidades de camada de tiles (as construções agora são imagens do PixelLab)."""
from pathlib import Path
import sys
RAIZ = Path(__file__).resolve().parents[2]
sys.path.insert(0,str(RAIZ/'ferramentas/fazenda'))
import gerar_fazenda as F
RES_TILESET='res://recursos/cidade/tileset_cidade.tres'
RES_CONSTRUCOES='res://recursos/cidade/tileset_construcoes.tres'
RES_FLORESTA='res://assets/cenario/Seasonal Forest/arena/spring.png'
RES_MADEIRA=F.RES_STARTER+'simplified full timber.png'
RES_INTERIOR=F.RES_STARTER+'home interiors, timber roof.png'
MODELOS={'venda':(7,2,0,0,False,False),'sede':(9,2,0,0,False,False),
    'enfermaria':(6,2,0,0,False,False),'pousada':(8,4,0,0,False,False),
    'mistica':(6,2,0,0,False,True),'casa_bento':(6,2,0,0,True,False)}


def recurso_tileset(caminho,folhas,nome):
    t=[f'[gd_resource type="TileSet" load_steps={len(folhas)*2+1} format=3]']
    for i,(folha,largura,altura,rotulo) in enumerate(folhas):
        t += [f'[ext_resource type="Texture2D" path="{folha}" id="{i}"]']
    for i,(_,largura,altura,rotulo) in enumerate(folhas):
        t += [f'[sub_resource type="TileSetAtlasSource" id="Fonte{i}"]',f'resource_name = "{rotulo}"',f'texture = ExtResource("{i}")','texture_region_size = Vector2i(16, 16)']
        t += [f'{x}:{y}/0 = 0' for y in range(altura) for x in range(largura)]
    t += ['[resource]',f'resource_name = "{nome}"','resource_local_to_scene = true','tile_size = Vector2i(16, 16)']
    t += [f'sources/{i} = SubResource("Fonte{i}")' for i in range(len(folhas))]
    (RAIZ/caminho).write_text('\n'.join(t)+'\n')


def gerar_tileset():
    """TileSet do terreno da vila: quatro folhas 4x6 de tiles 16x16 (primavera; cidade.gd troca a textura por estação)"""
    base='res://assets/cenario/cidade/terreno/witchbrook/primavera/'
    grama='res://assets/cenario/cidade/terreno/mana_seed/primavera/'
    recurso_tileset('recursos/cidade/tileset_terreno.tres',[(grama+'grama_terra.png',4,6,'GRAMA E TERRA'),(grama+'grama_pedra.png',4,6,'GRAMA E PEDRA'),(base+'terra_pedra.png',4,6,'TERRA E PEDRA'),(grama+'grama_agua.png',4,6,'GRAMA E AGUA')],'Vila - grama Mana Seed')


def camada(c,nome,celulas,tileset,pai='.',origem=(0,0),lado=16,altura=None,z=-999,**_):
    dados=[]
    for (x,y),peca in sorted(celulas.items(),key=lambda t:(t[0][1],t[0][0])):
        fonte,tx,ty=peca[:3];alt=peca[3] if len(peca)>3 else 0
        dados.append((x,y,fonte,tx,ty,alt))
    c.no(nome,'TileMapLayer',pai,[f'position = {F.vec(*origem)}','texture_filter = 1',f'z_index = {z}',f'tile_map_data = {F.T.codificar_tiles(dados)}',f'tile_set = ExtResource("{tileset}")'])


def telhado(largura):
    pecas={}
    # Mesmos recortes conferidos da casa da fazenda. Amplia-se só o miolo.
    cols=[8,9]+[10]*(largura-5)+[11,12,13]
    for y in range(4):
        for x,tx in enumerate(cols):
            # A abertura solta da folha é coberta por telhas da própria folha.
            pecas[(x,y)]=(0,13 if tx==11 and y<2 else tx,2+y)
    return pecas


def paredes(largura,andares,porta):
    pecas={}
    for y in range(andares):
        for x in range(largura):
            tx=8 if x in [0,largura-1] else 9
            alt=4096 if x==largura-1 else 0
            if x==porta and y>=andares-2:tx=12;alt=0
            pecas[(x,y)]=(0,tx,6+y%2,alt)
    return pecas


def construcao(ident,modelo):
    largura,andares,_,_,anexo,torre=modelo
    c=F.Cena();tiles=c.recurso('TileSet',RES_CONSTRUCOES,'tileset')
    script=c.recurso('Script','res://codigo/cidade/construcao_modular.gd','construcao')
    ox=-(largura//2)*16-8;ext=32 if anexo else 48 if torre else 0
    c.no(ident.capitalize(),'Node2D',raiz=True,props=[f'script = ExtResource("{script}")',f'area_visual = Rect2({ox-(48 if torre else 0)}, {-andares*16-64}, {largura*16+ext}, {andares*16+64})'])
    camada(c,'Paredes',paredes(largura,andares,largura//2),tiles,origem=(ox,-andares*16),z=0)
    camada(c,'Telhado',telhado(largura),tiles,origem=(ox,-andares*16-64),z=2)
    janelas={}
    for x in ([1,largura-3] if largura>=7 else [1]):
        for y in range(2):
            for dx in range(2):janelas[(x+dx,y)]=(1,24+dx,1+y)
    camada(c,'Janelas',janelas,tiles,origem=(ox,-32),z=1)
    if andares>=4:
        camada(c,'JanelasAndar',janelas,tiles,origem=(ox,-64),z=1)
    if anexo:
        camada(c,'AnexoParedes',paredes(2,2,-1),tiles,origem=(ox+largura*16,-32),z=0)
        cobertura={(x,y):(0,8 if x==0 else 13,2+y) for y in range(4) for x in range(2)}
        camada(c,'AnexoTelhado',cobertura,tiles,origem=(ox+largura*16,-96),z=2)
    if torre:
        camada(c,'TorreParedes',paredes(3,4,-1),tiles,origem=(ox-48,-64),z=0)
        cobertura={(x,y):(0,[8,10,13][x],2+y) for y in range(4) for x in range(3)}
        camada(c,'TorreTelhado',cobertura,tiles,origem=(ox-48,-128),z=3)
        camada(c,'TorreJanela',{(1,0):(0,10,6),(1,1):(0,10,7)},tiles,origem=(ox-48,-48),z=1)
    (RAIZ/'recursos/cidade/construcoes'/f'{ident}.tscn').write_text(c.texto())


def main():
    gerar_tileset()
    for ident,modelo in MODELOS.items():construcao(ident,modelo)
    print('Seis construcoes diferentes montadas com Mana Seed original.')

if __name__=='__main__':main()
