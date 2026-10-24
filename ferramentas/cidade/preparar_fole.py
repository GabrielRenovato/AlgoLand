"""Integra o fole pintado em resolução4×, com geometria sazonal idêntica."""
from pathlib import Path
from PIL import Image
RAIZ = Path(__file__).resolve().parents[2]
FONTE = RAIZ / 'arte/fontes/forja/fole/original.png'
DESTINO = RAIZ / 'assets/cenario/cidade/interiores_detalhados/fole'
ESTACOES = ('primavera', 'verao', 'outono', 'inverno')

def preparar():
    original = Image.open(FONTE).convert('RGBA')
    # Um único recorte canônico; pés, dobradiça, alavanca e bico não mudam entre estações.
    caixa = original.getchannel('A').getbbox()
    base = original.crop(caixa).resize((192, 116), Image.Resampling.LANCZOS)
    DESTINO.mkdir(parents=True, exist_ok=True)
    for estacao, fatores in zip(ESTACOES, [(1,1,1),(1.012,1,.985),(.985,.975,.96),(.965,.985,1.015)]):
        canais = list(base.split())
        for i, fator in enumerate(fatores):
            canais[i] = canais[i].point(lambda valor: min(255, round(valor * fator)))
        Image.merge('RGBA', canais).save(DESTINO / (estacao+'.png'))
if __name__ == '__main__':
    preparar()
