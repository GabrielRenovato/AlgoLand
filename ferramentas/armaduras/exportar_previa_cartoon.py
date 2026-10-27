#!/usr/bin/env python3
"""Empacota os recortes compilados em GIF; não desenha nem modifica as fontes."""
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageSequence

RAIZ = Path(__file__).resolve().parents[2]
ASSETS = RAIZ / 'assets/personagens/raven_cartoon/armaduras/cavaleiro_aco'
SAIDA = RAIZ / 'arte/previas/armaduras/cavaleiro_aco_cartoon'
DIRECOES = ['frente', 'costas', 'direita', 'esquerda']


def quadro(pagina, q, espelhar=False):
    with Image.open(ASSETS / 'completo' / f'{pagina}.png') as im:
        largura = im.width // 4
        recorte = im.crop((q * largura, 0, (q + 1) * largura, 896))
    if espelhar:
        recorte = recorte.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    tela = Image.new('RGBA', (640, 896))
    # Mesmo pivô horizontal do consumidor, incluindo o avanço do ataque lateral.
    x = 64 if largura == 512 else 40 if 'direita' in pagina else 0
    if espelhar and largura == 640:
        x = -40
    tela.alpha_composite(recorte, (x, 0))
    return tela.resize((240, 336), Image.Resampling.LANCZOS)


def exportar():
    SAIDA.mkdir(parents=True, exist_ok=True)
    contrato = json.loads((RAIZ / 'arte/fontes/personagens/raven_cartoon/corrida/passo_no_jogo.json').read_text())
    gravacao = json.loads((RAIZ / 'arte/previas/personagens/raven_cartoon/no_jogo/gravacao.json').read_text())
    ciclo_ms = 1000 * contrato['distancia_ciclo_mundo'] / gravacao['velocidades']['cartoon']
    limites = [round(ciclo_ms * q / 40) * 10 for q in range(5)]
    corrida_ms = [b - a for a, b in zip(limites, limites[1:])]
    for acao, rotulo in [('corrida', 'CORRIDA'), ('ataque', 'GOLPE 1'), ('ataque2', 'GOLPE 2')]:
        quadros = []
        contato = Image.new('RGB', (960, 1440), '#414c44')
        for q in range(4):
            tela = Image.new('RGB', (960, 360), '#414c44')
            desenho = ImageDraw.Draw(tela)
            for coluna, direcao in enumerate(DIRECOES):
                if acao == 'corrida':
                    pagina, espelho = acao + '_' + direcao, False
                else:
                    sufixo = {'frente': 'baixo', 'costas': 'cima'}.get(direcao, 'direita')
                    pagina, espelho = acao + '_' + sufixo, direcao == 'esquerda'
                im = quadro(pagina, q, espelho)
                tela.paste(im, (coluna * 240, 24), im)
                desenho.text((coluna * 240 + 20, 8), f'{rotulo} - {direcao.upper()}', fill='white')
            contato.paste(tela, (0, q * 360))
            quadros.append(tela)
        # Corrida: ciclo físico da configuração atual em velocidade máxima.
        duracoes = corrida_ms if acao == 'corrida' else [160, 60, 70, 200]
        quadros[0].save(SAIDA / f'{acao}_somente_armadura.gif', save_all=True,
                        append_images=quadros[1:], duration=duracoes, loop=0, disposal=2)
        contato.save(SAIDA / f'{acao}_quadros.png')
    animados, tempos = [], []
    for acao, repeticoes in [('corrida', 4), ('ataque', 2), ('ataque2', 2)]:
        with Image.open(SAIDA / f'{acao}_somente_armadura.gif') as im:
            fases = [(q.convert('RGB'), q.info['duration']) for q in ImageSequence.Iterator(im)]
        for _ in range(repeticoes):
            for q, tempo in fases:
                animados.append(q.copy())
                tempos.append(tempo)
    animados[0].save(SAIDA / 'armadura_animada_sem_corpo.gif', save_all=True,
                     append_images=animados[1:], duration=tempos, loop=0, disposal=2)
    (SAIDA / 'previas.json').write_text(json.dumps({
        'origem': str(ASSETS.relative_to(RAIZ)), 'corpo_incorporado': False,
        'direcoes': DIRECOES, 'quadros': 4, 'tempos_ataque_ms': [160, 60, 70, 200],
        'corrida_previa_ms': corrida_ms,
        'observacao': 'Corrida no jogo varia com a distancia fisica; GIF usa o ciclo e a velocidade atuais, com a precisao de 10 ms do formato. Fontes originais preservadas.'
    }, ensure_ascii=False, indent=2) + '\n')
    print('Prévia: três GIFs, quatro direções, somente equipamento; três folhas de contato.')


if __name__ == '__main__':
    exportar()
