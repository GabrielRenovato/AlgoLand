#!/usr/bin/env python3
"""Layout da decoração da vila. Gera assets/cenario/cidade/decoracao/decoracao.json (lido por codigo/cidade/decoracao_vila.gd).
Cada peça é posta pela base-centro (x, y no mapa da cidade, 704x576); o retângulo com pixels da imagem vem de
medidas_decoracao.json (ferramentas/cidade/medir_decoracao.gd). Uso: python3 ferramentas/cidade/layout_decoracao.py
"""
from pathlib import Path
import json

RAIZ = Path(__file__).resolve().parents[2]
SAIDA = RAIZ / 'assets/cenario/cidade/decoracao/decoracao.json'
MEDIDAS = json.loads((Path(__file__).parent / 'medidas_decoracao.json').read_text())
AMBIENTES = json.loads((RAIZ / 'assets/cenario/cidade/ambientes/manifesto.json').read_text())
for chave, dados in AMBIENTES.items():
    if chave.startswith('externo/'):
        nome = chave.split('/')[-1]
        MEDIDAS[nome] = [dados['usado'][2], dados['usado'][3], *dados['usado']]

LAMPIAO = '#ffcf7a'

# Guardadas para reutilização; não entram no layout ativo. Os sprites e as máscaras
# de sombra também permanecem em assets/cenario/cidade.
BARRACAS_RESERVADAS = [
    ('feira_a', 202, 180, {'col': [44, 10], 'fixar': True}),
    ('feira_b', 202, 244, {'col': [44, 10], 'fixar': True}),
]

# (imagem, x, y, opções). Opções: sazonal (a imagem tem uma versão por estação: <nome>_primavera/verao/outono/inverno.png),
# estacoes (lista de estações em que aparece), z_fixo (profundidade fixa, para peças no chão como a ponte), col [l, a] (padrão: 70% da largura usada x 8), luz [dx, dy, cor, escala, energia],
# animacao {quadros, fps, largura, altura}, espelhar, sem_col, medida (nome da imagem de onde vêm as medidas)
ITENS = [
    # A praça mantém livres os eixos de circulação e a frente do mural.
    ('fonte_anim', 336, 284, {'medida': 'fonte', 'col': [90, 48], 'animacao': {'quadros': 9, 'fps': 7, 'largura': 96, 'altura': 96}}),
    ('mural', 384, 346, {'col': [34, 8]}),
    ('poste_luz', 252, 240, {'col': [8, 6], 'luz': [0, -46, LAMPIAO, 1.1, 0.9]}),
    ('poste_luz', 420, 240, {'col': [8, 6], 'luz': [0, -46, LAMPIAO, 1.1, 0.9]}),
    ('poste_luz', 252, 326, {'col': [8, 6], 'luz': [0, -46, LAMPIAO, 1.1, 0.9]}),
    ('poste_luz', 420, 326, {'col': [8, 6], 'luz': [0, -46, LAMPIAO, 1.1, 0.9]}),
    ('placa_encruzilhada', 448, 244, {'col': [10, 6]}),
    ('ponte', 676, 298, {'z_fixo': -995, 'sem_col': True}),
    # O comércio fica na venda do Tomás; não há barracas sem interação.
    # Coreto e área de descanso formam o entorno da pousada.
    ('coreto', 448, 404, {'col': [72, 16]}),
    ('poste_luz', 180, 482, {'col': [8, 6], 'luz': [0, -46, LAMPIAO, 1.1, 0.9]}),
    ('poste_luz', 500, 482, {'col': [8, 6], 'luz': [0, -46, LAMPIAO, 1.1, 0.9]}),
    # Quintal rural: canteiro e galinheiro dentro da cerca, feno junto ao depósito.
    ('horta', 64, 522, {'col': [48, 10]}),
    ('galinheiro', 132, 524, {'col': [32, 10]}),
    ('galinha', 160, 536, {'sem_col': True, 'estacoes': [0, 1, 2]}),
    ('feno', 196, 538, {'col': [36, 10], 'estacoes': [2]}),
    ('lenha', 272, 496, {'col': [48, 10], 'estacoes': [2, 3]}),
    # A cerca contínua de LimitesVila já fecha este quintal em y=560.
    # Peças soltas aqui duplicavam postes e travessas sobre esse mesmo limite.
    # Bancos junto ao lago; a mesa fica no gramado entre o quintal e o parque.
    ('banco', 380, 500, {'col': [38, 8], 'assento': True}),
    # Piquenique a leste do lago: três objetos separados, com espaço entre os pés.
    ('mesa_piquenique', 576, 554, {'col': [40, 12], 'estacoes': [0, 1, 2], 'fixar': True}),
    ('banco_piquenique_esquerdo', 538, 552, {'col': [10, 8], 'assento': True, 'lado_assento': 1, 'estacoes': [0, 1, 2], 'fixar': True}),
    ('banco_piquenique_direito', 614, 552, {'col': [10, 8], 'assento': True, 'lado_assento': -1, 'estacoes': [0, 1, 2], 'fixar': True}),
    # Flores cultivadas junto à enfermaria e no parque, com repouso no inverno.
    ('canteiro', 600, 120, {'col': [44, 8]}),
]



CATEGORIAS = {
    'vegetacao': ['arvore', 'arbusto', 'flores', 'pedras', 'tufos', 'folhas', 'pedras_trilha', 'chao_grama_escura', 'chao_grama_clara',
                  'chao_tufos_altos', 'chao_trevos', 'chao_terra_marcada', 'chao_pedrinhas'],
    'construcoes': ['coreto', 'ponte', 'fonte', 'fonte_anim'],
}


def vegetacao_fixa():
    """Árvores do parque e arbustos ao lado das casas (a moldura de floresta vem de bordas_de_arvores)"""
    return [
        *[('arvore', x, y, {'sazonal': True, 'medida': 'arvore_primavera', 'col': [16, 10]}) for x, y in
          [(320, 554), (610, 566)]],
        *[('arbusto', x, y, {'sazonal': True, 'medida': 'arbusto_primavera', 'col': [22, 8]}) for x, y in
          [(236, 320), (444, 320), (536, 300), (340, 484)]],
    ]


def pasta(nome):
    for categoria, nomes in CATEGORIAS.items():
        if nome in nomes:
            return categoria
    return 'mobiliario'


def bordas_de_arvores():
    """Moldura de floresta em volta da vila (árvores e arbustos), longe das casas, entradas, ponte e portal (sorteio fixo)"""
    import random
    import sys
    sys.path.insert(0, str(Path(__file__).parent))
    import terreno_vila as TV
    predios = json.loads((RAIZ / 'codigo/cidade/layout_vila.json').read_text())['predios']
    rng = random.Random(7)
    livres = [(20, 272, 60), (488, 112, 56), (676, 272, 60), (336, 272, 110), (440, 530, 92)]
    fixos = [(i[1], i[2]) for i in globals().get('ITENS_ESPACADOS', ITENS)]
    candidatos = []
    # Duas fileiras em cima e embaixo e uma em cada lado (a do leste fica antes do rio)
    for x in range(10, 660, 40):
        candidatos += [(x + rng.randrange(-8, 8), 18 + rng.randrange(0, 10)), (x + 20 + rng.randrange(-8, 8), 70 + rng.randrange(0, 14)),
                       (x + rng.randrange(-8, 8), 572 - rng.randrange(0, 8))]
    for y in range(100, 560, 44):
        candidatos += [(12 + rng.randrange(0, 10), y + rng.randrange(-8, 8)), (636 + rng.randrange(-4, 4), y + rng.randrange(-8, 8))]
    achados = []
    for x, y in candidatos:
        if any(abs(x - ax) < 40 and abs(y - ay) < 30 for ax, ay in fixos + achados):
            continue
        if any(((x - lx) ** 2 + (y - ly) ** 2) ** 0.5 < r for lx, ly, r in livres):
            continue
        if any(abs(x - p['base'][0]) < 120 and -40 < y - p['base'][1] < 60 for p in predios.values()):
            continue
        if any(TV.terreno(x + dx, y, predios) != 'grama' for dx in (-16, 16)):
            continue
        achados.append((x, y))
    saida = []
    for i, (x, y) in enumerate(achados):
        if i % 4 == 3:
            saida.append(('arbusto', x, y, {'sazonal': True, 'medida': 'arbusto_primavera', 'col': [22, 8]}))
        else:
            saida.append(('arvore', x, y, {'sazonal': True, 'medida': 'arvore_primavera', 'col': [16, 10]}))
    return saida


def _predios():
    return json.loads((RAIZ / 'codigo/cidade/layout_vila.json').read_text())['predios']


def _casas():
    """Retângulos ocupados pelas casas, pela frente de cada porta e pela placa com o nome (mapa da cidade)"""
    ext = json.loads((RAIZ / 'assets/cenario/cidade/casas/exteriores.json').read_text())
    predios = _predios()
    retangulos = []
    for k, v in ext.items():
        bx, by = predios[k]['base']
        ax, ay = v['ancora']
        ux, uy, uw, uh = v['usado']
        retangulos.append((bx - ax + ux, by - ay + uy, bx - ax + ux + uw, by - ay + uy + uh))
        retangulos.append((bx - 18, by - 2, bx + 18, by + 46))
        placa = v['placa']
        px, py = bx + placa['pos'][0], by + placa['pos'][1]
        if placa.get('poste', True):
            tw, th = placa['tamanho']
            retangulos.append((px - 26, py - th, px + 26, py + 11))
        else:
            retangulos.append((px - 26, py, px + 26, py + 10))
    return retangulos


FIXOS = {'fonte_anim', 'coreto', 'placa_encruzilhada', 'mural', 'ponte', 'poste_luz'}
FOLGA = 5


def _retangulo(nome, x, y, usado):
    ux, uy, uw, uh = usado
    if nome in ('arvore', 'arbusto'):
        # A copa pode encostar na vizinha: só o tronco e a parte de baixo contam
        uw, uh = uw * 0.4, uh * 0.45
    return (x - uw / 2, y - uh, x + uw / 2, y)


def _bate(a, b, folga=FOLGA):
    return a[0] < b[2] + folga and a[2] + folga > b[0] and a[1] < b[3] + folga and a[3] + folga > b[1]


def _no_caminho(x, y, largura=12, altura=1):
    """A base da peça não pode ficar na água nem no meio de rua, praça ou calçada (a fonte e a ponte são exceção: fixas)"""
    import sys
    sys.path.insert(0, str(Path(__file__).parent))
    import terreno_vila as TV
    predios = _predios()
    return any(TV.terreno(x + dx, y - dy, predios) != 'grama'
               for dx in (-largura / 2, 0, largura / 2) for dy in (0, altura / 2, altura))


def espacar(itens):
    """Nenhuma peça fica em cima da outra: cada uma vai para a posição livre mais próxima da desejada (ou sai, se não há)"""
    ocupados = _casas()
    aceitos = []
    saida = []
    deslocamentos = sorted(((dx, dy) for dx in range(-60, 61, 6) for dy in range(-60, 61, 6)), key=lambda d: d[0] ** 2 + d[1] ** 2)
    for item in itens:
        nome, x, y, o = item
        medida = nome if 'externo/' + nome in AMBIENTES else o.get('medida', nome)
        usado = MEDIDAS[medida][2:6]
        raio = 0 if nome in FIXOS or o.get('fixar') else (24 if nome in ('arvore', 'arbusto') else 60)
        colocado = None
        if nome in FIXOS:
            # Peças que definem a vila ficam onde foram postas (o coreto pode cobrir um canto da sede, por exemplo)
            ret = _retangulo(nome, x, y, usado)
            aceitos.append(ret)
            saida.append(item)
            continue
        for dx, dy in deslocamentos:
            if dx * dx + dy * dy > raio * raio * 2:
                break
            ret = _retangulo(nome, x + dx, y + dy, usado)
            if ret[0] < 6 or ret[2] > 698 or ret[3] > 570:
                continue
            if any(_bate(ret, r) for r in ocupados + aceitos):
                continue
            col = o.get('col', [round(usado[2] * 0.7), 8])
            if _no_caminho(x + dx, y + dy, col[0], col[1]):
                continue
            colocado = (x + dx, y + dy, ret)
            break
        if colocado is None:
            if o.get('fixar'):
                raise ValueError(f'Grupo planejado sem espaço: {nome} em ({x}, {y})')
            print('  sem espaço, removido:', nome, x, y)
            continue
        aceitos.append(colocado[2])
        saida.append((nome, colocado[0], colocado[1], o))
    return saida, ocupados + aceitos


def detalhes_chao(ocupados):
    """Camada de detalhes no chão (manchas de grama escura e clara, tufos altos, trevos; na terra, manchas e pedrinhas), cada um
    no lugar onde faria sentido: grama escura na sombra (troncos, casas, borda da floresta), clara no campo aberto, tufos na beira
    das ruas e no pé dos objetos, terra marcada no meio das ruas e pedrinhas nas beiradas. Uma peça só entra se o desenho
    inteiro couber no terreno certo. As versões de estação vêm de tingir_sazonal.gd"""
    import random
    import sys
    sys.path.insert(0, str(Path(__file__).parent))
    import terreno_vila as TV
    predios = _predios()
    rng = random.Random(2026)
    ext = json.loads((RAIZ / 'assets/cenario/cidade/casas/exteriores.json').read_text())
    casas = []
    for k, v in ext.items():
        bx, by = predios[k]['base']
        ax, ay = v['ancora']
        ux, uy, uw, uh = v['usado']
        casas.append((bx - ax + ux, by - ay + uy, bx - ax + ux + uw, by - ay + uy + uh))
    arvores = [(i[1], i[2]) for i in globals().get('VEGETACAO_FINAL', []) if i[0] in ('arvore', 'arbusto')]
    pes = [(i[1], i[2]) for i in globals().get('ITENS_ESPACADOS', []) if i[0] in ('cerca', 'poste_luz', 'banco', 'mural', 'galinheiro', 'feno', 'lenha', 'barril_agua', 'placa_encruzilhada')]

    def cabe(nome, x, y, tipo):
        ux, uy, uw, uh = MEDIDAS[nome + ('_primavera' if nome != 'chao_trevos' else '')][2:6]
        for px in (x - uw / 2 + 2, x, x + uw / 2 - 2):
            for py in (y - uh + 2, y - uh / 2, y - 1):
                if TV.terreno(px, py, predios) != tipo:
                    return False
        ret = (x - uw / 2, y - uh, x + uw / 2, y)
        return not any(_bate(ret, c, -4) for c in casas)

    def perto(x, y, pontos, raio):
        return any((x - px) ** 2 + (y - py) ** 2 < raio * raio for px, py in pontos)

    def junto_de_casa(x, y):
        return any(c[0] - 24 < x < c[2] + 24 and c[3] - 10 < y < c[3] + 26 for c in casas)

    def beira_de_rua(x, y):
        return any(TV.terreno(x + dx, y + dy, predios) == 'terra' for dx in (-22, 0, 22) for dy in (-18, 0, 14))

    def meio_da_rua(x, y):
        return all(TV.terreno(x + dx, y + dy, predios) == 'terra' for dx in (-30, 30) for dy in (-26, 14))

    regras = [
        ('chao_grama_escura', 'grama', 0, lambda x, y: perto(x, y, arvores, 46) or junto_de_casa(x, y) or x < 70 or x > 600 or y < 80 or y > 540),
        ('chao_grama_clara', 'grama', 0, lambda x, y: not perto(x, y, arvores, 50) and not junto_de_casa(x, y) and not beira_de_rua(x, y)),
        ('chao_tufos_altos', 'grama', 0, lambda x, y: beira_de_rua(x, y) or perto(x, y, pes, 34)),
        ('chao_trevos', 'grama', 0, lambda x, y: not beira_de_rua(x, y)),
        ('chao_terra_marcada', 'terra', 0, meio_da_rua),
        ('chao_pedrinhas', 'terra', 0, lambda x, y: not meio_da_rua(x, y)),
    ]
    itens = []
    for nome, tipo, quantos, onde in regras:
        postos = []
        for _ in range(quantos * 120):
            if len(postos) >= quantos:
                break
            x, y = rng.randrange(8, 660), rng.randrange(24, 572)
            if not onde(x, y) or not cabe(nome, x, y, tipo):
                continue
            if perto(x, y, postos, 26):
                continue
            postos.append((x, y))
            opcoes = {'sem_col': True, 'z_fixo': -994, 'espelhar': rng.random() < 0.5}
            if nome == 'chao_trevos':
                opcoes['estacoes'] = [0, 1]
            else:
                opcoes['sazonal'] = True
                opcoes['medida'] = nome + '_primavera'
            itens.append((nome, x, y, opcoes))
    return itens


def chao_aconchegante():
    """O clima cuida das folhas; não desenhar trilhas soltas sem destino."""
    return []


def flores():
    """Flores espalhadas só na grama aberta, longe das casas e das outras peças (sorteio fixo)"""
    import random
    import sys
    sys.path.insert(0, str(Path(__file__).parent))
    import terreno_vila as TV
    predios = json.loads((RAIZ / 'codigo/cidade/layout_vila.json').read_text())['predios']
    rng = random.Random(1401026)
    ocupados = [(i[1], i[2]) for i in globals().get('ITENS_ESPACADOS', ITENS)]
    achados = []
    # Canteiros da enfermaria e do parque, em vez de sortear flores pela vila inteira.
    for x, y in [(620, 350), (592, 346), (360, 492), (570, 536)]:
        if any(TV.terreno(x + dx, y + dy, predios) != 'grama' for dx in (-14, 14) for dy in (-10, 6)):
            continue
        if any(abs(x - bx) < 90 and -30 < y - by < 14 and True for bx, by in [(p['base'][0], p['base'][1]) for p in predios.values()]):
            continue
        if any(abs(x - ox) < 36 and abs(y - oy) < 30 for ox, oy in ocupados + achados):
            continue
        achados.append((x, y))
        if len(achados) >= 8:
            break
    return [('flores', x, y, {'sem_col': True, 'estacoes': [0, 1, 2], 'z_fixo': -990}) for x, y in achados]


def livres_de(itens, ocupados):
    return [i for i in itens if not any(_bate(_retangulo(i[0], i[1], i[2], MEMEDIDA(i)), r, 2) for r in ocupados)]


def MEMEDIDA(item):
    return MEDIDAS[item[0] if 'externo/' + item[0] in AMBIENTES else item[3].get('medida', item[0])][2:6]


def montar(item):
    nome, x, y, o = item
    medida = nome if 'externo/' + nome in AMBIENTES else o.get('medida', nome)
    ux, uy, uw, uh = MEDIDAS[medida][2:6]
    saida = {'p': pasta(nome.replace('_anim', '') if nome.endswith('_anim') else nome) + '/' + nome, 'x': x, 'y': y, 'usado': [ux, uy, uw, uh]}
    if o.get('col'):
        saida['col'] = o['col']
    elif not o.get('sem_col'):
        saida['col'] = [round(uw * 0.7), 8]
    for chave in ('luz', 'animacao', 'espelhar', 'z_extra', 'sazonal', 'estacoes', 'z_fixo', 'assento', 'lado_assento'):
        if o.get(chave):
            saida[chave] = o[chave]
    if 'externo/' + nome in AMBIENTES:
        saida.update(AMBIENTES['externo/' + nome])
        saida.pop('sazonal', None)
    return saida


def itens_finais():
    # Primeiro o que define a vila (praça, comércio, mobília), depois as árvores fixas, a moldura de floresta e as flores
    objetos, ocupados = espacar(ITENS)
    global ITENS_ESPACADOS
    ITENS_ESPACADOS = objetos
    vegetacao, ocupados = _espacar_resto(vegetacao_fixa() + bordas_de_arvores(), ocupados)
    global VEGETACAO_FINAL
    VEGETACAO_FINAL = vegetacao
    return objetos + vegetacao + livres_de(flores(), ocupados) + livres_de(chao_aconchegante(), ocupados) + detalhes_chao(ocupados)


def _espacar_resto(itens, ocupados):
    """Árvores e arbustos: a copa inteira não pode cobrir casa, objeto ou outra peça já posta; entre plantas só conta a base
    (as copas podem se encostar, como numa mata)"""
    objetos = list(ocupados)
    plantas = []
    saida = []
    for nome, x, y, o in itens:
        medida = MEMEDIDA((nome, x, y, o))
        achou = None
        for dx, dy in sorted(((dx, dy) for dx in range(-18, 19, 6) for dy in range(-18, 19, 6)), key=lambda d: d[0] ** 2 + d[1] ** 2):
            base = _retangulo(nome, x + dx, y + dy, medida)
            ux, uy, uw, uh = medida
            copa = (x + dx - uw * 0.45, y + dy - uh * 0.95, x + dx + uw * 0.45, y + dy)
            # A moldura de floresta pode sair um pouco da tela (copas cortadas pela borda do mapa)
            if base[0] < -24 or base[2] > 728 or base[3] > 576 or base[1] < -60:
                continue
            if any(_bate(copa, q, 0) for q in objetos) or any(_bate(base, q) for q in plantas):
                continue
            if _no_caminho(x + dx, y + dy):
                continue
            achou = (x + dx, y + dy, base)
            break
        if achou is None:
            continue
        plantas.append(achou[2])
        saida.append((nome, achou[0], achou[1], o))
    return saida, objetos + plantas


def main():
    SAIDA.write_text(json.dumps([montar(i) for i in itens_finais()], indent=1))
    print(len(ITENS), 'peças fixas (mais as flores) gravadas em', SAIDA.relative_to(RAIZ))


if __name__ == '__main__':
    main()
