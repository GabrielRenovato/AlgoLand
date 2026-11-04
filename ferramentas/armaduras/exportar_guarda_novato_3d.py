#!/usr/bin/env python3
"""Monta diagnósticos a partir dos quadros reais do Godot, sem editar os recursos."""
from pathlib import Path
import argparse
import shutil
from PIL import Image, ImageDraw


def exportar(origem: Path, destino: Path):
    destino.mkdir(parents=True, exist_ok=True)
    quadros = list(origem.glob('*.png'))
    imagens = [Image.open(p).convert('RGBA') for p in quadros]
    caixas = [im.getbbox() for im in imagens if im.getbbox()]
    caixa = (min(b[0] for b in caixas)-3, min(b[1] for b in caixas)-3,
             max(b[2] for b in caixas)+3, max(b[3] for b in caixas)+3)
    escala = 5
    largura, altura = (caixa[2]-caixa[0])*escala, (caixa[3]-caixa[1])*escala

    def figura(nome):
        return Image.open(origem/nome).convert('RGBA').crop(caixa).resize(
            (largura, altura), Image.Resampling.NEAREST)

    def painel(nomes, colunas, titulos=None):
        linhas = (len(nomes)+colunas-1)//colunas
        painel = Image.new('RGB', (largura*colunas, (altura+30)*linhas), '#263c3b')
        desenho = ImageDraw.Draw(painel)
        for i, nome in enumerate(nomes):
            x, y = i % colunas*largura, i//colunas*(altura+30)
            im = figura(nome)
            painel.paste(im, (x, y+30), im)
            desenho.text((x+12, y+9), titulos[i] if titulos else nome[:-4], fill='white')
        return painel

    painel([f'parado_{d}.png' for d in [0, 2, 1, 3]], 4,
           ['FRENTE', 'COSTAS', 'DIREITA', 'ESQUERDA']).save(destino/'quatro_vistas.png')
    painel([f'andar_{d}_{q:02d}.png' for d in range(4) for q in range(8)], 8).save(destino/'caminhada_quadros.png')
    painel([f'pecas_{b:02d}.png' for b in [0, 1, 2, 4, 8, 15]], 6,
           ['CORPO E ROUPA', 'ELMO', 'PEITORAL', 'MANOPLAS', 'GREVAS', 'COMPLETO']).save(destino/'pecas_independentes.png')
    animados = []
    for q in range(8):
        tela = Image.new('RGB', (largura*4, altura), '#263c3b')
        for i, d in enumerate([0, 2, 1, 3]):
            im = figura(f'andar_{d}_{q:02d}.png')
            tela.paste(im, (i*largura, 0), im)
        animados.append(tela)
    animados[0].save(destino/'caminhada.gif', save_all=True, append_images=animados[1:],
                     duration=[170, 160, 170, 170, 160, 170, 170, 160], loop=0)
    nativos = destino/'quadros_nativos'
    nativos.mkdir(exist_ok=True)
    for p in quadros:
        shutil.copy2(p, nativos/p.name)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('origem', type=Path)
    parser.add_argument('--destino', type=Path, default=Path('arte/previas/armaduras/guarda_novato_3d'))
    args = parser.parse_args()
    exportar(args.origem, args.destino)
