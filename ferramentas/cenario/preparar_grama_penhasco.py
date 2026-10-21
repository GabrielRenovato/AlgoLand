#!/usr/bin/env python3
"""Grama original em tufos, na mesma direção visual do penhasco."""
from pathlib import Path
from PIL import Image
import sys

RAIZ=Path(__file__).resolve().parents[2]
FONTE=RAIZ/'arte/fontes/cenario/penhasco'
NOMES=['spring','summer','autumn','winter']

def paleta_morro(estacao):
    from grama_do_topo import faixa_topo
    return faixa_topo(estacao).convert('RGB')

def nativo(estacao):
    from grama_do_topo import campo_nativo
    return campo_nativo(estacao).crop((0,0,32,32))

def preparar():
    import gerar_natureza_original as N
    sys.path.insert(0,str(RAIZ/'ferramentas/arena'))
    import gerar_arena as G
    for e,nome in enumerate(NOMES):
        tile=nativo(e)
        destino=N.FONTE/'revisao_mana/nativos'/f'grama_{nome}.png'
        tile.save(destino)
        frequencias=sorted(tile.convert('RGB').getcolors(1024),reverse=True)
        tons=sorted([cor for _,cor in frequencias],key=sum)
        rampa=[tons[0],tons[0],frequencias[0][1],tons[-2],tons[-1]]
        N.PALETAS[e]['grama']=[''.join(f'{v:02x}' for v in cor) for cor in rampa]
        for relativo in ['natureza','fenda_bosque','fendas/andar_06','fendas/andar_10']:
            p=RAIZ/'assets/cenario/substitutos'/relativo/(nome+'.png')
            if not p.exists():continue
            tamanho=Image.open(p).size
            atlas=N.atlas_compativel(tamanho,e,G)
            mascara=Image.open(N.FONTE/'mascaras_margens'/f"{relativo.replace('/','_')}.png").convert('L')
            antigo=Image.open(p).convert('RGBA');grama=N.material('grama',e)
            # As margens mantêm os pixels de água e a máscara; só o chão muda.
            for y in range(256,tamanho[1]):
                for x in range(tamanho[0]):
                    atlas.putpixel((x,y),(0,0,0,0) if mascara.getpixel((x,y-256))==1 else antigo.getpixel((x,y)))
            atlas.save(p)
    N.terrenos()
    from grama_do_topo import exportar_bancos
    exportar_bancos(N)
    from preparar_penhasco import preparar_faixas
    preparar_faixas()
    from preparar_terra_natural import exportar_bancos as exportar_terra
    exportar_terra(N)
    print('Grama em tufos, margens e penhasco integrados nas quatro estações.')

if __name__=='__main__':preparar()
