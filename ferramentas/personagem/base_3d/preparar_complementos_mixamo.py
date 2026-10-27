#!/usr/bin/env python3
"""Recolhe os FBX escolhidos em Downloads, preservando fontes e hashes.

Use --verificar para listar pendências sem copiar arquivos. A seleção dos
clipes e as descrições oficiais ficam em mixamo/complementos.json.
"""
import argparse
import hashlib
import json
import shutil
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[3]
DESTINO = RAIZ / 'arte/fontes/personagens/base_3d/mixamo'
MANIFESTO = DESTINO / 'complementos.json'

def preparar(origem: Path, verificar: bool) -> int:
    catalogo = json.loads(MANIFESTO.read_text())
    pendentes = []
    for identificador, dados in catalogo.items():
        arquivo = origem / dados['arquivo']
        destino = DESTINO / dados['arquivo']
        if arquivo.is_file() and not verificar:
            if arquivo.resolve() != destino.resolve():
                if destino.exists() and arquivo.read_bytes() != destino.read_bytes():
                    raise ValueError(f'Fonte diferente já preservada: {destino}')
                if not destino.exists():
                    shutil.copy2(arquivo, destino)
        fonte = destino if destino.is_file() else arquivo
        if not fonte.is_file():
            pendentes.append(dados['arquivo'])
            print(f'PENDENTE: {dados["arquivo"]} — {dados["descricao_mixamo"]}')
            continue
        print(f'DISPONÍVEL: {identificador} — {fonte}')
        if not verificar:
            dados['sha256'] = hashlib.sha256(fonte.read_bytes()).hexdigest()
    if not verificar:
        MANIFESTO.write_text(json.dumps(catalogo, ensure_ascii=False, indent=2) + '\n')
    print(f'{len(catalogo) - len(pendentes)} disponíveis; {len(pendentes)} pendentes. Nenhuma animação do jogo foi substituída.')
    return 2 if pendentes else 0

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--origem', type=Path, default=Path.home() / 'Downloads')
    parser.add_argument('--verificar', action='store_true')
    args = parser.parse_args()
    raise SystemExit(preparar(args.origem, args.verificar))
