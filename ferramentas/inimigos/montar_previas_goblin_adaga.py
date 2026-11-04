"""Exporta contatos e GIFs dos mesmos atlas, quadros e tempos do SpriteFrames."""
from pathlib import Path
import json
import shutil
import sys
from PIL import Image, ImageDraw, ImageFont

RAIZ = Path(__file__).resolve().parents[2]
ASSETS = RAIZ / 'assets/inimigos/goblin_adaga'
DESTINO = RAIZ / 'arte/previas/inimigos/goblin_adaga'


def montar():
    registro = json.loads((ASSETS / 'registro_animacoes.json').read_text())
    fonte = ImageFont.load_default(size=14)
    for nome, ficha in registro['animacoes'].items():
        atlas = Image.open(ASSETS / f'{nome}.png').convert('RGBA')
        poses = []
        quantidade = len(ficha['duracoes_ms'])
        contato = Image.new('RGB', (1280, ((quantidade + 3) // 4) * 352), '#293435')
        for q in range(quantidade):
            x, y = q % ficha["grade"][0] * 640, q // ficha["grade"][0] * 640
            pose = atlas.crop((x, y, x+640, y+640)).resize((320, 320), Image.Resampling.NEAREST)
            quadro = Image.new('RGB', (320, 352), '#293435')
            desenho = ImageDraw.Draw(quadro)
            desenho.line((16, 312, 304, 312), fill='#62745c')
            quadro.paste(pose, (0, 32), pose)
            acao = 'CORRIDA' if nome.startswith('correr') else ('PARADO' if nome.startswith('parado') else ('DANO' if nome.startswith('ferido') else ('MORTE' if nome.startswith('morte') else f'COMBO / GOLPE {q//4+1}')))
            desenho.text((12, 9), f'{acao}   {q+1:02d}   {ficha["duracoes_ms"][q]} ms', font=fonte, fill='#eee7d2')
            poses.append(quadro)
            contato.paste(quadro, (q % 4 * 320, q // 4 * 352))
        contato.save(DESTINO / f'{nome}_contato.png')
        paleta = contato.quantize(colors=255, method=Image.Quantize.MEDIANCUT)
        gif = [pose.quantize(palette=paleta, dither=Image.Dither.NONE) for pose in poses]
        tempos = ficha['duracoes_ms'].copy()
        if nome.startswith('combo'):
            # Pausa de demonstração após o fim; o recurso do motor não repete o combo.
            gif.append(gif[-1].copy())
            tempos.append(250)
        gif[0].save(DESTINO / f'{nome}.gif', save_all=True, append_images=gif[1:],
                    duration=tempos, loop=0, disposal=2, optimize=False)


def montar_motor(origem, direcao='direita'):
    sufixo = '' if direcao == 'direita' else f'_{direcao}'
    shutil.copyfile(origem / 'no-mapa.png', DESTINO / f'no_mapa{sufixo}.png')
    for prefixo, tempos_arquivo, saida in [
        ('reproducao', 'instantes.json', 'reproducao_motor.gif'),
        ('deslocamento', 'instantes_deslocamento.json', 'corrida_deslocamento_motor.gif'),
    ]:
        instantes = json.loads((origem / tempos_arquivo).read_text())
        imagens = []
        for i in range(len(instantes)):
            quadro = Image.open(origem / f'{prefixo}-{i:03d}.png').convert('RGB')
            imagens.append(quadro.resize((quadro.width*2, quadro.height*2), Image.Resampling.NEAREST))
        amostras = imagens[::max(1, len(imagens)//8)]
        contato = Image.new('RGB', (imagens[0].width, imagens[0].height*len(amostras)))
        for i, amostra in enumerate(amostras):
            contato.paste(amostra, (0, i*amostra.height))
        paleta = contato.quantize(colors=255, method=Image.Quantize.MEDIANCUT)
        gif = [im.quantize(palette=paleta, dither=Image.Dither.NONE) for im in imagens]
        tempos = [max(10, round((b-a)*100)*10) for a, b in zip(instantes, instantes[1:])]
        tempos.append(40)
        saida = Path(saida)
        gif[0].save(DESTINO / f'{saida.stem}{sufixo}{saida.suffix}', save_all=True, append_images=gif[1:],
                    duration=tempos, loop=0, disposal=2, optimize=False)


def montar_combos_quatro_direcoes():
    registro = json.loads((ASSETS / 'registro_animacoes.json').read_text())
    direcoes = ['direita', 'esquerda', 'baixo', 'cima']
    atlas = {d: Image.open(ASSETS / f'combo_{d}.png').convert('RGBA') for d in direcoes}
    imagens = []
    for q in range(12):
        quadro = Image.new('RGB', (640, 704), '#293435')
        desenho = ImageDraw.Draw(quadro)
        for j, d in enumerate(direcoes):
            x, y = j % 2 * 320, j // 2 * 352
            desenho.text((x+12, y+9), f'{d.upper()} / GOLPE {q//4+1}', fill='#eee7d2')
            pose = atlas[d].crop((q % 4 * 640, q // 4 * 640, (q % 4+1)*640, (q // 4+1)*640)).resize((320, 320), Image.Resampling.NEAREST)
            quadro.paste(pose, (x, y+32), pose)
        imagens.append(quadro)
    contato = Image.new('RGB', (640*3, 704*4), '#293435')
    for q, quadro in enumerate(imagens):
        contato.paste(quadro, (q % 3*640, q // 3*704))
    paleta = contato.quantize(colors=255, method=Image.Quantize.MEDIANCUT)
    gif = [im.quantize(palette=paleta, dither=Image.Dither.NONE) for im in imagens]
    tempos = registro['animacoes']['combo_direita']['duracoes_ms'].copy()
    tempos[-1] += 250  # Pausa demonstrativa após encerrar; não altera o recurso.
    gif[0].save(DESTINO / 'combos_efeito_quatro_direcoes.gif', save_all=True,
                append_images=gif[1:], duration=tempos, loop=0, disposal=2, optimize=False)


def montar_mortes_quatro_direcoes():
    registro = json.loads((ASSETS / 'registro_animacoes.json').read_text())
    if 'morte_direita' not in registro['animacoes']:
        return
    direcoes = ['direita', 'esquerda', 'baixo', 'cima']
    atlas = {d: Image.open(ASSETS / f'morte_{d}.png').convert('RGBA') for d in direcoes}
    imagens = []
    for q in range(8):
        quadro = Image.new('RGB', (640,704), '#293435')
        desenho = ImageDraw.Draw(quadro)
        for j,d in enumerate(direcoes):
            x,y = j%2*320,j//2*352
            desenho.text((x+12,y+9), f'{d.upper()} / MORTE', fill='#eee7d2')
            pose = atlas[d].crop((q%4*640,q//4*640,(q%4+1)*640,(q//4+1)*640)).resize((320,320),Image.Resampling.NEAREST)
            quadro.paste(pose,(x,y+32),pose)
        imagens.append(quadro)
    contato = Image.new('RGB',(640*8,704),'#293435')
    for q,quadro in enumerate(imagens): contato.paste(quadro,(q*640,0))
    paleta = contato.quantize(colors=255,method=Image.Quantize.MEDIANCUT)
    gif = [im.quantize(palette=paleta,dither=Image.Dither.NONE) for im in imagens]
    tempos = registro['animacoes']['morte_direita']['duracoes_ms'].copy()
    tempos[-1] += 700  # Pausa demonstrativa; o visual segura o último quadro.
    gif[0].save(DESTINO / 'morte_quatro_direcoes.gif',save_all=True,append_images=gif[1:],duration=tempos,loop=0,disposal=2,optimize=False)


if __name__ == '__main__':
    montar()
    montar_combos_quatro_direcoes()
    montar_mortes_quatro_direcoes()
    if '--motor' in sys.argv:
        direcao = next((a.split('=', 1)[1] for a in sys.argv if a.startswith('--direcao=')), 'direita')
        if direcao not in ('direita', 'baixo', 'cima', 'esquerda'):
            raise ValueError('Direção não preparada')
        sufixo = '' if direcao == 'direita' else f'-{direcao}'
        montar_motor(Path(f'/tmp/algoland-adaga-reproducao{sufixo}'), direcao)
