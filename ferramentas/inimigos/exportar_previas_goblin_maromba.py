"""Monta GIFs de capturas renderizadas pelo Godot; não altera os sprites do jogo."""
from pathlib import Path
from PIL import Image

RAIZ = Path(__file__).resolve().parents[2] / 'arte/previas/inimigos/goblin_maromba'


def exportar(pasta, nome, largura=960, duracao=50):
    quadros = []
    for caminho in sorted(pasta.glob('quadro_*.png')):
        quadro = Image.open(caminho).convert('RGB')
        if quadro.width > largura:
            quadro = quadro.resize((largura, round(quadro.height * largura / quadro.width)), Image.Resampling.NEAREST)
        quadros.append(quadro)
    if not quadros:
        raise RuntimeError(f'Sem capturas: {pasta}')
    # Amostra a carga, o impacto e a recuperação para conservar as cores do especial.
    amostra = Image.new('RGB', (quadros[0].width, quadros[0].height * 4))
    for i, indice in enumerate([0, len(quadros)//3, len(quadros)*2//3, len(quadros)-1]):
        amostra.paste(quadros[indice], (0, i * quadros[0].height))
    paleta = amostra.quantize(colors=256, method=Image.Quantize.MEDIANCUT)
    animacao = [quadro.quantize(palette=paleta, dither=Image.Dither.NONE) for quadro in quadros]
    animacao[0].save(pasta / nome, save_all=True, append_images=animacao[1:], duration=duracao, loop=0, disposal=1, optimize=False)
    print(f'{nome}: {len(animacao)} quadros')


if __name__ == '__main__':
    exportar(RAIZ, 'animacoes_goblin_maromba.gif')
    exportar(RAIZ / 'execucao', 'especial_fatal.gif')
    exportar(RAIZ / 'caminhada', 'caminhada_lateral.gif', duracao=10)
