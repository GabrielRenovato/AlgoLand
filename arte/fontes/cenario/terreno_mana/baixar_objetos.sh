#!/bin/bash
# Baixa as fachadas e placas listadas em jobs_objetos.txt (job nome) para esta pasta, pulando as que já existem
cd "$(dirname "$0")"
while read -r job nome; do
  [ -z "$job" ] && continue
  if [ ! -s "$nome.png" ]; then
    curl -s -o "$nome.png.tmp" -w "%{http_code}" "https://api.pixellab.ai/mcp/images/$job/download" | grep -q 200 && head -c 8 "$nome.png.tmp" | grep -q PNG && mv "$nome.png.tmp" "$nome.png" && echo "ok $nome" || { rm -f "$nome.png.tmp"; echo "pendente $nome"; }
  fi
done < jobs_objetos.txt
