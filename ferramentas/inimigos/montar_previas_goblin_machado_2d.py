"""Exporta contatos e GIFs dos mesmos atlas, quadros e tempos do SpriteFrames."""
from pathlib import Path
import json
import shutil
import sys
from PIL import Image, ImageDraw, ImageFont

RAIZ = Path(__file__).resolve().parents[2]
ASSETS = RAIZ / 'assets/inimigos/goblin_machado_2d'
DESTINO = RAIZ / 'arte/previas/inimigos/goblin_machado_2d'


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
            acao = 'CORRIDA' if nome.startswith('correr') else ('PARADO' if nome.startswith('parado') else ('DANO' if nome.startswith('ferido') else ('MORTE' if nome.startswith('morte') else 'ATAQUE')))
            desenho.text((12, 9), f'{acao}   {q+1:02d}   {ficha["duracoes_ms"][q]} ms', font=fonte, fill='#eee7d2')
            poses.append(quadro)
            contato.paste(quadro, (q % 4 * 320, q // 4 * 352))
        contato.save(DESTINO / f'{nome}_contato.png')
        paleta = contato.quantize(colors=255, method=Image.Quantize.MEDIANCUT)
        gif = [pose.quantize(palette=paleta, dither=Image.Dither.NONE) for pose in poses]
        tempos = ficha['duracoes_ms'].copy()
        if nome.startswith('ataque'):
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
        if not (origem / tempos_arquivo).exists():
            continue
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


def montar_dano_morte():
    registro = json.loads((ASSETS / 'registro_animacoes.json').read_text())
    if 'morte_direita' not in registro['animacoes']:
        return
    direcoes = ['direita', 'esquerda', 'baixo', 'cima']
    atlas = {}
    def pose(acao, direcao, q):
        nome = f'{acao}_{direcao}'
        if acao == 'parado':
            nome, q = (f'ferido_{direcao}', 3) if direcao == 'esquerda' else (f'ataque_{direcao}', 7)
        if nome not in atlas:
            atlas[nome] = Image.open(ASSETS / f'{nome}.png').convert('RGBA')
        return atlas[nome].crop((q%4*640, q//4*640, (q%4+1)*640, (q//4+1)*640)).resize((320, 320), Image.Resampling.NEAREST)
    sequencia = [('parado', 0, 200)]
    for acao in ['ferido', 'morte']:
        tempos = registro['animacoes'][f'{acao}_direita']['duracoes_ms']
        sequencia.extend((acao, q, t) for q, t in enumerate(tempos))
        if acao == 'ferido':
            sequencia.append(('parado', 0, 250))
    imagens = []
    for acao, q, _ in sequencia:
        quadro = Image.new('RGB', (640,704), '#293435')
        desenho = ImageDraw.Draw(quadro)
        for i, d in enumerate(direcoes):
            x, y = i%2*320, i//2*352
            desenho.text((x+12,y+9), f'{d.upper()} / {acao.upper()}', fill='#eee7d2')
            p = pose(acao,d,q)
            quadro.paste(p,(x,y+32),p)
        imagens.append(quadro)
    amostras = Image.new('RGB',(640*len(imagens),704))
    for i, im in enumerate(imagens): amostras.paste(im,(i*640,0))
    paleta = amostras.quantize(colors=255,method=Image.Quantize.MEDIANCUT)
    gif = [im.quantize(palette=paleta,dither=Image.Dither.NONE) for im in imagens]
    tempos = [t for _,_,t in sequencia]
    tempos[-1] += 700  # Segura o corpo na demonstração; no motor permanece indefinidamente.
    gif[0].save(DESTINO / 'dano_morte_quatro_direcoes.gif',save_all=True,append_images=gif[1:],duration=tempos,loop=0,disposal=2,optimize=False)


if __name__ == '__main__':
    montar()
    montar_dano_morte()
    if '--motor' in sys.argv:
        direcao = next((a.split('=', 1)[1] for a in sys.argv if a.startswith('--direcao=')), 'direita')
        if direcao not in ('direita', 'baixo', 'cima', 'esquerda'):
            raise ValueError('Direção não preparada')
        sufixo = '' if direcao == 'direita' else f'-{direcao}'
        montar_motor(Path(f'/tmp/algoland-machado-2d-reproducao{sufixo}'), direcao)
