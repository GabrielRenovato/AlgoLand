"""Retira somente os arbustos dos atlas substitutos e suas bases físicas."""
import re


def remover(texto):
    blocos = re.split(r'\n(?=\[)', texto)
    fontes = set()
    atlas = {}
    for bloco in blocos:
        if bloco.startswith('[ext_resource') and 'assets/cenario/substitutos/' in bloco:
            fontes.add(re.search(r' id="([^"]+)"', bloco)[1])
    for bloco in blocos:
        if not bloco.startswith('[sub_resource type="AtlasTexture"'):
            continue
        if not any(f'atlas = ExtResource("{fonte}")' in bloco for fonte in fontes):
            continue
        regiao = re.search(r'region = Rect2\(([^)]+)\)', bloco)
        if regiao:
            numeros = tuple(float(n) for n in regiao[1].split(','))
            if numeros in [(16, 128, 16, 32), (32, 128, 32, 32)]:
                atlas[re.search(r'id="([^"]+)"', bloco)[1]] = numeros[2]
    nomes, caminhos, bases = set(), set(), set()
    for bloco in blocos:
        if not bloco.startswith('[node '):
            continue
        textura = re.search(r'texture = SubResource\("([^"]+)"\)', bloco)
        if not textura or textura[1] not in atlas:
            continue
        nome = re.search(r'name="([^"]+)"', bloco)[1]
        pai = re.search(r'parent="([^"]+)"', bloco)[1]
        nomes.add(nome)
        caminhos.add(pai + '/' + nome)
        posicao = re.search(r'position = Vector2\(([^)]+)\)', bloco)
        x, y = (float(n) for n in posicao[1].split(','))
        largura = atlas[textura[1]] / 2 - 3
        bases.add((x-largura, y-8, x+largura, y))
    if not nomes:
        return texto
    obstaculos = set()
    for recurso in re.findall(r'\{[^{}]*"tipo": "arbusto"[^{}]*\}', texto):
        no = re.search(r'"no": NodePath\("([^"]+)"\)', recurso)
        if no and no[1] in caminhos:
            obstaculos.add(re.search(r'"obstaculo": NodePath\("([^"]+)"\)', recurso)[1])
            texto = texto.replace(recurso + ', ', '')
            texto = texto.replace(', ' + recurso, '')
    saida = []
    for bloco in re.split(r'\n(?=\[)', texto):
        if bloco.startswith('[node '):
            nome = re.search(r'name="([^"]+)"', bloco)[1]
            pai = re.search(r'parent="([^"]+)"', bloco)
            caminho = (pai[1] + '/' if pai and pai[1] != '.' else '') + nome
            if caminho in caminhos or caminho in obstaculos:
                continue
            if 'type="CollisionPolygon2D"' in bloco:
                origem = re.search(r'metadata/sprite_colisao = "([^"]+)"', bloco)
                if origem and origem[1] in nomes:
                    continue
                poligono = re.search(r'polygon = PackedVector2Array\(([^)]+)\)', bloco)
                if poligono:
                    ns = [float(n) for n in poligono[1].split(',')]
                    if len(ns) == 8:
                        xs, ys = ns[::2], ns[1::2]
                        base = (min(xs), min(ys), max(xs), max(ys))
                        cantos = {(base[0],base[1]), (base[2],base[1]), (base[2],base[3]), (base[0],base[3])}
                        if base in bases and set(zip(xs,ys)) == cantos:
                            continue
        saida.append(bloco)
    return '\n'.join(saida)
