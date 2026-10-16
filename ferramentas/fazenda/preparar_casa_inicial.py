#!/usr/bin/env python3
"""Prepara a fachada inicial a partir do original preservado, sem chamadas de geração.
Uso: python3 ferramentas/fazenda/preparar_casa_inicial.py
"""
from pathlib import Path
import json
from PIL import Image, ImageDraw

RAIZ = Path(__file__).resolve().parents[2]
FONTE = RAIZ / 'arte/fontes/fazenda/casa_inicial/exterior_original.png'


ESTACOES = ['primavera', 'verao', 'outono', 'inverno']


def variantes_sazonais(original):
    """Floreiras fixas nas janelas; apenas plantas e neve variam entre as estações."""
    variantes = []
    inverno = FONTE.with_name('exterior_inverno_original.png')
    nevada = None
    if inverno.exists():
        nevada = Image.open(inverno).convert('RGBA')
        nevada.putalpha(nevada.getchannel('A').point(lambda a: 255 if a >= 128 else 0))
        nevada = nevada.crop(nevada.getbbox()).resize(original.size, Image.Resampling.NEAREST)
    for estacao in range(4):
        nova = original.copy()
        d = ImageDraw.Draw(nova)
        if estacao == 3:
            # Usa a neve desenhada na referência de inverno somente sobre as telhas.
            # A marcenaria, porta, câmera e alfa do edifício permanecem os da casa original.
            for y in range(52):
                for x in range(original.width):
                    r, g, b, a = original.getpixel((x, y))
                    telha = a and r > g * 1.28 and g > b * 1.25
                    if nevada and telha:
                        nr, ng, nb, na = nevada.getpixel((x, y))
                        if na and min(nr, ng, nb) > 115 and max(nr, ng, nb) - min(nr, ng, nb) < 75:
                            nova.putpixel((x, y), (nr, ng, nb, 255))
            # Capas sobre as superfícies horizontais expostas e a boca da chaminé.
            for x in range(original.width):
                ys = [y for y in range(original.height) if original.getpixel((x, y))[3]]
                if ys:
                    topo = ys[0]
                    for dy in range(2):
                        if original.getpixel((x, topo + dy))[3]:
                            nova.putpixel((x, topo + dy), (227, 238, 241, 255) if dy == 0 else (167, 193, 210, 255))
        for centro in [28, 84]:
            # As duas caixas são parte da casa e não mudam de posição entre estações.
            d.rectangle((centro - 9, 73, centro + 9, 77), fill='#523b2c')
            d.line((centro - 8, 74, centro + 8, 74), fill='#b58752')
            d.line((centro - 7, 76, centro + 7, 76), fill='#805237')
            if estacao == 3:
                d.line((centro - 9, 72, centro + 9, 72), fill='#e3eef1')
                d.line((centro - 8, 73, centro + 8, 73), fill='#a7c1d2')
                continue
            escura, clara, flor = [('#3f5735', '#829453', '#e8a7b8'),
                                   ('#334d2e', '#70984b', '#f1cf67'),
                                   ('#68472e', '#b28546', '#cc884a')][estacao]
            for i, dx in enumerate([-7, -3, 2, 6]):
                y = 70 - i % 2
                d.line((centro + dx, 73, centro + dx, y), fill=escura)
                d.line((centro + dx - 1, y + 1, centro + dx + 1, y + 1), fill=clara)
                d.point((centro + dx, y - 1), fill=flor)
                if estacao != 2:
                    d.point((centro + dx - 1, y - 1), fill=flor)
        variantes.append(nova)
    return variantes


def exportar_estacoes(imagem):
    caminhos = []
    variantes = variantes_sazonais(imagem)
    for nome, variante in zip(ESTACOES, variantes):
        fonte = RAIZ / 'assets/cenario/fazenda/casa_inicial' / (nome + '.png')
        alvo = RAIZ / 'assets/cenario/cidade/ambientes/fachada/casa_jogador' / (nome + '.png')
        for caminho in [fonte, alvo]:
            caminho.parent.mkdir(parents=True, exist_ok=True)
            variante.save(caminho)
        caminhos.append('res://' + str(alvo.relative_to(RAIZ)))
    manifesto = RAIZ / 'assets/cenario/cidade/ambientes/manifesto.json'
    dados = json.loads(manifesto.read_text())
    dados['fachada/casa_jogador'] = {'texturas': caminhos, 'quadros': 1, 'fps': 0,
                                    'usado': [0, 0, imagem.width, imagem.height], 'escala_origem': 1}
    manifesto.write_text(json.dumps(dados, indent=1, ensure_ascii=False) + '\n')


def main():
    imagem = Image.open(FONTE).convert('RGBA')
    # O original tem resíduos de alfa quase invisíveis fora da casa. Corta só após limpar o alfa.
    imagem.putalpha(imagem.getchannel('A').point(lambda a: 255 if a >= 128 else 0))
    imagem = imagem.crop(imagem.getbbox())
    altura = round(imagem.height * 112 / imagem.width)
    imagem = imagem.resize((112, altura), Image.Resampling.NEAREST)
    alfa = imagem.getchannel('A')
    imagem = imagem.convert('RGB').quantize(colors=48, method=Image.Quantize.MEDIANCUT).convert('RGBA')
    imagem.putalpha(alfa)
    imagem.save(RAIZ / 'assets/cenario/cidade/casas/exterior/casa_jogador.png')
    sombra = Image.new('RGBA', imagem.size, 'white')
    sombra.putalpha(alfa)
    sombra.save(RAIZ / 'assets/cenario/cidade/sombras/casas/casa_jogador.png')
    manifesto = RAIZ / 'assets/cenario/cidade/casas/exteriores.json'
    dados = json.loads(manifesto.read_text())
    dados['casa_jogador'] = {
        'ancora': [56, altura], 'usado': [0, 0, 112, altura],
        # A colisão permanece no Obstaculo1 do terreno, como as demais colisões da fazenda.
        'colisoes': [], 'chamine': [35, -altura + 3], 'janelas': [[-29, -24], [29, -24]],
    }
    manifesto.write_text(json.dumps(dados, indent=1) + '\n')
    exportar_estacoes(imagem)
    print('Fachada inicial em quatro estações: 112 ×', altura)


if __name__ == '__main__':
    main()
