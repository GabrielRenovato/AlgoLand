#!/usr/bin/env python3
"""Confere caminhos literais do jogo e impede dependências de fontes/legado."""
from pathlib import Path
import re
import sys

RAIZ = Path(__file__).resolve().parents[2]
EXTENSOES = {".gd", ".tscn", ".tres", ".gdshader"}
REFERENCIA = re.compile(r'(?P<aspas>["\'])(?P<caminho>res://[^\r\n]*?)(?P=aspas)')


def auditar() -> list[str]:
    erros = []
    arquivos = [RAIZ / "project.godot", RAIZ / "export_presets.cfg"]
    for pasta in ["codigo", "cenas", "recursos", "assets"]:
        arquivos.extend(p for p in (RAIZ / pasta).rglob("*") if p.suffix in EXTENSOES)
    for arquivo in arquivos:
        for numero, linha in enumerate(arquivo.read_text().splitlines(), 1):
            if linha.lstrip().startswith("#"):
                continue
            for resultado in REFERENCIA.finditer(linha):
                caminho = resultado.group("caminho")
                if "%" in caminho or "*" in caminho or "\\" in caminho:
                    continue
                relativo = caminho.removeprefix("res://")
                if relativo.startswith(("arte/", "arquivo/", "builds/")):
                    erros.append(f"{arquivo.relative_to(RAIZ)}:{numero}: dependência de desenvolvimento: {caminho}")
                elif not (RAIZ / relativo).exists():
                    erros.append(f"{arquivo.relative_to(RAIZ)}:{numero}: caminho ausente: {caminho}")
    return erros


if __name__ == "__main__":
    erros = auditar()
    for erro in erros:
        print(erro)
    print(f"Referências do jogo: {len(erros)} falhas.")
    sys.exit(bool(erros))
