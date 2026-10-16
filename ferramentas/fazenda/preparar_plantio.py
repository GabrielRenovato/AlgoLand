#!/usr/bin/env python3
"""Prepara os assets da mecanica de plantio (Etapa B). Python puro (sem PIL), deterministico.

Como usar (da raiz do projeto):
    python3 ferramentas/fazenda/preparar_plantio.py [pasta_do_farm_rpg]
    flatpak run org.godotengine.Godot --headless --path . --import      # importa os PNGs novos

O que faz:
  - copia de "Farm RPG - Tiny Asset Pack" (EmanuelleDev, emanuelledev.itch.io) SO o que o plantio usa, para
    res://assets/cenario/Farm RPG/: as tiras das 12 plantas (Crops/<Estacao>/<Planta>.png: quadros de 16x16, ou 16x32 nas altas,
    com semente -> estagios -> item colhido), "All Crops.png" (sacos de semente e icones dos itens) e a licenca
    (Documentation.txt: o credito "EmanuelleDev" e obrigatorio);
  - copia o caldeirao (Objects/Work Benches/Kitchen pot.png -> assets/cenario/Farm RPG/caldeirao.png: 5 quadros de 32x32, o
    primeiro apagado e 4 com fogo e bolhas) e a folha de pocoes (Icons/RPG icons/Extras/Potions.png ->
    assets/ui/fazenda/pocoes.png: 5 colunas x 7 linhas de 16x16; colunas 1-4 = verde, vermelha, roxa e azul);
  - desenha assets/ui/fazenda/icones_ferramentas.png (enxada, regador e cesta, 16x16 cada, lado a lado).
Nenhuma construcao nem personagem do pack entra no jogo (o estilo e diferente do Mana Seed).
"""
import os
import shutil
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.normpath(os.path.join(AQUI, "..", ".."))
sys.path.insert(0, os.path.join(AQUI, "..", "arena"))
import png_puro as P  # noqa: E402

PADRAO_ORIGEM = ("/tmp/claude-1000/-home-alfeim-AlgoLand/ccef2aa9-5145-4440-bb95-45d50b90211d/scratchpad/farm_rpg/"
                 "Farm RPG - Tiny Asset Pack - (All in One)")
DESTINO = os.path.join(RAIZ, "assets/cenario", "Farm RPG")

# tiras usadas (relativas a Crops/)
TIRAS = ["Spring/Strawberry.png", "Spring/Carrot.png", "Spring/Potato.png", "Spring/Cauliflower.png",
         "Summer/Tomato.png", "Summer/Sunflower.png", "Summer/Watermelon.png", "Fall/Corn.png",
         "Fall/Pumpkin.png", "Fall/Beetroot.png", "Fall/Eggplant.png", "Fall/Grapes.png"]


def nova(w, h):
    return P.Imagem(w, h, bytearray(w * h * 4))


def colar(dst, src, ox, oy):
    """Cola `src` em `dst` em (ox, oy) respeitando o alfa (pixel opaco ou transparente, sem mistura)."""
    for y in range(src.h):
        for x in range(src.w):
            if src.alfa(x, y) == 0:
                continue
            px, py = ox + x, oy + y
            if 0 <= px < dst.w and 0 <= py < dst.h:
                i = (py * dst.w + px) * 4
                j = (y * src.w + x) * 4
                dst.dados[i:i + 4] = src.dados[j:j + 4]


def copiar_pack(origem):
    for rel in TIRAS:
        destino = os.path.join(DESTINO, "Crops", rel)
        os.makedirs(os.path.dirname(destino), exist_ok=True)
        shutil.copyfile(os.path.join(origem, "Crops", rel), destino)
    shutil.copyfile(os.path.join(origem, "Crops", "All Crops.png"), os.path.join(DESTINO, "Crops", "All Crops.png"))
    shutil.copyfile(os.path.join(origem, "Documentation.txt"), os.path.join(DESTINO, "Documentation.txt"))


def copiar_alquimia(origem):
    """Caldeirao da fazenda (onde a colheita vira pocao) e os icones das pocoes."""
    shutil.copyfile(os.path.join(origem, "Objects", "Work Benches", "Kitchen pot.png"), os.path.join(DESTINO, "caldeirao.png"))
    destino_ui = os.path.join(RAIZ, "assets/ui", "fazenda")
    os.makedirs(destino_ui, exist_ok=True)
    shutil.copyfile(os.path.join(origem, "Icons", "RPG icons", "Extras", "Potions.png"), os.path.join(destino_ui, "pocoes.png"))


# ---------------------------------------------------------------- icones das ferramentas (16x16)
PALETA = {
    "o": (38, 26, 22, 255),     # contorno
    "w": (150, 98, 58, 255),    # madeira
    "W": (196, 140, 84, 255),   # madeira clara
    "m": (140, 152, 166, 255),  # metal
    "M": (214, 224, 232, 255),  # metal claro
    "d": (84, 94, 108, 255),    # metal escuro
    "b": (62, 140, 220, 255),   # agua
    "B": (150, 208, 250, 255),  # agua clara
    "y": (222, 184, 92, 255),   # palha
    "Y": (248, 222, 140, 255),  # palha clara
    "r": (150, 108, 52, 255),   # palha escura
    ".": (0, 0, 0, 0),
}

ENXADA = [
    "................",
    ".............oo.",
    "............oWwo",
    "...........oWwo.",
    "..........oWwo..",
    ".........oWwo...",
    "........oWwo....",
    ".......oWwo.....",
    "......oWwo......",
    ".....oWwo.oo....",
    "....oWwooMMo....",
    "...oooooMMmo....",
    "..oMMMMMMmdo....",
    "..oMMmmmmddo....",
    "..oooooooooo....",
    "................",
]

REGADOR = [
    "................",
    "................",
    "..oo.......oooo.",
    ".oMMo.....oWwwwo",
    ".oMMo.....oWo.oo",
    "..oMo.oooooW.oo.",
    "...oo.omMMmmoo..",
    "....oooMmmmmmdo.",
    "...b..omMmmmmdo.",
    "..bB..omMmmmmdo.",
    "...b..oMmmmmddo.",
    "..b...omdddddmo.",
    "......oooooooo..",
    "................",
    "................",
    "................",
]

CESTA = [
    "................",
    "....oooooooo....",
    "...oWwwwwwwWo...",
    "..oWo......oWo..",
    "..oWo......oWo..",
    "..oWo......oWo..",
    ".oooooooooooooo.",
    ".oYyYyYyYyYyYyo.",
    ".oyrryrryrryrro.",
    ".oYyYyYyYyYyYyo.",
    "..oyrryrryrryo..",
    "..oYyYyYyYyYyo..",
    "..oyrryrryrryo..",
    "...oooooooooo...",
    "................",
    "................",
]


def desenhar_icone(mapa):
    img = nova(16, 16)
    for y, linha in enumerate(mapa):
        assert len(linha) == 16, linha
        for x, c in enumerate(linha):
            r, g, b, a = PALETA[c]
            i = (y * 16 + x) * 4
            img.dados[i:i + 4] = bytes((r, g, b, a))
    return img


def montar_icones():
    saida = nova(48, 16)
    for k, mapa in enumerate((ENXADA, REGADOR, CESTA)):
        colar(saida, desenhar_icone(mapa), k * 16, 0)
    destino = os.path.join(RAIZ, "assets/ui", "fazenda")
    os.makedirs(destino, exist_ok=True)
    P.salvar(saida, os.path.join(destino, "icones_ferramentas.png"))


def main():
    origem = sys.argv[1] if len(sys.argv) > 1 else PADRAO_ORIGEM
    if os.path.isdir(origem):
        os.makedirs(DESTINO, exist_ok=True)
        copiar_pack(origem)
        copiar_alquimia(origem)
        print("pack copiado para", os.path.relpath(DESTINO, RAIZ))
    else:
        print("pasta do Farm RPG nao encontrada (%s): so os icones das ferramentas foram refeitos" % origem)
    montar_icones()
    print("icones: assets/ui/fazenda/icones_ferramentas.png")


if __name__ == "__main__":
    main()
