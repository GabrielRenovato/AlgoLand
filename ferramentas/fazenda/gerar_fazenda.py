#!/usr/bin/env python3
"""Gerador da fazenda e da casa (Etapa A). Python puro, sem PIL/numpy; deterministico (semente fixa).

Como usar (da raiz do projeto):
    python3 ferramentas/fazenda/gerar_fazenda.py
    python3 ferramentas/fazenda/gerar_fazenda.py --somente-casa  # preserva o terreno existente
    flatpak run org.godotengine.Godot --headless --path . --import

Saida:
  - Fachada inicial: casa_exterior.gd e casas/exterior/casa_jogador.png, no mesmo sistema da cidade.
    Para preparar a imagem preservada: python3 ferramentas/fazenda/preparar_casa_inicial.py
  - cenas/terreno_fazenda.tscn : mapa (grama sazonal, estrada e a grande area de plantio em terra, a casa com canteiros de
    flores, o pomar e a pedreira que a machadinha e a picareta derrubam, o limite do mapa). Usa os mesmos sistemas da arena: Estacoes (troca de folha), clima,
    profundidade (Objetos3D + profundidade_grupo.gd) e colisoes medidas por pixel
  - cenas/fazenda.tscn : o terreno + Jogador, luz, HUD, Interface e vinheta (sem inimigos nem ondas)
  - (Etapa B) o no Plantio (solo arado, plantas e clima do dia) e a meta "barra_ferramentas" (o HUD mostra a barra da ferramenta ativa)
  - cenas/casa.tscn : o interior (piso, parede com janela, cama, bau, estante, mesa e cadeiras do Mana Seed; duas xicaras de
    cafe na mesa e as zonas das cadeiras: F senta e toma um cafezinho, ver codigo/logica/cadeira.gd)

Reaproveita de ferramentas/arena/gerar_arena.py as folhas sazonais, a terra em autotile (blob 3x3) e as medidas
de colisao por pixel das arvores.
"""
import math
import os
import random
import sys
from pathlib import Path

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
# A casa no alto, com canteiros de flores na frente; a estrada passa embaixo dela, de oeste para a saida da vila (leste);
# abaixo da estrada, a grande area de plantio (as pocoes sao feitas com a Dona Rosa, na enfermaria da vila). O pomar
# (carvalhos que a machadinha corta) fica no sudeste e a pedreira (pedras da picareta) no nordeste. Aro de abetos em volta.
MAPA_W, MAPA_H = 72, 48
LIMITES = (0, 0, MAPA_W * TILE, MAPA_H * TILE)
CASA_BASE = (352, 216)                               # centro da base do desenho da casa
PORTA_CENTRO_X = CASA_BASE[0] - 48 + (D.PORTA_X[0] + D.PORTA_X[1]) // 2
CASA_RET = (PORTA_CENTRO_X - 56, CASA_BASE[1] - 100, PORTA_CENTRO_X + 56, CASA_BASE[1] + 52)  # zona proibida de props
PORTA_AREA = (PORTA_CENTRO_X, CASA_BASE[1] + 14)     # zona de interacao da porta
PORTA_CHEGADA = (PORTA_CENTRO_X, CASA_BASE[1] + 40)
ESTRADA_Y = 296
LAGO = (652, 452)                                    # centro do laguinho (lago_fazenda.gd), entre a horta e o pomar
TRILHA = [(PORTA_CENTRO_X, CASA_BASE[1] + 18), (PORTA_CENTRO_X, ESTRADA_Y)]      # da porta ate a estrada
TRILHA_CIDADE = [(88, ESTRADA_Y), (LIMITES[2] + 16, ESTRADA_Y)]                  # a estrada (leste: a vila)
CAMINHOS = [TRILHA, TRILHA_CIDADE]
PORTAO_CIDADE = (LIMITES[2] - 40, ESTRADA_Y)
CHEGADA_CIDADE = (LIMITES[2] - 72, ESTRADA_Y - 9)   # pes alinhados a estrada; fora da zona de retorno
PLANTIO = (6, 21, 37, 36)                            # tiles (x0, y0, x1, y1): a area de plantio (terra), 32 x 16
PLANTIO_PX = (PLANTIO[0] * TILE, PLANTIO[1] * TILE, (PLANTIO[2] + 1) * TILE, (PLANTIO[3] + 1) * TILE)
CANTEIROS_FLORES = [(15, 14, 18, 16), (25, 14, 28, 16)]  # tiles (x0, y0, x1, y1) dos dois lados da porta
POMAR = [(744, 516), (848, 488), (952, 528), (1056, 492), (792, 612), (904, 626), (1016, 604)]
PEDREIRA = (50, 6, 64, 12)                           # tiles onde ficam as pedras da picareta
# Bordas: ao norte o paredao de penhasco (a face de um plato largo do Seasonal Forest, topo fora do mapa, pe na linha
# PE_NORTE) com abetos em cima; a oeste, a leste e ao sul uma floresta fechada de abetos em duas fileiras desencontradas
# (a beirada de plato vista de cima ficava uma tira fina e feia). A floresta leste abre na estrada (saida para a vila)
PE_NORTE = 4                                         # linha de tiles do pe do penhasco norte
BEIRADA_OESTE, BEIRADA_LESTE = 3, MAPA_W - 4         # colunas onde a floresta das laterais termina
BEIRADA_SUL = MAPA_H - 8                             # linha da cerca do sul
# Cerca de madeira (ferramentas/fazenda/montar_cerca.py) logo na frente da floresta: a oeste, a leste e ao sul, do pe do
# paredao norte ate a esquina; abre um portao na estrada para a vila
CERCA_OESTE, CERCA_LESTE = 64, MAPA_W * TILE - 64     # x dos postes das cercas laterais
CERCA_SUL = BEIRADA_SUL * TILE + 16                   # y da base da cerca do sul
CERCA_NORTE = (PE_NORTE + 1) * TILE + 8               # y da base do primeiro poste das laterais
RES_FARM = "res://assets/cenario/Farm RPG/"

SAIDA_TERRENO = os.path.join(RAIZ, "cenas", "terreno_fazenda.tscn")
SAIDA_FAZENDA = os.path.join(RAIZ, "cenas", "fazenda.tscn")
SAIDA_CASA = os.path.join(RAIZ, "cenas", "casa.tscn")
PNG_CASA = os.path.join(RAIZ, "assets/cenario", "Starter Pack", "casa_fazenda.png")
RES_STARTER = "res://assets/cenario/Starter Pack/"


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


def construir_mapa():
    m = Mapa()
    m.recursos = []   # o que a machadinha e a picareta derrubam (codigo/logica/extracao_fazenda.gd)

    def obstaculo(poli):
        m.obstaculos.append(poli)
        return "Obstaculos/Obstaculo%d" % len(m.obstaculos)

    r_abeto = G.medir_base_arvore(G.EVERGREEN_VERAO, G.ABETO["regiao"])
    r_carv = G.medir_base_arvore(G.VERAO.img, G.CARVALHO["regiao"])

    # ---- A fachada compartilha casa_exterior.gd com a cidade. Só a base bloqueia;
    # o telhado fica translúcido quando o jogador passa atrás. A porta mantém o caminho existente.
    m.sprites.append({"nome": "Casa", "x": CASA_BASE[0], "y": CASA_BASE[1], "tipo": "casa"})
    obstaculo(retangulo(PORTA_CENTRO_X - 46, CASA_BASE[1] - 22, PORTA_CENTRO_X + 46, CASA_BASE[1] - 2))
    m.ocupados.append((PORTA_CENTRO_X, CASA_BASE[1] - 40, 78))
    m.ocupados.append((LAGO[0], LAGO[1], 52))   # nada nasce em cima do laguinho

    # ---- penhascos em volta
    norte = G.montar_mesa(-2, PE_NORTE - 7, MAPA_W + 4, False)
    m.penhasco.update(norte)
    obstaculo(retangulo(-80, -80, LIMITES[2] + 80, (PE_NORTE + 1) * TILE - 4))
    vao_estrada = range((ESTRADA_Y - 40) // TILE, (ESTRADA_Y + 40) // TILE + 1)
    # limites: a cerca (o que fica atras dela e floresta)
    y_vao0, y_vao1 = ESTRADA_Y - 24, ESTRADA_Y + 24
    obstaculo(retangulo(-80, -80, CERCA_OESTE + 4, LIMITES[3] + 80))
    obstaculo(retangulo(CERCA_LESTE - 4, -80, LIMITES[2] + 80, y_vao0))
    obstaculo(retangulo(CERCA_LESTE - 4, y_vao1, LIMITES[2] + 80, LIMITES[3] + 80))
    obstaculo(retangulo(-80, CERCA_SUL - 6, LIMITES[2] + 80, LIMITES[3] + 80))
    m.cercas = []   # (tipo, x, y): "horizontal", "poste" ou "vertical", pela base
    for y in range(CERCA_NORTE, CERCA_SUL - 8, 24):
        m.cercas.append(("vertical", CERCA_OESTE, y))
        if not (y_vao0 - 8 <= y <= y_vao1 + 16):
            m.cercas.append(("vertical", CERCA_LESTE, y))
    for x in range(CERCA_OESTE, CERCA_LESTE, 16):
        m.cercas.append(("horizontal", x, CERCA_SUL))
    m.cercas.append(("poste", CERCA_LESTE, CERCA_SUL))
    # postes do portao, dos dois lados da estrada
    m.cercas += [("poste", CERCA_LESTE, y_vao0 - 2), ("poste", CERCA_LESTE, y_vao1 + 14)]

    # ---- terra: caminhos + area de plantio
    def no_caminho(px, py, folga):
        return any(G.dist_segmento((px, py), c[i], c[i + 1]) <= folga for c in CAMINHOS for i in range(len(c) - 1))

    def na_forma(x, y):
        if PLANTIO[0] <= x <= PLANTIO[2] and PLANTIO[1] <= y <= PLANTIO[3]:
            return True
        return no_caminho(x * TILE + 8, y * TILE + 8, 20.0)

    proibido = set()
    for cy in range(-2, MAPA_H + 2):
        for cx in range(-2, MAPA_W + 2):
            px, py = cx * TILE + 8, cy * TILE + 8
            dentro_casa = CASA_RET[0] - 8 <= px <= CASA_RET[2] + 8 and CASA_RET[1] <= py <= CASA_BASE[1] + 6
            if dentro_casa or not (1 <= cx < MAPA_W - 1 and 1 <= cy < MAPA_H - 1):
                proibido.add((cx, cy))
    S = {(cx, cy) for cy in range(MAPA_H) for cx in range(MAPA_W) if (cx, cy) not in proibido and na_forma(cx, cy)}
    # a estrada sai pela borda leste (sem o canto arredondado do autotile ali)
    S |= {(cx, cy) for cy in range(MAPA_H) for cx in range(BEIRADA_LESTE - 1, MAPA_W) if abs(cy * TILE + 8 - ESTRADA_Y) <= 20}
    S = G.regularizar_terra(S, proibido - {(cx, cy) for (cx, cy) in S})
    m.terra = G.tiles_terra(S)

    # ---- chao: grama com flores esparsas, e os canteiros de flores na frente da casa (so flor)
    for cy in range(-3, MAPA_H + 3):
        for cx in range(-3, MAPA_W + 3):
            m.chao[(cx, cy)] = RNG.choice(G.FLORES) if RNG.random() < 0.03 else RNG.choice(G.GRAMA)
    for x0, y0, x1, y1 in CANTEIROS_FLORES:
        for cy in range(y0, y1 + 1):
            for cx in range(x0, x1 + 1):
                m.chao[(cx, cy)] = RNG.choice(G.FLORES)
        m.ocupados.append(((x0 + x1 + 1) * 8, (y0 + y1 + 1) * 8, 36))

    def livre(x, y, raio):
        if not (CERCA_OESTE + 16 + raio <= x <= CERCA_LESTE - 16 - raio
                and (PE_NORTE + 2) * TILE + raio <= y <= CERCA_SUL - 20):
            return False
        if CASA_RET[0] - 24 - raio <= x <= CASA_RET[2] + 24 + raio and CASA_RET[1] - 30 - raio <= y <= CASA_RET[3] + 28 + raio:
            return False
        if PLANTIO_PX[0] - 28 - raio <= x <= PLANTIO_PX[2] + 28 + raio and PLANTIO_PX[1] - 28 - raio <= y <= PLANTIO_PX[3] + 28 + raio:
            return False
        if no_caminho(x, y, 36 + raio):
            return False
        return all(math.hypot(x - ox, y - oy) >= orr + raio for ox, oy, orr in m.ocupados)

    def espalhar(qtd, raio, area=None, tentativas=6000):
        x0, y0, x1, y1 = area or (0, 0, LIMITES[2], LIMITES[3])
        pts = []
        for _ in range(tentativas):
            if len(pts) >= qtd:
                break
            x, y = RNG.uniform(x0, x1), RNG.uniform(y0, y1)
            if livre(x, y, raio):
                pts.append((round(x), round(y)))
                m.ocupados.append((x, y, raio))
        return pts

    # ---- pomar: carvalhos que a machadinha corta
    for i, (x, y) in enumerate(POMAR):
        nome = "Carvalho%02d" % (i + 1)
        m.sprites.append({"nome": nome, "x": x, "y": y, "tipo": "carvalho"})
        bx = x + G.CARVALHO["offset"][0]
        m.recursos.append({"chave": nome, "tipo": "arvore", "pos": (x, y), "no": "Objetos3D/" + nome,
                           "obstaculo": obstaculo(retangulo(bx + r_carv[0], y - 8, bx + r_carv[2], y))})
        m.ocupados.append((x, y, 44))

    # ---- abetos: uma fileira em cima do paredao norte e duas desencontradas nas outras bordas (nao cortam: sao o limite
    # do mapa; a floresta leste abre na estrada)
    def abeto(x, y):
        x, y = round(x), round(y)
        m.sprites.append({"nome": "AbetoBorda%02d" % len(m.sprites), "x": x, "y": y, "tipo": "abeto"})
        bx = x + G.ABETO["offset"][0]
        obstaculo(retangulo(bx + r_abeto[0], y - 8, bx + r_abeto[2], y))

    for k in range(LIMITES[2] // 30 + 1):
        abeto(k * 30 + RNG.uniform(4, 14), RNG.uniform(10, 20))
    passo = 22
    for fileira, recuo in enumerate((10, 32)):
        desloca = 0 if fileira == 0 else passo / 2
        for k in range(int((LIMITES[3] - 40) / passo) + 1):
            y = 40 + desloca + k * passo + RNG.uniform(-2, 2)
            if y > LIMITES[3] - 2:
                continue
            abeto(recuo + RNG.uniform(-2, 2), y)
            if abs(y - ESTRADA_Y) >= 56:
                abeto(LIMITES[2] - recuo + RNG.uniform(-2, 2), y)
        for k in range(int((LIMITES[2] - 2 * 44) / passo) + 1):
            x = 44 + desloca + k * passo + RNG.uniform(-2, 2)
            abeto(x, LIMITES[3] - 2 - (fileira * 22) + RNG.uniform(-2, 2))

    # ---- carvalhos soltos e arbustos (a machadinha corta os dois)
    for i, (x, y) in enumerate(espalhar(4, 58.0, (96, 100, LIMITES[2] - 96, CERCA_SUL - 24))):
        nome = "Carvalho%02d" % (len(POMAR) + i + 1)
        m.sprites.append({"nome": nome, "x": x, "y": y, "tipo": "carvalho"})
        bx = x + G.CARVALHO["offset"][0]
        m.recursos.append({"chave": nome, "tipo": "arvore", "pos": (x, y), "no": "Objetos3D/" + nome,
                           "obstaculo": obstaculo(retangulo(bx + r_carv[0], y - 8, bx + r_carv[2], y))})
    arbustos = [(CANTEIROS_FLORES[0][0] * TILE - 12, 268), (CANTEIROS_FLORES[1][2] * TILE + 28, 268)]
    arbustos += espalhar(10, 24.0)
    for i, (x, y) in enumerate(arbustos):
        tipo = "arbusto_g" if i % 2 == 0 else "arbusto_m"
        nome = "Arbusto%02d" % (i + 1)
        m.sprites.append({"nome": nome, "x": x, "y": y, "tipo": tipo})
        cfg = G.ARBUSTO_G if tipo == "arbusto_g" else G.ARBUSTO_M
        ox, oy = cfg["offset"]
        c = cfg["colisao"]
        m.recursos.append({"chave": nome, "tipo": "arbusto", "pos": (x, y), "no": "Objetos3D/" + nome,
                           "obstaculo": obstaculo(retangulo(x + ox + c[0], y + oy + c[1], x + ox + c[2], y + oy + c[3]))})
        m.ocupados.append((x, y, 24))

    # ---- pedras: a pedreira no nordeste e algumas soltas (a picareta quebra todas)
    usadas = set()
    def pedra(cel):
        if cel in usadas or cel in m.terra:
            return
        usadas.add(cel)
        t = RNG.choice(G.ROCHAS)
        m.detalhes[cel] = t
        r = G.retangulo_rocha(t)
        m.recursos.append({"chave": "Pedra_%d_%d" % cel, "tipo": "pedra", "pos": (cel[0] * TILE + 8, cel[1] * TILE + r[3]),
                           "celula": cel, "obstaculo": obstaculo(retangulo(cel[0] * TILE + r[0], cel[1] * TILE + r[1],
                                                                           cel[0] * TILE + r[2], cel[1] * TILE + r[3]))})
        m.ocupados.append((cel[0] * TILE + 8, cel[1] * TILE + 8, 14))
    x0, y0, x1, y1 = PEDREIRA
    for (x, y) in espalhar(16, 16.0, (x0 * TILE, y0 * TILE, x1 * TILE, y1 * TILE)):
        pedra((int(x // TILE), int(y // TILE)))
    for (x, y) in espalhar(6, 20.0):
        pedra((int(x // TILE), int(y // TILE)))
    # ---- plantinhas soltas (enfeite sem colisao)
    for (x, y) in espalhar(22, 14.0):
        cel = (int(x // TILE), int(y // TILE))
        if cel in usadas or cel in m.terra:
            continue
        usadas.add(cel)
        m.detalhes[cel] = RNG.choice(G.PLANTAS)
    return m


def escrever_terreno(m):
    c = Cena()
    folha = c.recurso("Texture2D", "res://assets/cenario/Seasonal Forest/arena/spring.png", "arena_folha")
    ev_inverno = c.recurso("Texture2D", "res://assets/cenario/23.05a - Arctic Woodland 1.1/evergreen trees/evergreen trees (winter, top snow) 80x112.png", "evergreen_inverno")
    s_casa_fachada = c.recurso("Script", "res://codigo/cidade/casa_exterior.gd", "casa_fachada")
    s_plantio = c.recurso("Script", "res://codigo/logica/plantio.gd", "plantio_script")
    s_interagivel = c.recurso("Script", "res://codigo/logica/interagivel.gd", "interagivel_script")
    s_grupo = c.recurso("Script", "res://codigo/cenario/profundidade_grupo.gd", "prof_grupo")
    s_estacoes = c.recurso("Script", "res://codigo/cenario/estacoes.gd", "estacoes_script")
    s_passagem = c.recurso("Script", "res://codigo/logica/passagem.gd", "passagem_script")
    s_extracao = c.recurso("Script", "res://codigo/logica/extracao_fazenda.gd", "extracao_script")
    s_vida = c.recurso("Script", "res://codigo/cenario/vida_fazenda.gd", "vida_script")
    # a cerca sai no verao; codigo/cenario/cerca_sazonal.gd troca pela estacao
    texturas_cerca = {t: c.recurso("Texture2D", "res://assets/cenario/fazenda/cerca/verao/%s.png" % t, "cerca_" + t)
                      for t in ("horizontal", "poste", "vertical")}
    s_cerca = c.recurso("Script", "res://codigo/cenario/cerca_sazonal.gd", "cerca_script")
    s_lago = c.recurso("Script", "res://codigo/cenario/lago_fazenda.gd", "lago_script")

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
    c.sub_recurso("RectangleShape2D", "Forma_porta", ["size = Vector2(30, 28)"])

    c.no("Terrains", "Node2D", props=["texture_filter = 1"], raiz=True)
    camada(c, "Chao", m.chao, "TileSet_fazenda")
    camada(c, "Terra", m.terra, "TileSet_fazenda")
    camada(c, "Agua", {}, "TileSet_fazenda")
    camada(c, "Penhasco", m.penhasco, "TileSet_fazenda")
    camada(c, "Detalhes", m.detalhes, "TileSet_fazenda")

    # laguinho do regador (desenhado em codigo por lago_fazenda.gd), entre a horta e o pomar
    c.no("Lago", "Node2D", props=["position = " + vec(*LAGO), 'script = ExtResource("%s")' % s_lago])
    c.no("Objetos3D", "Node2D", props=['script = ExtResource("%s")' % s_grupo])
    cfgs = {"abeto": ("Atlas_abeto", G.ABETO["offset"]), "carvalho": ("Atlas_carvalho", G.CARVALHO["offset"]),
            "arbusto_g": ("Atlas_arbusto_g", G.ARBUSTO_G["offset"]), "arbusto_m": ("Atlas_arbusto_m", G.ARBUSTO_M["offset"])}
    # a casa primeiro na ordem (nome fixo "Casa": os testes e o profundidade_grupo a conhecem)
    for s in sorted(m.sprites, key=lambda s: (s["tipo"] != "casa", s["y"], s["x"])):
        if s["tipo"] == "casa":
            c.no(s["nome"], "Node2D", "Objetos3D", [
                "position = %s" % vec(PORTA_CENTRO_X, s["y"]),
                'script = ExtResource("%s")' % s_casa_fachada, 'id = "casa_jogador"', "metadata/nivel_casa = 1"])
        else:
            tex, off = cfgs[s["tipo"]]
            c.no(s["nome"], "Sprite2D", "Objetos3D", [
                "position = %s" % vec(s["x"], s["y"]), 'texture = SubResource("%s")' % tex, "centered = false",
                "offset = %s" % vec(off[0], off[1])])

    # cerca (z pela base, como os outros objetos)
    for i, (tipo, x, y) in enumerate(m.cercas):
        alt = 47 if tipo == "vertical" else 23
        larg = 16 if tipo == "horizontal" else 8
        c.no("Cerca%03d" % (i + 1), "Sprite2D", "Objetos3D", [
            "position = %s" % vec(x, y), 'texture = ExtResource("%s")' % texturas_cerca[tipo], "centered = false",
            "offset = %s" % vec(-4, -alt), 'metadata/peca = "%s"' % tipo], grupos=["cerca"])

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

    # passagens: a estrada para a vila (leste) e a porta da casa
    c.sub_recurso("RectangleShape2D", "Forma_cidade", ["size = Vector2(28, 32)"])
    c.no("PassagemCidade", "Area2D", props=["position = %s" % vec(*PORTAO_CIDADE), 'script = ExtResource("%s")' % s_passagem,
                                           'cena_destino = "res://cenas/cidade.tscn"', 'ponto_chegada = "fazenda"',
                                           'so_entre_ondas = false', 'deslocamento_aviso = Vector2(0, -30)'])
    c.no("Forma", "CollisionShape2D", "PassagemCidade", ['shape = SubResource("Forma_cidade")'])
    c.no("PlacaCidade", "Label", props=['offset_left = %d.0' % (CERCA_LESTE - 96), 'offset_top = %d.0' % (ESTRADA_Y - 40),
                                       'offset_right = %d.0' % (CERCA_LESTE - 16), 'offset_bottom = %d.0' % (ESTRADA_Y - 22),
                                       'mouse_filter = 2', 'theme_override_font_sizes/font_size = 8', 'text = "VILA >"',
                                       'theme_override_colors/font_shadow_color = Color(0.16, 0.11, 0.1, 1)',
                                       'theme_override_constants/shadow_offset_x = 1', 'theme_override_constants/shadow_offset_y = 1', 'horizontal_alignment = 1'])
    c.no("PortaCasa", "Area2D", props=["position = %s" % vec(*PORTA_AREA), 'script = ExtResource("%s")' % s_passagem,
                                       'cena_destino = "res://cenas/casa.tscn"', 'ponto_chegada = "entrada"',
                                       "deslocamento_aviso = Vector2(0, -50)"])
    c.no("Forma", "CollisionShape2D", "PortaCasa", ['shape = SubResource("Forma_porta")'])
    c.no("Chegada_cidade", "Marker2D", ".", ["position = %s" % vec(*CHEGADA_CIDADE)], grupos=["chegada"])
    c.no("Chegada_porta", "Marker2D", ".", ["position = %s" % vec(*PORTA_CHEGADA)], grupos=["chegada"])
    c.no("Estacoes", "Node", ".", ['script = ExtResource("%s")' % s_estacoes, "seguir_calendario = true"])
    c.no("CercaSazonal", "Node", ".", ['script = ExtResource("%s")' % s_cerca])
    # Etapa B: solo arado, plantas, cursor e clima do dia (por ultimo: o _ready do Estacoes ja rodou). A area de plantio e
    # Fazenda.AREA_PLANTIO (autoload), igual a PLANTIO daqui
    c.no("Plantio", "Node2D", ".", ['script = ExtResource("%s")' % s_plantio])
    # Arvores e pedras que a machadinha e a picareta derrubam (por enquanto sem drop)
    itens = []
    for rec in m.recursos:
        campos = ['"chave": "%s"' % rec["chave"], '"tipo": "%s"' % rec["tipo"], '"pos": %s' % vec(*rec["pos"]),
                  '"obstaculo": NodePath("%s")' % rec["obstaculo"]]
        if "no" in rec:
            campos.append('"no": NodePath("%s")' % rec["no"])
        if "celula" in rec:
            campos.append('"celula": Vector2i(%d, %d)' % rec["celula"])
        itens.append("{" + ", ".join(campos) + "}")
    def desenho_e_colisao(cfg):
        ox, oy = cfg["offset"]
        x0, y0, x1, y1 = cfg["colisao"]
        return "Rect2(%d, %d, 0, 0)" % (ox, oy), "Rect2(%d, %d, %d, %d)" % (ox + x0, oy + y0, x1 - x0, y1 - y0)
    des_m, col_m = desenho_e_colisao(G.ARBUSTO_M)
    des_g, col_g = desenho_e_colisao(G.ARBUSTO_G)
    col_rochas = ", ".join("Rect2(%d, %d, %d, %d)" % (r[0], r[1], r[2] - r[0], r[3] - r[1]) for r in map(G.retangulo_rocha, G.ROCHAS))
    c.no("Extracao", "Node2D", ".", ['script = ExtResource("%s")' % s_extracao, "recursos = [%s]" % ", ".join(itens),
                                     "desenho_arbusto = " + des_m, "desenho_arvoreta = " + des_g,
                                     "colisao_arbusto = " + col_m, "colisao_arvoreta = " + col_g,
                                     # desenhos sem chao: ferramentas/fazenda/recortar_entulho.py (pedra_N na ordem de G.ROCHAS)
                                     "colisoes_pedra = Array[Rect2]([%s])" % col_rochas, "variantes_mato = %d" % len(G.PLANTAS)])
    # Vaga-lumes a noite e borboletas de dia sobre os canteiros e a horta
    canteiros = [(x0 * TILE, y0 * TILE, (x1 - x0 + 1) * TILE, (y1 - y0 + 1) * TILE) for x0, y0, x1, y1 in CANTEIROS_FLORES]
    canteiros.append((PLANTIO_PX[0], PLANTIO_PX[1], PLANTIO_PX[2] - PLANTIO_PX[0], PLANTIO_PX[3] - PLANTIO_PX[1]))
    c.no("Vida", "Node2D", ".", ['script = ExtResource("%s")' % s_vida,
                                 "area = Rect2(64, 96, %d, %d)" % (LIMITES[2] - 128, LIMITES[3] - 160),
                                 "canteiros = Array[Rect2]([%s])" % ", ".join("Rect2(%d, %d, %d, %d)" % r for r in canteiros)])
    return c.texto()


def escrever_fazenda():
    c = Cena()
    terreno = c.recurso("PackedScene", "res://cenas/terreno_fazenda.tscn", "terreno")
    jogador = c.recurso("PackedScene", "res://cenas/jogador.tscn", "jogador")
    vinheta = c.recurso("PackedScene", "res://cenas/efeitos/vinheta.tscn", "vinheta")
    s_luz = c.recurso("Script", "res://codigo/efeitos/iluminacao.gd", "iluminacao")
    ui = c.recurso("PackedScene", "res://cenas/ui.tscn", "ui")
    interface = c.recurso("PackedScene", "res://cenas/ui/interface.tscn", "interface")
    s_raiz = c.recurso("Script", "res://codigo/logica/fazenda.gd", "fazenda_gd")
    c.no("fazenda", "Node2D", props=['script = ExtResource("%s")' % s_raiz, "limites = Rect2(%d, %d, %d, %d)" % (
        LIMITES[0], LIMITES[1], LIMITES[2] - LIMITES[0], LIMITES[3] - LIMITES[1]), 'metadata/titulo_hud = "FAZENDA"',
                                  "metadata/barra_ferramentas = true"], raiz=True)
    c.no("Terrains", "", ".", instancia=terreno)
    c.no("Jogador", "", ".", ["z_index = 1", "position = %s" % vec(*PORTA_CHEGADA), "collision_mask = 96"], instancia=jogador)
    c.no("Vinheta", "", ".", ["layer = 1"], instancia=vinheta)
    c.no("Iluminacao", "Node", ".", ['script = ExtResource("%s")' % s_luz])
    c.no("CanvasModulate", "CanvasModulate", "Iluminacao", ["color = Color(0.86, 0.88, 1, 1)"])
    c.no("assets/ui", "", ".", instancia=ui)
    c.no("Interface", "", ".", instancia=interface)
    return c.texto()


# ---------------------------------------------------------------- interior da casa
# Planta inicial de um cômodo no layout dos interiores da vila, casa "casa_jogador"
# (ferramentas/cidade/layout_interiores.py, montada por codigo/cidade/interior_casa.gd). Aqui ficam os moveis do Mana Seed
# que tem comportamento: a cama (o sono animado, cama.gd), o bau, a estante, a mesa e as cadeiras do cafezinho (cadeira.gd).
# Casa inicial de um cômodo. Posição da base-centro de cada móvel na planta; as colisoes sao relativas a base (x0, y0, x1, y1)
MOVEIS_CASA = {"Cama": (216, 120), "Bau": (40, 78), "Estante": (104, 66), "Mesa": (88, 142), "CadeiraE": (61, 140), "CadeiraD": (115, 140)}
COLISOES_CASA = {"Cama": (-16, -50, 16, 0), "Bau": (-16, -10, 16, 0), "Estante": (-16, -12, 16, 0), "Mesa": (-16, -18, 16, 0),
                 "CadeiraE": (-3, -6, 9, 0), "CadeiraD": (-9, -6, 3, 0)}


def escrever_casa():
    layout = __import__("json").load(open(os.path.join(RAIZ, "assets/cenario/cidade/interiores/interiores.json")))
    geo = layout["casas"]["casa_jogador"]["geometria"]
    c = Cena()
    sheet_mov = c.recurso("Texture2D", RES_STARTER + "cozy furnishings sampler.png", "moveis")
    s_grupo = c.recurso("Script", "res://codigo/cenario/profundidade_grupo.gd", "prof_grupo")
    s_passagem = c.recurso("Script", "res://codigo/cidade/passagem_cidade.gd", "passagem_script")
    s_inter = c.recurso("Script", "res://codigo/logica/interagivel.gd", "interagivel_script")
    s_interior = c.recurso("Script", "res://codigo/cidade/interior_casa.gd", "interior_script")
    jogador = c.recurso("PackedScene", "res://cenas/jogador.tscn", "jogador")
    vinheta = c.recurso("PackedScene", "res://cenas/efeitos/vinheta.tscn", "vinheta")
    ui = c.recurso("PackedScene", "res://cenas/ui.tscn", "ui")
    interface = c.recurso("PackedScene", "res://cenas/ui/interface.tscn", "interface")

    regioes = {n: r for n, r, _, _ in D.MOVEIS}
    espelhos = {n: e for n, _, _, e in D.MOVEIS}
    for nome, r in regioes.items():
        if nome == "Cama":
            continue   # a cama e montada em faixas (abaixo)
        c.sub_recurso("AtlasTexture", "Atlas_" + nome, ['atlas = ExtResource("%s")' % sheet_mov, "region = Rect2(%d, %d, %d, %d)" % r])
    # Cama em faixas horizontais alinhadas a grade de profundidade (8 px, ver profundidade.gd): a origem de cada faixa fica
    # logo acima do fim da faixa (y = 8k + 7.99), assim quem esta na mesma faixa de altura fica NA FRENTE da cama e quem
    # esta acima dela fica atras. Uma cama inteira com z pela base cortava o jogador encostado de lado
    cama_r = regioes["Cama"]
    cama_bx, cama_by = MOVEIS_CASA["Cama"]
    cama_topo = cama_by - cama_r[3]
    cama_faixas = []
    k = cama_topo // 8
    while k * 8 < cama_by:
        topo, base = max(k * 8, cama_topo), min(k * 8 + 8, cama_by)
        cama_faixas.append((k, topo, base))
        k += 1
    for k, topo, base in cama_faixas:
        c.sub_recurso("AtlasTexture", "Atlas_Cama_%d" % k, ['atlas = ExtResource("%s")' % sheet_mov,
                      "region = Rect2(%d, %d, %d, %d)" % (cama_r[0], cama_r[1] + (topo - cama_topo), cama_r[2], base - topo)])
    s_cama = c.recurso("Script", "res://codigo/cenario/cama.gd", "cama_script")
    c.sub_recurso("RectangleShape2D", "Forma_saida", ["size = Vector2(40, 16)"])
    c.sub_recurso("RectangleShape2D", "Forma_cama", ["size = Vector2(84, 76)"])
    # xicara de cafe (cozy furnishings sampler: x 177, y 68, 10x8) e a zona de cada cadeira
    c.sub_recurso("AtlasTexture", "Atlas_Cafe", ['atlas = ExtResource("%s")' % sheet_mov, "region = Rect2(177, 68, 10, 8)"])
    c.sub_recurso("CircleShape2D", "Forma_cadeira", ["radius = 15.0"])
    s_cadeira = c.recurso("Script", "res://codigo/logica/cadeira.gd", "cadeira_script")

    c.no("casa", "Node2D", props=['metadata/titulo_hud = "CASA"', "metadata/nivel_casa = 1"], raiz=True)
    c.no("Fundo", "ColorRect", props=["z_index = -1001", "offset_left = -900.0", "offset_top = -700.0",
                                      "offset_right = 900.0", "offset_bottom = 700.0", "mouse_filter = 2",
                                      "color = Color(0.075, 0.07, 0.105, 1)"])
    # paredes, pisos, colisao das paredes e moveis de enfeite
    c.no("Interior", "Node2D", props=['script = ExtResource("%s")' % s_interior, 'id = "casa_jogador"'])
    c.no("CanvasModulate", "CanvasModulate", props=["color = Color(1, 0.94, 0.86, 1)"])

    c.no("Objetos3D", "Node2D", props=['script = ExtResource("%s")' % s_grupo])
    for k, topo, base in cama_faixas:
        y_origem = k * 8 + 7.99
        c.no("Cama_f%d" % k, "Sprite2D", "Objetos3D", [
            "position = %s" % vec(cama_bx, y_origem), 'texture = SubResource("Atlas_Cama_%d")' % k, "centered = false",
            "offset = %s" % vec(-(cama_r[2] // 2), topo - y_origem)])
    # no que cuida do sono: deitar()/levantar() (cabeca, cobertor, Z), na base-centro da cama
    c.no("CamaDormindo", "Node2D", "Objetos3D", ["position = %s" % vec(cama_bx, cama_by), 'script = ExtResource("%s")' % s_cama,
                                                  'folha = ExtResource("%s")' % sheet_mov])
    for nome, (bx, by) in sorted(MOVEIS_CASA.items(), key=lambda m: m[1][1]):
        if nome == "Cama":
            continue
        w, h = regioes[nome][2], regioes[nome][3]
        props = ["position = %s" % vec(bx, by), 'texture = SubResource("Atlas_%s")' % nome, "centered = false",
                 "offset = %s" % vec(-(w // 2), -h)]
        if espelhos[nome]:
            props.append("flip_h = true")
        c.no(nome, "Sprite2D", "Objetos3D", props)
    # as xicaras de cafe sao filhas da mesa (desenham logo acima dela)
    for nome_xicara, dx in (("Cafe_E", -9), ("Cafe_D", 9)):
        c.no(nome_xicara, "Sprite2D", "Objetos3D/Mesa", ["position = %s" % vec(dx, -22), 'texture = SubResource("Atlas_Cafe")'])

    # colisoes dos moveis do Mana Seed (as paredes sao do Interior). A da cama tem a largura exata do desenho: o jogador
    # encosta de lado e e desenhado por cima (a cama e fatiada em faixas, cada uma com a sua profundidade)
    c.no("Colisoes", "StaticBody2D", props=["collision_layer = 64", "collision_mask = 0"])
    for nome, (x0, y0, x1, y1) in COLISOES_CASA.items():
        bx, by = MOVEIS_CASA[nome]
        c.sub_recurso("RectangleShape2D", "Forma_" + nome, ["size = %s" % vec(x1 - x0, y1 - y0)])
        c.no("Col" + nome, "CollisionShape2D", "Colisoes", ["position = %s" % vec(bx + (x0 + x1) / 2, by + (y0 + y1) / 2),
                                                           'shape = SubResource("Forma_%s")' % nome])
    # saida (sai sozinho ao pisar no vao da porta, como nas casas da vila) e cama
    c.no("SaidaCasa", "Area2D", props=["position = %s" % vec(*geo["saida"]), 'script = ExtResource("%s")' % s_passagem,
                                       'cena_destino = "res://cenas/fazenda.tscn"', 'ponto_chegada = "porta"',
                                       "so_entre_ondas = false", "automatica = true"])
    c.no("Forma", "CollisionShape2D", "SaidaCasa", ['shape = SubResource("Forma_saida")'])
    c.no("Cama", "Area2D", props=["position = %s" % vec(cama_bx, cama_by - 26), 'script = ExtResource("%s")' % s_inter,
                                  'nome_tela = "dormir"', "so_entre_ondas = false", "deslocamento_aviso = Vector2(0, -52)"])
    c.no("Forma", "CollisionShape2D", "Cama", ['shape = SubResource("Forma_cama")'])
    # cadeiras: a esquerda olha para a direita e a direita (espelhada) para a esquerda, as duas para a mesa
    mesa_x, mesa_y = MOVEIS_CASA["Mesa"]
    for nome_cad, dx, lado, cafe in (("CadeiraE", -24, 1, "Cafe_E"), ("CadeiraD", 24, -1, "Cafe_D")):
        c.no("Zona" + nome_cad, "Area2D", props=["position = %s" % vec(mesa_x + dx, mesa_y - 8), 'script = ExtResource("%s")' % s_cadeira,
                                                  "so_entre_ondas = false", "deslocamento_aviso = Vector2(0, -34)", "lado = %d" % lado,
                                                  "assento = %s" % vec(1 * lado, -9), "saida = %s" % vec(0, -20),
                                                  'cafe = NodePath("../Objetos3D/Mesa/%s")' % cafe, 'mesa = NodePath("../Objetos3D/Mesa")'])
        c.no("Forma", "CollisionShape2D", "Zona" + nome_cad, ['shape = SubResource("Forma_cadeira")'])
    c.no("Chegada_entrada", "Marker2D", ".", ["position = %s" % vec(*geo["chegada"])], grupos=["chegada"])
    # ao acordar, o jogador aparece ao lado da cama (do lado do quarto, a esquerda dela)
    c.no("Chegada_cama", "Marker2D", ".", ["position = %s" % vec(cama_bx - 30, cama_by - 16)], grupos=["chegada"])
    c.no("Jogador", "", ".", ["z_index = 1", "position = %s" % vec(*geo["chegada"]), "collision_mask = 96"], instancia=jogador)
    c.no("Vinheta", "", ".", ["layer = 1"], instancia=vinheta)
    c.no("assets/ui", "", ".", instancia=ui)
    c.no("Interface", "", ".", instancia=interface)
    return c.texto()


def main():
    if "--somente-casa" in sys.argv:
        Path(SAIDA_CASA).write_text(escrever_casa(), encoding="utf-8")
        print("cena: casa")
        return
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
