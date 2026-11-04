#!/usr/bin/env python3
"""Prévias diagnósticas dos quadros reais do Godot; preserva pivôs e tempos dos FBX."""
from pathlib import Path
import argparse
import json
import shutil
from PIL import Image, ImageDraw


def exportar(origem: Path, destino: Path):
    destino.mkdir(parents=True, exist_ok=True)
    tempos = json.loads((origem/'tempos.json').read_text())
    nomes = list(origem.glob('*.png'))
    caixas = [Image.open(p).getbbox() for p in nomes]
    caixas = [b for b in caixas if b]
    caixa = (min(b[0] for b in caixas)-3, min(b[1] for b in caixas)-3,
             max(b[2] for b in caixas)+3, max(b[3] for b in caixas)+3)
    w, h = (caixa[2]-caixa[0])*4, (caixa[3]-caixa[1])*4

    def figura(nome):
        return Image.open(origem/nome).convert('RGBA').crop(caixa).resize((w, h), Image.Resampling.NEAREST)

    for acao, clipe in [('andar', 'Caminhada_Feminina'), ('parado', 'Descanso_Feminino'), ('conversa', 'Conversa_Feminina')]:
        contato = Image.new('RGB', (w*12, h*4), '#263c3b')
        frames = []
        for q in range(12):
            tela = Image.new('RGB', (w*4, h), '#263c3b')
            for i, d in enumerate([0, 2, 1, 3]):
                im = figura(f'feminino_{acao}_{d}_{q:02d}.png')
                tela.paste(im, (i*w, 0), im)
                contato.paste(im, (q*w, i*h), im)
            frames.append(tela)
        duracao = tempos[clipe]*100
        duracoes = [(round((q+1)*duracao/12)-round(q*duracao/12))*10 for q in range(12)]
        frames[0].save(destino/f'{acao}.gif', save_all=True, append_images=frames[1:], duration=duracoes, loop=0)
        contato.save(destino/f'{acao}_quadros.png')
    ids = ['dara', 'lia', 'rosa', 'estela', 'mara', 'cora', 'yuna', 'elia']
    galeria = Image.new('RGB', (w*8, h+30), '#263c3b')
    draw = ImageDraw.Draw(galeria)
    for i, id in enumerate(ids):
        im = figura(f'elenco_{id}_0_00.png')
        galeria.paste(im, (i*w, 30), im)
        draw.text((i*w+10, 10), id.capitalize(), fill='white')
    galeria.save(destino/'moradoras.png')
    nativos = destino/'quadros_nativos'
    nativos.mkdir(exist_ok=True)
    for p in nomes:
        shutil.copy2(p, nativos/p.name)
    shutil.copy2(origem/'tempos.json', destino/'tempos.json')


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('origem', type=Path)
    p.add_argument('--destino', type=Path, default=Path('arte/previas/npcs/movimentos_femininos'))
    a = p.parse_args()
    exportar(a.origem, a.destino)
