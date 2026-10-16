#!/bin/bash
# Renderiza recortes da arena (render_arena.gd) ou da cena de jogo (render_jogo.gd). Uso:
#   ferramentas/arena/renderizar.sh arena <tomadas.json> <pasta_saida>    # terreno.tscn sozinho (zoom/estacao/colisoes)
#   ferramentas/arena/renderizar.sh jogo  <tomadas.json> <pasta_saida>    # cenario.tscn como o jogador ve
#   ferramentas/arena/renderizar.sh titulo <tomadas.json> <pasta_saida>   # inicio_do_jogo.tscn
#   ferramentas/arena/renderizar.sh fazenda <tomadas.json> <pasta_saida>  # fazenda.tscn (jogador em coordenadas da cena)
#   ferramentas/arena/renderizar.sh casa <tomadas.json> <pasta_saida>     # casa.tscn
# Os formatos do JSON estao no cabecalho de cada script .gd. Precisa de janela; no flatpak use pastas dentro de ~/.
RAIZ="$(cd "$(dirname "$0")/../.." && pwd)"
case "$1" in
  arena)  CENA=${CENA_ARENA:-res://cenas/terreno.tscn};        SCRIPT=render_arena.gd ;;
  jogo)   CENA=res://cenas/cenario.tscn;        SCRIPT=render_jogo.gd ;;
  titulo) CENA=res://cenas/inicio_do_jogo.tscn; SCRIPT=render_jogo.gd ;;
  fazenda) CENA=res://cenas/fazenda.tscn;       SCRIPT=render_jogo.gd ;;
  casa)   CENA=res://cenas/casa.tscn;           SCRIPT=render_jogo.gd ;;
  *) echo "uso: renderizar.sh arena|jogo|titulo|fazenda|casa <tomadas.json> <pasta_saida>"; exit 1 ;;
esac
flatpak run org.godotengine.Godot --path "$RAIZ" --script res://ferramentas/arena/$SCRIPT -- "$CENA" "$2" "$3" 2>&1 | grep -E "^salvo|SCRIPT|Parse"
