#!/bin/bash
# Atalho para ampliar_folha.gd (precisa de janela). Uso:
#   ferramentas/arena/ampliar.sh <png> <saida.png> <escala> [col lin larg alt [larg_tile [alt_tile]]]
# No flatpak do Godot so a pasta pessoal e visivel (nao o /tmp): grave a saida em algum lugar de ~/.
RAIZ="$(cd "$(dirname "$0")/../.." && pwd)"
flatpak run org.godotengine.Godot --path "$RAIZ" --script res://ferramentas/arena/ampliar_folha.gd -- "$@" 2>&1 | grep -E "^salvo|ERROR|SCRIPT"
