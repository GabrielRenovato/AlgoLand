#!/usr/bin/env python3
"""Compõe os 28 quadros de chuva por morador com a arte direcional preservada.
Os corpos mantêm escala, pivô, roupas e passos originais; a célula maior acomoda o guarda-chuva.
"""
from pathlib import Path
import colorsys
import json
from PIL import Image, ImageDraw

RAIZ = Path(__file__).resolve().parents[2]
FONTES = RAIZ / 'arte/fontes/npcs/guarda_chuva'
SAIDA = RAIZ / 'assets/npcs/cidade/chuva'
CORES = {'tomas': '#bb7750', 'rosa': '#78985a', 'caio': '#548bb1',
         'estela': '#9374ae', 'lia': '#ba647d', 'bento': '#b29b50'}
DIRECOES = ['baixo', 'direita', 'cima', 'esquerda']
# Posição da haste nas quatro vistas recortadas, antes de inserir o trecho reto.
HASTES = [17, 17, 17, 17]


def acessorios():
    original = Image.open(FONTES / 'original.png').convert('RGBA')
    original.putalpha(original.getchannel('A').point(lambda a: 255 if a >= 128 else 0))
    resultado = []
    for i in range(4):
        # A copa é radial e permanece nivelada quando o morador vira o corpo.
        # As vistas laterais inclinadas da geração são apenas referências, não quadros do jogo.
        q = original.crop((0, 0, original.width // 4, original.height))
        q = q.crop(q.getbbox())
        q = q.resize((round(q.width * 32 / q.height), 32), Image.Resampling.NEAREST)
        # Mais espaço entre a copa e a mão, sem aumentar a copa em relação ao personagem.
        novo = Image.new('RGBA', (q.width, 44))
        novo.alpha_composite(q.crop((0, 0, q.width, 22)), (0, 0))
        for y in range(22, 34):
            novo.alpha_composite(q.crop((0, 21, q.width, 22)), (0, y))
        novo.alpha_composite(q.crop((0, 22, q.width, 32)), (0, 34))
        resultado.append(novo)
    return resultado


def tingir(imagem, cor):
    nova = imagem.copy()
    rgb = tuple(int(cor[i:i + 2], 16) / 255 for i in (1, 3, 5))
    matiz, saturacao, _ = colorsys.rgb_to_hsv(*rgb)
    for y in range(imagem.height):
        for x in range(imagem.width):
            r, g, b, a = imagem.getpixel((x, y))
            # Tecido azul; ferragens douradas e cabo preservam suas cores.
            if a and b > r * 1.05 and g > r:
                _, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
                novo = colorsys.hsv_to_rgb(matiz, min(0.75, s * (0.6 + saturacao)), v)
                nova.putpixel((x, y), tuple(round(c * 255) for c in novo) + (255,))
    return nova


# Âncoras conferidas por quadro: não estimar a posição da mão pelo corpo.

def compor(quadro, guarda, linha, mao):
    tela = Image.new('RGBA', (96, 96))
    # A haste é transladada inteira pelo deslocamento real da mão. A copa nunca gira ou deforma.
    pos_guarda = (16 + mao[0] - HASTES[linha], 16 + mao[1] - 38)
    if linha == 2:
        tela.alpha_composite(guarda, pos_guarda)
    tela.alpha_composite(quadro, (16, 16))
    if linha != 2:
        tela.alpha_composite(guarda, pos_guarda)
    # A palma e o punho originais passam à frente do cabo no ponto de contato.
    x, y = mao
    tela.alpha_composite(quadro.crop((x - 1, y - 1, x + 2, y + 2)), (16 + x - 1, 16 + y - 1))
    return tela


def main():
    SAIDA.mkdir(parents=True, exist_ok=True)
    manifesto_caminho = RAIZ / 'assets/npcs/cidade/manifesto.json'
    manifesto = json.loads(manifesto_caminho.read_text())
    guardas = acessorios()
    maos_por_quadro = json.loads((FONTES / "ancoras_maos.json").read_text())["moradores"]
    for nome, cor in CORES.items():
        original = Image.open(RAIZ / 'assets/npcs/cidade' / (nome + '.png')).convert('RGBA')
        folha = Image.new('RGBA', (7 * 96, 4 * 96))
        pasta = SAIDA / nome
        pasta.mkdir(exist_ok=True)
        ancoras = []
        for linha in range(4):
            guarda = tingir(guardas[linha], cor)
            ancoras_linha = []
            for coluna in range(7):
                quadro = original.crop((coluna * 64, linha * 64, (coluna + 1) * 64, (linha + 1) * 64))
                mao = tuple(maos_por_quadro[nome][linha][coluna])
                assert quadro.getpixel(mao)[3] > 0, (nome, linha, coluna, mao)
                ancoras_linha.append(list(mao))
                composto = compor(quadro, guarda, linha, mao)
                folha.alpha_composite(composto, (coluna * 96, linha * 96))
                composto.save(pasta / ('%s_%s.png' % (DIRECOES[linha], 'parado' if coluna == 0 else 'andar_%02d' % coluna)))
            ancoras.append(ancoras_linha)
        (pasta / 'ancoras_mao.json').write_text(json.dumps({'direcoes': DIRECOES, 'maos': ancoras, 'apoio_haste': [17, 38], 'margem': [16, 16]}, indent=1) + '\n')
        folha.save(SAIDA / (nome + '.png'))
        manifesto[nome]['folha_chuva'] = 'res://assets/npcs/cidade/chuva/' + nome + '.png'
        manifesto[nome]['quadro_chuva'] = [96, 96]
        manifesto[nome]['margem_chuva'] = [16, 16]
        previa = RAIZ / 'arte/previas/cidade' / ('chuva_' + nome + '.png')
        previa.parent.mkdir(parents=True, exist_ok=True)
        folha.resize((folha.width * 2, folha.height * 2), Image.Resampling.NEAREST).save(previa)
        print(nome, ': 28 quadros de chuva, célula 96 × 96, corpo preservado em escala nativa')
    manifesto_caminho.write_text(json.dumps(manifesto, ensure_ascii=False, indent='\t') + '\n')
    exportar_previas()


def exportar_previas():
    quadros = []
    for coluna in range(1, 7):
        tela = Image.new('RGBA', (6 * 80, 4 * 80), '#29282b')
        for x, nome in enumerate(CORES):
            folha = Image.open(SAIDA / (nome + '.png')).convert('RGBA')
            for y in range(4):
                q = folha.crop((coluna * 96 + 8, y * 96, (coluna + 1) * 96 - 8, y * 96 + 80))
                tela.alpha_composite(q, (x * 80, y * 80))
        quadros.append(tela.resize((960, 640), Image.Resampling.NEAREST))
    pasta = RAIZ / 'arte/previas/cidade'
    quadros[0].save(pasta / 'moradores_chuva_quadros.png')
    quadros[0].save(pasta / 'moradores_chuva_mao.gif', save_all=True,
                   append_images=quadros[1:], duration=125, loop=0, disposal=2)


if __name__ == '__main__':
    main()
