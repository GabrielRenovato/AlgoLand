"""Leitura e escrita determinística de PCKs completos (sem deltas binários)."""
import hashlib
import re
import struct
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Entrada:
    dados: bytes
    flags: int = 0


def ler_pck(caminho: Path) -> dict[str, Entrada]:
    dados = caminho.read_bytes()
    if dados[:4] != b'GDPC':
        raise ValueError(f'{caminho}: assinatura PCK inválida')
    formato, = struct.unpack_from('<I', dados, 4)
    flags, base = struct.unpack_from('<IQ', dados, 20)
    if formato not in (2, 3, 4) or flags & ~2:
        raise ValueError('PCK deve ser versão 2/3/4, sem criptografia ou bundle')
    pos = struct.unpack_from('<Q', dados, 32)[0] if formato >= 3 else 96
    quantidade, = struct.unpack_from('<I', dados, pos)
    pos += 4
    entradas = {}
    for _ in range(quantidade):
        tam, = struct.unpack_from('<I', dados, pos)
        pos += 4
        nome = dados[pos:pos + tam].rstrip(b'\0').decode().removeprefix('res://')
        pos += tam
        offset, tamanho, md5, modo = struct.unpack_from('<QQ16sI', dados, pos)
        pos += 36
        if modo & ~2:
            raise ValueError(f'{nome}: criptografia/delta binário não suportado')
        conteudo = dados[base + offset:base + offset + tamanho] if not modo & 2 else b''
        if not modo & 2 and (len(conteudo) != tamanho or hashlib.md5(conteudo).digest() != md5):
            raise ValueError(f'{nome}: conteúdo PCK corrompido')
        entradas[nome] = Entrada(conteudo, modo)
    return entradas


def escrever_pck(caminho: Path, entradas: dict[str, Entrada]) -> None:
    nomes = sorted(entradas)
    diretorio = bytearray(struct.pack('<I', len(nomes)))
    corpo = bytearray()
    for nome in nomes:
        item = entradas[nome]
        texto = ('res://' + nome).encode()
        texto += b'\0' * (-len(texto) % 4)
        diretorio += struct.pack('<I', len(texto)) + texto
        diretorio += struct.pack('<QQ16sI', len(corpo), len(item.dados), hashlib.md5(item.dados).digest(), item.flags)
        corpo += item.dados
        corpo += b'\0' * (-len(corpo) % 16)
    base = 96 + len(diretorio)
    cabecalho = b'GDPC' + struct.pack('<IIIIIQ', 2, 4, 0, 0, 0, base) + bytes(64)
    caminho.write_bytes(cabecalho + diretorio + corpo)


def limitar_pacotes(grupos: dict[str, dict[str, Entrada]], limite: int = 8 * 1024 * 1024) -> dict[str, dict[str, Entrada]]:
    """Mantém PCKs completos abaixo do limite de transferência, sem cortar recursos.

    O aplicativo existente já monta todos os pacotes antes de carregar os recursos;
    por isso referências entre partes continuam funcionando sem um APK novo.
    """
    resultado = {}
    for area_id, entradas in sorted(grupos.items()):
        partes = []
        parte = {}
        tamanho = 100  # Cabeçalho de 96 bytes e quantidade de arquivos.
        for nome, entrada in sorted(entradas.items()):
            texto = len(('res://' + nome).encode())
            custo = 40 + texto + (-texto % 4) + len(entrada.dados) + (-len(entrada.dados) % 16)
            if 100 + custo > limite:
                raise ValueError(f'Recurso excede o limite de {limite} bytes: {nome}')
            if tamanho + custo > limite:
                partes.append(parte)
                parte = {}
                tamanho = 100
            parte[nome] = entrada
            tamanho += custo
        if parte:
            partes.append(parte)
        for indice, arquivos in enumerate(partes, 1):
            nome = area_id if len(partes) == 1 else f'{area_id}_{indice:02d}'
            if nome in resultado:
                raise ValueError(f'Identificador de pacote repetido: {nome}')
            resultado[nome] = arquivos
    return resultado


def area(caminho: str) -> str:
    caminho = caminho.removeprefix('res://')
    andar = re.search(r'(?:cenas/fendas/|codigo/fendas/plantas/)andar_(\d+)', caminho)
    if andar:
        return 'andar_' + andar[1]
    regras = {
        'interface': ('codigo/ui/', 'recursos/ui/', 'cenas/ui', 'assets/ui/', 'assets/fontes/'),
        'floresta': ('codigo/floresta/', 'cenas/floresta.', 'cenas/terreno_floresta.', 'assets/animais/floresta/'),
        'fendas': ('codigo/fendas/', 'cenas/andar_fenda.', 'assets/cenario/florestas/'),
        'fazenda': ('codigo/fazenda/', 'cenas/fazenda.', 'cenas/casa.', 'cenas/galinheiro.', 'assets/cenario/fazenda/'),
        'cidade': ('codigo/cidade/', 'cenas/cidade', 'assets/cenario/cidade/'),
        'praia': ('codigo/pesca/', 'cenas/praia.', 'assets/pesca/', 'assets/cenario/praia/'),
        'audio': ('assets/audio/',),
    }
    return next((nome for nome, prefixos in regras.items() if caminho.startswith(prefixos)), 'compartilhado')


def dividir(entradas: dict[str, Entrada], base: dict[str, Entrada] | None = None) -> dict[str, dict[str, Entrada]]:
    # .import/.remap apontam para os binários em .godot: seguem a área do fonte.
    donos = {}
    for nome, entrada in ((base or {}) | entradas).items():
        if nome.endswith(('.import', '.remap')):
            for destino in re.findall(rb'res://[^"\s]+', entrada.dados):
                donos[destino.decode().removeprefix('res://')] = area(nome)
    grupos = {}
    for nome, entrada in entradas.items():
        grupos.setdefault(donos.get(nome, area(nome)), {})[nome] = entrada
    return grupos
