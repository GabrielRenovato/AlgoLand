#!/usr/bin/env bash
# Sobe o servidor do lobby nesta máquina e abre um túnel HTTPS temporário (Cloudflare "quick tunnel", sem conta).
# Imprime o endereço wss:// para colocar no jogo. O endereço muda a cada execução. Ctrl+C encerra tudo.
set -euo pipefail
cd "$(dirname "$0")"
PORTA="${PORTA:-8787}"
[ -d node_modules ] || npm install --no-audit --no-fund
PORTA="$PORTA" node servidor.mjs &
SERVIDOR=$!
trap 'kill $SERVIDOR 2>/dev/null; podman rm -f algoland-tunel >/dev/null 2>&1 || true' EXIT
sleep 1
podman rm -f algoland-tunel >/dev/null 2>&1 || true
podman run --rm --name algoland-tunel --network=host docker.io/cloudflare/cloudflared:latest tunnel --no-autoupdate --url "http://127.0.0.1:$PORTA" 2>&1 \
  | while IFS= read -r linha; do
      echo "$linha"
      if [[ "$linha" =~ https://[a-z0-9-]+\.trycloudflare\.com ]]; then
        echo; echo ">>> Endereço do lobby para o jogo: wss://${BASH_REMATCH[0]#https://}"; echo
      fi
    done
