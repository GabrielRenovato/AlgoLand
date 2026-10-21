"""Regressão da casca que virava verde ao reduzir as cores da copa."""
from pathlib import Path
from PIL import Image

RAIZ=Path(__file__).resolve().parents[1]
for especie in ['arvore','arvore_var']:
    for estacao in ['spring','summer','autumn','winter']:
        im=Image.open(RAIZ/'assets/cenario/substitutos/natureza'/f'{especie}_{estacao}.png').convert('RGBA')
        assert im.size==(128,128)
        assert len({p for p in im.get_flattened_data() if p[3]})<=18,('excesso de cores',especie,estacao)
        assert im.getbbox()[3]==128,('apoio',especie,estacao)
        # O abeto tem pontas de agulhas baixas: medir a coluna do tronco,
        # sem confundir essas folhas legítimas com casca verde.
        faixa=range(63,65) if especie=='arvore_var' else range(128)
        casca=[im.getpixel((x,y)) for y in range(110,128) for x in faixa if im.getpixel((x,y))[3]]
        assert len(casca)>15,('tronco ausente',especie,estacao)
        verdes=[p for p in casca if p[1]>p[0]*1.08 and p[1]>p[2]*1.15]
        assert len(verdes)/len(casca)<.05,('casca contaminada pela copa',especie,estacao,len(verdes))
        assert set(im.getchannel('A').get_flattened_data())<={0,255},('halo',especie,estacao)
for estacao in ['spring','summer','autumn','winter']:
    a=Image.open(RAIZ/f'assets/cenario/substitutos/natureza/arvore_{estacao}.png')
    b=Image.open(RAIZ/f'assets/cenario/substitutos/natureza/arvore_var_{estacao}.png')
    assert a.tobytes()!=b.tobytes(),('espécies idênticas',estacao)
    caixa=b.getbbox()
    assert (caixa[2]-caixa[0])/(caixa[3]-caixa[1])<.6,('abeto perdeu silhueta estreita',estacao)
    assert caixa[3]-caixa[1]>=104,('abeto encolheu para uma folhosa menor',estacao)
print('ARVORES FLORESTA: 0 falhas; oito troncos, raízes e alfa binário.')
