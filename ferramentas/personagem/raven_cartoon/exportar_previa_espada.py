#!/usr/bin/env python3
"""Confere capturas reais e exporta o GIF; não desenha nem altera os sprites."""
from pathlib import Path
from collections import Counter
import json
import math
from PIL import Image, ImageSequence

RAIZ = Path(__file__).resolve().parents[3]
PREVIA = RAIZ/'arte/previas/personagens/raven_cartoon/ataques_quatro_direcoes_com_espada'


def exportar():
    dados = json.loads((RAIZ/'assets/personagens/raven_cartoon/pegadas_espada_base.json').read_text())
    espada = Image.open(RAIZ/'assets/personagens/raven_cartoon/espada_base_cartoon.png').convert('RGBA')
    limites = espada.getchannel('A').point(lambda v: 255 if v > 128 else 0).getbbox()
    frames = [Image.open(PREVIA/'motor'/f'quadro_{i:02d}.png').convert('RGB') for i in range(1, 5)]
    assert all(im.size == (1280, 1280) for im in frames), 'Captura cortada pelo gerenciador de janelas.'
    evidencias = []
    for q, im in enumerate(frames):
        for i, direcao in enumerate(['baixo', 'direita', 'cima', 'esquerda']):
            x, y = (i % 2)*640, (i//2)*640
            brancos = Counter(im.crop((x+8, y+64, x+632, y+632)).get_flattened_data())[(245, 250, 247)]
            assert (brancos > 8000) if q in (1, 2) else (brancos == 0), (direcao, q, 'fase do rastro', brancos)
            fonte = 'direita' if direcao == 'esquerda' else direcao
            pegada = dados['direcoes'][fonte][q]
            raiz = (i % 2)*640+320, (i//2)*640+600
            pivo_corpo = (280 if fonte == 'direita' else 320, 850)
            sinal = -1 if direcao == 'esquerda' else 1
            angulo = math.radians(pegada['angulo_graus'])

            def tela(ponto):
                x = (ponto[0]-dados['pivo'][0])*dados['escala']*dados.get('largura_relativa', 1.0)
                y = (ponto[1]-dados['pivo'][1])*dados['escala']
                xr = x*math.cos(angulo)-y*math.sin(angulo)
                yr = x*math.sin(angulo)+y*math.cos(angulo)
                return (raiz[0]+sinal*0.6*(pegada['mao'][0]-pivo_corpo[0]+xr),
                        raiz[1]+0.6*(pegada['mao'][1]-pivo_corpo[1]+yr))

            for canto in [(limites[0], limites[1]), (limites[2], limites[1]),
                          (limites[0], limites[3]), (limites[2], limites[3])]:
                x, y = tela(canto)
                assert (i % 2)*640+8 <= x < (i % 2+1)*640-8, (direcao, q, 'corte lateral', x)
                assert (i//2)*640+64 <= y < (i//2+1)*640-8, (direcao, q, 'corte/título', y)
            # Amostra dentro da lâmina, longe da mão. Diferencia aço do fundo e da pele.
            x, y = map(round, tela((474, 400)))
            cor = im.getpixel((x, y))
            assert min(cor) > 120 and cor[2]+3 >= max(cor[0], cor[1]), (direcao, q, 'lâmina oculta', cor)
            evidencias.append({'direcao': direcao, 'quadro': q+1, 'amostra_lamina': [x, y], 'cor': cor})
    # Pontos de cruzamento real da lâmina com o arco no segundo quadro.
    for ponto in [(564, 502), (96, 887)]:
        assert frames[1].getpixel(ponto) == (245, 250, 247), ('espada à frente do rastro', ponto)
    arquivo = PREVIA/'ataques_com_espada_e_rastro_v2.gif'
    frames[0].save(arquivo, save_all=True, append_images=frames[1:], duration=dados['tempos_ms'], loop=0, disposal=2)
    with Image.open(arquivo) as gif:
        assert sum(q.info['duration'] for q in ImageSequence.Iterator(gif)) == 490
        assert gif.info['loop'] == 0
    (PREVIA/'revisao_visual.json').write_text(json.dumps({'capturas': 4, 'direcoes': 4,
        'margens_arma_conferidas': True, 'amostras_lamina_visivel': evidencias,
        'dimensao': [1280, 1280], 'tempos_ms': dados['tempos_ms']}, ensure_ascii=False, indent=2)+'\n')
    print('16 amostras da lâmina visível; rastro nas fases 2/3; margens conferidas em16 poses; GIF490ms.')


if __name__ == '__main__':
    exportar()
