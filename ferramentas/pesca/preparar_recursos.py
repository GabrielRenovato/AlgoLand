#!/usr/bin/env python3
"""Prepara o atlas 16 px da praia, o pescador e ícones originais do Tiny RPG."""
from pathlib import Path
import json
import subprocess
import tempfile
from PIL import Image

RAIZ = Path(__file__).resolve().parents[2]
PACOTE = RAIZ / 'arte/pacotes/_zips_originais/Farm RPG - Tiny Asset Pack - (All in One).rar'
PEIXES = [
    ('sardinha', 'SARDINHA', 'Sea/Sardine.png'),
    ('anchova', 'ANCHOVA', 'Sea/Anchovy.png'),
    ('atum', 'ATUM', 'Sea/Tuna.png'),
    ('salmao', 'SALMAO', 'Sea/Salmon.png'),
    ('linguado', 'LINGUADO', 'Sea/Flounder.png'),
    ('baiacu', 'BAIACU', 'Sea/pufferfish.png'),
    ('carpa', 'CARPA', 'River/Carp.png'),
    ('bagre', 'BAGRE', 'River/Bullhead Catfish.png'),
    ('perca', 'PERCA', 'River/Perch.png'),
    ('dourado', 'DOURADO', 'River/Dorado.png'),
    ('truta', 'TRUTA TIGRE', 'River/Tiger Trout.png'),
    ('esturjao', 'ESTURJAO', 'River/Sturgeon.png'),
]


def preparar_tiles():
    original = Image.open(RAIZ / 'arte/fontes/praia/atlas_original.png').convert('RGB')
    atlas = Image.new('RGB', (128, 96))
    for y in range(2):
        for x in range(4):
            caixa = (round(x * original.width / 4), round(y * original.height / 2),
                     round((x + 1) * original.width / 4), round((y + 1) * original.height / 2))
            tile = original.crop(caixa).resize((32, 32), Image.Resampling.BOX)
            tile = tile.quantize(colors=12).convert('RGB')
            atlas.paste(tile, (x * 32, y * 32))
    # Faixa gradual entre água rasa e funda, sem uma linha de corte na cor.
    rasa = atlas.crop((64, 0, 96, 32))
    funda = atlas.crop((96, 0, 128, 32))
    for y in range(32):
        for x in range(32):
            t = y / 31
            atlas.putpixel((x, 64 + y), tuple(round(a * (1 - t) + b * t)
                for a, b in zip(rasa.getpixel((x, y)), funda.getpixel((x, y)))))
    atlas.save(RAIZ / 'assets/cenario/praia/atlas.png')


def preparar_peixes():
    caminho_catalogo = RAIZ / 'assets/pesca/catalogo.json'
    catalogo = json.loads(caminho_catalogo.read_text()) if caminho_catalogo.exists() else {'peixes': {}}
    catalogo['fonte'] = 'Farm RPG - Tiny Asset Pack - (All in One)'
    with tempfile.TemporaryDirectory(prefix='algoland-peixes-') as tmp:
        subprocess.run(['unrar', 'x', '-idq', str(PACOTE), '*/Icons/Fish/*',
                        '*/Icons/RPG icons/Weapons and Armor/1. Wood/Fishing Rod.png', tmp + '/'], check=True)
        base = Path(tmp) / catalogo['fonte'] / 'Icons'
        for id_peixe, nome, caminho in PEIXES:
            destino = f'assets/pesca/peixes/{id_peixe}.png'
            imagem = Image.open(base / 'Fish' / caminho)
            # As folhas Tiny incluem contorno, máscara e variantes: só o ícone colorido 16x16.
            imagem.crop((0, 0, 16, 16)).save(RAIZ / destino)
            catalogo['peixes'][id_peixe] = {'nome': nome, 'icone': 'res://' + destino,
                'ambiente': 'mar' if caminho.startswith('Sea/') else 'rio', 'original': 'Icons/Fish/' + caminho,
                'recorte': [0, 0, 16, 16]}
        for id_item, caminho in [('vara', 'RPG icons/Weapons and Armor/1. Wood/Fishing Rod.png'), ('isca', 'Fish/Worm bait.png')]:
            Image.open(base / caminho).crop((0, 0, 16, 16)).save(RAIZ / f'assets/pesca/{id_item}.png')
    (RAIZ / 'assets/pesca/catalogo.json').write_text(json.dumps(catalogo, ensure_ascii=False, indent=2) + '\n')


def preparar_nilo():
    caminho = RAIZ / 'arte/fontes/npcs/nilo/rotacoes_original.png'
    if not caminho.exists():
        raise FileNotFoundError('Falta a folha original de Nilo: ' + str(caminho))
    original = Image.open(caminho).convert('RGBA')
    folha = Image.new('RGBA', (256, 64))
    for coluna in range(4):
        imagem = original.crop((round(coluna * original.width / 4), 0,
                               round((coluna + 1) * original.width / 4), original.height))
        caixa = imagem.getchannel('A').point(lambda a: 255 if a > 100 else 0).getbbox()
        if caixa is None:
            raise ValueError('Rotação vazia: ' + str(coluna))
        imagem = imagem.crop(caixa)
        imagem = imagem.resize((round(imagem.width * 31 / imagem.height), 31), Image.Resampling.NEAREST)
        folha.paste(imagem, (coluna * 64 + (64 - imagem.width) // 2, 15))
    folha.save(RAIZ / 'assets/npcs/cidade/nilo.png')


def preparar_adornos():
    original = Image.open(RAIZ / 'arte/fontes/praia/adornos_original.png').convert('RGBA')
    # A geração deixou as bases dos coqueiros abaixo da metade: preservar as raízes.
    recortes = [
        ('coqueiro_a', (0, 0, 512, 590), 88),
        ('coqueiro_b', (512, 0, 1024, 590), 84),
        ('pedras', (1024, 0, 1536, 590), 24),
        ('conchas', (0, 600, 512, 1024), 13),
        ('madeira', (512, 600, 1024, 1024), 15),
        ('capim', (1024, 600, 1536, 1024), 20),
    ]
    destino = RAIZ / 'assets/cenario/praia/adornos'
    destino.mkdir(parents=True, exist_ok=True)
    for nome, caixa, altura in recortes:
        imagem = original.crop(caixa)
        usado = imagem.getchannel('A').point(lambda a: 255 if a > 30 else 0).getbbox()
        if usado is None:
            raise ValueError('Adorno vazio: ' + nome)
        imagem = imagem.crop(usado)
        imagem = imagem.resize((round(imagem.width * altura / imagem.height), altura), Image.Resampling.NEAREST)
        imagem.save(destino / (nome + '.png'))


def preparar_casa_e_caminhada():
    for tipo, tamanho in [('exterior', (160, 160)), ('interior', (320, 224))]:
        imagem = Image.open(RAIZ / f'arte/fontes/praia/palafita_{tipo}_original.png').convert('RGBA')
        imagem.resize(tamanho, Image.Resampling.NEAREST).save(RAIZ / f'assets/cenario/praia/palafita/{tipo}.png')
    original = Image.open(RAIZ / 'arte/fontes/npcs/nilo/andar_original.png').convert('RGBA')
    folha = Image.new('RGBA', (384, 256))
    xs = [0, 320, 555, 790, 1025, 1265, 1536]
    ys = [0, 270, 525, 775, 1024]
    for linha in range(4):
        for coluna in range(6):
            imagem = original.crop((xs[coluna], ys[linha], xs[coluna + 1], ys[linha + 1]))
            usado = imagem.getchannel('A').point(lambda a: 255 if a > 100 else 0).getbbox()
            if usado is None:
                raise ValueError(f'Quadro vazio do Nilo: {linha}/{coluna}')
            imagem = imagem.crop(usado)
            imagem = imagem.resize((round(imagem.width * 31 / imagem.height), 31), Image.Resampling.NEAREST)
            folha.paste(imagem, (coluna * 64 + (64 - imagem.width) // 2, linha * 64 + 15))
    folha.save(RAIZ / 'assets/npcs/cidade/nilo_andar.png')


def preparar_refinamento():
    imagem = Image.open(RAIZ / 'arte/fontes/praia/casa_cais_original.png').convert('RGBA')
    imagem = imagem.crop(imagem.getchannel('A').point(lambda a: 255 if a > 50 else 0).getbbox())
    imagem.thumbnail((144, 136), Image.Resampling.NEAREST)
    casa = Image.new('RGBA', (160, 160))
    casa.paste(imagem, ((160 - imagem.width) // 2, 8))
    casa.save(RAIZ / 'assets/cenario/praia/palafita/exterior.png')
    original = Image.open(RAIZ / 'arte/fontes/npcs/nilo/folha_refinada_original.png').convert('RGBA')
    parado = Image.new('RGBA', (256, 64))
    andar = Image.new('RGBA', (384, 256))
    for linha in range(4):
        for coluna in range(7):
            quadro = original.crop((round(coluna * original.width / 7), round(linha * original.height / 4),
                                    round((coluna + 1) * original.width / 7), round((linha + 1) * original.height / 4)))
            caixa = quadro.getchannel('A').point(lambda a: 255 if a > 100 else 0).getbbox()
            if caixa is None:
                raise ValueError(f'Quadro refinado vazio: {linha}/{coluna}')
            quadro = quadro.crop(caixa)
            quadro = quadro.resize((round(quadro.width * 31 / quadro.height), 31), Image.Resampling.NEAREST)
            quadro.putalpha(quadro.getchannel('A').point(lambda a: 255 if a >= 128 else 0))
            if coluna == 0:
                parado.paste(quadro, (linha * 64 + (64 - quadro.width) // 2, 15))
            else:
                andar.paste(quadro, ((coluna - 1) * 64 + (64 - quadro.width) // 2, linha * 64 + 15))
    parado.save(RAIZ / 'assets/npcs/cidade/nilo.png')
    andar.save(RAIZ / 'assets/npcs/cidade/nilo_andar.png')


if __name__ == '__main__':
    preparar_tiles()
    preparar_peixes()
    preparar_nilo()
    preparar_adornos()
    preparar_casa_e_caminhada()
    preparar_refinamento()
    print('Praia: atlas 128x96, 12 peixes originais, vara, isca e 4 direções do Nilo.')
