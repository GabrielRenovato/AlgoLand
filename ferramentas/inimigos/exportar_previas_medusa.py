"""Monta GIFs de capturas renderizadas pelo Godot; não altera os sprites do jogo."""
from pathlib import Path
import json
import sys
from PIL import Image

RAIZ = Path(__file__).resolve().parents[2] / 'arte/previas/inimigos/medusa'


def exportar(pasta, nome, largura=960, duracoes=None, recorte=None):
    quadros = []
    for caminho in sorted(pasta.glob('quadro_*.png')):
        quadro = Image.open(caminho).convert('RGB')
        if recorte is not None:
            quadro = quadro.crop(recorte)
        if quadro.width > largura:
            quadro = quadro.resize((largura, round(quadro.height * largura / quadro.width)), Image.Resampling.NEAREST)
        quadros.append(quadro)
    if not quadros:
        raise RuntimeError(f'Sem capturas: {pasta}')
    # Amostra a carga, o impacto e o cascalho para conservar as cores do especial.
    amostra = Image.new('RGB', (quadros[0].width, quadros[0].height * 4))
    for i, indice in enumerate([0, len(quadros)//3, len(quadros)*2//3, len(quadros)-1]):
        amostra.paste(quadros[indice], (0, i * quadros[0].height))
    paleta = amostra.quantize(colors=256, method=Image.Quantize.MEDIANCUT)
    animacao = [quadro.quantize(palette=paleta, dither=Image.Dither.NONE) for quadro in quadros]
    if duracoes is not None and len(duracoes) != len(animacao):
        raise ValueError('A duração deve corresponder a cada quadro renderizado.')
    animacao[0].save(pasta / nome, save_all=True, append_images=animacao[1:], duration=duracoes if duracoes is not None else 50, loop=0, disposal=1, optimize=False)
    print(f'{nome}: {len(animacao)} quadros')


if __name__ == '__main__':
    if '--poses-pixellab' in sys.argv:
        for direcao in ('baixo', 'cima', 'direita', 'esquerda'):
            pasta = RAIZ / 'pixellab' / direcao
            quantidade = len(list(pasta.glob('quadro_*.png')))
            # GIF usa centésimos: esta sequência conserva os 60 Hz no total.
            duracoes = [round((i + 1) * 100 / 60) * 10 - round(i * 100 / 60) * 10 for i in range(quantidade)]
            exportar(pasta, 'garras.gif', largura=500, duracoes=duracoes, recorte=(350, 150, 850, 500))
    elif '--combate' in sys.argv or '--fluidez' in sys.argv:
        registros = json.loads((RAIZ / 'combate/tempos.json').read_text())
        for fase in (1, 2, 3):
            tempos = [r['tempo_ms'] for r in registros if r['fase'] == fase]
            duracoes = [max(20, round((b - a) / 10) * 10) for a, b in zip(tempos, tempos[1:])]
            duracoes.append(duracoes[-1])
            exportar(RAIZ / f'combate/fase_{fase}', 'combo.gif', largura=1152, duracoes=duracoes)
            if '--fluidez' in sys.argv and fase == 3:
                exportar(RAIZ / 'combate/fase_3', 'fluidez.gif', largura=640, duracoes=duracoes, recorte=(350, 180, 850, 480))
    else:
        exportar(RAIZ, 'animacoes_medusa.gif')
        revisao = RAIZ / 'revisao_arte'
        exportar(revisao if revisao.exists() else RAIZ / 'ruina', 'ruina.gif', largura=1152)
