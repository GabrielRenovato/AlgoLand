#!/usr/bin/env python3
"""PostToolUse (Edit/Write): valida a sintaxe de arquivos .json editados.

Se o JSON estiver quebrado, sai com código 2 para devolver o erro ao Claude na mesma rodada.
Arquivos fora de .json são ignorados.
"""
import json
import sys
from pathlib import Path


def main() -> int:
    try:
        entrada = json.load(sys.stdin)
    except json.JSONDecodeError:
        return 0
    caminho = entrada.get("tool_input", {}).get("file_path", "")
    if not caminho.endswith(".json"):
        return 0
    arquivo = Path(caminho)
    if not arquivo.is_file():
        return 0
    try:
        json.loads(arquivo.read_text(encoding="utf-8"))
    except json.JSONDecodeError as erro:
        print(f"JSON inválido em {caminho}: linha {erro.lineno}, coluna {erro.colno}: {erro.msg}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
