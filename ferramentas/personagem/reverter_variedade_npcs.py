#!/usr/bin/env python3
"""Desfaz a variedade de NPCs (cores, corpo, idade, acessórios, nomes): restaura os arquivos de
arquivo/backups/variedade_npcs_20261031 e apaga os arquivos novos. Uso: python3 ferramentas/personagem/reverter_variedade_npcs.py
Para só desligar sem restaurar, ponha ATIVA = false em codigo/dados/variacao_npcs.gd."""
from pathlib import Path
import shutil
raiz = Path(__file__).resolve().parents[2]
backup = raiz / "arquivo/backups/variedade_npcs_20261031"
for origem in sorted(backup.rglob("*")):
    if origem.is_file():
        destino = raiz / origem.relative_to(backup)
        shutil.copy2(origem, destino)
        print("restaurado", destino.relative_to(raiz))
for novo in ["codigo/dados/variacao_npcs.gd", "codigo/dados/variacao_npcs.gd.uid", "codigo/npcs/acessorios_npc_3d.gd", "codigo/npcs/acessorios_npc_3d.gd.uid"]:
    caminho = raiz / novo
    if caminho.exists():
        caminho.unlink()
        print("removido", novo)
print("Pronto: variedade de NPCs revertida.")
