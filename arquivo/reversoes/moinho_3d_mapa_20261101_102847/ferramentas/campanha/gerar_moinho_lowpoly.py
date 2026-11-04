"""Exporta GLB com materiais compartilhados e roda animada; usa apenas a biblioteca padrão."""
from pathlib import Path
import json, math, struct

RAIZ = Path(__file__).resolve().parents[2]
DESTINO = RAIZ / 'assets/cenario/campanha/moinho_lowpoly'
dados = json.loads((RAIZ / 'arte/fontes/campanha/moinho_lowpoly/geometria.json').read_text())
documento = {'asset': {'version': '2.0', 'generator': 'AlgoLand — moinho low poly'},
             'scene': 0, 'scenes': [{'nodes': [0]}],
             'nodes': [{'name': 'MoinhoLowPoly', 'children': [1, 2]},
                       {'name': 'Estrutura', 'mesh': 0},
                       {'name': 'Roda', 'mesh': 1, 'translation': [-2.86, 1.55, .2]}],
             'meshes': [], 'materials': [], 'bufferViews': [], 'accessors': []}
binario = bytearray()
materiais = {}

def acesso(valores, tipo, limites=False):
    dimensao = {'SCALAR': 1, 'VEC3': 3, 'VEC4': 4}[tipo]
    while len(binario) % 4:
        binario.append(0)
    deslocamento = len(binario)
    binario.extend(struct.pack('<' + 'f' * len(valores), *valores))
    vista = len(documento['bufferViews'])
    documento['bufferViews'].append({'buffer': 0, 'byteOffset': deslocamento, 'byteLength': len(valores)*4})
    item = {'bufferView': vista, 'componentType': 5126, 'count': len(valores)//dimensao, 'type': tipo}
    if limites:
        item['min'] = [min(valores[i::dimensao]) for i in range(dimensao)]
        item['max'] = [max(valores[i::dimensao]) for i in range(dimensao)]
    documento['accessors'].append(item)
    return len(documento['accessors'])-1

def material(cor):
    if cor not in materiais:
        rgb = [int(cor[i:i+2], 16)/255 for i in (1,3,5)]
        # Entradas sRGB convertidas para cor linear do glTF.
        rgb = [v/12.92 if v <= .04045 else ((v+.055)/1.055)**2.4 for v in rgb]
        materiais[cor] = len(documento['materials'])
        documento['materials'].append({'name': 'Material_'+cor[1:], 'pbrMetallicRoughness':
            {'baseColorFactor': rgb+[1], 'metallicFactor': .0, 'roughnessFactor': .82}, 'doubleSided': True})
    return materiais[cor]

triangulos = 0
for nome, faces, pivo in [('Estrutura', dados['fixed'], [0,0,0]), ('Roda', dados['moving'], [-2.86,1.55,.2])]:
    grupos = {}
    for face in faces:
        posicoes, normais = grupos.setdefault(face['color'], ([], []))
        pontos = [[p[i]-pivo[i] for i in range(3)] for p in face['points']]
        for i in range(1,len(pontos)-1):
            a,b,c = pontos[0],pontos[i],pontos[i+1]
            u,v = [b[j]-a[j] for j in range(3)], [c[j]-a[j] for j in range(3)]
            normal = [u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]]
            modulo = math.sqrt(sum(n*n for n in normal)) or 1
            normal = [n/modulo for n in normal]
            for p in [a,b,c]:
                posicoes.extend(p); normais.extend(normal)
            triangulos += 1
    primitivas = []
    for cor,(posicoes,normais) in grupos.items():
        primitivas.append({'attributes': {'POSITION': acesso(posicoes,'VEC3',True),'NORMAL': acesso(normais,'VEC3')}, 'material': material(cor)})
    documento['meshes'].append({'name': nome, 'primitives': primitivas})

tempos = [i*12/48 for i in range(49)]
rotacoes = []
for t in tempos:
    angulo = -t/12*math.tau
    rotacoes.extend([math.sin(angulo/2),0,0,math.cos(angulo/2)])
documento['animations'] = [{'name':'girar_roda', 'samplers':[{'input':acesso(tempos,'SCALAR',True),'output':acesso(rotacoes,'VEC4'),'interpolation':'LINEAR'}],
                           'channels':[{'sampler':0,'target':{'node':2,'path':'rotation'}}]}]
documento['buffers'] = [{'byteLength': len(binario)}]
texto = json.dumps(documento,separators=(',',':'),ensure_ascii=False).encode()
texto += b' ' * (-len(texto)%4)
binario.extend(b'\0'*(-len(binario)%4))
glb = struct.pack('<III',0x46546c67,2,12+8+len(texto)+8+len(binario))
glb += struct.pack('<II',len(texto),0x4e4f534a)+texto+struct.pack('<II',len(binario),0x004e4942)+binario
DESTINO.mkdir(parents=True,exist_ok=True)
(DESTINO/'moinho.glb').write_bytes(glb)
ficha = {'triangulos':triangulos,'materiais':len(materiais),'bytes_glb':len(glb),'unidade':'metro',
         'roda':{'no':'Roda','pivo':[-2.86,1.55,.2],'eixo':'X','animacao':'girar_roda','ciclo_segundos':12},
         'estado':'Modelo e prévia próprios. Ainda não substitui o moinho 2D da campanha.'}
(DESTINO/'ficha.json').write_text(json.dumps(ficha,indent=2,ensure_ascii=False)+'\n')
print(json.dumps(ficha,ensure_ascii=False))
