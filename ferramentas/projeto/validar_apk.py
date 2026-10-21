#!/usr/bin/env python3
"""Confere dependências reais de scripts/cenas dentro do APK, inclusive recursos importados."""
import argparse
from pathlib import Path
import re
import zipfile

RAIZ = Path(__file__).resolve().parents[2]
REFERENCIAS = re.compile(r'''(?:preload|load)\(\s*"(res://[^"\n]+)"\s*\)|(?:preload|load)\(\s*'(res://[^'\n]+)'\s*\)|\[ext_resource[^\n]*path="(res://[^"\n]+)"''')

def validar(apk: Path) -> list[str]:
    with zipfile.ZipFile(apk) as pacote:
        nomes = {nome.removeprefix('assets/') for nome in pacote.namelist() if nome.startswith('assets/')}
        def presente(recurso):
            return any(recurso + sufixo in nomes for sufixo in ('', '.import', '.remap'))
        falhas = set()
        for pasta in ('codigo', 'cenas'):
            for fonte in (RAIZ / pasta).rglob('*'):
                if fonte.suffix not in ('.gd', '.tscn'):
                    continue
                relativo = fonte.relative_to(RAIZ).as_posix()
                if not presente(relativo):
                    continue
                for resultado in REFERENCIAS.finditer(fonte.read_text()):
                    caminho = next(grupo for grupo in resultado.groups() if grupo).removeprefix('res://')
                    if not presente(caminho):
                        falhas.add(f'{relativo}: recurso ausente no APK: {caminho}')
        # O remapeamento também precisa apontar para dados que viajaram no pacote.
        for nome in sorted(nomes):
            if not nome.endswith(('.import', '.remap')):
                continue
            for caminho in re.findall(r'(?m)^path="res://([^"\n]+)"', pacote.read('assets/' + nome).decode('utf-8')):
                if caminho not in nomes:
                    falhas.add(f'{nome}: destino importado ausente: {caminho}')
        return sorted(falhas)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('apk', type=Path)
    args = parser.parse_args()
    erros = validar(args.apk)
    print(f'APK: {len(erros)} falhas de dependências.')
    for erro in erros:
        print(erro)
    raise SystemExit(bool(erros))
