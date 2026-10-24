#!/usr/bin/env python3
"""Layout dos seis interiores da vila. Gera assets/cenario/cidade/interiores/interiores.json.
Salas ortogonais com tiles Mana Seed nativos, paredes em corte e móveis separados. Cada móvel é
posto pela base-centro (x, y em pixels da sala); a medida do retângulo com pixels vem de medidas_moveis.json
(ferramentas/interiores/medir.gd). Uso: python3 ferramentas/cidade/layout_interiores.py
"""
from pathlib import Path
import argparse
import json

RAIZ = Path(__file__).resolve().parents[2]
SAIDA = RAIZ / 'assets/cenario/cidade/interiores/interiores.json'
MEDIDAS = json.loads((Path(__file__).parent / 'medidas_moveis.json').read_text())
AMBIENTES = json.loads((RAIZ / 'assets/cenario/cidade/ambientes/manifesto.json').read_text())

# Cores das luzes
FOGO = '#ff9a45'
VELA = '#ffc46b'
LAMPIAO = '#ffd488'
CRISTAL = '#a98bff'
POCAO = '#7dffb0'
ERVA = '#cfffb0'


def geo(largura, altura, porta, sul, areas, janelas=()):
    """Planta de uma casa, em pixels (múltiplos de 8). areas = (nome, [x, y, l, a], piso): cômodos e corredores de
    chão, com piso escuro/medio/claro; o resto é parede ou lado de fora (codigo/cidade/sala_topdown.gd).
    Cômodos lado a lado ficam a 8 px (uma parede); um embaixo do outro, a 40 px (a face de madeira).
    porta = [x0, x1] da saída, na borda de baixo do cômodo cujo chão termina em sul; janelas = [x, y do chão]."""
    meio = (porta[0] + porta[1]) // 2
    areas = list(areas) + [('saida', [porta[0], sul, porta[1] - porta[0], altura - sul], 'medio')]
    return {'recorte': [0, 0, largura, altura], 'porta': porta, 'chao_sul': sul,
            'parede_oeste': min(r[0] for _, r, _ in areas), 'parede_leste': max(r[0] + r[2] for _, r, _ in areas),
            'parede_norte': min(r[1] for _, r, _ in areas),
            'chegada': [meio, sul - 26], 'saida': [meio, sul + 6],
            'areas': [{'nome': n, 'retangulo': r, 'piso': t} for n, r, t in areas], 'janelas': list(janelas)}


# Opções por móvel:
#   chao: tapete, desenhado no chão e sem colisão
#   col: [largura, altura] da colisão na base (padrão: 88% da largura usada e 30% da altura, entre 8 e 16)
#   luzes: [dx, dy, cor, escala, energia, tipo] relativos à base; tipo "fogo" (tremula), "pulso" (respira) ou "fixa"
#   fumaca: [dx, dy] de onde sobe vapor/fumaça
#   id: nome do nó (para a cama de dormir e o quadro de avisos)
#   de: casa de onde vem o móvel, quando é emprestado de outro interior
#   espelhar: vira o desenho na horizontal
#   variante: tom da madeira e dos tecidos (nogueira, pinho, cerejeira, gasta; interior_casa.gd VARIANTES), para os
#             moveis emprestados entre casas nao ficarem todos iguais; 'original' mantem o desenho
# Cada casa tem cômodos separados conforme o uso, ligados por portas e corredores, e o contorno acompanha os
# cômodos (estilo Stardew). Móvel encostado numa face que tem outro cômodo logo acima tem no máximo ~40 px.
CASAS = {
    # Venda do Tomas: loja na frente, depósito atrás; ao lado, a cozinha e o quarto dele
    'venda': {
        'geometria': geo(568, 344, [184, 216], 320, [
            ('loja', [16, 176, 360, 144], 'medio'),
            ('deposito', [16, 40, 152, 96], 'escuro'),
            ('porta_deposito', [64, 136, 32, 40], 'escuro'),
            ('cozinha', [400, 40, 152, 120], 'medio'),
            ('porta_cozinha', [456, 160, 32, 40], 'claro'),
            ('quarto', [400, 200, 152, 120], 'claro'),
            ('porta_quarto', [376, 248, 24, 32], 'medio'),
        ], janelas=[[248, 176], [104, 40], [496, 40]]),
        'itens': [
            # Loja
            ('tapete', 200, 312, {'chao': True}),
            ('prateleira', 200, 190, {'de': 'pousada'}),
            ('prateleira_b', 296, 188, {}),
            ('prateleira', 340, 188, {}),
            ('mesa_frutas', 128, 210, {'col': [28, 14]}),
            ('cestos', 40, 210, {'col': [38, 14]}),
            ('balcao', 240, 254, {'col': [60, 14], 'luzes': [[-10, -30, LAMPIAO, 0.5, 0.55, 'fixa']]}),
            ('bau', 40, 308, {'col': [26, 12]}),
            ('planta', 120, 306, {'col': [14, 8]}),
            ('sacos', 324, 306, {'col': [52, 16]}),
            # Depósito
            ('barris', 48, 76, {'de': 'pousada', 'col': [50, 12]}),
            ('barris_caixas', 136, 88, {'col': [48, 16]}),
            ('sacos', 136, 130, {'col': [52, 16]}),
            ('bau', 36, 130, {'col': [26, 12]}),
            # Cozinha
            ('lareira', 432, 60, {'de': 'casa_bento', 'col': [44, 12], 'luzes': [[0, -20, FOGO, 0.9, 0.9, 'fogo']]}),
            ('prateleira', 532, 58, {}),
            ('cadeira', 448, 120, {'de': 'sede', 'col': [12, 8]}),
            ('mesa', 488, 124, {'de': 'pousada', 'col': [44, 14]}),
            # Quarto
            ('cama', 532, 264, {'de': 'casa_bento', 'col': [28, 48]}),
            ('mesa', 440, 224, {'de': 'enfermaria', 'col': [28, 14]}),
            ('cadeira', 470, 222, {'de': 'sede', 'col': [12, 8]}),
            ('bau', 424, 312, {'col': [26, 12]}),
        ],
        'pontos': {'trabalho': [240, 212], 'passeio': [150, 262]},
    },
    # Sede da comunidade: salão de reuniões no meio; arquivo à esquerda, gabinete e copa à direita
    'sede': {
        'geometria': geo(576, 312, [256, 288], 272, [
            ('salao', [160, 40, 224, 232], 'medio'),
            ('arquivo', [16, 80, 120, 160], 'escuro'),
            ('porta_arquivo', [136, 144, 24, 32], 'escuro'),
            ('gabinete', [408, 40, 152, 112], 'claro'),
            ('porta_gabinete', [384, 80, 24, 32], 'claro'),
            ('copa', [408, 192, 152, 112], 'escuro'),
            ('porta_copa', [384, 224, 24, 32], 'escuro'),
        ], janelas=[[64, 80], [456, 40], [456, 192]]),
        'itens': [
            # Salão
            ('tapete_corredor', 272, 272, {'chao': True}),
            ('lareira', 272, 58, {'col': [34, 12], 'luzes': [[0, -20, FOGO, 0.9, 0.9, 'fogo']]}),
            ('estandarte', 208, 62, {'col': [24, 10]}),
            ('estandarte', 336, 62, {'col': [24, 10], 'espelhar': True}),
            # Recepção: Lia atrás do balcão e acesso frontal livre desde a entrada.
            ('balcao', 272, 152, {'de': 'pousada', 'col': [102, 14], 'id': 'BalcaoAtendimento', 'luzes': [[-26, -39, LAMPIAO, 0.45, 0.5, 'fixa']]}),
            ('quadro_avisos', 344, 250, {'col': [40, 10], 'id': 'Mural'}),
            ('cadeira', 192, 250, {'col': [12, 8]}),
            # Arquivo
            ('estante', 40, 98, {}),
            ('estante', 106, 98, {}),
            ('mesa', 56, 176, {'de': 'enfermaria', 'col': [28, 14], 'luzes': [[6, -20, VELA, 0.4, 0.45, 'fogo']]}),
            ('cadeira', 88, 174, {'col': [12, 8]}),
            ('bau', 40, 232, {'de': 'venda', 'col': [26, 12]}),
            ('planta', 112, 232, {'de': 'venda', 'col': [14, 8]}),
            # Gabinete
            ('estante', 432, 62, {'de': 'mistica'}),
            ('planta', 540, 58, {'de': 'venda', 'col': [14, 8]}),
            ('cadeira', 488, 98, {'col': [12, 8]}),
            ('mesa', 488, 128, {'de': 'pousada', 'col': [44, 14]}),
            # Copa
            ('barris', 440, 216, {'de': 'pousada', 'col': [50, 12]}),
            ('prateleira', 536, 208, {'de': 'venda'}),
            ('mesa', 488, 280, {'de': 'pousada', 'col': [44, 14]}),
            ('cadeira', 454, 278, {'col': [12, 8]}),
            ('cadeira', 522, 278, {'col': [12, 8]}),
        ],
        'pontos': {'trabalho': [312, 236], 'passeio': [216, 204]},
        'mural': [344, 230],
    },
    # Enfermaria da Dona Rosa: recepção na entrada, botica de ervas atrás dela e a ala dos leitos ao lado
    'enfermaria': {
        'geometria': geo(576, 296, [128, 160], 272, [
            ('recepcao', [16, 152, 256, 120], 'claro'),
            ('botica', [16, 40, 160, 72], 'escuro'),
            ('porta_botica', [64, 112, 32, 40], 'escuro'),
            ('leitos', [296, 40, 264, 232], 'claro'),
            ('porta_leitos', [272, 192, 24, 32], 'claro'),
        ], janelas=[[216, 152], [344, 40], [440, 40], [128, 40]]),
        'itens': [
            # Botica
            ('armario', 40, 60, {}),
            ('ervas', 152, 62, {'luzes': [[0, -22, ERVA, 0.5, 0.35, 'pulso']]}),
            ('pocoes', 104, 58, {'de': 'mistica', 'luzes': [[0, -26, POCAO, 0.5, 0.3, 'pulso']]}),
            ('sacos', 140, 106, {'de': 'casa_bento', 'col': [54, 14]}),
            # Recepção
            ('lavatorio', 32, 180, {'col': [24, 12]}),
            ('mesa', 96, 226, {'col': [28, 18], 'luzes': [[8, -22, LAMPIAO, 0.5, 0.6, 'fixa']]}),
            ('estante', 248, 180, {'de': 'sede'}),
            ('banco_reuniao', 232, 232, {'de': 'sede', 'col': [30, 8]}),
            ('planta', 32, 264, {'de': 'venda', 'col': [14, 8]}),
            # Leitos
            ('cama', 324, 96, {'col': [24, 30]}),
            ('cama', 372, 96, {'col': [24, 30]}),
            ('cama', 420, 96, {'col': [24, 30]}),
            ('cama', 468, 96, {'col': [24, 30]}),
            ('cama', 516, 96, {'col': [24, 30]}),
            ('biombo', 344, 236, {'col': [36, 10]}),
            ('cama', 420, 264, {'col': [24, 30]}),
            ('cama', 468, 264, {'col': [24, 30]}),
            ('lavatorio', 536, 236, {'col': [24, 12]}),
        ],
        'pontos': {'trabalho': [96, 190], 'passeio': [440, 170]},
    },
    # Pousada do Coreto: taverna grande no meio (balcão comprido com banquetas, garrafas e barris atrás, lareira,
    # mesas e um palquinho para o bardo); cozinha à esquerda e dois quartos de hóspedes à direita
    'pousada': {
        'geometria': geo(672, 352, [312, 344], 328, [
            ('taverna', [144, 40, 368, 288], 'medio'),
            ('cozinha', [16, 40, 104, 128], 'escuro'),
            ('porta_cozinha', [120, 88, 24, 32], 'escuro'),
            ('quarto_1', [536, 40, 120, 104], 'claro'),
            ('porta_quarto_1', [512, 72, 24, 32], 'claro'),
            ('quarto_2', [536, 184, 120, 104], 'claro'),
            ('porta_quarto_2', [512, 216, 24, 32], 'claro'),
        ], janelas=[[596, 40], [596, 184], [64, 40]]),
        'itens': [
            # Atrás do balcão: garrafas e barris na parede
            ('prateleira', 172, 58, {}),
            ('barris', 226, 74, {'col': [50, 12]}),
            ('prateleira', 282, 58, {'espelhar': True}),
            ('barris', 338, 74, {'col': [50, 12]}),
            # Balcão comprido (duas peças) com banquetas na frente
            ('balcao', 200, 140, {'col': [102, 14], 'luzes': [[0, -30, LAMPIAO, 0.55, 0.6, 'fixa']]}),
            ('balcao', 302, 140, {'col': [102, 14], 'espelhar': True, 'variante': 'original', 'luzes': [[0, -30, LAMPIAO, 0.55, 0.6, 'fixa']]}),
            ('banqueta', 168, 162, {'col': [12, 6]}),
            ('banqueta', 200, 162, {'col': [12, 6]}),
            ('banqueta', 232, 162, {'col': [12, 6]}),
            ('banqueta', 270, 162, {'col': [12, 6]}),
            ('banqueta', 302, 162, {'col': [12, 6]}),
            ('banqueta', 334, 162, {'col': [12, 6]}),
            # Canto da lareira: tapete redondo na frente
            ('lareira', 430, 64, {'col': [52, 12], 'luzes': [[0, -22, FOGO, 1.0, 1.0, 'fogo']]}),
            ('tapete', 430, 102, {'chao': True}),
            # Palco do bardo, encostado na parede da direita
            ('tapete', 474, 236, {'de': 'venda', 'chao': True}),
            # Seis mesas de banco corrido em grade (duas colunas à esquerda, uma à direita), com o corredor
            # livre da porta até o balcão
            ('banco_reuniao', 184, 194, {'de': 'sede', 'col': [30, 8], 'variante': 'cerejeira'}),
            ('mesa', 184, 226, {'col': [44, 18], 'luzes': [[0, -22, VELA, 0.4, 0.5, 'fogo']]}),
            ('banco_reuniao', 184, 248, {'de': 'sede', 'col': [30, 8], 'variante': 'cerejeira'}),
            ('banco_reuniao', 184, 266, {'de': 'sede', 'col': [30, 8], 'variante': 'cerejeira'}),
            ('mesa', 184, 298, {'col': [44, 18], 'luzes': [[0, -22, VELA, 0.4, 0.5, 'fogo']]}),
            ('banco_reuniao', 184, 320, {'de': 'sede', 'col': [30, 8], 'variante': 'cerejeira'}),
            ('banco_reuniao', 264, 194, {'de': 'sede', 'col': [30, 8], 'variante': 'cerejeira'}),
            ('mesa', 264, 226, {'col': [44, 18], 'luzes': [[0, -22, VELA, 0.4, 0.5, 'fogo']]}),
            ('banco_reuniao', 264, 248, {'de': 'sede', 'col': [30, 8], 'variante': 'cerejeira'}),
            ('banco_reuniao', 264, 266, {'de': 'sede', 'col': [30, 8], 'variante': 'cerejeira'}),
            ('mesa', 264, 298, {'col': [44, 18], 'luzes': [[0, -22, VELA, 0.4, 0.5, 'fogo']]}),
            ('banco_reuniao', 264, 320, {'de': 'sede', 'col': [30, 8], 'variante': 'cerejeira'}),
            ('banco_reuniao', 400, 194, {'de': 'sede', 'col': [30, 8], 'variante': 'cerejeira'}),
            ('mesa', 400, 226, {'col': [44, 18], 'luzes': [[0, -22, VELA, 0.4, 0.5, 'fogo']]}),
            ('banco_reuniao', 400, 248, {'de': 'sede', 'col': [30, 8], 'variante': 'cerejeira'}),
            ('banco_reuniao', 400, 266, {'de': 'sede', 'col': [30, 8], 'variante': 'cerejeira'}),
            ('mesa', 400, 298, {'col': [44, 18], 'luzes': [[0, -22, VELA, 0.4, 0.5, 'fogo']]}),
            ('banco_reuniao', 400, 320, {'de': 'sede', 'col': [30, 8], 'variante': 'cerejeira'}),
            # Entrada: cardápio ao lado da porta, planta e estoque nos cantos
            ('cardapio', 362, 324, {'col': [30, 10]}),
            ('planta', 146, 324, {'de': 'venda', 'col': [14, 8]}),
            ('barris_caixas', 488, 322, {'de': 'venda', 'col': [48, 16]}),
            # Cozinha
            ('lareira', 48, 60, {'de': 'casa_bento', 'col': [44, 12], 'luzes': [[0, -20, FOGO, 0.9, 0.9, 'fogo']]}),
            ('prateleira', 96, 62, {}),
            ('mesa', 64, 130, {'de': 'enfermaria', 'col': [28, 14]}),
            ('sacos', 50, 164, {'de': 'casa_bento', 'col': [54, 14]}),
            # Quarto 1 (onde o jogador dorme)
            ('cama', 636, 104, {'id': 'Cama', 'col': [28, 48]}),
            ('mesa', 580, 66, {'de': 'enfermaria', 'col': [28, 14], 'luzes': [[6, -20, VELA, 0.4, 0.45, 'fogo']]}),
            ('bau', 568, 136, {'de': 'venda', 'col': [26, 12]}),
            # Quarto 2
            ('cama', 636, 248, {'de': 'casa_bento', 'col': [28, 48]}),
            ('lavatorio', 580, 206, {'de': 'enfermaria', 'col': [24, 12]}),
            ('bau', 568, 280, {'de': 'venda', 'col': [26, 12]}),
        ],
        'pontos': {'trabalho': [474, 230], 'passeio': [330, 200], 'cama': [608, 112], 'balcao': [251, 84]},
        # Quem se aquece aqui no inverno, perto da lareira e no balcão
        'inverno': [[412, 116], [448, 116], [400, 136], [430, 136], [460, 136], [430, 152]],
    },
    # Casa da Mística: laboratório à esquerda, observatório atrás da sala de leitura e o quarto dela à direita
    'mistica': {
        'geometria': geo(544, 312, [248, 280], 280, [
            ('sala', [152, 152, 224, 128], 'medio'),
            ('laboratorio', [16, 72, 128, 144], 'escuro'),
            ('porta_laboratorio', [144, 168, 8, 32], 'escuro'),
            ('observatorio', [168, 40, 192, 72], 'escuro'),
            ('porta_observatorio', [248, 112, 32, 40], 'escuro'),
            ('quarto', [384, 96, 144, 136], 'claro'),
            ('porta_quarto', [376, 176, 8, 32], 'claro'),
        ], janelas=[[208, 40], [320, 40], [48, 72], [432, 96]]),
        'itens': [
            # Observatório
            ('telescopio', 216, 96, {'col': [30, 12]}),
            ('mesa_cristal', 320, 96, {'col': [38, 16], 'luzes': [[0, -28, CRISTAL, 0.9, 0.8, 'pulso']]}),
            # Laboratório
            ('pocoes', 104, 92, {'luzes': [[0, -26, POCAO, 0.7, 0.45, 'pulso']]}),
            ('caldeirao', 48, 150, {'col': [22, 12], 'luzes': [[0, -22, POCAO, 0.7, 0.8, 'pulso']], 'fumaca': [0, -32]}),
            ('ervas', 104, 212, {'de': 'enfermaria', 'luzes': [[0, -22, ERVA, 0.5, 0.35, 'pulso']]}),
            # Sala de leitura
            ('tapete', 264, 240, {'chao': True}),
            ('mesa', 212, 200, {'de': 'enfermaria', 'col': [28, 14], 'luzes': [[6, -20, VELA, 0.4, 0.45, 'fogo']]}),
            ('planta', 356, 272, {'de': 'venda', 'col': [14, 8]}),
            # Quarto
            ('cama', 408, 164, {'de': 'casa_bento', 'col': [28, 48]}),
            ('espelho', 472, 116, {'col': [26, 10], 'luzes': [[0, -28, CRISTAL, 0.8, 0.45, 'pulso']]}),
            ('estante', 506, 120, {}),
            ('tapete', 472, 210, {'chao': True, 'de': 'pousada'}),
        ],
        'pontos': {'trabalho': [280, 80], 'passeio': [264, 222]},
    },
    # Casa do Bento: cozinha com lareira no meio; quarto à esquerda e oficina de ferramentas e sementes à direita
    'casa_bento': {
        'geometria': geo(528, 248, [216, 248], 224, [
            ('cozinha', [136, 56, 192, 168], 'medio'),
            ('quarto', [16, 96, 104, 112], 'claro'),
            ('porta_quarto', [120, 144, 16, 32], 'claro'),
            ('oficina', [352, 40, 168, 128], 'escuro'),
            ('porta_oficina', [328, 104, 24, 32], 'escuro'),
        ], janelas=[[160, 56], [64, 96]]),
        'itens': [
            # Cozinha
            ('tapete', 232, 216, {'chao': True}),
            ('lareira', 232, 74, {'col': [44, 12], 'luzes': [[0, -20, FOGO, 1.0, 0.95, 'fogo']]}),
            ('prateleira', 300, 72, {'de': 'venda'}),
            ('mesa', 232, 160, {'col': [44, 22], 'luzes': [[0, -22, VELA, 0.4, 0.45, 'fogo']]}),
            ('cadeira', 198, 158, {'de': 'sede', 'col': [12, 8]}),
            ('cadeira', 266, 158, {'de': 'sede', 'col': [12, 8]}),
            ('cestos', 164, 218, {'de': 'venda', 'col': [38, 14]}),
            # Quarto
            ('cama', 36, 160, {'col': [28, 48]}),
            ('bau', 96, 126, {'de': 'venda', 'col': [26, 12]}),
            ('balanco', 92, 204, {'col': [30, 12]}),
            # Oficina
            ('ferramentas', 432, 58, {'col': [56, 10]}),
            ('bancada', 432, 130, {'col': [66, 16]}),
            ('sacos', 488, 164, {'col': [54, 14]}),
        ],
        'pontos': {'trabalho': [424, 84], 'passeio': [232, 196]},
    },
    # Casa inicial: um único cômodo, com os mesmos pisos e paredes Mana Seed da vila.
    # Cama, baú, estante e mesa com cadeiras são montados pelo gerador da fazenda.
    # Melhorias futuras podem ampliar esta planta sem trocar o id da casa ou suas chegadas.
    'casa_jogador': {
        'geometria': geo(256, 216, [112, 144], 192, [
            ('sala_inicial', [16, 48, 224, 144], 'medio'),
        ], janelas=[[64, 48]]),
        'itens': [
            ('lareira', 160, 66, {'de': 'casa_bento', 'col': [44, 12],
                                'luzes': [[0, -20, FOGO, 0.65, 0.65, 'fogo']]}),
            ('tapete', 128, 190, {'de': 'venda', 'chao': True}),
        ],
        'pontos': {},
    },
}


from layout_carpintaria import planta_carpintaria
CASAS['carpintaria'] = planta_carpintaria(geo)


def montar_item(casa, prop, x, y, opcoes):
    casa = opcoes.get('de', casa)
    preparado = AMBIENTES.get('interior/' + casa + '/' + prop)
    ux, uy, uw, uh = preparado['usado'] if preparado else MEDIDAS[casa][prop][2:6]
    item = {'p': prop, 'x': x, 'y': y, 'usado': [ux, uy, uw, uh], 'chao': bool(opcoes.get('chao'))}
    if not item['chao']:
        largura, altura = opcoes.get('col') or [round(uw * 0.88), min(16, max(8, round(uh * 0.3)))]
        item['col'] = [largura, altura]
    if opcoes.get('luzes'):
        item['luzes'] = opcoes['luzes']
    if opcoes.get('fumaca'):
        item['fumaca'] = opcoes['fumaca']
    if opcoes.get('id'):
        item['id'] = opcoes['id']
    if opcoes.get('espelhar'):
        item['espelhar'] = True
    if opcoes.get('variante'):
        item['variante'] = opcoes['variante']
    preparado = AMBIENTES.get('interior/' + casa + '/' + prop)
    if preparado:
        escala = preparado['escala_origem']
        item.update(preparado)
        if 'col' in item:
            item['col'] = [max(4, round(c * escala)) for c in item['col']]
        if 'luzes' in item:
            item['luzes'] = [[round(l[0] * escala), round(l[1] * escala), *l[2:]] for l in item['luzes']]
        if 'fumaca' in item:
            item['fumaca'] = [round(v * escala) for v in item['fumaca']]
    return item


# Tom dos moveis emprestados de outra casa (opcao "de"), para cada casa ter o seu; e o rodizio dado as copias repetidas
# do mesmo movel numa casa (a primeira fica com o tom original). Uma "variante" escrita no item tem a palavra final
VARIANTE_DA_CASA = {'venda': 'pinho', 'sede': 'nogueira', 'enfermaria': 'pinho', 'pousada': 'cerejeira',
                    'mistica': 'nogueira', 'casa_bento': 'gasta', 'casa_jogador': 'pinho'}
RODIZIO_VARIANTES = ['nogueira', 'cerejeira', 'gasta', 'pinho']


def variar(casa, itens):
    """Escolhe a variante de cada movel: emprestado leva o tom da casa; copia repetida entra no rodizio"""
    vistos = {}
    saida = []
    for prop, x, y, opcoes in itens:
        opcoes = dict(opcoes)
        chave = (opcoes.get('de', casa), prop)
        vez = vistos.get(chave, 0)
        vistos[chave] = vez + 1
        if 'variante' not in opcoes and not opcoes.get('chao'):
            if vez > 0:
                opcoes['variante'] = RODIZIO_VARIANTES[(vez - 1) % len(RODIZIO_VARIANTES)]
            elif 'de' in opcoes:
                opcoes['variante'] = VARIANTE_DA_CASA.get(casa, 'pinho')
        saida.append((prop, x, y, opcoes))
    return saida


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--casa', choices=CASAS, help='Regenera somente esta casa, preservando as demais.')
    args = parser.parse_args()
    # Casas de outros preparadores, como a forja, não pertencem a este gerador.
    saida = json.loads(SAIDA.read_text()) if SAIDA.exists() else {'casas': {}}
    for casa, dados in CASAS.items():
        if args.casa and casa != args.casa:
            continue
        geometria = dict(dados['geometria'])
        geometria['perspectiva'] = 'topdown_comodos'
        entrada = {
            'geometria': geometria,
            'itens': [montar_item(casa, p, x, y, o) for p, x, y, o in variar(casa, dados['itens'])],
            'pontos': dados['pontos']}
        for chave in ('mural', 'inverno'):
            if chave in dados:
                entrada[chave] = dados[chave]
        saida['casas'][casa] = entrada
    SAIDA.write_text(json.dumps(saida, indent=1))
    print('Layout dos interiores gravado em', SAIDA.relative_to(RAIZ))


if __name__ == '__main__':
    main()
