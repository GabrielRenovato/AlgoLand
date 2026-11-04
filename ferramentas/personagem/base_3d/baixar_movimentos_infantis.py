#!/usr/bin/env python3
"""Baixa a fonte CC0 oficial e expande accessors esparsos para o importador GLTF."""
import hashlib
import json
from pathlib import Path
import struct
import urllib.request

URL = 'https://gobkit.com/freebies/human001/Schoolkid.glb'
PAGINA = 'https://gobkit.itch.io/gobkit-free-character-pack-vol-1'


def compatibilizar(dados):
    tamanho = struct.unpack_from('<I', dados, 12)[0]
    modelo = json.loads(dados[20:20 + tamanho])
    inicio = 20 + tamanho
    tamanho_bin = struct.unpack_from('<I', dados, inicio)[0]
    binario = bytearray(dados[inicio + 8:inicio + 8 + tamanho_bin])
    tipos = {5120: 'b', 5121: 'B', 5122: 'h', 5123: 'H', 5125: 'I', 5126: 'f'}
    componentes = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}
    for accessor in modelo['accessors']:
        if 'sparse' not in accessor:
            continue
        tamanho_item = struct.calcsize('<' + tipos[accessor['componentType']]) * componentes[accessor['type']]
        denso = bytearray(accessor['count'] * tamanho_item)
        if 'bufferView' in accessor:
            view = modelo['bufferViews'][accessor['bufferView']]
            for i in range(accessor['count']):
                pos = view.get('byteOffset', 0) + accessor.get('byteOffset', 0) + i * view.get('byteStride', tamanho_item)
                denso[i*tamanho_item:(i+1)*tamanho_item] = binario[pos:pos+tamanho_item]
        esparso = accessor.pop('sparse')
        indices, valores = esparso['indices'], esparso['values']
        vi = modelo['bufferViews'][indices['bufferView']]
        vv = modelo['bufferViews'][valores['bufferView']]
        formato = '<' + tipos[indices['componentType']]
        for i in range(esparso['count']):
            indice = struct.unpack_from(formato, binario, vi.get('byteOffset', 0) + indices.get('byteOffset', 0) + i*struct.calcsize(formato))[0]
            pos = vv.get('byteOffset', 0) + valores.get('byteOffset', 0) + i*tamanho_item
            denso[indice*tamanho_item:(indice+1)*tamanho_item] = binario[pos:pos+tamanho_item]
        binario.extend(b'\0' * (-len(binario) % 4))
        accessor['bufferView'] = len(modelo['bufferViews'])
        accessor['byteOffset'] = 0
        modelo['bufferViews'].append({'buffer': 0, 'byteOffset': len(binario), 'byteLength': len(denso)})
        binario.extend(denso)
    modelo['buffers'][0]['byteLength'] = len(binario)
    texto = json.dumps(modelo, separators=(',', ':')).encode()
    texto += b' ' * (-len(texto) % 4)
    binario.extend(b'\0' * (-len(binario) % 4))
    return struct.pack('<4sII', b'glTF', 2, 28+len(texto)+len(binario)) + struct.pack('<I4s', len(texto), b'JSON') + texto + struct.pack('<I4s', len(binario), b'BIN\0') + binario


def main():
    pasta = Path(__file__).resolve().parents[3] / 'arte/fontes/personagens/base_3d/movimentos_infantis'
    pasta.mkdir(parents=True, exist_ok=True)
    dados = urllib.request.urlopen(urllib.request.Request(URL, headers={'User-Agent': 'Mozilla/5.0'}), timeout=45).read()
    (pasta/'Schoolkid-original.glb').write_bytes(dados)
    (pasta/'Schoolkid-compativel.glb').write_bytes(compatibilizar(dados))
    (pasta/'fonte.json').write_text(json.dumps({'autor': 'Gobkit', 'pagina': PAGINA, 'download': URL, 'licenca': 'CC0 1.0', 'sha256_original': hashlib.sha256(dados).hexdigest(), 'uso': 'Somente caminhada e descanso retargetados para nosso manequim; não usa corpo, textura ou roupa externos.', 'ajuste': 'Accessors esparsos expandidos sem alterar valores de poses.'}, ensure_ascii=False, indent=2)+'\n')
    print(pasta)

if __name__ == '__main__':
    main()
