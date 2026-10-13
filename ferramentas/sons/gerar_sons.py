#!/usr/bin/env python3
"""Gera os efeitos sonoros 8-bit do AlgoLand em res://sons/*.wav.

Python puro (wave + math + random), no estilo do sfxr: ondas quadrada, triangulo, serra e ruido,
envelope ADSR, slide de frequencia, vibrato, arpejo e um filtro passa-baixa simples.
Cada som tem uma semente fixa e o arquivo WAV nao guarda data nem metadados, entao rodar de novo
gera arquivos identicos (byte a byte).

Uso (a partir da raiz do projeto):
    python3 ferramentas/sons/gerar_sons.py            # grava em sons/
    python3 ferramentas/sons/gerar_sons.py --resumo   # alem de gravar, imprime pico/duracao de cada som
"""
import math
import os
import random
import struct
import sys
import wave

TAXA = 22050  # Hz, mono, 16 bits
PICO_MAXIMO = 0.9  # nenhum som passa disso (sem clipping); cada som ainda tem o seu "nivel"

PASTA_SAIDA = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "sons")


def nota(semitons):
    """Frequencia (Hz) a `semitons` do La 440."""
    return 440.0 * 2.0 ** (semitons / 12.0)


# Notas usadas nas melodias curtas (semitons a partir do La 4)
DO4, RE4, MI4, FA4, SOL4, LA4, SI4 = -9, -7, -5, -4, -2, 0, 2
DO5, MI5, SOL5, LA5, SI5 = 3, 7, 10, 12, 14
DO6, MI6 = 15, 19


def voz(onda, f_ini, f_fim=None, dur=0.2, ataque=0.004, decaimento=0.05, sustentacao=0.6,
        liberacao=0.06, duty=0.5, duty_fim=None, vibrato_hz=0.0, vibrato_prof=0.0,
        arpejo=None, filtro_ini=1.0, filtro_fim=None, volume=1.0, inicio=0.0, curva=1.0, semente=1):
    """Sintetiza uma voz e devolve (indice_inicial, amostras).

    onda: "quadrada", "triangulo", "serra" ou "ruido" (ruido de amostra-e-segura: a frequencia
          controla o quao grosso e o ruido, como no sfxr).
    f_ini/f_fim: frequencia inicial/final em Hz (slide exponencial; curva > 1 atrasa a queda).
    duty/duty_fim: largura do pulso da onda quadrada (0.5 = quadrada cheia).
    vibrato_hz/prof: modulacao da frequencia (prof = fracao, 0.05 = 5%).
    arpejo: lista de (tempo_em_s, multiplicador) que troca a frequencia (notas de melodia).
    filtro_ini/fim: coeficiente do passa-baixa de um polo (1 = sem filtro, perto de 0 = muito abafado).
    """
    rng = random.Random(semente)
    f_fim = f_ini if f_fim is None else f_fim
    duty_fim = duty if duty_fim is None else duty_fim
    filtro_fim = filtro_ini if filtro_fim is None else filtro_fim
    total = max(int(dur * TAXA), 1)
    inicio_amostra = int(inicio * TAXA)
    saida = []
    fase = 0.0
    ruido = rng.uniform(-1.0, 1.0)
    filtrado = 0.0
    mult_arpejo = 1.0
    arpejo = sorted(arpejo) if arpejo else []
    for i in range(total):
        t = i / TAXA
        progresso = i / total
        for tempo, mult in arpejo:
            if t >= tempo:
                mult_arpejo = mult
        freq = f_ini * (f_fim / f_ini) ** (progresso ** curva) * mult_arpejo
        if vibrato_hz > 0.0:
            freq *= 1.0 + vibrato_prof * math.sin(2.0 * math.pi * vibrato_hz * t)
        passo = freq / TAXA
        fase += passo
        if fase >= 1.0:
            fase -= int(fase)
            if onda == "ruido":
                ruido = rng.uniform(-1.0, 1.0)
        if onda == "quadrada":
            largura = duty + (duty_fim - duty) * progresso
            amostra = 1.0 if fase < largura else -1.0
        elif onda == "triangulo":
            amostra = 4.0 * abs(fase - 0.5) - 1.0
        elif onda == "serra":
            amostra = 2.0 * fase - 1.0
        else:
            amostra = ruido
        coef = filtro_ini + (filtro_fim - filtro_ini) * progresso
        filtrado += coef * (amostra - filtrado)
        # Envelope ADSR: ataque -> decaimento ate o nivel de sustentacao -> sustenta -> liberacao
        inicio_liberacao = max(dur - liberacao, 0.0)
        if t < ataque:
            env = t / ataque if ataque > 0 else 1.0
        elif t < ataque + decaimento:
            env = 1.0 + (sustentacao - 1.0) * (t - ataque) / decaimento
        else:
            env = sustentacao
        if t > inicio_liberacao and liberacao > 0:
            env *= max(1.0 - (t - inicio_liberacao) / liberacao, 0.0)
        saida.append(filtrado * env * volume)
    return inicio_amostra, saida


def misturar(vozes, nivel=0.8, fade_final=True):
    """Soma as vozes e normaliza o pico para `nivel` (sem passar de PICO_MAXIMO).
    fade_final=False e para sons em loop: o fim emenda no comeco sem a queda a zero."""
    comprimento = max(inicio + len(amostras) for inicio, amostras in vozes)
    mix = [0.0] * comprimento
    for inicio, amostras in vozes:
        for i, valor in enumerate(amostras):
            mix[inicio + i] += valor
    pico = max(abs(v) for v in mix) or 1.0
    ganho = min(nivel, PICO_MAXIMO) / pico
    mix = [v * ganho for v in mix]
    # Fade de 2 ms no fim para nao estalar
    fade = min(int(0.002 * TAXA), len(mix)) if fade_final else 0
    for i in range(fade):
        mix[len(mix) - 1 - i] *= i / fade
    return mix


def melodia(onda, notas, duracao_nota, inicio=0.0, **extra):
    """Sequencia de notas (semitons), uma voz por nota; cada nota se sobrepoe um pouco a seguinte."""
    vozes = []
    for indice, semitons in enumerate(notas):
        vozes.append(voz(onda, nota(semitons), dur=duracao_nota * 1.15, inicio=inicio + indice * duracao_nota,
                         semente=1 + indice, **extra))
    return vozes


# ---------------------------------------------------------------------------
# Definicao de cada som: nome -> (nivel, funcao que devolve a lista de vozes)
# ---------------------------------------------------------------------------

def golpe_espada():
    return [
        voz("ruido", 3200, 900, dur=0.16, ataque=0.003, decaimento=0.05, sustentacao=0.35, liberacao=0.08,
            filtro_ini=0.55, filtro_fim=0.18, volume=0.8, semente=11),
        voz("quadrada", 620, 140, dur=0.14, ataque=0.002, decaimento=0.04, sustentacao=0.4, liberacao=0.07,
            duty=0.25, duty_fim=0.5, volume=0.45, semente=12),
    ]


def golpe_lanca():
    return [
        voz("ruido", 4500, 1800, dur=0.1, ataque=0.002, decaimento=0.03, sustentacao=0.3, liberacao=0.05,
            filtro_ini=0.7, filtro_fim=0.3, volume=0.7, semente=21),
        voz("serra", 980, 330, dur=0.12, ataque=0.002, decaimento=0.03, sustentacao=0.45, liberacao=0.06,
            filtro_ini=0.6, volume=0.5, semente=22),
    ]


def flecha():
    return [
        voz("triangulo", 280, 1250, dur=0.16, ataque=0.005, decaimento=0.04, sustentacao=0.5, liberacao=0.08,
            volume=0.6, semente=31),
        voz("ruido", 2500, 6000, dur=0.18, ataque=0.01, decaimento=0.06, sustentacao=0.25, liberacao=0.1,
            filtro_ini=0.25, filtro_fim=0.6, volume=0.45, semente=32),
    ]


def acerto():
    return [
        voz("ruido", 1800, 500, dur=0.09, ataque=0.001, decaimento=0.03, sustentacao=0.3, liberacao=0.05,
            filtro_ini=0.7, filtro_fim=0.3, volume=0.85, semente=41),
        voz("quadrada", 240, 70, dur=0.1, ataque=0.001, decaimento=0.04, sustentacao=0.4, liberacao=0.05,
            duty=0.5, volume=0.6, semente=42),
    ]


def inimigo_morre():
    return [
        voz("quadrada", 520, 70, dur=0.3, ataque=0.002, decaimento=0.08, sustentacao=0.55, liberacao=0.12,
            duty=0.35, duty_fim=0.5, vibrato_hz=18, vibrato_prof=0.04, volume=0.7, semente=51),
        voz("ruido", 1500, 300, dur=0.22, ataque=0.002, decaimento=0.06, sustentacao=0.35, liberacao=0.1,
            filtro_ini=0.5, filtro_fim=0.15, volume=0.5, semente=52),
    ]


def jogador_dano():
    return [
        voz("serra", 340, 110, dur=0.26, ataque=0.002, decaimento=0.06, sustentacao=0.55, liberacao=0.12,
            vibrato_hz=28, vibrato_prof=0.07, filtro_ini=0.7, volume=0.8, semente=61),
        voz("ruido", 1400, 400, dur=0.12, ataque=0.001, decaimento=0.04, sustentacao=0.3, liberacao=0.06,
            filtro_ini=0.6, filtro_fim=0.25, volume=0.6, semente=62),
    ]


def jogador_morre():
    return [
        voz("serra", 420, 38, dur=0.9, ataque=0.005, decaimento=0.2, sustentacao=0.6, liberacao=0.35,
            vibrato_hz=7, vibrato_prof=0.05, filtro_ini=0.55, filtro_fim=0.2, volume=0.8, semente=71),
        voz("quadrada", 210, 40, dur=0.8, ataque=0.005, decaimento=0.2, sustentacao=0.45, liberacao=0.3,
            duty=0.25, duty_fim=0.5, volume=0.45, semente=72),
        voz("ruido", 900, 150, dur=0.7, ataque=0.005, decaimento=0.15, sustentacao=0.25, liberacao=0.3,
            filtro_ini=0.35, filtro_fim=0.08, volume=0.5, semente=73),
    ]


def dash():
    return [
        voz("ruido", 1200, 5200, dur=0.17, ataque=0.01, decaimento=0.05, sustentacao=0.5, liberacao=0.09,
            filtro_ini=0.2, filtro_fim=0.65, volume=0.7, semente=81),
        voz("triangulo", 180, 760, dur=0.15, ataque=0.005, decaimento=0.04, sustentacao=0.5, liberacao=0.07,
            volume=0.5, semente=82),
    ]


def reviver():
    return (melodia("quadrada", [DO4, MI4, SOL4, DO5, MI5], 0.1, duty=0.25, decaimento=0.04, sustentacao=0.55,
                    liberacao=0.08, volume=0.6)
            + [voz("triangulo", nota(MI5), nota(DO6), dur=0.4, inicio=0.35, ataque=0.01, decaimento=0.1,
                   sustentacao=0.5, liberacao=0.2, vibrato_hz=9, vibrato_prof=0.02, volume=0.7, semente=91)])


def moeda():
    return [
        voz("quadrada", nota(SI5), dur=0.06, ataque=0.001, decaimento=0.02, sustentacao=0.8, liberacao=0.01,
            duty=0.5, volume=0.8, semente=101),
        voz("quadrada", nota(MI6), dur=0.2, inicio=0.06, ataque=0.001, decaimento=0.05, sustentacao=0.45,
            liberacao=0.12, duty=0.5, volume=0.8, semente=102),
    ]


def compra():
    return ([voz("ruido", 6500, 6500, dur=0.025, ataque=0.001, decaimento=0.01, sustentacao=0.4, liberacao=0.01,
                 filtro_ini=0.9, volume=0.4, semente=111)]
            + melodia("quadrada", [SOL5, SI5, MI6], 0.07, inicio=0.03, duty=0.5, decaimento=0.03, sustentacao=0.6,
                      liberacao=0.06, volume=0.7)
            + [voz("triangulo", nota(MI6), dur=0.22, inicio=0.24, ataque=0.002, decaimento=0.06, sustentacao=0.4,
                   liberacao=0.14, volume=0.6, semente=112)])


def melhoria():
    # Martelada na bigorna (ruido + metal) seguida de um motivo ascendente
    return ([voz("ruido", 3800, 900, dur=0.1, ataque=0.001, decaimento=0.03, sustentacao=0.3, liberacao=0.06,
                 filtro_ini=0.8, filtro_fim=0.3, volume=0.8, semente=121),
             voz("triangulo", 1180, 1100, dur=0.28, ataque=0.001, decaimento=0.1, sustentacao=0.3, liberacao=0.16,
                 vibrato_hz=35, vibrato_prof=0.03, volume=0.5, semente=122)]
            + melodia("quadrada", [DO5, MI5, SOL5, DO6], 0.09, inicio=0.16, duty=0.25, decaimento=0.04,
                      sustentacao=0.6, liberacao=0.1, volume=0.55))


def erro():
    return [
        voz("quadrada", 150, 120, dur=0.1, ataque=0.002, decaimento=0.02, sustentacao=0.8, liberacao=0.02,
            duty=0.5, volume=0.8, semente=131),
        voz("quadrada", 118, 95, dur=0.16, inicio=0.12, ataque=0.002, decaimento=0.03, sustentacao=0.7,
            liberacao=0.06, duty=0.5, volume=0.8, semente=132),
    ]


def onda_inicio():
    return [
        voz("serra", nota(LA4 - 12), nota(LA4 - 12), dur=0.22, ataque=0.01, decaimento=0.05, sustentacao=0.8,
            liberacao=0.03, filtro_ini=0.35, volume=0.7, semente=141),
        voz("serra", nota(MI4), nota(MI4), dur=0.45, inicio=0.22, ataque=0.01, decaimento=0.08, sustentacao=0.75,
            liberacao=0.18, filtro_ini=0.35, volume=0.75, semente=142),
        voz("quadrada", nota(MI4 + 12), dur=0.4, inicio=0.24, ataque=0.01, decaimento=0.08, sustentacao=0.4,
            liberacao=0.16, duty=0.25, volume=0.35, semente=143),
    ]


def onda_fim():
    return melodia("quadrada", [DO5, MI5, SOL5, DO6], 0.11, duty=0.5, decaimento=0.05, sustentacao=0.6,
                   liberacao=0.1, volume=0.6) + [
        voz("triangulo", nota(DO6), dur=0.45, inicio=0.4, ataque=0.005, decaimento=0.12, sustentacao=0.5,
            liberacao=0.25, vibrato_hz=7, vibrato_prof=0.015, volume=0.7, semente=151)]


def chefe_aparece():
    return [
        voz("serra", 82, 52, dur=1.1, ataque=0.05, decaimento=0.2, sustentacao=0.8, liberacao=0.4,
            vibrato_hz=5, vibrato_prof=0.06, filtro_ini=0.3, volume=0.9, semente=161),
        voz("quadrada", 41, 36, dur=1.0, ataque=0.05, decaimento=0.2, sustentacao=0.7, liberacao=0.35,
            duty=0.25, volume=0.5, semente=162),
        voz("ruido", 220, 70, dur=1.0, ataque=0.08, decaimento=0.3, sustentacao=0.45, liberacao=0.4,
            filtro_ini=0.25, filtro_fim=0.06, volume=0.6, semente=163),
        voz("serra", 164, 104, dur=0.5, inicio=0.5, ataque=0.02, decaimento=0.15, sustentacao=0.6, liberacao=0.25,
            filtro_ini=0.3, volume=0.4, semente=164),
    ]


def chefe_morre():
    return [
        voz("ruido", 2600, 120, dur=1.0, ataque=0.002, decaimento=0.25, sustentacao=0.4, liberacao=0.55,
            filtro_ini=0.7, filtro_fim=0.05, volume=0.9, semente=171),
        voz("quadrada", 360, 28, dur=0.95, ataque=0.002, decaimento=0.2, sustentacao=0.5, liberacao=0.45,
            duty=0.3, duty_fim=0.5, vibrato_hz=12, vibrato_prof=0.05, volume=0.6, semente=172),
        voz("serra", 110, 30, dur=0.8, ataque=0.002, decaimento=0.15, sustentacao=0.6, liberacao=0.4,
            filtro_ini=0.3, volume=0.6, semente=173),
    ] + melodia("triangulo", [DO5, MI5, SOL5, DO6], 0.12, inicio=0.55, decaimento=0.06, sustentacao=0.5,
                liberacao=0.14, volume=0.45)


def estacao():
    # Tres notas suaves e uma nota longa: um "sino" que marca a troca de estacao
    return (melodia("triangulo", [SOL4, DO5, MI5], 0.14, decaimento=0.08, sustentacao=0.45, liberacao=0.14,
                    volume=0.7)
            + [voz("triangulo", nota(SOL5), dur=0.5, inicio=0.42, ataque=0.004, decaimento=0.15, sustentacao=0.35,
                   liberacao=0.3, vibrato_hz=6, vibrato_prof=0.01, volume=0.75, semente=181),
               voz("quadrada", nota(SOL5 + 12), dur=0.3, inicio=0.42, ataque=0.002, decaimento=0.1, sustentacao=0.2,
                   liberacao=0.2, duty=0.125, volume=0.2, semente=182)])


def menu_mover():
    return [voz("quadrada", 760, 820, dur=0.045, ataque=0.001, decaimento=0.015, sustentacao=0.6, liberacao=0.02,
                duty=0.5, volume=0.8, semente=191)]


def menu_confirmar():
    return [
        voz("quadrada", 520, 520, dur=0.05, ataque=0.001, decaimento=0.01, sustentacao=0.8, liberacao=0.01,
            duty=0.5, volume=0.8, semente=201),
        voz("quadrada", 780, 780, dur=0.09, inicio=0.05, ataque=0.001, decaimento=0.02, sustentacao=0.6,
            liberacao=0.05, duty=0.5, volume=0.8, semente=202),
    ]


def trovao():
    """Estrondo grave: estalo curto de ruido claro, depois rumores de ruido abafado que rolam e se afastam."""
    return [
        voz("ruido", 9000, 2500, dur=0.14, ataque=0.001, decaimento=0.05, sustentacao=0.3, liberacao=0.07,
            filtro_ini=0.9, filtro_fim=0.3, volume=0.55, semente=401),
        voz("ruido", 700, 90, dur=1.3, ataque=0.012, decaimento=0.35, sustentacao=0.4, liberacao=0.8,
            filtro_ini=0.16, filtro_fim=0.03, vibrato_hz=6.0, vibrato_prof=0.25, volume=1.0, semente=402),
        voz("ruido", 420, 70, dur=0.9, inicio=0.32, ataque=0.08, decaimento=0.3, sustentacao=0.35, liberacao=0.5,
            filtro_ini=0.1, filtro_fim=0.025, volume=0.8, semente=403),
        voz("triangulo", 62, 28, dur=1.2, ataque=0.01, decaimento=0.3, sustentacao=0.45, liberacao=0.7,
            volume=0.8, semente=404),
    ]


DURACAO_CHUVA = 2.6   # s: tempo do trecho que se repete
EMENDA_CHUVA = 0.4    # s: trecho final misturado ao comeco para o loop nao ter clique


def chuva():
    """Chuva em loop: ruido filtrado (chiado de gotas) com variacao lenta e pingos esparsos.
    O fim e misturado ao comeco (crossfade de potencia constante), entao o loop fecha sem clique."""
    rng = random.Random(501)
    total = int(DURACAO_CHUVA * TAXA)
    emenda = int(EMENDA_CHUVA * TAXA)
    n = total + emenda
    bruto = []
    rapido = 0.0
    lento = 0.0
    nivel = 1.0
    alvo = 1.0
    gota = 0.0
    for i in range(n):
        if i % 1100 == 0:
            alvo = rng.uniform(0.75, 1.15)
        nivel += 0.0008 * (alvo - nivel)
        branco = rng.uniform(-1.0, 1.0)
        # passa-faixa: abafa o agudo cortante (polo rapido) e tira o grave (polo lento)
        rapido += 0.42 * (branco - rapido)
        lento += 0.035 * (rapido - lento)
        valor = (rapido - lento) * nivel
        # pingos: estalos curtos e suaves
        if rng.random() < 0.0009:
            gota = rng.uniform(0.4, 1.0)
        valor += gota * rng.uniform(-1.0, 1.0) * 0.5
        gota *= 0.93
        bruto.append(valor)
    saida = []
    for i in range(total):
        if i < emenda:
            peso = i / emenda
            a = math.sin(peso * math.pi / 2.0)
            b = math.cos(peso * math.pi / 2.0)
            saida.append(bruto[i] * a + bruto[total + i] * b)
        else:
            saida.append(bruto[i])
    return [(0, saida)]


def enxada():
    """Golpe na terra: baque grave e abafado com um estalo de torrões."""
    return [
        voz("ruido", 900, 200, dur=0.17, ataque=0.002, decaimento=0.05, sustentacao=0.3, liberacao=0.09,
            filtro_ini=0.3, filtro_fim=0.07, volume=0.9, semente=601),
        voz("triangulo", 150, 55, dur=0.15, ataque=0.002, decaimento=0.05, sustentacao=0.4, liberacao=0.08,
            volume=0.75, semente=602),
        voz("ruido", 3200, 1400, dur=0.07, inicio=0.03, ataque=0.001, decaimento=0.02, sustentacao=0.3,
            liberacao=0.04, filtro_ini=0.5, filtro_fim=0.25, volume=0.3, semente=603),
    ]


def regar():
    """Água saindo do regador: chiado filtrado e borbulhante, um pouco mais longo que os outros golpes."""
    return [
        voz("ruido", 2600, 3400, dur=0.55, ataque=0.07, decaimento=0.12, sustentacao=0.65, liberacao=0.22,
            filtro_ini=0.28, filtro_fim=0.42, vibrato_hz=23, vibrato_prof=0.3, volume=0.8, semente=611),
        voz("triangulo", 520, 980, dur=0.07, inicio=0.12, ataque=0.003, decaimento=0.02, sustentacao=0.5,
            liberacao=0.03, volume=0.35, semente=612),
        voz("triangulo", 430, 860, dur=0.07, inicio=0.27, ataque=0.003, decaimento=0.02, sustentacao=0.5,
            liberacao=0.03, volume=0.3, semente=613),
        voz("triangulo", 610, 1100, dur=0.06, inicio=0.39, ataque=0.003, decaimento=0.02, sustentacao=0.5,
            liberacao=0.03, volume=0.3, semente=614),
    ]


def plantar():
    """Semente caindo na terra: um plop curto e dois grãos."""
    return [
        voz("triangulo", 330, 540, dur=0.1, ataque=0.002, decaimento=0.04, sustentacao=0.4, liberacao=0.05,
            volume=0.7, semente=621),
        voz("ruido", 1800, 600, dur=0.06, ataque=0.001, decaimento=0.02, sustentacao=0.3, liberacao=0.03,
            filtro_ini=0.45, filtro_fim=0.2, volume=0.4, semente=622),
        voz("triangulo", 260, 420, dur=0.08, inicio=0.09, ataque=0.002, decaimento=0.03, sustentacao=0.35,
            liberacao=0.04, volume=0.45, semente=623),
    ]


def colher():
    """Planta arrancada da terra: estalo seco e um pop agudo de recompensa."""
    return [
        voz("ruido", 2400, 700, dur=0.08, ataque=0.001, decaimento=0.03, sustentacao=0.3, liberacao=0.04,
            filtro_ini=0.55, filtro_fim=0.2, volume=0.55, semente=631),
        voz("quadrada", 420, 980, dur=0.09, inicio=0.04, ataque=0.002, decaimento=0.03, sustentacao=0.5,
            liberacao=0.04, duty=0.25, volume=0.6, semente=632),
        voz("triangulo", nota(SOL5), dur=0.14, inicio=0.12, ataque=0.002, decaimento=0.05, sustentacao=0.4,
            liberacao=0.08, volume=0.55, semente=633),
    ]


def caldeirao():
    """Pocao pronta no caldeirao: bolhas que sobem (plops graves e rapidos) e um brilho magico no fim."""
    bolhas = []
    for k, (f0, t0) in enumerate([(180, 0.0), (240, 0.07), (200, 0.13), (300, 0.2), (260, 0.26), (360, 0.33)]):
        bolhas.append(voz("triangulo", f0, f0 * 2.4, dur=0.07, inicio=t0, ataque=0.002, decaimento=0.03,
                          sustentacao=0.4, liberacao=0.03, volume=0.6, semente=651 + k))
    return (bolhas
            + [voz("ruido", 900, 400, dur=0.4, ataque=0.02, decaimento=0.1, sustentacao=0.4, liberacao=0.2,
                   filtro_ini=0.25, filtro_fim=0.1, volume=0.35, semente=660)]
            + melodia("triangulo", [SOL5, DO6, MI6], 0.07, inicio=0.42, decaimento=0.04, sustentacao=0.5,
                      liberacao=0.08, vibrato_hz=8, vibrato_prof=0.015, volume=0.55))


def beber():
    """Pocao bebida: dois goles (glub glub) e o efeito subindo em arpejo."""
    return ([voz("quadrada", 260, 150, dur=0.08, ataque=0.002, decaimento=0.03, sustentacao=0.5, liberacao=0.03,
                 duty=0.25, filtro_ini=0.35, volume=0.65, semente=671),
             voz("quadrada", 240, 135, dur=0.08, inicio=0.11, ataque=0.002, decaimento=0.03, sustentacao=0.5,
                 liberacao=0.03, duty=0.25, filtro_ini=0.35, volume=0.65, semente=672)]
            + melodia("quadrada", [DO5, MI5, SOL5, DO6], 0.05, inicio=0.22, duty=0.125, decaimento=0.02,
                      sustentacao=0.55, liberacao=0.05, volume=0.5))


def pegar_semente():
    """Saquinho de semente recolhido: um pop macio e um trinado curto (mais suave que a moeda)."""
    return [
        voz("triangulo", 420, 820, dur=0.07, ataque=0.002, decaimento=0.03, sustentacao=0.5, liberacao=0.03,
            volume=0.7, semente=681),
        voz("triangulo", nota(MI5), dur=0.1, inicio=0.06, ataque=0.002, decaimento=0.03, sustentacao=0.5,
            liberacao=0.05, volume=0.55, semente=682),
        voz("triangulo", nota(SOL5), dur=0.13, inicio=0.12, ataque=0.002, decaimento=0.04, sustentacao=0.45,
            liberacao=0.08, volume=0.5, semente=683),
    ]


def aparo():
    """Aparo perfeito: clangor de metal (dois tons altos que ressoam) sobre uma batida seca."""
    return [
        voz("ruido", 3800, 1500, dur=0.06, ataque=0.001, decaimento=0.02, sustentacao=0.3, liberacao=0.03,
            filtro_ini=0.8, filtro_fim=0.4, volume=0.8, semente=701),
        voz("quadrada", 1900, 1750, dur=0.26, ataque=0.001, decaimento=0.08, sustentacao=0.3, liberacao=0.12,
            duty=0.125, vibrato_hz=22, vibrato_prof=0.01, volume=0.6, semente=702),
        voz("quadrada", 2870, 2700, dur=0.2, ataque=0.001, decaimento=0.06, sustentacao=0.25, liberacao=0.1,
            duty=0.25, volume=0.4, semente=703),
    ]


def bloqueio():
    """Golpe segurado pela guarda: pancada abafada, sem o brilho do aparo perfeito."""
    return [
        voz("ruido", 1500, 380, dur=0.09, ataque=0.001, decaimento=0.03, sustentacao=0.3, liberacao=0.05,
            filtro_ini=0.5, filtro_fim=0.2, volume=0.8, semente=711),
        voz("quadrada", 200, 62, dur=0.12, ataque=0.001, decaimento=0.05, sustentacao=0.4, liberacao=0.06,
            duty=0.5, volume=0.7, semente=712),
    ]


def escudada():
    """Empurrao com o escudo: um chiado de ar e uma pancada grave logo depois."""
    return [
        voz("ruido", 2400, 700, dur=0.14, ataque=0.004, decaimento=0.05, sustentacao=0.4, liberacao=0.06,
            filtro_ini=0.45, filtro_fim=0.2, volume=0.55, semente=721),
        voz("quadrada", 150, 45, dur=0.16, inicio=0.07, ataque=0.001, decaimento=0.06, sustentacao=0.45, liberacao=0.08,
            duty=0.5, volume=0.8, semente=722),
        voz("ruido", 1200, 300, dur=0.1, inicio=0.07, ataque=0.001, decaimento=0.03, sustentacao=0.3, liberacao=0.06,
            filtro_ini=0.5, filtro_fim=0.2, volume=0.7, semente=723),
    ]


# nome -> (nivel de pico, funcao). O nivel varia para balancear o volume entre os sons
SONS = {
    "golpe_espada": (0.75, golpe_espada),
    "golpe_lanca": (0.75, golpe_lanca),
    "flecha": (0.65, flecha),
    "acerto": (0.8, acerto),
    "inimigo_morre": (0.75, inimigo_morre),
    "jogador_dano": (0.85, jogador_dano),
    "jogador_morre": (0.9, jogador_morre),
    "dash": (0.6, dash),
    "reviver": (0.75, reviver),
    "moeda": (0.6, moeda),
    "compra": (0.7, compra),
    "melhoria": (0.8, melhoria),
    "erro": (0.7, erro),
    "onda_inicio": (0.8, onda_inicio),
    "onda_fim": (0.8, onda_fim),
    "chefe_aparece": (0.9, chefe_aparece),
    "chefe_morre": (0.9, chefe_morre),
    "estacao": (0.65, estacao),
    "menu_mover": (0.45, menu_mover),
    "menu_confirmar": (0.55, menu_confirmar),
    "trovao": (0.9, trovao),
    "chuva": (0.5, chuva),
    "enxada": (0.8, enxada),
    "regar": (0.55, regar),
    "plantar": (0.6, plantar),
    "colher": (0.65, colher),
    "caldeirao": (0.7, caldeirao),
    "beber": (0.7, beber),
    "pegar_semente": (0.55, pegar_semente),
    "aparo": (0.75, aparo),
    "bloqueio": (0.7, bloqueio),
    "escudada": (0.75, escudada),
}
# Sons que se repetem em loop (sem o fade de 2 ms no fim)
SONS_EM_LOOP = {"chuva"}


def gravar_wav(caminho, amostras):
    """WAV mono 16 bits. O modulo wave nao grava data nem metadados: a saida e deterministica."""
    dados = b"".join(struct.pack("<h", max(-32767, min(32767, int(round(v * 32767))))) for v in amostras)
    with wave.open(caminho, "wb") as arquivo:
        arquivo.setnchannels(1)
        arquivo.setsampwidth(2)
        arquivo.setframerate(TAXA)
        arquivo.writeframes(dados)


def main():
    resumo = "--resumo" in sys.argv
    os.makedirs(PASTA_SAIDA, exist_ok=True)
    for nome, (nivel, criar) in SONS.items():
        amostras = misturar(criar(), nivel, fade_final=nome not in SONS_EM_LOOP)
        gravar_wav(os.path.join(PASTA_SAIDA, nome + ".wav"), amostras)
        if resumo:
            pico = max(abs(v) for v in amostras)
            rms = math.sqrt(sum(v * v for v in amostras) / len(amostras))
            print("%-15s %5.2f s  pico %.2f  rms %.3f" % (nome, len(amostras) / TAXA, pico, rms))
    print("%d sons gravados em %s" % (len(SONS), os.path.normpath(PASTA_SAIDA)))


if __name__ == "__main__":
    main()
