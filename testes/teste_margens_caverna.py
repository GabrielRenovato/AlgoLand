#!/usr/bin/env python3
"""A estação muda a luz da água subterrânea, sem abrir buracos ou colar chão nas margens."""
from pathlib import Path
from PIL import Image

RAIZ = Path(__file__).resolve().parents[1]
PASTA = RAIZ / 'assets/cenario/fendas/andar_07'
mascaras = []
cores = set()
for estacao in ['spring', 'summer', 'autumn', 'winter']:
    imagem = Image.open(PASTA / f'{estacao}.png').convert('RGBA')
    margem = imagem.crop((0, 256, imagem.width, imagem.height))
    alfa = margem.getchannel('A').tobytes()
    assert 0 in alfa and 255 in alfa, f'{estacao}: falta água ou transparência na margem'
    mascaras.append(alfa)
    cores.add(imagem.tobytes())
    for x, y in [(11, 13), (12, 13), (13, 13), (12, 14), (13, 14)]:
        r, g, b, a = imagem.getpixel((x * 16 + 8, y * 16 + 8))
        assert a == 255 and b > r and g > r, f'{estacao}: água interna perdeu seu material'
    print(f'OK margem mineral transparente e agua protegida: {estacao}')
assert all(m == mascaras[0] for m in mascaras), 'A estação modificou o contorno da água'
assert len(cores) == 4, 'Faltam os reflexos das quatro estações'
print('OK contorno sazonal estável, sem recortes retangulares')

# Uma faixa transparente no atlas base deixava a folha antiga aparecer no andar11.
for andar in [3,4,7,11]:
    atlas=Image.open(RAIZ/f"assets/cenario/fendas/rpgw_caves/andar_{andar:02}.png").convert("RGBA")
    assert atlas.getchannel("A").getextrema()==(255,255), f"Andar {andar}: piso deixa o terreno antigo aparecer"
print("OK pisos RPGW opacos, sem faixas do terreno antigo")
