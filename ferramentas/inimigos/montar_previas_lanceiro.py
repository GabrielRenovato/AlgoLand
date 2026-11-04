"""Formata prévias dos atlas exportados, sem modificar a arte consumida pelo jogo."""
from pathlib import Path
import json
from PIL import Image, ImageDraw

RAIZ = Path(__file__).resolve().parents[2]
ATLAS = RAIZ / 'assets/inimigos/goblins_moinho/lanceiro'
SAIDA = RAIZ / 'arte/previas/inimigos/goblins_moinho/lanceiro'
DIRECOES = ['baixo', 'direita', 'cima', 'esquerda']


def montar():
    registro = json.loads((ATLAS / 'registro.json').read_text())
    quadros = {}
    for acao in ['andar', 'ataque']:
        contato = Image.new('RGB', (1536, 4 * 224), '#303739')
        desenho = ImageDraw.Draw(contato)
        for linha, direcao in enumerate(DIRECOES):
            nome = f'{acao}_{direcao}'
            atlas = Image.open(ATLAS / f'{nome}.png').convert('RGBA')
            poses = []
            for q in range(6):
                # Recorte fixo em todos os quadros: não esconde deslocamentos de pivô.
                pose = atlas.crop((q * 256, 56, (q + 1) * 256, 256))
                fundo = Image.new('RGB', (256, 200), '#303739')
                fundo.paste(pose, (0, 0), pose)
                poses.append(fundo)
                contato.paste(fundo, (q * 256, linha * 224 + 24))
                desenho.text((q * 256 + 8, linha * 224 + 7), f'{acao} {direcao} / {q + 1}', fill='white')
            quadros[nome] = poses
            duracoes = registro[nome]['duracoes_ms']
            poses[0].save(SAIDA / f'{nome}.gif', save_all=True, append_images=poses[1:], duration=duracoes, loop=0)
        contato.save(SAIDA / f'{acao}-contato.jpg', quality=95)
    demonstracao, tempos = [], []
    for acao, repeticoes in [('andar', 2), ('ataque', 1)]:
        for _ in range(repeticoes):
            for q in range(6):
                quadro = Image.new('RGB', (512, 448), '#303739')
                desenho = ImageDraw.Draw(quadro)
                for i, direcao in enumerate(DIRECOES):
                    x, y = i % 2 * 256, i // 2 * 224
                    quadro.paste(quadros[f'{acao}_{direcao}'][q], (x, y + 24))
                    desenho.text((x + 8, y + 7), f'{direcao.upper()} / {acao}', fill='white')
                demonstracao.append(quadro)
                tempos.append(registro[f'{acao}_baixo']['duracoes_ms'][q])
    demonstracao[0].save(SAIDA / 'lanceiro-quatro-direcoes.gif', save_all=True, append_images=demonstracao[1:], duration=tempos, loop=0)


if __name__ == '__main__':
    montar()
