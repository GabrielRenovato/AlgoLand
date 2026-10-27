#!/usr/bin/env python3
"""Compara a deriva das solas entre poses de apoio nas gravações reais."""
import json
from math import hypot
from pathlib import Path
from statistics import mean

RAIZ = Path(__file__).resolve().parents[3]
PREVIA = RAIZ/'arte/previas/personagens/raven_cartoon/no_jogo'


def medir(dados, contrato):
    apoios = contrato['apoios_direita']
    escala = dados.get('escala_mundo', contrato['escala_mundo'])
    entrada = None
    pares = []
    for captura in dados['capturas']:
        if captura['acao'] != 'correr' or captura['direcao'] not in ['direita', 'esquerda']:
            entrada = None
            continue
        if entrada and entrada['direcao'] == captura['direcao']:
            a, b = entrada['quadro'], captura['quadro']
            if a == b:
                continue
            dt = (captura['tempo_ms']-entrada['tempo_ms'])/1000
            dx = captura['posicao'][0]-entrada['posicao'][0]
            dy = captura['posicao'][1]-entrada['posicao'][1]
            # Descartar aceleração inicial e frenagem; comparar o mesmo pé em apoio.
            if (a, b) in [(0, 1), (2, 3)] and dt > 0 and hypot(dx, dy)/dt >= 78:
                sinal = -1 if captura['direcao'] == 'esquerda' else 1
                deriva = hypot(dx+sinal*(apoios[b][0]-apoios[a][0])*escala,
                               dy+(apoios[b][1]-apoios[a][1])*escala)
                pares.append({'direcao': captura['direcao'], 'quadros': [a+1, b+1],
                              'inicio_ms': entrada['tempo_ms'], 'fim_ms': captura['tempo_ms'],
                              'deslocamento_corpo': hypot(dx, dy), 'deriva_sola': deriva})
        entrada = captura
    assert len(pares) >= 4, 'Gravar mais apoios em velocidade estável antes de concluir.'
    return {'pares': pares, 'deriva_media': mean(p['deriva_sola'] for p in pares)}


def analisar():
    contrato = json.loads((RAIZ/'arte/fontes/personagens/raven_cartoon/corrida/passo_no_jogo.json').read_text())
    antes = medir(json.loads((PREVIA/'passada/antes_gravacao.json').read_text()), contrato)
    depois = medir(json.loads((PREVIA/'gravacao.json').read_text()), contrato)
    resultado = {'metodo': 'Variação da posição mundial do centro da sola entre entradas em poses consecutivas de apoio; perfis direito e esquerdo.',
                 'antes': antes, 'depois': depois,
                 'reducao_percentual': 100*(1-depois['deriva_media']/antes['deriva_media']),
                 'limite': 'Mede as transições de apoio no perfil. Quatro desenhos discretos ainda mantêm a sola fixa dentro de cada pose; não mede ausência de deriva em todos os instantes ou nas vistas frontal/traseira.'}
    (PREVIA/'passada/comparacao.json').write_text(json.dumps(resultado, ensure_ascii=False, indent=2)+'\n')
    print(f'Deriva média nas transições de apoio: {antes["deriva_media"]:.2f} → {depois["deriva_media"]:.2f} pixels de mundo; redução {resultado["reducao_percentual"]:.1f}%.')


if __name__ == '__main__':
    analisar()
