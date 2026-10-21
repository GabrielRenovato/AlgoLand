#!/usr/bin/env python3
"""Prepara a revisão de nitidez para a grade, alpha e pivô do AlgoLand.

Usa redesenhos em nitidez/, com grupos maiores sobre o modelo escolhido.
As primeiras gerações e referências ficam arquivadas em revisao_mana/.
"""
from pathlib import Path
from PIL import Image

RAIZ = Path(__file__).resolve().parents[2]
FONTE = RAIZ/'arte/fontes/cenario/algoland_original/revisao_mana'
NOMES = ['spring','summer','autumn','winter']

def preparar():
    destino=FONTE/'nativos';destino.mkdir(exist_ok=True)
    from preparar_arvores_floresta import preparar as preparar_arvores
    from preparar_grama_penhasco import nativo
    preparar_arvores()
    for e,nome in enumerate(NOMES):
        nativo(e).save(destino/f'grama_{nome}.png')

if __name__=='__main__':preparar()
