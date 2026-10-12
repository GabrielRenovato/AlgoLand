#!/usr/bin/env python3
"""Gerador da fazenda e da casa (Etapa A). Python puro, sem PIL/numpy; deterministico (semente fixa).

Como usar (da raiz do projeto):
    python3 ferramentas/fazenda/gerar_fazenda.py
    flatpak run org.godotengine.Godot --headless --path . --import      # importa o PNG da casa gerado

Saida:
  - Tiles/Starter Pack/casa_fazenda.png : a casa de fora MONTADA a partir de pecas de "simplified full timber.png"
    (ver casa_dados.montar_casa: o bloco cru recebe 3 remendos conferidos em ampliacao)
  - cenas/terreno_fazenda.tscn : mapa (grama sazonal, trilha e area de plantio em terra, a casa, arvores, pedras, a caverna
    de volta para a arena, o limite do mapa). Usa os mesmos sistemas da arena: Estacoes (troca de folha), clima,
    profundidade (Objetos3D + profundidade_grupo.gd) e colisoes medidas por pixel
  - cenas/fazenda.tscn : o terreno + Jogador, luz, HUD, Interface e vinheta (sem inimigos nem ondas)
  - (Etapa B) o caldeirao onde a colheita vira pocao (Tiles/Farm RPG/caldeirao.png, copiado por ferramentas/fazenda/preparar_plantio.py), o
    no Plantio (solo arado, plantas e clima do dia) e a meta "barra_ferramentas" (o HUD mostra a barra da ferramenta ativa)
  - cenas/casa.tscn : o interior (piso, parede com janela, cama, bau, estante, mesa e cadeiras do Mana Seed)

Reaproveita de ferramentas/arena/gerar_arena.py as folhas sazonais, a terra em autotile (blob 3x3), a caverna e as medidas
de colisao por pixel das arvores.
"""
import math
import os
import random
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
ARENA = os.path.join(AQUI, "..", "arena")
sys.path.insert(0, ARENA)
sys.path.insert(0, AQUI)
import gerar_arena as G  # noqa: E402
import png_puro as P  # noqa: E402
import tscn as T  # noqa: E402
import compor as C  # noqa: E402
import casa_dados as D  # noqa: E402

RAIZ = G.RAIZ
TILE = 16
RNG = random.Random(20261011)
G.RNG = RNG  # tiles_terra sorteia o centro da terra pelo RNG do modulo

# ---------------------------------------------------------------- layout da fazenda (px; tiles = px / 16)
MAPA_W, MAPA_H = 60, 42
LIMITES = (0, 0, MAPA_W * TILE, MAPA_H * TILE)
CAV_TX, CAV_TY = 9, 0                                # caverna de volta para a arena (origem em tiles)
CAV_PASSAGEM = (CAV_TX * TILE + 40, (CAV_TY + 5) * TILE + 6)
CAV_CHEGADA = (CAV_TX * TILE + 40, (CAV_TY + 5) * TILE + 34)
CASA_BASE = (608, 252)                               # centro da base do desenho da casa
CASA_RET = (CASA_BASE[0] - 48, CASA_BASE[1] - 140, CASA_BASE[0] + 48, CASA_BASE[1] + 52)  # zona proibida de props
PORTA_CENTRO_X = CASA_BASE[0] - 48 + (D.PORTA_X[0] + D.PORTA_X[1]) // 2
PORTA_AREA = (PORTA_CENTRO_X, CASA_BASE[1] + 14)     # zona de interacao da porta
PORTA_CHEGADA = (PORTA_CENTRO_X, CASA_BASE[1] + 40)
TRILHA = [(CAV_PASSAGEM[0], 96), (CAV_PASSAGEM[0], 200), (CAV_PASSAGEM[0] + 40, 268), (PORTA_CENTRO_X, 270)]
PLANTIO = (17, 22, 31, 30)                           # tiles (x0, y0, x1, y1): a area de plantio (terra)
PLANTIO_PX = (PLANTIO[0] * TILE, PLANTIO[1] * TILE, (PLANTIO[2] + 1) * TILE, (PLANTIO[3] + 1) * TILE)

# Etapa B: o caldeirao (centro da base do desenho, em px) fica do lado direito da area de plantio, onde era a caixa de entrega
CALDEIRAO = (548, 396)
RES_FARM = "res://Tiles/Farm RPG/"

SAIDA_TERRENO = os.path.join(RAIZ, "cenas", "terreno_fazenda.tscn")
SAIDA_FAZENDA = os.path.join(RAIZ, "cenas", "fazenda.tscn")
SAIDA_CASA = os.path.join(RAIZ, "cenas", "casa.tscn")
PNG_CASA = os.path.join(RAIZ, "Tiles", "Starter Pack", "casa_fazenda.png")
RES_STARTER = "res://Tiles/Starter Pack/"


# ---------------------------------------------------------------- escritor de .tscn
class Cena:
    def __init__(self):
        self.ext = []     # (tipo, caminho, id)
        self.sub = []     # blocos de texto
        self.nos = []
        self._ids = {}

    def recurso(self, tipo, caminho, nome=None):
        chave = (tipo, caminho)
        if chave not in self._ids:
            self._ids[chave] = nome or "%d_%s" % (len(self.ext) + 1, tipo.lower())
            self.ext.append((tipo, caminho, self._ids[chave]))
        return self._ids[chave]

    def sub_recurso(self, tipo, ident, linhas):
        self.sub.append('[sub_resource type="%s" id="%s"]\n%s\n' % (tipo, ident, "\n".join(linhas)))
        return ident

    def no(self, nome, tipo, pai=".", props=(), grupos=(), instancia=None, raiz=False):
        cab = '[node name="%s"' % nome
        if instancia:
            cab += ' parent="%s" instance=ExtResource("%s")' % (pai, instancia)
        else:
            cab += ' type="%s"' % tipo
            if not raiz:
                cab += ' parent="%s"' % pai
        if grupos:
            cab += ' groups=[%s]' % ", ".join('"%s"' % g for g in grupos)
        cab += "]"
        self.nos.append(cab + "\n" + "\n".join(props) + ("\n" if props else ""))

    def texto(self):
        passos = len(self.ext) + len(self.sub) + 1
        partes = ["[gd_scene load_steps=%d format=3]\n" % passos]
        for tipo, caminho, ident in self.ext:
            partes.append('[ext_resource type="%s" path="%s" id="%s"]' % (tipo, caminho, ident))
        partes.append("")
        partes += [b for b in self.sub]
        partes += self.nos
        return "\n".join(partes).rstrip("\n") + "\n"


def vec(x, y):
    return "Vector2(%s, %s)" % (T.fmt(x), T.fmt(y))


def retangulo(x0, y0, x1, y1):
    return G.poligono_retangulo(x0, y0, x1, y1)


def camada(cena, nome, celulas, tileset, z=-1000):
    if celulas:
        dados = [(x, y, 0, t[0], t[1], 0) for (x, y), t in sorted(celulas.items(), key=lambda kv: (kv[0][1], kv[0][0]))]
        props = ["texture_filter = 1", "z_index = %d" % z, "tile_map_data = %s" % T.codificar_tiles(dados),
                 'tile_set = SubResource("%s")' % tileset]
    else:
        props = ["texture_filter = 1", "z_index = %d" % z, 'tile_set = SubResource("%s")' % tileset]
    cena.no(nome, "TileMapLayer", ".", props)


# ---------------------------------------------------------------- pecas montadas
def gerar_png_casa():
    casa = D.montar_casa()
    P.salvar(casa, PNG_CASA)


# ---------------------------------------------------------------- terreno da fazenda
class Mapa:
    def __init__(self):
        self.chao, self.terra, self.penhasco, self.detalhes = {}, {}, {}, {}
        self.sprites = []      # dicts: nome, x, y, tipo
        self.obstaculos = []   # poligonos
        self.ocupados = []     # (x, y, raio)

    def livre(self, x, y, raio, margem=36.0):
        if not (margem <= x <= LIMITES[2] - margem and margem <= y <= LIMITES[3] - margem):
            return False
        # casa, caverna, area de plantio (com folga) e trilha
        if CASA_RET[0] - 24 - raio <= x <= CASA_RET[2] + 24 + raio and CASA_RET[1] - 30 - raio <= y <= CASA_RET[3] + 28 + raio:
            return False
        cx0, cy0 = CAV_TX * TILE, CAV_TY * TILE
        if cx0 - 36 - raio <= x <= cx0 + 80 + 36 + raio and y <= cy0 + 80 + 56 + raio:
            return False
        if PLANTIO_PX[0] - 28 - raio <= x <= PLANTIO_PX[2] + 28 + raio and PLANTIO_PX[1] - 28 - raio <= y <= PLANTIO_PX[3] + 28 + raio:
            return False
        for i in range(len(TRILHA) - 1):
            if G.dist_segmento((x, y), TRILHA[i], TRILHA[i + 1]) < 40 + raio:
                return False
        for ox, oy, orr in self.ocupados:
            if math.hypot(x - ox, y - oy) < orr + raio:
                return False
        return True

    def espalhar(self, qtd, raio, margem=36.0, tentativas=6000):
        pts = []
        for _ in range(tentativas):
            if len(pts) >= qtd:
                break
            x = RNG.uniform(margem, LIMITES[2] - margem)
            y = RNG.uniform(margem, LIMITES[3] - margem)
            if self.livre(x, y, raio, margem):
                pts.append((round(x), round(y)))
                self.ocupados.append((x, y, raio))
        return pts


def construir_mapa():
    m = Mapa()
    # ---- caverna (volta para a arena) com os dois abetos que escondem as laterais cortadas da pedra
    caverna = G.montar_caverna(CAV_TX, CAV_TY)
    m.penhasco.update(caverna)
    m.obstaculos.append(G.poligono_de_stamp(caverna, G.solido_caverna))
    base_cav = (CAV_TY + 5) * TILE
    r_abeto = G.medir_base_arvore(G.EVERGREEN_VERAO, G.ABETO["regiao"])
    for i, (x, y) in enumerate(((CAV_TX * TILE - 2, base_cav), (CAV_TX * TILE + 82, base_cav - 4))):
        m.sprites.append({"nome": "AbetoCaverna%d" % (i + 1), "x": x, "y": y, "tipo": "abeto"})
        bx = x + G.ABETO["offset"][0]
        m.obstaculos.append(retangulo(bx + r_abeto[0], y - 8, bx + r_abeto[2], y))
    m.ocupados.append((CAV_TX * TILE + 40, base_cav, 50))

    # ---- a casa: um sprite so (origem na base), colisao so na base (a parede de 32 px; o telhado nao bloqueia: o
    # jogador passa atras dele e o profundidade_grupo.gd deixa o desenho translucido)
    m.sprites.append({"nome": "Casa", "x": CASA_BASE[0], "y": CASA_BASE[1], "tipo": "casa"})
    m.obstaculos.append(retangulo(CASA_BASE[0] - 48 + 2, CASA_BASE[1] - 30, CASA_BASE[0] + 48 - 2, CASA_BASE[1]))

    # ---- terra: trilha da caverna ate a porta + area de plantio
    def na_forma(x, y):
        px, py = x * TILE + 8, y * TILE + 8
        if PLANTIO[0] <= x <= PLANTIO[2] and PLANTIO[1] <= y <= PLANTIO[3]:
            return True
        return min(G.dist_segmento((px, py), TRILHA[i], TRILHA[i + 1]) for i in range(len(TRILHA) - 1)) <= 20.0

    proibido = set()
    for cy in range(-2, MAPA_H + 2):
        for cx in range(-2, MAPA_W + 2):
            px, py = cx * TILE + 8, cy * TILE + 8
            dentro_casa = CASA_RET[0] - 8 <= px <= CASA_RET[2] + 8 and CASA_RET[1] <= py <= CASA_BASE[1] + 6
            dentro_cav = CAV_TX * TILE - 8 <= px <= (CAV_TX + 5) * TILE + 8 and py <= (CAV_TY + 5) * TILE + 8
            if dentro_casa or dentro_cav or not (1 <= cx < MAPA_W - 1 and 1 <= cy < MAPA_H - 1):
                proibido.add((cx, cy))
    S = {(cx, cy) for cy in range(MAPA_H) for cx in range(MAPA_W) if (cx, cy) not in proibido and na_forma(cx, cy)}
    S = G.regularizar_terra(S, proibido)
    m.terra = G.tiles_terra(S)

    # ---- chao: grama com flores esparsas (margem de 2 tiles alem do mapa; a camera e presa nos LIMITES)
    for cy in range(-3, MAPA_H + 3):
        for cx in range(-3, MAPA_W + 3):
            if RNG.random() < 0.04:
                m.chao[(cx, cy)] = RNG.choice(G.FLORES)
            else:
                m.chao[(cx, cy)] = RNG.choice(G.GRAMA)

    # ---- aro de abetos nas bordas (fora da caverna) + carvalhos, arbustos, pedras e plantas
    espaco = 30
    for lado in ("n", "s", "o", "l"):
        n = (LIMITES[2] if lado in "ns" else LIMITES[3]) // espaco
        for k in range(n):
            t = k * espaco + RNG.uniform(6, 22)
            if lado == "n":
                x, y = t, RNG.uniform(58, 76)
                if CAV_TX * TILE - 40 < x < (CAV_TX + 5) * TILE + 40:
                    continue
            elif lado == "s":
                x, y = t, RNG.uniform(LIMITES[3] - 12, LIMITES[3] - 2)
            elif lado == "o":
                x, y = RNG.uniform(12, 26), t + 60
            else:
                x, y = RNG.uniform(LIMITES[2] - 26, LIMITES[2] - 12), t + 60
            if y > LIMITES[3] - 1 or y < 40 or x < 8 or x > LIMITES[2] - 8:
                continue
            x, y = round(x), round(y)
            m.sprites.append({"nome": "AbetoBorda%02d" % len(m.sprites), "x": x, "y": y, "tipo": "abeto"})
            bx = x + G.ABETO["offset"][0]
            m.obstaculos.append(retangulo(bx + r_abeto[0], y - 8, bx + r_abeto[2], y))
    r_carv = G.medir_base_arvore(G.VERAO.img, G.CARVALHO["regiao"])
    for i, (x, y) in enumerate(m.espalhar(6, 58.0, margem=96.0)):
        m.sprites.append({"nome": "Carvalho%02d" % (i + 1), "x": x, "y": y, "tipo": "carvalho"})
        bx = x + G.CARVALHO["offset"][0]
        m.obstaculos.append(retangulo(bx + r_carv[0], y - 8, bx + r_carv[2], y))
    for i, (x, y) in enumerate(m.espalhar(8, 26.0, margem=48.0)):
        tipo = "arbusto_g" if i % 2 == 0 else "arbusto_m"
        m.sprites.append({"nome": "Arbusto%02d" % (i + 1), "x": x, "y": y, "tipo": tipo})
        cfg = G.ARBUSTO_G if tipo == "arbusto_g" else G.ARBUSTO_M
        ox, oy = cfg["offset"]
        c = cfg["colisao"]
        m.obstaculos.append(retangulo(x + ox + c[0], y + oy + c[1], x + ox + c[2], y + oy + c[3]))
    usadas = set()
    for (x, y) in m.espalhar(9, 20.0, margem=48.0):
        cel = (int(x // TILE), int(y // TILE))
        if cel in usadas or cel in m.terra:
            continue
        usadas.add(cel)
        t = RNG.choice(G.ROCHAS)
        m.detalhes[cel] = t
        r = G.retangulo_rocha(t)
        m.obstaculos.append(retangulo(cel[0] * TILE + r[0], cel[1] * TILE + r[1], cel[0] * TILE + r[2], cel[1] * TILE + r[3]))
    for (x, y) in m.espalhar(18, 14.0, margem=40.0):
        cel = (int(x // TILE), int(y // TILE))
        if cel in usadas or cel in m.terra:
            continue
        usadas.add(cel)
        m.detalhes[cel] = RNG.choice(G.PLANTAS)
    # ---- Etapa B (posicao fixa, depois de todo o sorteio: o resto do mapa nao muda): o caldeirao no fogareiro
    # (desenho de 32x32 com a base na linha 30 e o fogareiro de x 5 a 26: 22 px de largura)
    m.sprites.append({"nome": "Caldeirao", "x": CALDEIRAO[0], "y": CALDEIRAO[1], "tipo": "caldeirao"})
    m.obstaculos.append(retangulo(CALDEIRAO[0] - 11, CALDEIRAO[1] - 9, CALDEIRAO[0] + 11, CALDEIRAO[1]))
    return m


def escrever_terreno(m):
    c = Cena()
    folha = c.recurso("Texture2D", "res://Tiles/Seasonal Forest/arena/spring.png", "arena_folha")
    ev_inverno = c.recurso("Texture2D", "res://Tiles/23.05a - Arctic Woodland 1.1/evergreen trees/evergreen trees (winter, top snow) 80x112.png", "evergreen_inverno")
    tex_casa = c.recurso("Texture2D", RES_STARTER + "casa_fazenda.png", "casa_png")
    tex_caldeirao = c.recurso("Texture2D", RES_FARM + "caldeirao.png", "caldeirao_png")
    s_caldeirao = c.recurso("Script", "res://Codigos/Design/caldeirao.gd", "caldeirao_script")
    s_plantio = c.recurso("Script", "res://Codigos/Logicas/plantio.gd", "plantio_script")
    s_interagivel = c.recurso("Script", "res://Codigos/Logicas/interagivel.gd", "interagivel_script")
    s_grupo = c.recurso("Script", "res://Codigos/Design/profundidade_grupo.gd", "prof_grupo")
    s_estacoes = c.recurso("Script", "res://Codigos/Design/estacoes.gd", "estacoes_script")
    s_passagem = c.recurso("Script", "res://Codigos/Logicas/passagem.gd", "passagem_script")

    fonte = ["texture = ExtResource(\"%s\")" % folha] + ["%d:%d/0 = 0" % (tx, ty) for tx, ty in G.TILES_USADOS]
    c.sub_recurso("TileSetAtlasSource", "Fonte_fazenda", fonte)
    c.sub_recurso("TileSet", "TileSet_fazenda", ['sources/0 = SubResource("Fonte_fazenda")'])
    # texturas das arvores: "arvore" (Estacoes troca a folha evergreen), "amostra" (folha sazonal)
    r = G.ABETO["regiao"]
    c.sub_recurso("AtlasTexture", "Atlas_abeto", ['resource_name = "arvore"', 'atlas = ExtResource("%s")' % ev_inverno,
                                                   "region = Rect2(%d, %d, %d, %d)" % r])
    for ident, cfg in (("Atlas_carvalho", G.CARVALHO), ("Atlas_arbusto_g", G.ARBUSTO_G), ("Atlas_arbusto_m", G.ARBUSTO_M)):
        rg = cfg["regiao"]
        c.sub_recurso("AtlasTexture", ident, ['resource_name = "amostra"', 'atlas = ExtResource("%s")' % folha,
                                              "region = Rect2(%d, %d, %d, %d)" % rg])
    c.sub_recurso("RectangleShape2D", "Forma_passagem", ["size = Vector2(56, 24)"])
    c.sub_recurso("RectangleShape2D", "Forma_porta", ["size = Vector2(30, 28)"])
    # o caldeirao e um AtlasTexture de 32x32 (o profundidade_grupo mede o sprite pela textura: so o quadro visivel conta);
    # o script dele anima os quadros 1-4 (fogo e bolhas)
    c.sub_recurso("AtlasTexture", "Atlas_caldeirao", ['atlas = ExtResource("%s")' % tex_caldeirao, "region = Rect2(32, 0, 32, 32)"])
    c.sub_recurso("RectangleShape2D", "Forma_caldeirao", ["size = Vector2(48, 44)"])

    c.no("Terrains", "Node2D", props=["texture_filter = 1"], raiz=True)
    camada(c, "Chao", m.chao, "TileSet_fazenda")
    camada(c, "Terra", m.terra, "TileSet_fazenda")
    camada(c, "Agua", {}, "TileSet_fazenda")
    camada(c, "Penhasco", m.penhasco, "TileSet_fazenda")
    camada(c, "Detalhes", m.detalhes, "TileSet_fazenda")

    c.no("Objetos3D", "Node2D", props=['script = ExtResource("%s")' % s_grupo])
    cfgs = {"abeto": ("Atlas_abeto", G.ABETO["offset"]), "carvalho": ("Atlas_carvalho", G.CARVALHO["offset"]),
            "arbusto_g": ("Atlas_arbusto_g", G.ARBUSTO_G["offset"]), "arbusto_m": ("Atlas_arbusto_m", G.ARBUSTO_M["offset"])}
    # a casa primeiro na ordem (nome fixo "Casa": os testes e o profundidade_grupo a conhecem)
    for s in sorted(m.sprites, key=lambda s: (s["tipo"] != "casa", s["y"], s["x"])):
        if s["tipo"] == "casa":
            c.no(s["nome"], "Sprite2D", "Objetos3D", [
                "position = %s" % vec(s["x"], s["y"]), 'texture = ExtResource("%s")' % tex_casa, "centered = false",
                "offset = %s" % vec(-48, -96)])
        elif s["tipo"] == "caldeirao":
            c.no(s["nome"], "Sprite2D", "Objetos3D", [
                "position = %s" % vec(s["x"], s["y"]), 'texture = SubResource("Atlas_caldeirao")', "centered = false",
                "offset = %s" % vec(-16, -31), 'script = ExtResource("%s")' % s_caldeirao])
        else:
            tex, off = cfgs[s["tipo"]]
            c.no(s["nome"], "Sprite2D", "Objetos3D", [
                "position = %s" % vec(s["x"], s["y"]), 'texture = SubResource("%s")' % tex, "centered = false",
                "offset = %s" % vec(off[0], off[1])])

    c.no("Obstaculos", "StaticBody2D", props=["collision_layer = 64", "collision_mask = 0"])
    for i, poli in enumerate(m.obstaculos):
        c.no("Obstaculo%d" % (i + 1), "CollisionPolygon2D", "Obstaculos", ["polygon = %s" % T.poligono(poli)])

    # borda do mapa: o jogador nao sai (a camera tambem e presa em fazenda.gd)
    c.no("LimiteFazenda", "StaticBody2D", props=["collision_layer = 64", "collision_mask = 0"])
    x0, y0, x1, y1 = LIMITES
    paredes = [("Norte", -80, -80, x1 + 80, y0 + 6), ("Sul", -80, y1 - 6, x1 + 80, y1 + 80),
               ("Oeste", -80, -80, x0 + 14, y1 + 80), ("Leste", x1 - 14, -80, x1 + 80, y1 + 80)]
    for nome, ax, ay, bx, by in paredes:
        c.sub_recurso("RectangleShape2D", "Forma_limite_" + nome, ["size = %s" % vec(bx - ax, by - ay)])
        c.no("Limite" + nome, "CollisionShape2D", "LimiteFazenda", [
            "position = %s" % vec((ax + bx) / 2, (ay + by) / 2), 'shape = SubResource("Forma_limite_%s")' % nome])

    # passagens: caverna (volta para a arena, so quando a arena nao esta em onda: la nao existe onda) e a porta da casa
    c.no("PassagemCaverna", "Area2D", props=["position = %s" % vec(*CAV_PASSAGEM), 'script = ExtResource("%s")' % s_passagem,
                                             'cena_destino = "res://cenas/cenario.tscn"', 'ponto_chegada = "caverna"',
                                             "deslocamento_aviso = Vector2(0, -38)"])
    c.no("Forma", "CollisionShape2D", "PassagemCaverna", ['shape = SubResource("Forma_passagem")'])
    c.no("PortaCasa", "Area2D", props=["position = %s" % vec(*PORTA_AREA), 'script = ExtResource("%s")' % s_passagem,
                                       'cena_destino = "res://cenas/casa.tscn"', 'ponto_chegada = "entrada"',
                                       "deslocamento_aviso = Vector2(0, -50)"])
    c.no("Forma", "CollisionShape2D", "PortaCasa", ['shape = SubResource("Forma_porta")'])
    # Etapa B: o caldeirao (a colheita vira pocao); F/Y como os outros interagiveis
    c.no("InteracaoCaldeirao", "Area2D", props=["position = %s" % vec(CALDEIRAO[0], CALDEIRAO[1] - 6), 'script = ExtResource("%s")' % s_interagivel,
                                              'nome_tela = "caldeirao"', "so_entre_ondas = false", "deslocamento_aviso = Vector2(0, -40)"])
    c.no("Forma", "CollisionShape2D", "InteracaoCaldeirao", ['shape = SubResource("Forma_caldeirao")'])
    c.no("Chegada_caverna", "Marker2D", ".", ["position = %s" % vec(*CAV_CHEGADA)], grupos=["chegada"])
    c.no("Chegada_porta", "Marker2D", ".", ["position = %s" % vec(*PORTA_CHEGADA)], grupos=["chegada"])
    c.no("Estacoes", "Node", ".", ['script = ExtResource("%s")' % s_estacoes, "seguir_calendario = true"])
    # Etapa B: solo arado, plantas, cursor e clima do dia (por ultimo: o _ready do Estacoes ja rodou). A area de plantio e
    # Fazenda.AREA_PLANTIO (autoload), igual a PLANTIO daqui
    c.no("Plantio", "Node2D", ".", ['script = ExtResource("%s")' % s_plantio])
    return c.texto()


def escrever_fazenda():
    c = Cena()
    terreno = c.recurso("PackedScene", "res://cenas/terreno_fazenda.tscn", "terreno")
    jogador = c.recurso("PackedScene", "res://cenas/Jogador.tscn", "jogador")
    vinheta = c.recurso("PackedScene", "res://cenas/efeitos/vinheta.tscn", "vinheta")
    s_luz = c.recurso("Script", "res://Codigos/Efeitos/iluminacao.gd", "iluminacao")
    ui = c.recurso("PackedScene", "res://cenas/ui.tscn", "ui")
    interface = c.recurso("PackedScene", "res://cenas/ui/interface.tscn", "interface")
    s_raiz = c.recurso("Script", "res://Codigos/Logicas/fazenda.gd", "fazenda_gd")
    c.no("fazenda", "Node2D", props=['script = ExtResource("%s")' % s_raiz, "limites = Rect2(%d, %d, %d, %d)" % (
        LIMITES[0], LIMITES[1], LIMITES[2] - LIMITES[0], LIMITES[3] - LIMITES[1]), 'metadata/titulo_hud = "FAZENDA"',
                                  "metadata/barra_ferramentas = true"], raiz=True)
    c.no("Terrains", "", ".", instancia=terreno)
    c.no("Jogador", "", ".", ["z_index = 1", "position = %s" % vec(*CAV_CHEGADA), "collision_mask = 96"], instancia=jogador)
    c.no("Vinheta", "", ".", ["layer = 1"], instancia=vinheta)
    c.no("Iluminacao", "Node", ".", ['script = ExtResource("%s")' % s_luz])
    c.no("CanvasModulate", "CanvasModulate", "Iluminacao", ["color = Color(0.86, 0.88, 1, 1)"])
    c.no("UI", "", ".", instancia=ui)
    c.no("Interface", "", ".", instancia=interface)
    return c.texto()


# ---------------------------------------------------------------- interior da casa
def escrever_casa():
    c = Cena()
    sheet_int = c.recurso("Texture2D", RES_STARTER + "home interiors, timber roof.png", "interiores")
    sheet_mov = c.recurso("Texture2D", RES_STARTER + "cozy furnishings sampler.png", "moveis")
    s_grupo = c.recurso("Script", "res://Codigos/Design/profundidade_grupo.gd", "prof_grupo")
    s_passagem = c.recurso("Script", "res://Codigos/Logicas/passagem.gd", "passagem_script")
    s_inter = c.recurso("Script", "res://Codigos/Logicas/interagivel.gd", "interagivel_script")
    jogador = c.recurso("PackedScene", "res://cenas/Jogador.tscn", "jogador")
    vinheta = c.recurso("PackedScene", "res://cenas/efeitos/vinheta.tscn", "vinheta")
    ui = c.recurso("PackedScene", "res://cenas/ui.tscn", "ui")
    interface = c.recurso("PackedScene", "res://cenas/ui/interface.tscn", "interface")

    fundo, piso, parede = D.celulas_interior()
    usados = sorted({t for cam in (fundo, piso, parede) for t in cam.values()})
    c.sub_recurso("TileSetAtlasSource", "Fonte_casa", ['texture = ExtResource("%s")' % sheet_int] + ["%d:%d/0 = 0" % t for t in usados])
    c.sub_recurso("TileSet", "TileSet_casa", ['sources/0 = SubResource("Fonte_casa")'])
    for nome, cfg in ((n, (r, p)) for n, r, p, _ in D.MOVEIS):
        r = cfg[0]
        c.sub_recurso("AtlasTexture", "Atlas_" + nome, ['atlas = ExtResource("%s")' % sheet_mov, "region = Rect2(%d, %d, %d, %d)" % r])
    c.sub_recurso("RectangleShape2D", "Forma_saida", ["size = Vector2(30, 18)"])
    c.sub_recurso("RectangleShape2D", "Forma_cama", ["size = Vector2(84, 76)"])

    c.no("casa", "Node2D", props=['metadata/titulo_hud = "CASA"'], raiz=True)
    # fundo escuro (a cor do tile de "parede por cima" da folha) alem do comodo
    c.no("Fundo", "ColorRect", props=["z_index = -1001", "offset_left = -900.0", "offset_top = -700.0",
                                      "offset_right = 900.0", "offset_bottom = 700.0", "mouse_filter = 2",
                                      "color = Color(0.0941176, 0.0941176, 0.12549, 1)"])
    camada(c, "Fundo2", fundo, "TileSet_casa", z=-1000)
    camada(c, "Piso", piso, "TileSet_casa", z=-999)
    camada(c, "Paredes", parede, "TileSet_casa", z=-998)
    c.no("CanvasModulate", "CanvasModulate", props=["color = Color(1, 0.94, 0.86, 1)"])

    c.no("Objetos3D", "Node2D", props=['script = ExtResource("%s")' % s_grupo])
    for nome, regiao, (bx, by), espelho in sorted(D.MOVEIS, key=lambda m: m[2][1]):
        w, h = regiao[2], regiao[3]
        props = ["position = %s" % vec(bx, by), 'texture = SubResource("Atlas_%s")' % nome, "centered = false",
                 "offset = %s" % vec(-(w // 2), -h)]
        if espelho:
            props.append("flip_h = true")
        c.no(nome, "Sprite2D", "Objetos3D", props)

    # colisoes: paredes (a de baixo com o vao da porta), e a base de cada movel
    c.no("Colisoes", "StaticBody2D", props=["collision_layer = 64", "collision_mask = 0"])
    sw, sh = D.SALA_W * TILE, D.SALA_H * TILE
    nx0, nx1 = D.NICHO_X[0] * TILE, (D.NICHO_X[1] + 1) * TILE
    blocos = [("ParedeNorte", -64, -80, sw + 64, 4), ("ParedeOeste", -64, -80, 0, sh + 80), ("ParedeLeste", sw, -80, sw + 64, sh + 80),
              ("ParedeSulE", -64, sh, nx0, sh + 80), ("ParedeSulD", nx1, sh, sw + 64, sh + 80), ("FundoNicho", nx0, sh + 16, nx1, sh + 80),
              ("Cama", 24, 10, 56, 60), ("Bau", 80, 8, 112, 18), ("Estante", 136, 12, 168, 24),
              ("Mesa", 120, 88, 152, 106), ("CadeiraE", 106, 98, 118, 104), ("CadeiraD", 154, 98, 166, 104)]
    for nome, x0, y0, x1, y1 in blocos:
        c.sub_recurso("RectangleShape2D", "Forma_" + nome, ["size = %s" % vec(x1 - x0, y1 - y0)])
        c.no("Col" + nome, "CollisionShape2D", "Colisoes", ["position = %s" % vec((x0 + x1) / 2, (y0 + y1) / 2),
                                                           'shape = SubResource("Forma_%s")' % nome])
    # saida (o vao na parede sul) e cama
    centro_nicho = (nx0 + nx1) // 2
    c.no("SaidaCasa", "Area2D", props=["position = %s" % vec(centro_nicho, sh + 6), 'script = ExtResource("%s")' % s_passagem,
                                       'cena_destino = "res://cenas/fazenda.tscn"', 'ponto_chegada = "porta"',
                                       "deslocamento_aviso = Vector2(0, -30)"])
    c.no("Forma", "CollisionShape2D", "SaidaCasa", ['shape = SubResource("Forma_saida")'])
    c.no("Cama", "Area2D", props=["position = %s" % vec(40, 34), 'script = ExtResource("%s")' % s_inter, 'nome_tela = "dormir"',
                                  "so_entre_ondas = false", "deslocamento_aviso = Vector2(0, -52)"])
    c.no("Forma", "CollisionShape2D", "Cama", ['shape = SubResource("Forma_cama")'])
    c.no("Chegada_entrada", "Marker2D", ".", ["position = %s" % vec(centro_nicho, sh - 14)], grupos=["chegada"])
    c.no("Chegada_cama", "Marker2D", ".", ["position = %s" % vec(70, 44)], grupos=["chegada"])
    c.no("Jogador", "", ".", ["z_index = 1", "position = %s" % vec(centro_nicho, sh - 14), "collision_mask = 96"], instancia=jogador)
    c.no("Vinheta", "", ".", ["layer = 1"], instancia=vinheta)
    c.no("UI", "", ".", instancia=ui)
    c.no("Interface", "", ".", instancia=interface)
    return c.texto()


def main():
    gerar_png_casa()
    print("png:", os.path.relpath(PNG_CASA, RAIZ))
    m = construir_mapa()
    open(SAIDA_TERRENO, "w", encoding="utf-8").write(escrever_terreno(m))
    open(SAIDA_FAZENDA, "w", encoding="utf-8").write(escrever_fazenda())
    open(SAIDA_CASA, "w", encoding="utf-8").write(escrever_casa())
    print("cenas: terreno_fazenda, fazenda, casa")
    print("camadas: chao=%d terra=%d penhasco=%d detalhes=%d | sprites=%d | obstaculos=%d"
          % (len(m.chao), len(m.terra), len(m.penhasco), len(m.detalhes), len(m.sprites), len(m.obstaculos)))
    for i, poli in enumerate(m.obstaculos):
        if len(poli) < 3 or G.auto_intersecao(poli):
            print("PROBLEMA: Obstaculo%d invalido" % (i + 1))


if __name__ == "__main__":
    main()
