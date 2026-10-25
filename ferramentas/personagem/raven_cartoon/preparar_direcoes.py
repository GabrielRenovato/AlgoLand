#!/usr/bin/env python3
"""Empacota costas e perfis; preserva a corrida frontal aprovada."""
from pathlib import Path
from statistics import median
from hashlib import sha256
import json
from PIL import Image, ImageOps, ImageDraw

RAIZ = Path(__file__).resolve().parents[3]
FONTES = RAIZ / 'arte/fontes/personagens/raven_cartoon/corrida_direcoes_4'
PREVIAS = RAIZ / 'arte/previas/personagens/raven_cartoon/corrida_direcoes_4'
ASSETS = RAIZ / 'assets/personagens/raven_cartoon'
CELULA = (512, 896)


def caixa(im):
    return im.getchannel('A').point(lambda v: 255 if v > 128 else 0).getbbox()


def recortar(f):
    im = Image.open(f).convert('RGBA')
    w, h = (im.width + 1) // 2, (im.height + 1) // 2
    return [im.crop(((i % 2)*w, (i // 2)*h, (i % 2+1)*w, (i // 2+1)*h)) for i in range(4)]


def exportar(nome, quadros):
    pasta = PREVIAS / nome
    pasta.mkdir(parents=True, exist_ok=True)
    atlas = Image.new('RGBA', (2048, 896))
    gif = []
    for q, im in enumerate(quadros):
        im.save(pasta / f'quadro_{q+1:02d}.png')
        atlas.alpha_composite(im, (512*q, 0))
        fundo = Image.new('RGBA', CELULA, '#ece7d8')
        fundo.alpha_composite(im)
        gif.append(fundo.resize((384, 672), Image.Resampling.LANCZOS).convert('RGB'))
    atlas.save(ASSETS / f'corrida_{nome}_4.png')
    atlas.save(pasta / 'quatro_quadros_juntos.png')
    gif[0].save(pasta / f'corrida_{nome}.gif', save_all=True, append_images=gif[1:], duration=100, loop=0, disposal=2)


def preparar():
    todos = {}
    for nome, corrigidos in [('costas', [1, 3]), ('direita', [2])]:
        pasta = FONTES / nome
        originais = recortar(pasta / 'folha_gerada_v1.png')
        revisados = recortar(pasta / 'folha_corrigida.png')
        imagens = [revisados[q] if q in corrigidos else originais[q] for q in range(4)]
        fontes = ['folha_corrigida.png' if q in corrigidos else 'folha_gerada_v1.png' for q in range(4)]
        if nome == 'direita':
            for q in [2, 3]:
                fontes[q] = f'quadro_{q+1:02d}_pernas_corrigidas.png'
                im = Image.open(pasta / fontes[q]).convert('RGBA')
                # Geração isolada retorna a mesma célula ampliada 2x; escala uniforme da tela.
                imagens[q] = im.resize(imagens[q].size, Image.Resampling.LANCZOS)
        else:
            fontes[1] = 'quadro_02_pe_corrigido.png'
            im = Image.open(pasta / fontes[1]).convert('RGBA')
            imagens[1] = im.resize(imagens[1].size, Image.Resampling.LANCZOS)
            imagens[3] = ImageOps.mirror(imagens[1])
            fontes[3] = 'quadro_02_pe_corrigido.png (espelhado)'
        # Uma única escala por direção; nenhum quadro é dimensionado por seu contorno.
        escala = 755 / median(caixa(im)[3]-caixa(im)[1] for im in imagens)
        quadros, dados = [], []
        for q, im in enumerate(imagens):
            im = im.resize((round(im.width*escala), round(im.height*escala)), Image.Resampling.LANCZOS)
            bb = caixa(im)
            a = im.getchannel('A')
            centros = []
            for y in range(bb[1]+25, bb[1]+65):
                xs = [x for x in range(im.width) if a.getpixel((x, y)) > 128]
                centros.append((min(xs)+max(xs))/2)
            # No perfil, a cabeça projeta-se à frente do quadril; preservar essa relação.
            alvo_cabeca = 280 if nome == 'direita' else 256
            dx, dy = round(alvo_cabeca-median(centros)), 850-(bb[3]-1)
            final = Image.new('RGBA', CELULA)
            final.alpha_composite(im, (dx, dy))
            limite = caixa(final)
            assert limite[0] > 15 and limite[2] < 497 and limite[1] > 15 and limite[3] == 851, (nome, q, limite)
            quadros.append(final)
            dados.append({'quadro': q+1, 'translacao': [dx, dy], 'limites': limite, 'duracao_ms': 100,
                          'fonte': fontes[q],
                          'sha256_rgba': sha256(final.tobytes()).hexdigest()})
        contrato = json.loads((pasta / 'contrato.json').read_text())
        contrato.update({'escala_unica': escala, 'quadros_exportados': dados,
                         'apoio': 'sola de apoio identificada nos quatro quadros; chão y850',
                         'estado': 'empacotado para revisão no motor'})
        (pasta / 'contrato.json').write_text(json.dumps(contrato, ensure_ascii=False, indent=2)+'\n')
        todos[nome] = quadros
        exportar(nome, quadros)
    todos['esquerda'] = [ImageOps.mirror(im) for im in todos['direita']]
    exportar('esquerda', todos['esquerda'])
    (FONTES / 'esquerda.json').write_text(json.dumps({'origem': 'direita', 'transformacao': 'espelhamento horizontal da célula inteira', 'pivo': [256, 850], 'quadros': 4, 'duracoes_ms': [100]*4}, ensure_ascii=False, indent=2)+'\n')
    frente = RAIZ / 'arte/previas/personagens/raven_cartoon/corrida_frente_4'
    todos = {'frente': [Image.open(frente/f'quadro_{i:02d}.png').convert('RGBA') for i in range(1, 5)], **todos}
    recursos = ['[gd_resource type="SpriteFrames" load_steps=21 format=3]']
    for i, nome in enumerate(todos):
        recursos.append(f'[ext_resource type="Texture2D" path="res://assets/personagens/raven_cartoon/corrida_{nome}_4.png" id="{i}"]')
    for i, nome in enumerate(todos):
        for q in range(4):
            recursos.append(f'[sub_resource type="AtlasTexture" id="{nome}{q}"]\natlas = ExtResource("{i}")\nregion = Rect2({q*512}, 0, 512, 896)\nfilter_clip = true')
    animacoes = []
    for nome in todos:
        frames = ', '.join(f'{{"duration": 1.0, "texture": SubResource("{nome}{q}")}}' for q in range(4))
        animacoes.append(f'{{"frames": [{frames}], "loop": true, "name": &"correr_{nome}", "speed": 10.0}}')
    recursos.append('[resource]\nanimations = ['+',\n'.join(animacoes)+']')
    (ASSETS/'corrida_quatro_direcoes.tres').write_text('\n\n'.join(recursos)+'\n')
    # Comparação sincronizada usa exatamente os PNGs consumidos no Godot.
    comparacao = []
    for q in range(4):
        im = Image.new('RGB', (1024, 480), '#ece7d8')
        for i, (nome, quadros) in enumerate(todos.items()):
            mini = quadros[q].resize((256, 448), Image.Resampling.LANCZOS)
            im.paste(mini, (i*256, 32), mini)
            ImageDraw.Draw(im).text((i*256+128, 15), nome.upper(), fill='#454440', anchor='mm')
        comparacao.append(im)
    comparacao[0].save(PREVIAS/'quatro_direcoes.gif', save_all=True, append_images=comparacao[1:], duration=100, loop=0, disposal=2)
    print('Costas, direita e esquerda: quatro quadros/direção, 10fps; frente preservada.')


if __name__ == '__main__':
    preparar()
