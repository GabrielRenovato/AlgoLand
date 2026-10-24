#!/usr/bin/env bash
# Abre o painel do lobby no navegador (http://127.0.0.1:8790), iniciando-o se preciso.
# Se o serviço algoland-painel estiver instalado, usa ele; senão sobe um temporário (some ao reiniciar o computador).
set -euo pipefail
cd "$(dirname "$0")/painel"
URL="http://127.0.0.1:8790"
if ! curl -s -m 2 -o /dev/null "$URL/api/estado"; then
  if systemctl --user cat algoland-painel >/dev/null 2>&1; then
    systemctl --user start algoland-painel
  else
    systemd-run --user --unit=algoland-painel-teste --working-directory="$PWD" --setenv=PATH="$PATH" "$(command -v node)" painel.mjs >/dev/null
  fi
  for _ in $(seq 1 20); do curl -s -m 1 -o /dev/null "$URL/api/estado" && break; sleep 0.3; done
fi
echo "Painel em $URL"
command -v xdg-open >/dev/null && xdg-open "$URL" >/dev/null 2>&1 || true
