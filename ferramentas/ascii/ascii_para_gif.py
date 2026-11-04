#!/usr/bin/env python3
"""Junta quadros ASCII (quadro_0.txt, quadro_1.txt, ...) num GIF animado, sem dependências.

  python3 ferramentas/ascii/ascii_para_gif.py arte/ascii/dragao_anim saida.gif [--escala 8] [--atraso 110] [--fundo 222436]
"""
import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from ascii_para_png import ler  # noqa: E402


def lzw(indices, minimo):
    """Compressão LZW do GIF (códigos de tamanho variável, 12 bits no máximo)."""
    limpar, fim = 1 << minimo, (1 << minimo) + 1
    tabela, proximo, tamanho = {}, fim + 1, minimo + 1
    bits, n_bits, saida = 0, 0, bytearray()

    def emitir(codigo):
        nonlocal bits, n_bits
        bits |= codigo << n_bits
        n_bits += tamanho
        while n_bits >= 8:
            saida.append(bits & 255)
            bits >>= 8
            n_bits -= 8

    emitir(limpar)
    atual = indices[0]
    for k in indices[1:]:
        chave = (atual, k)
        if chave in tabela:
            atual = tabela[chave]
            continue
        emitir(atual)
        if proximo < 4096:
            tabela[chave] = proximo
            proximo += 1
            if proximo > (1 << tamanho) and tamanho < 12:
                tamanho += 1
        else:
            emitir(limpar)
            tabela, proximo, tamanho = {}, fim + 1, minimo + 1
        atual = k
    emitir(atual)
    emitir(fim)
    if n_bits:
        saida.append(bits & 255)
    return bytes(saida)


def blocos(dados):
    return b"".join(bytes([len(dados[i:i + 255])]) + dados[i:i + 255] for i in range(0, len(dados), 255)) + b"\x00"


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("pasta", type=Path)
    p.add_argument("saida", type=Path)
    p.add_argument("--escala", type=int, default=6)
    p.add_argument("--atraso", type=int, default=110, help="milissegundos por quadro")
    p.add_argument("--fundo", default="222436", help="cor de fundo em hex (o GIF não usa transparência)")
    a = p.parse_args()
    arquivos = sorted(a.pasta.glob("quadro_*.txt"), key=lambda f: int(f.stem.split("_")[1]))
    if not arquivos:
        sys.exit("nenhum quadro_N.txt na pasta")
    fundo = tuple(int(a.fundo[i:i + 2], 16) for i in (0, 2, 4))
    cores = [fundo]
    quadros = []
    for arq in arquivos:
        paleta, linhas = ler(arq)
        largura = max(len(l) for l in linhas)
        grade = []
        for linha in linhas:
            linha = linha.ljust(largura, ".")
            fila = []
            for c in linha:
                cor = fundo if c == "." else paleta[c]
                if cor not in cores:
                    cores.append(cor)
                fila.append(cores.index(cor))
            grade.append(fila)
        quadros.append(grade)
    if len(cores) > 256:
        sys.exit("paleta grande demais para GIF")
    n = max(2, (len(cores) - 1).bit_length())
    tabela_cores = b"".join(bytes(c) for c in cores) + bytes(3 * ((1 << n) - len(cores)))
    e = max(1, a.escala)
    larg = len(quadros[0][0]) * e
    alt = len(quadros[0]) * e
    saida = bytearray(b"GIF89a" + larg.to_bytes(2, "little") + alt.to_bytes(2, "little") + bytes([0x80 | 0x70 | (n - 1), 0, 0]))
    saida += tabela_cores
    saida += b"\x21\xff\x0bNETSCAPE2.0\x03\x01\x00\x00\x00"
    for grade in quadros:
        indices = []
        for fila in grade:
            ampliada = [i for i in fila for _ in range(e)]
            for _ in range(e):
                indices.extend(ampliada)
        saida += b"\x21\xf9\x04\x04" + max(2, round(a.atraso / 10)).to_bytes(2, "little") + b"\x00\x00"
        saida += b"\x2c\x00\x00\x00\x00" + larg.to_bytes(2, "little") + alt.to_bytes(2, "little") + b"\x00"
        saida += bytes([max(2, n)]) + blocos(lzw(indices, max(2, n)))
    saida += b"\x3b"
    a.saida.write_bytes(bytes(saida))
    print(f"{a.saida}: {len(quadros)} quadros, {larg}x{alt}px, {len(saida) // 1024} KB")


if __name__ == "__main__":
    main()
