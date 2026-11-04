"""Lê as peças pintadas e registra juntas; não pinta nem altera imagens."""
from pathlib import Path
import json
from PIL import Image

RAIZ = Path(__file__).resolve().parents[2]
PASTA = RAIZ / 'arte/fontes/inimigos/goblins_moinho/lanceiro/rig_2d'
NOMES = ['corpo', 'braco_d', 'antebraco_d', 'mao_d', 'braco_e', 'antebraco_e', 'mao_e', 'coxa_d', 'canela_d', 'bota_d', 'coxa_e', 'canela_e', 'bota_e', 'lanca', 'sola_d', 'sola_e']


def registrar(nome):
    im = Image.open(PASTA / f'pecas_{nome}.png').convert('RGBA')
    w, h = im.size
    rgba = im.load()
    mascara = bytearray(a > 220 for a in im.getchannel('A').tobytes())
    partes = []
    for indice in range(w * h):
        if not mascara[indice]:
            continue
        mascara[indice] = 0
        fila = [indice]
        pontos = []
        while fila:
            k = fila.pop()
            y, x = divmod(k, w)
            pontos.append((x, y))
            for v in (k - 1 if x else -1, k + 1 if x + 1 < w else -1, k - w if y else -1, k + w if y + 1 < h else -1):
                if v >= 0 and mascara[v]:
                    mascara[v] = 0
                    fila.append(v)
        if len(pontos) > 500:
            partes.append(pontos)
    partes = sorted(partes, key=len, reverse=True)[:16]
    partes.sort(key=lambda p: (int(sum(y for _, y in p) / len(p) / (h / 4)), sum(x for x, _ in p) / len(p)))
    if len(partes) != 16:
        raise ValueError(f'{nome}: {len(partes)} peças; precisa de revisão do arranjo')
    fichas = {}
    for chave, pontos in zip(NOMES, partes):
        x0, y0 = min(x for x, _ in pontos), min(y for _, y in pontos)
        x1, y1 = max(x for x, _ in pontos) + 1, max(y for _, y in pontos) + 1
        largura, altura = x1 - x0, y1 - y0
        def junta(f):
            faixa = [(x, y) for x, y in pontos if abs((y - y0) / altura - f) < .035]
            return [sum(x - x0 for x, _ in faixa) / len(faixa), sum(y - y0 for _, y in faixa) / len(faixa)]
        a, b = junta(.10), junta(.90)
        if chave == 'corpo':
            a = [largura * .50, altura * .88]
        elif chave.startswith(('bota', 'sola')):
            a = [largura * (.3 if nome == 'direita' else .7 if nome == 'esquerda' else .5), altura * .18]
            b = [a[0], altura * .92]
            if nome == 'direita' and chave == 'bota_e':
                a[0] = largura * .7
                b[0] = a[0]
        elif chave.startswith('mao'):
            verdes = [(x - x0, y - y0) for x, y in pontos if rgba[x, y][1] > rgba[x, y][0] * 1.05 and rgba[x, y][1] > rgba[x, y][2] * 1.1]
            if verdes:
                b = [sum(x for x, _ in verdes) / len(verdes), sum(y for _, y in verdes) / len(verdes)]
        elif chave == 'lanca':
            a = [largura * .5, altura * .5]
            b = [largura, altura * .5]
        fichas[chave] = {'ret': [x0, y0, largura, altura], 'a': a, 'b': b, 'espelhar': nome == 'direita' and chave == 'bota_e'}
    return {'fonte': f'pecas_{nome}.png', 'pecas': fichas}


if __name__ == '__main__':
    fichas = {n: registrar(n) for n in ['direita', 'baixo', 'cima', 'esquerda'] if (PASTA / f'pecas_{n}.png').exists()}
    (PASTA / 'juntas.json').write_text(json.dumps(fichas, ensure_ascii=False, indent=2) + '\n')
    print('Juntas registradas:', ', '.join(fichas))
