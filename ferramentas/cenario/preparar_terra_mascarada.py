#!/usr/bin/env python3
"""Máscaras semânticas de terra: preservam os tiles Wang, a guia e a vegetação Gentle."""
from pathlib import Path
from PIL import Image
from preparar_terra_natural import campo_nativo,NOMES,CENTROS,BORDAS,paleta

RAIZ=Path(__file__).resolve().parents[2]
SAIDA=RAIZ/'assets/cenario/substitutos/terra_mascarada'


def salvar(im,p):
    p.parent.mkdir(parents=True,exist_ok=True)
    im.save(p)


def preparar():
    for e,nome in enumerate(NOMES):
        campo=campo_nativo(e)
        salvar(campo,RAIZ/f'assets/cenario/substitutos/terra_continua/campo_{nome}.png')
        pasta=['primavera','verao','outono','inverno'][e]
        # Os atlas locais da cidade são composições conhecidas da mesma terra.
        # A classificação exata preserva até os pixels isolados da guia de pedra.
        cores=set(campo.convert('RGB').get_flattened_data())|set(paleta(e))
        import gerar_natureza_original as N
        cores.add(tuple(bytes.fromhex(N.PALETAS[e]['terra'][2])))
        for par in ['grama_terra','terra_pedra']:
            origem=Image.open(RAIZ/f'assets/cenario/algoland_original/{pasta}/{par}.png').convert('RGB')
            mascara=Image.new('RGBA',origem.size,(0,255,0,255))
            for y in range(origem.height):
                for x in range(origem.width):
                    cor=origem.getpixel((x,y))
                    if cor in cores:
                        sombra=199 if cor==paleta(e)[0] else 255
                        mascara.putpixel((x,y),(255,sombra,0,255))
            salvar(mascara,SAIDA/f'cidade/{nome}_{par}.png')
        for andar in [1,2,5,8]:
            origem=Image.open(RAIZ/f'assets/cenario/fendas/andar_{andar:02}/{nome}.png').convert('RGBA')
            terra=set()
            grama=set()
            for tx,ty in CENTROS:
                terra.update(origem.crop((tx*16,ty*16,tx*16+16,ty*16+16)).convert('RGB').get_flattened_data())
            for ty in range(1,6):
                grama.update(origem.crop((0,ty*16,16,ty*16+16)).convert('RGB').get_flattened_data())
            # A paleta de terra foi medida no próprio material. Na franja, só
            # a classificação entre as duas paletas é usada; a geometria não muda.
            cache={}
            mascara=Image.new('RGBA',origem.size,(0,255,0,255))
            for tx,ty in CENTROS+BORDAS:
                for y in range(16):
                    for x in range(16):
                        cor=origem.getpixel((tx*16+x,ty*16+y))
                        if not cor[3]:continue
                        rgb=cor[:3]
                        if rgb not in cache:
                            dt=min(sum((a-b)**2 for a,b in zip(rgb,c)) for c in terra)
                            dg=min(sum((a-b)**2 for a,b in zip(rgb,c)) for c in grama)
                            cache[rgb]=dt<dg
                        if (tx,ty) in CENTROS or cache[rgb]:
                            mascara.putpixel((tx*16+x,ty*16+y),(255,255,0,255))
            salvar(mascara,SAIDA/f'andar_{andar:02}/{nome}.png')
    print('Terra: campos e máscaras da cidade e florestas preparados nas quatro estações.')


if __name__=='__main__':preparar()
