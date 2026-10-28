#!/usr/bin/env bash
# Painel do servidor online no Fly.io (São Paulo): abre o túnel privado `fly proxy` até o painel
# administrativo da máquina (porta 8788, só na rede privada) e uma cópia do painel ligada a ele em
# http://127.0.0.1:8791. Os botões de ligar/desligar do painel agem no serviço do PC, não no Fly
# (no Fly: ~/.fly/bin/flyctl machine restart / flyctl logs -a algoland-duelo).
set -euo pipefail
cd "$(dirname "$0")/painel"
FLY="${FLYCTL:-$HOME/.fly/bin/flyctl}"
URL="http://127.0.0.1:8791"
if ! curl -s -m 2 -o /dev/null "http://127.0.0.1:8789/estado"; then
  systemd-run --user --unit=algoland-fly-proxy-$$ "$FLY" proxy 8789:8788 -a algoland-duelo >/dev/null
  for _ in $(seq 1 30); do curl -s -m 1 -o /dev/null "http://127.0.0.1:8789/estado" && break; sleep 0.5; done
fi
if ! curl -s -m 2 -o /dev/null "$URL/api/estado"; then
  systemd-run --user --unit=algoland-painel-fly-$$ --working-directory="$PWD" --setenv=PATH="$PATH" \
    --setenv=PAINEL_PORTA=8791 --setenv=ADMIN_URL=http://127.0.0.1:8789 "$(command -v node)" painel.mjs >/dev/null
  for _ in $(seq 1 20); do curl -s -m 1 -o /dev/null "$URL/api/estado" && break; sleep 0.3; done
fi
echo "Painel do Fly em $URL"
command -v xdg-open >/dev/null && xdg-open "$URL" >/dev/null 2>&1 || true
