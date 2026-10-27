#!/usr/bin/env python3
"""Empacota capturas do Godot e confere margens da referência original."""
from pathlib import Path
from collections import Counter
from PIL import Image, ImageSequence

RAIZ = Path(__file__).resolve().parents[3]
PREVIA = RAIZ/'arte/previas/personagens/raven_cartoon/ataques_quatro_direcoes_com_espada'


def exportar(golpe=1):
    previa = RAIZ/'arte/previas/personagens/raven_cartoon/combo_golpe2' if golpe == 2 else PREVIA
    coluna = 4 if golpe == 2 else 0
    for camada in ['corpo', 'espada']:
        atlas = Image.open(RAIZ/f'assets/personagens/raven_cartoon/comparacao_mana_{camada}.png')
        for linha in range(4):
            for q in range(4):
                limites = atlas.crop(((q+coluna)*64, linha*64, (q+coluna+1)*64, (linha+1)*64)).getbbox()
                x0, y0, x1, y1 = limites
                assert 24 <= 270+(x0-32)*8 < 270+(x1-32)*8 <= 520
                assert 110 <= 470+(y0-44)*8 < 470+(y1-44)*8 <= 624
    quadros = [Image.open(previa/'motor/comparacao'/f'quadro_{q:02d}.png').convert('RGB')
               for q in range(1, 5)]
    assert all(im.size == (1920, 1280) for im in quadros)
    for q, im in enumerate(quadros):
        for i in range(4):
            x, y = (i % 2)*960, (i//2)*640
            recorte = im.crop((x+520, y+110, x+950, y+620))
            brancos = Counter(recorte.get_flattened_data())[(245, 250, 247)]
            assert (brancos > 4000) if q in (1, 2) else (brancos == 0), (q, i, brancos)
    destino = previa/('comparacao_mana_seed.gif' if golpe == 2 else 'comparacao_mana_seed_com_rastro_v2.gif')
    quadros[0].save(destino, save_all=True, append_images=quadros[1:],
                    duration=[160, 60, 70, 200], loop=0, disposal=2)
    with Image.open(destino) as gif:
        assert [im.info['duration'] for im in ImageSequence.Iterator(gif)] == [160, 60, 70, 200]
    if golpe == 2:
        for i, direcao in enumerate(['baixo', 'direita', 'cima', 'esquerda']):
            x, y = (i % 2)*960, (i//2)*640
            recortes = [im.crop((x, y, x+960, y+640)) for im in quadros]
            recortes[0].save(previa/f'comparacao_{direcao}.gif', save_all=True, append_images=recortes[1:],
                            duration=[160, 60, 70, 200], loop=0, disposal=2)
    print('Comparação exportada: quatro quadros, 490ms; rastro nas fases 2/3, ausente na preparação e término; margens conferidas.')


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('--golpe', type=int, choices=[1, 2], default=1)
    exportar(parser.parse_args().golpe)
