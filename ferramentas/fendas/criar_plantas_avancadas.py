#!/usr/bin/env python3
"""Dez plantas novas (andares 12 a 21): o circuito avançado deixa de repetir os mapas 2 a 11.

Cada planta é determinística (semente por andar), segue o formato de codigo/fendas/plantas/andar_NN.json e cresce em
largura, câmaras e encontros em relação ao andar 11. Depois de rodar, gere as cenas com:
    python3 ferramentas/fendas/gerar_jornada.py --andar N     (N de 12 a 21)
"""
import json
import math
import random
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
PLANTAS = RAIZ / 'codigo/fendas/plantas'

# andar: (nome, bioma, estação 0-3, guardião, rótulo das áreas)
ESPECIFICACOES = {
    12: ('Canions Rubros', 'pedreira', 2, 'minotauro', 'Clareira'),
    13: ('Cataratas Silenciosas', 'caverna_agua', 1, 'medusa', 'Camara'),
    14: ('Cidadela Soterrada', 'ruinas', 3, 'goblin_maromba', 'Clareira'),
    15: ('Veios de Ferro', 'caverna_mina', 0, 'cogumelo', 'Camara'),
    16: ('Catacumbas de Cristal', 'caverna', 2, 'dragao_vermelho', 'Camara'),
    17: ('Pedreira do Trovao', 'pedreira', 3, 'minotauro', 'Clareira'),
    18: ('Lagos do Eco', 'caverna_agua', 0, 'medusa', 'Camara'),
    19: ('Fortaleza Partida', 'ruinas', 1, 'goblin_maromba', 'Clareira'),
    20: ('Forja Esquecida', 'caverna_mina', 2, 'cogumelo', 'Camara'),
    21: ('Coracao do Abismo', 'caverna', 3, 'dragao_vermelho', 'Camara'),
}
# O layout inicial do andar 19 deixou a malha de navegação das ruínas inválida: outra semente resolve
SEMENTE_EXTRA = {19: 7}
FAIXAS_Y = [-496, -448, -352, -224, -160, -80, -32, 32, 160, 224, 336, 416, 448, 496]
RAIO_TRILHA = {'pedreira': 88, 'ruinas': 88, 'caverna_agua': 88, 'caverna_mina': 80, 'caverna': 80}
FORMAS_LAGO = [(64, 50), (192, 64), (112, 72), (160, 90)]


def contrato(bioma: str) -> dict:
    base = {'pedreira': 9, 'ruinas': 10, 'caverna_agua': 7, 'caverna_mina': 3, 'caverna': 11}[bioma]
    return json.loads((PLANTAS / f'andar_{base:02}.json').read_text())


def sortear_y(rng: random.Random, anterior: int, antes: int) -> int:
    candidatos = [y for y in FAIXAS_Y if 224 <= abs(y - anterior) <= 960 and y != antes]
    return rng.choice(candidatos)


def lagos(rng: random.Random, setores: list, trilhas: list, x0: int, largura: int) -> list:
    lobos = []
    for _ in range(600):
        if len(lobos) >= 13:
            break
        rx, ry = rng.choice(FORMAS_LAGO)
        x = rng.randrange(x0 + 220, x0 + largura - 220)
        y = rng.randrange(-560, 640)
        if any(abs(x - s['centro'][0]) < s['raios'][0] + rx + 70 and abs(y - s['centro'][1]) < s['raios'][1] + ry + 70 for s in setores):
            continue
        if any(abs(x - l[0]) < l[2] + rx + 60 and abs(y - l[1]) < l[3] + ry + 60 for l in lobos):
            continue
        perto = False
        for t in trilhas:
            (ax, ay), (bx, by) = t['pontos']
            comprimento = max(math.hypot(bx - ax, by - ay), 1)
            u = max(0, min(1, ((x - ax) * (bx - ax) + (y - ay) * (by - ay)) / comprimento ** 2))
            if math.hypot(x - (ax + u * (bx - ax)), y - (ay + u * (by - ay))) < t['raio'] + max(rx, ry) + 56:
                perto = True
                break
        if not perto:
            lobos.append([x, y, rx, ry])
    return lobos


def criar(andar: int) -> dict:
    nome, bioma, estacao, guardiao_id, rotulo = ESPECIFICACOES[andar]
    rng = random.Random(20261025 + andar + SEMENTE_EXTRA.get(andar, 0))
    passo_andar = andar - 11
    largura = 5000 + 270 * passo_andar
    largura -= largura % 32
    x0 = -largura // 2
    areas = 11 + round(passo_andar * 0.55)
    entrada = [x0 + 320, rng.choice([-32, 0, 32, 416, 448])]
    guardiao = [x0 + largura - 320, rng.choice([-384, -160, -96, 160])]
    passo = (guardiao[0] - entrada[0]) / (areas + 1)
    patio = bioma == 'ruinas'
    raio_t = RAIO_TRILHA[bioma]

    def setor(id_, nome_, centro, raios, grupos):
        s = {'id': id_, 'nome': nome_, 'centro': [int(centro[0]), int(centro[1])], 'raios': raios, 'grupos': grupos}
        if patio:
            s['formato'] = 'patio'
        return s

    setores = [setor('entrada', 'Portal', entrada, [136, 112], 0)]
    anterior, antes = entrada[1], entrada[1]
    for i in range(1, areas + 1):
        y = sortear_y(rng, anterior, antes)
        x = entrada[0] + passo * i + rng.randrange(-48, 49, 16)
        setores.append(setor(f'area_{i}', f'{rotulo} {i}', (round(x / 16) * 16, y), [136, 112], 2 if i % 2 else 1))
        antes, anterior = anterior, y
    setores.append(setor('guardiao', 'Guardiao', guardiao, [176, 144], 0))

    centros = [s['centro'] for s in setores]
    ligacoes = {(i, i + 1) for i in range(len(centros) - 1)}
    # Atalhos formam laços: o jogador escolhe entre dois caminhos até a mesma câmara.
    for i in range(1, len(centros) - 3, 3):
        ligacoes.add((i, i + 2))
    ligacoes.add((len(centros) - 3, len(centros) - 1))
    trilhas = [{'pontos': [centros[a], centros[b]], 'raio': raio_t} for a, b in sorted(ligacoes)]

    grupos = sum(s['grupos'] for s in setores)
    comuns = min(8 + (andar - 10) // 3, 11)
    elites = min(5 + passo_andar // 2, 10)
    estoque = grupos * comuns * 3 + elites * 9
    exigida = round(min(0.93, 0.899 + 0.004 * passo_andar), 3)
    base = contrato(bioma)
    planta = {
        'andar': andar, 'nome': nome, 'bioma': bioma, 'estacao': estacao, 'grade': 16,
        'limites': [x0, -720, largura, 1440], 'entrada': entrada, 'guardiao': guardiao,
        'setores': setores, 'trilhas': trilhas,
        'lago': {'lobos': lagos(rng, setores, trilhas, x0, largura) if bioma == 'caverna_agua' else [], 'folga': 28},
        'combate': {'comuns_por_grupo': comuns, 'elites': elites, 'meta': round(estoque * exigida),
                    'pontos_comum': 3, 'pontos_elite': 9, 'fracao_exigida': exigida},
        'guardiao_id': guardiao_id, 'contrato_visual': base['contrato_visual'],
    }
    if 'direcao_ambiental' in base:
        planta['direcao_ambiental'] = base['direcao_ambiental']
    return planta


if __name__ == '__main__':
    for numero in ESPECIFICACOES:
        planta = criar(numero)
        (PLANTAS / f'andar_{numero:02}.json').write_text(json.dumps(planta, indent=2, ensure_ascii=False) + '\n')
        x0, _, w, h = planta['limites']
        print(numero, planta['nome'], planta['bioma'], f'{w}x{h}', len(planta['setores']), 'setores', planta['combate']['meta'], 'pontos')
