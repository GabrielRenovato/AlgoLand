#!/usr/bin/env python3
"""Coloca o modelo canônico na grade do jogo, sem redesenhar a imagem."""
from pathlib import Path
from PIL import Image, ImageOps

RAIZ = Path(__file__).resolve().parents[3]


def preparar():
    atlas = Image.new('RGBA', (2560, 896))
    dados = [('frente', 'baixo', 'frente', 205), ('costas', 'cima', 'costas', 218),
             ('direita', 'direita', 'perfil', 200)]
    quadros = []
    for nome, pasta, modelo, raiz_x in dados:
        im = Image.open(RAIZ/f'arte/fontes/personagens/raven_cartoon/ataque_{pasta}/referencia_{modelo}.png').convert('RGBA')
        quadro = Image.new('RGBA', (640, 896))
        quadro.alpha_composite(im, (320-raiz_x, 60))
        quadros.append((nome, quadro))
    quadros.append(('esquerda', ImageOps.mirror(quadros[2][1])))
    recursos = ['[gd_resource type="SpriteFrames" load_steps=6 format=3]',
                '[ext_resource type="Texture2D" path="res://assets/personagens/raven_cartoon/parado_quatro_direcoes.png" id="1"]']
    animacoes = []
    for i, (nome, im) in enumerate(quadros):
        atlas.alpha_composite(im, (640*i, 0))
        recursos.append(f'[sub_resource type="AtlasTexture" id="q{i}"]\natlas = ExtResource("1")\nregion = Rect2({640*i}, 0, 640, 896)\nfilter_clip = true')
        animacoes.append(f'{{"frames": [{{"duration": 1.0, "texture": SubResource("q{i}")}}], "loop": true, "name": &"parado_{nome}", "speed": 1.0}}')
    recursos.append('[resource]\nanimations = ['+',\n'.join(animacoes)+']')
    destino = RAIZ/'assets/personagens/raven_cartoon'
    atlas.save(destino/'parado_quatro_direcoes.png')
    (destino/'parado_quatro_direcoes.tres').write_text('\n\n'.join(recursos)+'\n')
    print('Repouso: quatro vistas do canônico, pivô320/850, escala original preservada.')


if __name__ == '__main__':
    preparar()
