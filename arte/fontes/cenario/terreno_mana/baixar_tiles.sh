#!/bin/bash
# Baixa os 16 tiles de cada estação listada em tiles_pro.txt (id estação) para <estação>/frame_N.png, refazendo os arquivos truncados
cd "$(dirname "$0")"
while read -r id est; do
  [ -z "$id" ] && continue
  mkdir -p "$est"
  for i in $(seq 0 15); do
    alvo="$est/frame_$i.png"
    for tentativa in 1 2 3; do
      if [ -s "$alvo" ] && python3 - "$alvo" <<'PY'
import sys,struct,zlib
d=open(sys.argv[1],'rb').read()
i=8;idat=b''
while i<len(d):
    l=struct.unpack('>I',d[i:i+4])[0]
    if d[i+4:i+8]==b'IDAT': idat+=d[i+8:i+8+l]
    i+=12+l
zlib.decompress(idat)
PY
      then break; fi
      curl -s -o "$alvo" "https://api.pixellab.ai/mcp/tiles-pro/$id/download?index=$i" >/dev/null 2>&1
      curl -s -o "$alvo" "https://backblaze.pixellab.ai/file/pixellab-tiles/a1e7979a-7a96-45f8-a8d0-425e05529327/$id/tile_$i.png"
    done
  done
  echo "ok $est"
done < tiles_pro.txt
