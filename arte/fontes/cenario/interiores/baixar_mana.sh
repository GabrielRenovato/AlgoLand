#!/bin/bash
# Baixa as imagens listadas em jobs_mana.txt (job casa nome) para <casa>_mana/<nome>.png, pulando as que já existem
cd "$(dirname "$0")"
while read -r job casa nome; do
  [ -z "$job" ] && continue
  mkdir -p "${casa}_mana"
  alvo="${casa}_mana/${nome}.png"
  if [ ! -s "$alvo" ]; then
    curl -s -o "$alvo.tmp" -w "%{http_code}" "https://api.pixellab.ai/mcp/images/$job/download" | grep -q 200 && head -c 8 "$alvo.tmp" | grep -q PNG && mv "$alvo.tmp" "$alvo" && echo "ok $alvo" || { rm -f "$alvo.tmp"; echo "pendente $alvo"; }
  fi
done < jobs_mana.txt
