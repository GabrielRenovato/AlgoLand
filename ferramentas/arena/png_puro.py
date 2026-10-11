"""Leitor minimo de PNG (RGBA 8 bits, sem entrelacamento) em Python puro, sem PIL/numpy.
Usado pelo gerador para medir pixels visiveis (colisoes) e conferir os tiles."""
import struct
import zlib


class Imagem:
    def __init__(self, largura, altura, dados):
        self.w = largura
        self.h = altura
        self.dados = dados  # bytearray RGBA

    def pixel(self, x, y):
        i = (y * self.w + x) * 4
        return self.dados[i], self.dados[i + 1], self.dados[i + 2], self.dados[i + 3]

    def alfa(self, x, y):
        return self.dados[(y * self.w + x) * 4 + 3]


def carregar(caminho):
    bruto = open(caminho, "rb").read()
    assert bruto[:8] == b"\x89PNG\r\n\x1a\n", "nao e PNG"
    pos = 8
    idat = b""
    w = h = 0
    while pos < len(bruto):
        tam, tipo = struct.unpack(">I4s", bruto[pos:pos + 8])
        corpo = bruto[pos + 8:pos + 8 + tam]
        if tipo == b"IHDR":
            w, h, prof, cor, _, _, entr = struct.unpack(">IIBBBBB", corpo)
            assert prof == 8 and cor == 6 and entr == 0, "so RGBA8 sem entrelacamento"
        elif tipo == b"IDAT":
            idat += corpo
        pos += 12 + tam
    cru = zlib.decompress(idat)
    bpp = 4
    stride = w * bpp
    saida = bytearray(h * stride)
    anterior = bytearray(stride)
    p = 0
    for y in range(h):
        filtro = cru[p]
        linha = bytearray(cru[p + 1:p + 1 + stride])
        p += 1 + stride
        if filtro == 1:
            for i in range(bpp, stride):
                linha[i] = (linha[i] + linha[i - bpp]) & 255
        elif filtro == 2:
            for i in range(stride):
                linha[i] = (linha[i] + anterior[i]) & 255
        elif filtro == 3:
            for i in range(stride):
                esq = linha[i - bpp] if i >= bpp else 0
                linha[i] = (linha[i] + ((esq + anterior[i]) >> 1)) & 255
        elif filtro == 4:
            for i in range(stride):
                a = linha[i - bpp] if i >= bpp else 0
                b = anterior[i]
                c = anterior[i - bpp] if i >= bpp else 0
                pa = abs(b - c)
                pb = abs(a - c)
                pc = abs(a + b - 2 * c)
                if pa <= pb and pa <= pc:
                    pr = a
                elif pb <= pc:
                    pr = b
                else:
                    pr = c
                linha[i] = (linha[i] + pr) & 255
        saida[y * stride:(y + 1) * stride] = linha
        anterior = linha
    return Imagem(w, h, saida)


def salvar(img, caminho):
    cru = bytearray()
    stride = img.w * 4
    for y in range(img.h):
        cru.append(0)
        cru += img.dados[y * stride:(y + 1) * stride]

    def bloco(tipo, corpo):
        c = struct.pack(">I", len(corpo)) + tipo + corpo
        return c + struct.pack(">I", zlib.crc32(tipo + corpo) & 0xFFFFFFFF)

    dados = b"\x89PNG\r\n\x1a\n" + bloco(b"IHDR", struct.pack(">IIBBBBB", img.w, img.h, 8, 6, 0, 0, 0))
    dados += bloco(b"IDAT", zlib.compress(bytes(cru), 9)) + bloco(b"IEND", b"")
    open(caminho, "wb").write(dados)
