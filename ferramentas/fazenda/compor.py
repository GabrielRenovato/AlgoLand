"""Compositor minimo de sprites (Python puro, usa png_puro.py de ferramentas/arena) para montar e CONFERIR visualmente a casa
e o interior antes de gerar as cenas: recorta retangulos das folhas do Starter Pack, cola numa tela RGBA e amplia."""
import os
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(AQUI, "..", "arena"))
import png_puro as P  # noqa: E402

RAIZ = os.path.abspath(os.path.join(AQUI, "..", ".."))
PASTA_STARTER = os.path.join(RAIZ, "assets/cenario", "Starter Pack")
_cache = {}


def folha(nome):
    if nome not in _cache:
        _cache[nome] = P.carregar(os.path.join(PASTA_STARTER, nome))
    return _cache[nome]


def tela(w, h, fundo=(0, 0, 0, 0)):
    d = bytearray(w * h * 4)
    if fundo != (0, 0, 0, 0):
        for i in range(0, len(d), 4):
            d[i:i + 4] = bytes(fundo)
    return P.Imagem(w, h, d)


def colar(destino, nome, x, y, w, h, dx, dy, espelhar=False):
    """Cola o retangulo (x, y, w, h) da folha `nome` em (dx, dy) da tela, com alfa (so 0 ou 255 importa aqui)."""
    src = folha(nome)
    for j in range(h):
        for i in range(w):
            sx = x + (w - 1 - i if espelhar else i)
            px = src.pixel(sx, y + j)
            tx, ty = dx + i, dy + j
            if px[3] == 0 or not (0 <= tx < destino.w and 0 <= ty < destino.h):
                continue
            k = (ty * destino.w + tx) * 4
            a = px[3] / 255.0
            if a >= 0.999:
                destino.dados[k:k + 4] = bytes(px)
            else:
                for c in range(3):
                    destino.dados[k + c] = int(px[c] * a + destino.dados[k + c] * (1 - a))
                destino.dados[k + 3] = max(destino.dados[k + 3], px[3])


def ampliar(img, f):
    out = P.Imagem(img.w * f, img.h * f, bytearray(img.w * f * img.h * f * 4))
    for y in range(img.h):
        for x in range(img.w):
            px = bytes(img.dados[(y * img.w + x) * 4:(y * img.w + x) * 4 + 4])
            for j in range(f):
                base = ((y * f + j) * out.w + x * f) * 4
                out.dados[base:base + 4 * f] = px * f
    return out
