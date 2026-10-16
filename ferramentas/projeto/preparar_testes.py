#!/usr/bin/env python3
"""Cria um projeto de testes com saves isolados e recursos compartilhados."""
from pathlib import Path
import argparse
import re


def preparar(destino: Path) -> Path:
    raiz = Path(__file__).resolve().parents[2]
    destino = destino.expanduser().resolve()
    if destino == raiz or raiz in destino.parents:
        raise ValueError("A cópia de testes deve ficar fora do projeto principal.")
    destino.mkdir(parents=True, exist_ok=True)
    for antigo in destino.iterdir():
        if antigo.is_symlink() and not antigo.exists():
            antigo.unlink()
    for origem in raiz.iterdir():
        if origem.name in {".git", ".agents", "project.godot", "builds"}:
            continue
        alvo = destino / origem.name
        if alvo.is_symlink():
            alvo.unlink()
        if not alvo.exists():
            alvo.symlink_to(origem, target_is_directory=origem.is_dir())
    configuracao = (raiz / "project.godot").read_text()
    configuracao = re.sub(r'^config/name="[^"]*"', 'config/name="AlgoLand testes Carrasco"', configuracao, flags=re.M)
    (destino / "project.godot").write_text(configuracao)
    return destino


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("destino", type=Path)
    args = parser.parse_args()
    print(preparar(args.destino))
