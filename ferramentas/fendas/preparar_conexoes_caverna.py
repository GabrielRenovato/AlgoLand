"""Prepara uma folha desenhada para encaixes e uma bancada de montagem.

Não escolhe fragmentos de uma ilustração nem corrige bordas por deformação.
Os módulos de 64 px são subdivididos na grade de 16 px do AlgoLand.
"""
from pathlib import Path
import json
import sys
from PIL import Image

RAIZ = Path(__file__).resolve().parents[2]
BASE = RAIZ / 'assets/cenario/fendas/caverna_conexoes'
PECAS = {0:(3,2), 1:(2,2), 2:(0,2), 3:(1,2), 4:(2,0),
         5:(2,1), 7:(3,3), 8:(0,0), 10:(0,1), 11:(2,3),
         12:(1,0), 13:(1,3), 14:(0,3), 15:(1,1)}
ESPELHADAS = {13:14}

def main():
    original = Image.open(sys.argv[1]).convert('RGB')
    assert original.width == original.height, 'A folha precisa ser quadrada'
    # Normaliza a ampliação da folha de pixels lógicos, não uma ilustração.
    atlas = original.resize((256,256), Image.Resampling.NEAREST)
    BASE.mkdir(parents=True, exist_ok=True)
    atlas.save(BASE / 'atlas.png')
    # União de corredores e salas ortogonais com reentrâncias e larguras distintas.
    vertices = set()
    for x0,y0,x1,y1 in [(1,1,6,5),(5,3,10,7),(8,1,12,4)]:
        vertices.update((x,y) for y in range(y0,y1+1) for x in range(x0,x1+1))
    celulas = []
    mascaras = set()
    for y in range(9):
        for x in range(14):
            m = sum(bit for dx,dy,bit in [(0,0,1),(1,0,2),(0,1,4),(1,1,8)]
                    if (x+dx,y+dy) in vertices)
            assert m in PECAS, f'Encontro diagonal ambíguo: {(x,y,m)}'
            mascaras.add(m)
            if m == 0:
                continue
            ax,ay = PECAS[ESPELHADAS.get(m,m)]
            alternativa = 4096 if m in ESPELHADAS else 0
            if m == 15 and (x*7+y*11)%5 == 0:
                ax,ay = 3,(x+y)%2
            for sy in range(4):
                for sx in range(4):
                    origem_x = 3-sx if alternativa else sx
                    celulas.append([x*4+sx,y*4+sy,ax*4+origem_x,ay*4+sy,alternativa])
    dados = {'grade':16,'modulo':64,'tamanho':[896,576],
             'celulas':celulas,'mascaras':sorted(mascaras),
             'pecas':{str(k):list(v) for k,v in PECAS.items()},
             'espelhadas':{str(k):str(v) for k,v in ESPELHADAS.items()},
             'escopo':'Bancada visual; uma variante conforme pedido; sem substituir andares.'}
    (BASE/'bancada.json').write_text(json.dumps(dados,indent=2)+'\n')
    print(f'Bancada: {len(celulas)} células; máscaras {sorted(mascaras)}')

if __name__ == '__main__':
    main()
