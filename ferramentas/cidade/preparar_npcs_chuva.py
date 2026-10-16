#!/usr/bin/env python3
"""Prepara as capas de chuva dos seis moradores em 28 quadros nativos.
Preserva originais gerados, grade, escala no mapa e alinhamento dos pés das folhas normais.
Uso: python3 ferramentas/cidade/preparar_npcs_chuva.py
"""
from pathlib import Path
import json
from PIL import Image

RAIZ = Path(__file__).resolve().parents[2]
FONTES = RAIZ / 'arte/fontes/npcs/capas_chuva'
SAIDA = RAIZ / 'assets/npcs/cidade/capas_chuva'
PREVIAS = RAIZ / 'arte/previas/cidade'
NOMES = ['tomas', 'rosa', 'caio', 'estela', 'lia', 'bento']
DIRECOES = ['baixo', 'direita', 'cima', 'esquerda']
CELULA = 64


def carregar_fonte(caminho):
    imagem = Image.open(caminho).convert('RGBA')
    imagem.putalpha(imagem.getchannel('A').point(lambda a: 255 if a >= 128 else 0))
    return imagem


def recortar(fonte, coluna, linha):
    q = fonte.crop((round(coluna * fonte.width / 7), round(linha * fonte.height / 4),
                    round((coluna + 1) * fonte.width / 7), round((linha + 1) * fonte.height / 4)))
    caixa = q.getbbox()
    if caixa is None:
        raise ValueError('Quadro vazio: ' + str((coluna, linha)))
    return q.crop(caixa)


def montar(nome, dados):
    fonte = carregar_fonte(FONTES / (nome + '.png'))
    original = Image.open(RAIZ / 'assets/npcs/cidade' / (nome + '.png')).convert('RGBA')
    escala = (dados['altura_parado'] + 2) / recortar(fonte, 0, 0).height
    folha = Image.new('RGBA', (7 * CELULA, 4 * CELULA))
    for linha in range(4):
        for coluna in range(7):
            arte = recortar(fonte, coluna, linha)
            arte = arte.resize((max(1, round(arte.width * escala)), max(1, round(arte.height * escala))), Image.Resampling.NEAREST)
            # Os pés continuam na linha de cada pose original; só o capuz ganha altura.
            corpo = original.crop((coluna * 64, linha * 64, (coluna + 1) * 64, (linha + 1) * 64))
            caixa = corpo.getbbox()
            destino = ((CELULA - arte.width) // 2, caixa[3] - arte.height)
            assert destino[0] >= 0 and destino[1] >= 0, (nome, coluna, linha)
            assert destino[0] + arte.width <= CELULA and destino[1] + arte.height <= CELULA
            folha.alpha_composite(arte, (coluna * CELULA + destino[0], linha * CELULA + destino[1]))
    return folha


def exportar_previas():
    quadros = []
    for coluna in range(1, 7):
        tela = Image.new('RGBA', (6 * 56, 4 * 56), '#29282b')
        for x, nome in enumerate(NOMES):
            folha = Image.open(SAIDA / (nome + '.png')).convert('RGBA')
            for y in range(4):
                q = folha.crop((coluna * 64 + 4, y * 64 + 4, (coluna + 1) * 64 - 4, (y + 1) * 64 - 4))
                tela.alpha_composite(q, (x * 56, y * 56))
        quadros.append(tela.resize((1008, 672), Image.Resampling.NEAREST))
    PREVIAS.mkdir(parents=True, exist_ok=True)
    quadros[0].save(PREVIAS / 'moradores_capas_chuva.png')
    quadros[0].save(PREVIAS / 'moradores_capas_chuva.gif', save_all=True, append_images=quadros[1:], duration=125, loop=0, disposal=2)


def main():
    caminho_manifesto = RAIZ / 'assets/npcs/cidade/manifesto.json'
    manifesto = json.loads(caminho_manifesto.read_text())
    # Prepara todos antes de trocar qualquer folha em uso.
    folhas = {nome: montar(nome, manifesto[nome]) for nome in NOMES}
    SAIDA.mkdir(parents=True, exist_ok=True)
    for nome, folha in folhas.items():
        folha.save(SAIDA / (nome + '.png'))
        pasta = SAIDA / nome
        pasta.mkdir(exist_ok=True)
        for linha in range(4):
            for coluna in range(7):
                quadro = folha.crop((coluna * 64, linha * 64, (coluna + 1) * 64, (linha + 1) * 64))
                quadro.save(pasta / ('%s_%s.png' % (DIRECOES[linha], 'parado' if coluna == 0 else 'andar_%02d' % coluna)))
        manifesto[nome]['folha_chuva'] = 'res://assets/npcs/cidade/capas_chuva/' + nome + '.png'
        manifesto[nome]['quadro_chuva'] = [64, 64]
        manifesto[nome]['margem_chuva'] = [0, 0]
        manifesto[nome]['traje_chuva'] = 'capa'
        print(nome, ': 28 quadros com capa de chuva e capuz')
    caminho_manifesto.write_text(json.dumps(manifesto, ensure_ascii=False, indent='\t') + '\n')
    exportar_previas()


if __name__ == '__main__':
    main()
