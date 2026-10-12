"""Dados da casa: peca de fora montada em PNG e o interior (celulas de tiles e moveis). Usado por gerar_fazenda.py
e pela previa (compor.py), para conferir o desenho antes de gerar as cenas."""
import compor as C

TILE = 16
FOLHA_FORA = "simplified full timber.png"
FOLHA_DENTRO = "home interiors, timber roof.png"
FOLHA_MOVEIS = "cozy furnishings sampler.png"

# ---------------------------------------------------------------- fora
# Bloco 7x6 tiles da folha (colunas 8..14, linhas 2..7) = casa de frente com o telhado, a empena de enxaimel e a parede;
# a coluna 14 so tem o telhado (as linhas 4..7 dela sao a escada, outra peca). Conferido em ampliacao:
CASA_REGIAO = (128, 32, 112, 96)  # x, y, larg, alt na folha
CASA_LARG, CASA_ALT = 96, 96      # o recorte final (sem a escada e o beiral solto da coluna 14)


def montar_casa():
    """PNG 96x96 da casa. Remendos sobre o bloco cru:
    - coluna 14 inteira fora (escada e beiral que sobraria solto);
    - coluna 13, linhas 6..7: no lugar da porta aberta, o batente esquerdo da parede espelhado (fecha a parede na direita);
    - coluna 11, linhas 2..3: o vao do telhado recebe duas telhas da propria folha (coluna 13)."""
    casa = C.tela(CASA_LARG, CASA_ALT)
    C.colar(casa, FOLHA_FORA, 128, 32, CASA_LARG, 96, 0, 0)
    C.colar(casa, FOLHA_FORA, 128, 96, 16, 32, 80, 64, espelhar=True)
    C.colar(casa, FOLHA_FORA, 208, 32, 16, 16, 48, 0)
    C.colar(casa, FOLHA_FORA, 208, 48, 16, 16, 48, 16)
    return casa


# Porta da casa dentro do PNG (a coluna 12 da folha = x 64..80 do recorte)
PORTA_X = (64, 80)

# ---------------------------------------------------------------- dentro
# Grade do comodo em tiles (origem no canto superior esquerdo do PISO). Piso 12x7; parede norte 2 linhas acima (-2, -1);
# paredes laterais escuras; a parede sul tem o vao da porta (2 tiles) com a "nicho sul" da folha.
SALA_W, SALA_H = 12, 7
NICHO_X = (5, 6)            # colunas do vao na parede sul
JANELA_X = 5                # a janela da parede norte ocupa as colunas 5..6
FUNDO_RAIO = (-26, -18, 40, 30)  # (x0, y0, x1, y1) em tiles: tudo escuro ao redor

PISO = [(c, r) for c in range(5) for r in (5, 6)]          # piso "mais claro" (linhas 5 e 6 da folha)
PAREDE_NORTE = {-2: [(c, 14) for c in range(17, 22)], -1: [(c, 15) for c in range(17, 22)]}
JANELA = [[(24, 1), (25, 1)], [(24, 2), (25, 2)]]          # 2x2: parede com a janela (linhas -2 e -1)
ESCURO = (7, 2)
BORDA_L = (8, 2)   # escuro com borda a direita (parede esquerda, de frente para o piso)
BORDA_R = (6, 2)   # escuro com borda a esquerda (parede direita)
BORDA_S = (7, 1)   # escuro com borda em cima (parede sul)
CANTO_SE_ESQ = (8, 1)
CANTO_SD = (6, 1)
NICHO_L, NICHO_R = (19, 4), (22, 4)
NICHO_FUNDO = [(19, 5), (20, 5), (21, 5), (22, 5)]


def celulas_interior(janela=True):
    """(fundo, piso, parede): dicionarios {(x, y): (coluna, linha) na folha de interiores}."""
    fundo, piso, parede = {}, {}, {}
    x0, y0, x1, y1 = FUNDO_RAIO
    for y in range(y0, y1):
        for x in range(x0, x1):
            fundo[(x, y)] = ESCURO
    r = 0
    for y in range(SALA_H):
        for x in range(SALA_W):
            piso[(x, y)] = PISO[(x * 7 + y * 3) % len(PISO)]
    # parede norte
    for linha, pecas in PAREDE_NORTE.items():
        for x in range(SALA_W):
            parede[(x, linha)] = pecas[x % len(pecas)]
    if janela:
        for j, linha in enumerate(JANELA):
            for i, p in enumerate(linha):
                parede[(JANELA_X + i, -2 + j)] = p
    # paredes laterais (borda para o piso) do topo da parede norte ate o fim
    for y in range(-2, SALA_H + 2):
        parede[(-1, y)] = BORDA_L if y < SALA_H else CANTO_SE_ESQ if y == SALA_H else ESCURO
        parede[(SALA_W, y)] = BORDA_R if y < SALA_H else CANTO_SD if y == SALA_H else ESCURO
    # parede sul (linha SALA_H = faixa com borda em cima, linha SALA_H+1 = fundo do nicho / escuro)
    for x in range(SALA_W):
        if x == NICHO_X[0] - 1:
            parede[(x, SALA_H)] = NICHO_L
            parede[(x, SALA_H + 1)] = NICHO_FUNDO[0]
        elif x in NICHO_X:
            piso[(x, SALA_H)] = PISO[0]
            parede[(x, SALA_H + 1)] = NICHO_FUNDO[1 + NICHO_X.index(x)]
        elif x == NICHO_X[1] + 1:
            parede[(x, SALA_H)] = NICHO_R
            parede[(x, SALA_H + 1)] = NICHO_FUNDO[3]
        else:
            parede[(x, SALA_H)] = BORDA_S
            parede[(x, SALA_H + 1)] = ESCURO
    return fundo, piso, parede


# Moveis: nome, regiao na folha (x, y, larg, alt), posicao da BASE-centro em px do comodo (x, y_base)
# Regioes medidas por componentes de alfa e conferidas na ampliacao.
MOVEIS = [
    ("Cama", (208, 6, 32, 58), (40, 60), False),
    ("Bau", (96, 32, 32, 16), (96, 18), False),
    ("Estante", (128, 0, 32, 48), (152, 24), False),
    ("Mesa", (39, 5, 34, 42), (136, 106), False),
    ("CadeiraE", (1, 21, 13, 26), (112, 104), False),
    ("CadeiraD", (1, 21, 13, 26), (160, 104), True),
]


def montar_previa_interior(escala=4):
    fundo, piso, parede = celulas_interior()
    ox, oy = 3 * TILE, 4 * TILE   # margem em px da previa
    larg = (SALA_W + 6) * TILE
    alt = (SALA_H + 8) * TILE
    t = C.tela(larg, alt, (24, 22, 32, 255))
    for camada in (fundo, piso, parede):
        for (x, y), (c, r) in camada.items():
            px, py = ox + x * TILE, oy + y * TILE
            if 0 <= px < larg - TILE + 1 and 0 <= py < alt - TILE + 1:
                C.colar(t, FOLHA_DENTRO, c * TILE, r * TILE, TILE, TILE, px, py)
    for nome, (x, y, w, h), (bx, by), espelho in MOVEIS:
        C.colar(t, FOLHA_MOVEIS, x, y, w, h, ox + bx - w // 2, oy + by - h, espelhar=espelho)
    return C.ampliar(t, escala)


if __name__ == "__main__":
    import os
    from png_puro import salvar
    salvar(montar_previa_interior(4), os.path.expanduser("~/algoland_vis/prev_interior.png"))
    print("ok")
