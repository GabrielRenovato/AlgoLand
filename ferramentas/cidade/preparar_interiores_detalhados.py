"""Prepara materiais e móveis pintados4×, preservando as plantas existentes.

Fontes e pedidos: arte/fontes/cidade/interiores_detalhados/catalogo.json.
Não modifica interiores.json, colisões, pontos de atendimento nem assentos.
"""
from pathlib import Path
import json
import math
from PIL import Image, ImageChops, ImageEnhance
from preparar_chao_detalhado import periodizar
from preparar_complementos import salvar

RAIZ = Path(__file__).resolve().parents[2]
FONTES = RAIZ / 'arte/fontes/cidade/interiores_detalhados'
SAIDA = RAIZ / 'assets/cenario/cidade/interiores_detalhados'
ESTACOES = ['primavera', 'verao', 'outono', 'inverno']
ALIASES = {'prateleira_b': 'prateleira', 'mesa_reuniao': 'mesa',
           'barris_caixas': 'barris', 'tapete_corredor': 'tapete',
           'banco_reuniao': 'banqueta', 'cardapio': 'quadro_avisos'}


def recortar(im):
    im = im.convert('RGBA')
    bbox = im.getchannel('A').point(lambda a: 255 if a > 127 else 0).getbbox()
    assert bbox, 'Imagem vazia'
    im = im.crop(bbox)
    im.putalpha(im.getchannel('A').point(lambda a: 0 if a < 24 else a))
    return im


def tom(im, estacao):
    # Materiais abrigados: só exposição/luz ambiente; sem neve nos móveis.
    fatores = [(1, 1, 1), (1.012, 1, .985), (.985, .975, .96), (.965, .985, 1.015)][estacao]
    canais = list(im.split())
    for i, fator in enumerate(fatores):
        canais[i] = canais[i].point(lambda c: min(255, round(c * fator)))
    return Image.merge(im.mode, canais)


def nove_faixas(im, tamanho, borda=12):
    """Muda a proporção do tapete preservando cantos e espessura da borda."""
    w, h = tamanho
    bx, by = min(borda, w // 3), min(borda, h // 3)
    xs, ys = [0, borda, im.width - borda, im.width], [0, borda, im.height - borda, im.height]
    xd, yd = [0, bx, w - bx, w], [0, by, h - by, h]
    out = Image.new('RGBA', tamanho)
    for y in range(3):
        for x in range(3):
            parte = im.crop((xs[x], ys[y], xs[x+1], ys[y+1]))
            if x == 1 and y == 1 and h > w * 2:
                # O corredor recebe medalhões repetidos, mantendo o desenho
                # do tecido em vez de esticar uma flor pela extensão inteira.
                tw = xd[2] - xd[1]
                th = max(1, round(parte.height * tw / parte.width))
                motivo = parte.resize((tw, th), Image.Resampling.LANCZOS)
                for inicio in range(yd[1], yd[2], th):
                    altura = min(th, yd[2] - inicio)
                    out.alpha_composite(motivo.crop((0, 0, tw, altura)), (xd[1], inicio))
                continue
            parte = parte.resize((xd[x+1]-xd[x], yd[y+1]-yd[y]), Image.Resampling.LANCZOS)
            out.alpha_composite(parte, (xd[x], yd[y]))
    return out


def ajustar(original, tamanho, nome):
    if nome in ['tapete', 'tapete_corredor']:
        base = original.resize((224, 160), Image.Resampling.LANCZOS)
        return nove_faixas(base, tamanho)
    if nome in ['mesa', 'mesa_reuniao'] and tamanho[1] < 160:
        # Aproxima a câmera do topo do tampo, conservando a altura das pernas.
        # Pratos servidos pela taverna continuam inteiros sobre a superfície.
        largura, altura = tamanho
        h = round(original.height * largura / original.width)
        corte = round(h * .6)
        base = original.resize((largura, h), Image.Resampling.LANCZOS)
        pernas = base.crop((0, corte, largura, h))
        topo = base.crop((0, 0, largura, corte)).resize((largura, altura-pernas.height), Image.Resampling.LANCZOS)
        out = Image.new('RGBA', tamanho)
        out.alpha_composite(topo)
        out.alpha_composite(pernas, (0, altura-pernas.height))
        return out
    if nome == 'banco_reuniao':
        # Bancos compartilham a madeira da banqueta, conservando as pernas;
        # só a faixa entre elas alonga para o assento de duas pessoas.
        h = tamanho[1]
        base = original.resize((h, h), Image.Resampling.LANCZOS)
        margem = h // 3
        out = Image.new('RGBA', tamanho)
        out.alpha_composite(base.crop((0, 0, margem, h)))
        meio = base.crop((margem, 0, h-margem, h)).resize((tamanho[0]-2*margem, h), Image.Resampling.LANCZOS)
        out.alpha_composite(meio, (margem, 0))
        out.alpha_composite(base.crop((h-margem, 0, h, h)), (tamanho[0]-margem, 0))
        return out
    im = original.copy()
    im.thumbnail((tamanho[0]-4, tamanho[1]-2), Image.Resampling.LANCZOS)
    out = Image.new('RGBA', tamanho)
    out.alpha_composite(im, ((tamanho[0]-im.width)//2, tamanho[1]-im.height))
    return out


def quadro(base, nome, q, e, aquecimento):
    im = base.copy()
    if nome not in ['lareira', 'vela', 'planta', 'ervas', 'pocoes', 'mesa_cristal', 'caldeirao', 'espelho']:
        return im
    pix = im.load()
    fase = q * math.tau / 4
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = base.getpixel((x, y))
            if a < 64:
                continue
            fogo = ((nome == 'lareira' and y > im.height*.4) or (nome == 'vela' and y < im.height*.4)) and r > 190 and r > g*1.25 and g > b*1.7
            brilho = nome in ['pocoes', 'mesa_cristal', 'caldeirao', 'espelho'] and b > r*1.12 and b > g*.9
            folha = nome in ['planta', 'ervas'] and g > r*1.15 and g > b*1.15
            if fogo or brilho or folha:
                f = .92 + .08 * math.sin(fase + x*.06 + y*.12)
                if fogo and aquecimento and e == 1:
                    pix[x, y] = (round(r*.14), round(g*.16), round(b*.18), a)
                else:
                    pix[x, y] = (round(r*f), round(g*f), round(b*f), a)
    return im


def materiais():
    piso = Image.open(FONTES / 'piso.png').convert('RGB').resize((512, 512), Image.Resampling.LANCZOS)
    piso = periodizar(piso)
    parede = Image.open(FONTES / 'parede.png').convert('RGB')
    # O original tem margem de apresentação: recortar somente a moldura de
    # madeira. A margem quadriculada não pertence ao material da parede.
    r, g, b = parede.split()
    mascara = ImageChops.subtract(r, b).point(lambda c: 255 if c > 30 else 0)
    recorte = parede.crop(mascara.getbbox())
    horizontal = recorte.crop((round(recorte.width*.1), round(recorte.height*.055), round(recorte.width*.9), round(recorte.height*.16)))
    horizontal = horizontal.resize((256, 32), Image.Resampling.LANCZOS)
    horizontal = ImageEnhance.Brightness(ImageEnhance.Color(horizontal).enhance(.9)).enhance(.82)
    parede = recorte.resize((256, 128), Image.Resampling.LANCZOS)
    parede = parede.crop((2, 3, 254, 127)).resize((256, 128), Image.Resampling.LANCZOS)
    vertical = horizontal.transpose(Image.Transpose.ROTATE_90)
    janela = recortar(Image.open(FONTES / 'janela.png')).resize((128, 128), Image.Resampling.LANCZOS)
    for e, estacao in enumerate(ESTACOES):
        for nome, im in [('parede', parede), ('horizontal', horizontal), ('vertical', vertical), ('janela', janela)]:
            salvar(tom(im, e), SAIDA / 'materiais' / estacao / (nome + '.png'))
        for nome, brilho in [('medio', .88), ('escuro', .67), ('claro', 1.04)]:
            im = ImageEnhance.Color(ImageEnhance.Brightness(piso).enhance(brilho)).enhance(.86)
            salvar(tom(im, e), SAIDA / 'materiais' / estacao / ('piso_' + nome + '.png'))


def preparar():
    fontes = json.loads((FONTES / 'catalogo.json').read_text())
    ausentes = [r['id'] for r in fontes['recursos'] if not (FONTES / (r['id'] + '.png')).exists()]
    assert not ausentes, 'Fontes pendentes: ' + ', '.join(ausentes)
    materiais()
    layout = json.loads((RAIZ / 'assets/cenario/cidade/interiores/interiores.json').read_text())
    itens = {}
    for casa in layout['casas'].values():
        for item in casa['itens']:
            chave = item['texturas'][0].split('/ambientes/')[1].removesuffix('/primavera.png')
            itens.setdefault(chave, item)
    # A casa inicial também tem móveis definidos na cena, fora do layout.
    for nome, w, h in [('cama', 32, 58), ('estante', 32, 48), ('bau', 32, 26), ('cadeira', 13, 26), ('mesa', 34, 42), ('cafe', 10, 8)]:
        itens['casa_inicial/' + nome] = {'p': nome, 'usado': [0, 0, w, h]}
    itens['acessorios/vela'] = {'p': 'vela', 'usado': [0, 0, 6, 12]}
    for nome, w, h in [('caixas_peixes', 61, 44), ('equipamento_pesca', 45, 46)]:
        itens['palafita/' + nome] = {'p': nome, 'usado': [0, 0, w, h]}
    manifesto = {}
    for chave, item in itens.items():
        nome = item['p']
        canonico = ALIASES.get(nome, nome)
        origem = FONTES / (canonico + '.png')
        if canonico == 'banqueta':
            origem = RAIZ / 'arte/fontes/cidade/enfeites_detalhados/banqueta.png'
        original = recortar(Image.open(origem))
        usado = item['usado']
        tamanho = (int(usado[2])*4, int(usado[3])*4)
        base = ajustar(original, tamanho, nome)
        quadros = 4 if nome in ['lareira', 'vela', 'planta', 'ervas', 'pocoes', 'mesa_cristal', 'caldeirao', 'espelho'] else 1
        caminhos = []
        for e, estacao in enumerate(ESTACOES):
            sazonal = tom(base, e)
            folha = Image.new('RGBA', (tamanho[0]*quadros, tamanho[1]))
            for q in range(quadros):
                frame = quadro(sazonal, nome, q, e, item.get('calor_sazonal', False))
                folha.alpha_composite(frame, (q*tamanho[0], 0))
            caminho = SAIDA / 'moveis' / chave / (estacao + '.png')
            salvar(folha, caminho)
            caminhos.append('res://' + str(caminho.relative_to(RAIZ)))
        manifesto[chave] = {'texturas': caminhos, 'resolucao': 4, 'quadros': quadros,
                            'fps': 4 if nome == 'lareira' else (2 if quadros > 1 else 0),
                            'canvas_logico': list(usado[2:4]), 'fonte': str(origem.relative_to(RAIZ))}
    (SAIDA / 'manifesto.json').write_text(json.dumps(manifesto, ensure_ascii=False, indent=1) + '\n')
    print(f'Interiores: {len(manifesto)} móveis4×, sete materiais, quatro estações; plantas preservadas.')


if __name__ == '__main__':
    preparar()
