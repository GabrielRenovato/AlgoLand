#!/usr/bin/env python3
"""Registra os quatro quadros pela base física, sem redimensionar a arte."""
from pathlib import Path
import json
from PIL import Image
from preparar_modulares_clareiras import separar_peca

RAIZ = Path(__file__).resolve().parents[2]
ESTACOES = ['primavera', 'verao', 'outono', 'inverno']

def main():
    fontes = RAIZ / 'arte/fontes/campanha/bau_resgate'
    destino = RAIZ / 'assets/cenario/campanha/clareiras_modulares'
    primavera = Image.open(fontes / 'primavera.png').convert('RGBA')
    w, h = primavera.size
    regioes = [(i % 2 * (w//2), i//2 * (h//2), (i%2+1)*(w//2), (i//2+1)*(h//2)) for i in range(4)]
    ajustes = []
    larguras = []
    for regiao in regioes:
        quadro = separar_peca(primavera.crop(regiao))
        alfa = quadro.getchannel('A')
        caixa = alfa.point(lambda a: 255 if a>100 else 0).getbbox()
        y = caixa[3]-1
        base = [(x, yy) for yy in range(y-3, y+1) for x in range(quadro.width) if alfa.getpixel((x, yy))>100]
        ponta_x = sum(x for x, _ in base)/len(base)
        ajustes.append((round(440-ponta_x), 710-y))
        larguras.append(caixa[2]-caixa[0])
    ficha = {'quadros': 4, 'grade': [2, 2], 'duracao_quadro': .16, 'loop': False, 'variantes': {}}
    for estacao in ESTACOES:
        imagem = Image.open(fontes / (estacao+'.png')).convert('RGBA')
        if imagem.size != primavera.size: raise ValueError('Grade sazonal divergente: '+estacao)
        atlas = Image.new('RGBA', (1536,1536))
        for i, regiao in enumerate(regioes):
            quadro = separar_peca(imagem.crop(regiao))
            atlas.paste(quadro, (i%2*768+ajustes[i][0], i//2*768+ajustes[i][1]))
        arquivo = destino/estacao/'bau_animado.png'
        atlas.save(arquivo)
        ficha['variantes'][estacao] = {'textura': 'res://'+str(arquivo.relative_to(RAIZ)), 'quadro':[768,768], 'pivo':[440,710], 'largura_corpo':sum(larguras)/4}
    (destino/'bau_animado.json').write_text(json.dumps(ficha,ensure_ascii=False,indent=2)+'\n')

if __name__ == '__main__': main()
