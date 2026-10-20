"""Acrescenta a vegetação do novo terreno sem redistribuir os adornos da vila existente."""
import json
from pathlib import Path
from copy import deepcopy

RAIZ = Path(__file__).resolve().parents[2]

def atualizar():
    p=RAIZ/'assets/cenario/cidade/decoracao/decoracao.json'
    itens=[i for i in json.loads(p.read_text()) if not i.get('quintal_carpinteiro')]
    ambientes=json.loads((RAIZ/'assets/cenario/cidade/ambientes/manifesto.json').read_text())
    grupos={'arvore':[(744,94),(720,172),(816,88),(952,100),(992,160),(1008,508),(744,560),(832,568),(920,560),(1008,568)],
            'arbusto':[(720,234),(720,336),(952,322),(724,448),(936,450),(968,240)],
            'poste_luz':[(724,250)],
            'canteiro':[(760,232)],
            'flores':[(720,376),(720,408),(944,388),(944,414),(768,444),(864,444)]}
    # Reservar também o volume das copas, não apenas os troncos: o pasto
    # e o abrigo precisam permanecer visíveis durante toda a movimentação.
    layout=json.loads((RAIZ/'codigo/cidade/layout_vila.json').read_text())
    x,y,w,h=layout['quintal_carpinteiro']['cercado']
    for ax,ay in grupos['arvore']:
        usado=ambientes['externo/arvore']['usado']
        esquerda,direita=ax-usado[2]/2,ax+usado[2]/2
        topo=ay-usado[3]
        if esquerda<x+w+12 and direita>x-12 and topo<y+h+12 and ay>y-12:
            raise ValueError(f'Copa invade cercado: {(ax,ay)}')
    for nome,pontos in grupos.items():
        base=next((i for i in itens if i['p'].split('/')[-1]==nome),None)
        if base is None:
            base={'p':'vegetacao/'+nome,**ambientes['externo/'+nome]}
        if nome == 'flores':
            base={**base,'estacoes':[0,1,2]}
        for x,y in pontos:
            item=deepcopy(base);item.update(x=x,y=y,quintal_carpinteiro=True);itens.append(item)
    p.write_text(json.dumps(itens,ensure_ascii=False,indent=1)+'\n')

if __name__=='__main__': atualizar()
