#!/usr/bin/env python3
"""Gera praia navegável: areia, arrebentação, mar e píer com colisão separada."""
from pathlib import Path
import sys
import json
import math

RAIZ = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(RAIZ / 'ferramentas/cidade'))
import gerar_cidade as C
import gerar_tilesets as K
F = C.F


def gerar():
    C.liberar_saida_praia()
    K.recurso_tileset('recursos/praia/tileset_praia.tres',
        [('res://assets/cenario/praia/atlas.png', 8, 6, 'AREIA, MAR E PIER')], 'Praia')
    c = F.Cena()
    recursos = C.comuns(c, 'praia', 'PRAIA DA VILA', (336, 64), (704, 576))
    c.no('Terrains', 'Node2D', props=['texture_filter = 1'])
    c.no('Obstaculos', 'StaticBody2D', props=['collision_layer = 64', 'collision_mask = 0'])
    layout = json.loads((RAIZ / 'codigo/pesca/layout_praia.json').read_text())
    tileset = c.recurso('TileSet', 'res://recursos/praia/tileset_praia.tres', 'terreno')
    celulas = {}
    for y in range(-2, 38):
        for x in range(-2, 46):
            if y < 18:
                tx, ty = (6, 2) if (x // 2 * 13 + y // 2 * 7) % 53 == 0 and y > 7 else (0, 0)
            elif y < 20:
                tx, ty = 2, 2
            elif y < 24:
                tx, ty = 4, 0
            elif y < 26:
                tx, ty = 0, 4
            else:
                tx, ty = 6, 0
            celulas[(x, y)] = (0, tx + x % 2, ty + y % 2)
    K.camada(c, 'AreiaMar', celulas, tileset, 'Terrains', z=-1000)
    # A mesma composição por cantos da cidade: guia, cantos internos e externos sobre a areia.
    import terreno_vila as TV
    from preparar_orla import preparar
    preparar()
    def pavimentado(x, y):
        return (64 <= x <= 640 and 112 <= y <= 144) or (304 <= x <= 368 and y <= 128)
    orla = {}
    for y in range(-2, 11):
        for x in range(2, 42):
            cantos = ['pedra' if pavimentado(vx*16, vy*16) else 'grama'
                      for vx,vy in [(x,y),(x+1,y),(x,y+1),(x+1,y+1)]]
            if 'pedra' in cantos:
                _, tx, ty = TV.tile_da_celula(cantos, x, y)
                orla[(x,y)] = (0, tx, ty)
    K.recurso_tileset('recursos/praia/tileset_orla.tres',
        [('res://assets/cenario/praia/orla/primavera.png',4,6,'PEDRA E GUIA DA CIDADE')], 'Orla')
    pedra = c.recurso('TileSet', 'res://recursos/praia/tileset_orla.tres', 'pedra_orla')
    K.camada(c, 'CalcadaOrla', orla, pedra, 'Terrains', z=-999)
    piso_cais = 'res://assets/cenario/Starter Pack/home interiors, timber roof.png'
    K.recurso_tileset('recursos/praia/tileset_cais.tres', [(piso_cais, 31, 16, 'MADEIRA NATIVA MANA SEED')], 'Cais')
    cais = c.recurso('TileSet', 'res://recursos/praia/tileset_cais.tres', 'cais')
    pier = {}
    for bx, by, largura, altura in layout['cais']:
        for y in range(by // 16, (by + altura) // 16):
            for x in range(bx // 16, (bx + largura) // 16):
                pier[(x, y)] = (0, (x * 7 + y * 3) % 5, 9 + (x + y) % 2)
    K.camada(c, 'Pier', pier, cais, 'Terrains', z=-999)
    # Colisão da água desconta cada plataforma e conexão, inclusive os vãos entre píeres.
    def costa(x):
        a, b, d, e = layout['curvas_costa']
        return layout['costa_base'] + a * math.sin(x * b) + d * math.sin(x * e) + 4
    contador = 0
    for x in range(-32, 736, 8):
        intervalos = [(costa(x + 4), 608)]
        for bx, by, largura, altura in layout['cais']:
            if not bx <= x < bx + largura:
                continue
            proximos = []
            for inicio, fim in intervalos:
                if by >= fim or by + altura <= inicio:
                    proximos.append((inicio, fim))
                else:
                    if inicio < by:
                        proximos.append((inicio, by))
                    if by + altura < fim:
                        proximos.append((by + altura, fim))
            intervalos = proximos
        for inicio, fim in intervalos:
            C.colisao(c, f'Mar_{contador}', x, inicio, x + 8, fim)
            contador += 1
    for nome, caixa in [('Oeste', (-32, -32, 8, 608)),
                        ('Leste', (696, -32, 736, 608)), ('NorteOeste', (0, -32, 308, 8)),
                        ('NorteLeste', (364, -32, 704, 8))]:
        C.colisao(c, nome, *caixa)
    c.sub_recurso('RectangleShape2D', 'Forma_porta', ['size = Vector2(48, 28)'])
    C.passagem(c, 'VoltaCidade', (336, 20), 'cidade', 'praia', saida=(0,-1))
    c.no('Chegada_cidade', 'Marker2D', props=['position = Vector2(336, 64)'], grupos=['chegada'])
    C.placa(c, 'PlacaCidade', (310, 50), 'VILA')
    casa = c.recurso('Texture2D', 'res://assets/cenario/praia/palafita/exterior.png', 'palafita')
    palafita = layout['palafita']
    c.no('Palafita', 'Sprite2D', props=[f'position = {F.vec(*palafita["origem"])}', 'centered = false',
        'texture_filter = 1', f'z_index = {max(caixa[4] for caixa in palafita["colisoes"])}', f'texture = ExtResource("{casa}")'])
    for nome, *caixa in palafita['colisoes']:
        C.colisao(c, nome, *caixa)
    C.passagem(c, 'PortaPalafita', palafita['porta'], 'palafita', 'entrada')
    c.no('Chegada_palafita', 'Marker2D', props=[f'position = {F.vec(*palafita["chegada"])}'], grupos=['chegada'])
    montar_corrimaos(c, pier, costa)
    pescador = c.recurso('Script', 'res://codigo/pesca/pescador.gd', 'pescador')
    c.no('Nilo', 'CharacterBody2D', props=['position = Vector2(342, 404)', f'script = ExtResource("{pescador}")'])
    # Pontos de pesca (codigo/pesca/ponto_pesca.gd): onde o jogador lança a linha. `direcao` aponta para a água
    ponto = c.recurso('Script', 'res://codigo/pesca/ponto_pesca.gd', 'ponto_pesca')
    c.sub_recurso('RectangleShape2D', 'Forma_ponto_pesca', ['size = Vector2(36, 24)'])
    for nome, pos, direcao in [('PescaPierLeste', (372, 416), (1, 0)), ('PescaPonta', (352, 496), (0, 1)),
                               ('PescaOeste', (128, 400), (-1, 0)), ('PescaPalafita', (544, 436), (0, 1))]:
        c.no(nome, 'Area2D', props=[f'position = {F.vec(*pos)}', f'script = ExtResource("{ponto}")', f'direcao = {F.vec(*direcao)}'])
        c.no('Forma', 'CollisionShape2D', nome, ['shape = SubResource("Forma_ponto_pesca")'])
    C.finalizar(c, recursos)
    texto = c.texto().replace('res://codigo/cidade/cidade.gd', 'res://codigo/pesca/praia.gd')
    (RAIZ / 'cenas/praia.tscn').write_text(texto)
    gerar_palafita()
    print('Praia gerada: 704x576, saída norte e píer 64x208.')


def gerar_palafita():
    c = F.Cena()
    recursos = C.comuns(c, 'palafita', 'PESCARIA DO NILO', (160, 172), (320, 224))
    c.no('Terrains', 'Node2D')
    fundo = c.recurso('Script', 'res://codigo/pesca/interior_palafita.gd', 'interior')
    c.no('Interior', 'Node2D', props=[f'script = ExtResource("{fundo}")'])
    c.no('Obstaculos', 'StaticBody2D', props=['collision_layer = 64', 'collision_mask = 0'])
    for nome, caixa in [('Norte', (0, 0, 320, 52)), ('Oeste', (0, 0, 24, 224)),
                        ('Leste', (294, 0, 320, 224)), ('SulOeste', (0, 190, 128, 240)),
                        ('SulLeste', (188, 190, 320, 240)), ('Fogao', (24, 40, 68, 74)),
                        ('Prateleira', (24, 105, 94, 145)), ('Cama', (250, 28, 294, 110)),
                        ('Mesa', (256, 114, 294, 169)), ('BalcaoLoja', (95,116,225,128))]:
        C.colisao(c, nome, *caixa)
    c.sub_recurso('RectangleShape2D', 'Forma_porta', ['size = Vector2(40, 16)'])
    C.passagem(c, 'Saida', (160, 204), 'praia', 'palafita', automatica=True)
    c.no('Chegada_entrada', 'Marker2D', props=['position = Vector2(160, 172)'], grupos=['chegada'])
    pescador = c.recurso('Script', 'res://codigo/pesca/pescador.gd', 'pescador')
    c.no('Nilo', 'CharacterBody2D', props=[f'script = ExtResource("{pescador}")'])
    C.finalizar(c, recursos)
    (RAIZ / 'cenas/palafita.tscn').write_text(c.texto())


def montar_corrimaos(c, celulas, costa):
    """Bordas modulares do cais, com abertura para a vara do Nilo e entradas de terra."""
    horizontal = c.recurso('Texture2D', 'res://assets/cenario/fazenda/cerca/primavera/horizontal.png', 'cerca_horizontal')
    poste = c.recurso('Texture2D', 'res://assets/cenario/fazenda/cerca/primavera/poste.png', 'poste_cais')
    vertical = c.recurso('Texture2D', 'res://assets/cenario/fazenda/cerca/primavera/vertical.png', 'cerca_vertical')
    c.no('Corrimaos', 'Node2D', props=['texture_filter = 1'])
    indice = 0
    laterais = {}
    for x, y in sorted(celulas):
        for dx, dy in [(0, -1), (0, 1), (-1, 0), (1, 0)]:
            if (x + dx, y + dy) in celulas:
                continue
            px, py = x * 16, y * 16
            yy = py if dy == -1 else py + 16
            if py < costa(px) + 6:
                continue
            # O trecho de pesca fica aberto, com a colisão da água preservada.
            if dx == 1 and px == 368 and 384 <= py < 448:
                continue
            if dy:
                c.no(f'Travessa{indice}', 'Sprite2D', 'Corrimaos', [f'position = {F.vec(px, yy - 23)}', 'centered = false',
                    f'texture = ExtResource("{horizontal}")', f'z_index = {int(yy // 8) * 8}'])
                C.colisao(c, f'Corrimao{indice}', px, yy - 2, px + 16, yy + 2)
            else:
                # Os oito pixels da cerca ficam inteiros sobre a madeira.
                xx = px if dx == -1 else px + 8
                laterais.setdefault((xx, dx), []).append(py)
            indice += 1

    for (xx, _lado), alturas in sorted(laterais.items()):
        alturas.sort()
        trechos = []
        for py in alturas:
            if trechos and trechos[-1][1] == py:
                trechos[-1][1] = py + 16
            else:
                trechos.append([py, py + 16])
        for inicio, fim in trechos:
            # A barreira acompanha a base sobre a madeira, não só a água fora do cais.
            C.colisao(c, f'CorrimaoLateral{indice}', xx, inicio, xx + 8, fim)
            # O poste inicial e a peça vertical compartilham a mesma base.
            # Cada peça seguinte contém a ligação até o poste anterior.
            bases = [inicio, *range(inicio + 32, fim, 32), fim]
            for posicao, base in enumerate(bases):
                textura, altura = (poste, 23) if posicao == 0 else (vertical, 47)
                c.no(f'Lateral{indice}', 'Sprite2D', 'Corrimaos', [
                    f'position = {F.vec(xx, base - altura)}', 'centered = false',
                    f'texture = ExtResource("{textura}")', f'z_index = {base}'])
                indice += 1


if __name__ == '__main__':
    gerar()
