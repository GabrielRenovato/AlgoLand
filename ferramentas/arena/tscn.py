"""Utilidades para escrever cenas .tscn (formato texto do Godot 4) em Python puro."""
import base64
import struct


def codificar_tiles(celulas):
    """celulas: lista de (x, y, fonte, atlas_x, atlas_y, alternativa) -> PackedByteArray em base64.
    Formato do Godot 4: 2 bytes de cabecalho (versao 0) + 12 bytes por celula (int16 x, y; uint16 fonte, ax, ay, alt)."""
    dados = bytearray(b"\x00\x00")
    for x, y, fonte, ax, ay, alt in celulas:
        dados += struct.pack("<hhHHHH", x, y, fonte, ax, ay, alt)
    return 'PackedByteArray("%s")' % base64.b64encode(bytes(dados)).decode()


def decodificar_tiles(texto_pba):
    """Inverso de codificar_tiles (recebe a string base64 ou o PackedByteArray("...") inteiro)."""
    b64 = texto_pba
    if "(" in b64:
        b64 = b64.split('"')[1]
    dados = base64.b64decode(b64)
    celulas = []
    for i in range(2, len(dados), 12):
        celulas.append(struct.unpack("<hhHHHH", dados[i:i + 12]))
    return celulas


def vetor(*v):
    return "Vector2(%s)" % ", ".join(fmt(x) for x in v)


def fmt(n):
    if isinstance(n, float):
        s = ("%.4f" % n).rstrip("0").rstrip(".")
        return s if s not in ("", "-0") else "0"
    return str(n)


def poligono(pontos):
    plano = []
    for x, y in pontos:
        plano += [fmt(x), fmt(y)]
    return "PackedVector2Array(%s)" % ", ".join(plano)
