#!/usr/bin/env python3
"""Terra contínua com bordas de grama; preserva as células e máscaras dos mapas."""
from functools import lru_cache
from pathlib import Path
from PIL import Image
from grama_do_topo import montar_campo

RAIZ=Path(__file__).resolve().parents[2]
FONTE=RAIZ/'arte/fontes/cenario/terra_natural/quatro_estacoes.png'
NOMES=['spring','summer','autumn','winter']
CENTROS=[(2,1),(4,0),(4,1),(4,2),(4,3),(4,4)]
BORDAS=[(1,0),(2,0),(3,0),(1,1),(3,1),(1,2),(2,2),(3,2),(1,3),(2,3),(1,4),(2,4)]


@lru_cache(maxsize=4)
def campo_nativo(estacao):
    im=Image.open(FONTE).convert('RGB')
    w,h=im.width//2,im.height//2
    x,y=estacao%2*w,estacao//2*h
    painel=im.crop((x,y,x+w,y+h)).resize((112,90),Image.Resampling.NEAREST)
    painel=painel.quantize(colors=16,dither=Image.Dither.NONE).convert('RGB')
    return montar_campo(painel,1207+estacao)


@lru_cache(maxsize=4)
def paleta(estacao):
    campo=campo_nativo(estacao).convert('RGB')
    frequencias=sorted(campo.getcolors(16384),reverse=True)
    fundo=frequencias[0][1]
    tons=sorted([c for _,c in frequencias],key=sum)
    # Contato discreto: não usa a pedra mais escura como contorno de todo o caminho.
    escuro=tuple(round(v*.78) for v in fundo)
    sombra=tuple(round(v*.90) for v in fundo)
    return [escuro,sombra,fundo,tons[-3],tons[-1]]


def exportar_bancos(N):
    for e,nome in enumerate(NOMES):
        campo=campo_nativo(e)
        origem=Image.open(RAIZ/f'assets/cenario/substitutos/natureza/{nome}.png').convert('RGBA')
        atlas=Image.new('RGBA',(128,128*13))
        atlas.paste(campo,(0,0))
        grama=set(N.cores(e,'grama')[3:])
        escuro,sombra=N.cores(e,'terra')[:2]
        for banco,(tx,ty) in enumerate(BORDAS,1):
            modelo=origem.crop((tx*16,ty*16,tx*16+16,ty*16+16))
            for y in range(128):
                for x in range(128):
                    m=modelo.getpixel((x%16,y%16))
                    if not m[3]:continue
                    cor=campo.getpixel((x,y))
                    if m in grama:cor=m
                    elif m==escuro:cor=tuple(round(c*.78) for c in cor[:3])+(255,)
                    elif m==sombra:cor=tuple(round(c*.90) for c in cor[:3])+(255,)
                    atlas.putpixel((x,banco*128+y),cor)
        atlas.save(RAIZ/f'assets/cenario/substitutos/terra_continua/{nome}.png')


def preparar():
    # O preparo já existente atualiza as peças de terra com material e paleta novos,
    # mantendo as demais artes e as margens de água.
    from preparar_grama_penhasco import preparar as preparar_atlas
    preparar_atlas()
    from preparar_terra_mascarada import preparar as preparar_mascaras
    preparar_mascaras()


if __name__=='__main__':preparar()
