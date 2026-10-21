"""Prepara tufos inteiros da folha desenhada; fecha o material por cortes mínimos."""
from functools import lru_cache
from pathlib import Path
import random
from PIL import Image, ImageChops

RAIZ = Path(__file__).resolve().parents[2]
FONTE = RAIZ/'arte/fontes/cenario/grama_tufos/quatro_estacoes.png'


@lru_cache(maxsize=4)
def faixa_topo(estacao):
    """Referência cromática do morro; não é a fonte dos tufos do chão."""
    im = Image.open(RAIZ/'arte/fontes/cenario/penhasco/quatro_estacoes.png').convert('RGB')
    w, h = im.width//2, im.height//2
    x, y = estacao%2*w, estacao//2*h
    painel = im.crop((x,y,x+w,y+h)).resize((96,64),Image.Resampling.NEAREST)
    y0 = 2 if estacao == 3 else 0
    return painel.crop((0,y0,96,y0+4))


@lru_cache(maxsize=4)
def painel_nativo(estacao):
    im = Image.open(FONTE).convert('RGB')
    w, h = im.width//2, im.height//2
    x, y = estacao%2*w, estacao//2*h
    # Recupera os blocos quadrados da geração sem esticar os tufos.
    painel = im.crop((x,y,x+w,y+h)).resize((128,85),Image.Resampling.NEAREST)
    return painel.quantize(colors=16,dither=Image.Dither.NONE).convert('RGB')


def corte_minimo(a, b):
    """Caminho vertical de menor diferença; cada pixel continua sendo da fonte."""
    w, h = a.size
    erro = list(ImageChops.difference(a,b).get_flattened_data())
    anterior = [sum(v*v for v in erro[x]) for x in range(w)]
    caminhos = []
    for y in range(1,h):
        atual, volta = [], []
        for x in range(w):
            melhor = min(range(max(0,x-1),min(w,x+2)),key=lambda i:anterior[i])
            atual.append(anterior[melhor]+sum(v*v for v in erro[y*w+x]))
            volta.append(melhor)
        caminhos.append(volta)
        anterior = atual
    x = min(range(w),key=lambda i:anterior[i])
    caminho = [x]
    for volta in reversed(caminhos):
        x = volta[x]
        caminho.append(x)
    return list(reversed(caminho))


def diferenca(a,b):
    return sum((i%256)**2*n for i,n in enumerate(ImageChops.difference(a,b).histogram()))


def periodico(im):
    """Sobrepõe32px nas extremidades com recorte irregular, sem espelhar ou pintar molduras."""
    campo = im.copy()
    esquerda, direita = campo.crop((0,0,32,160)),campo.crop((128,0,160,160))
    corte = corte_minimo(esquerda,direita)
    for y in range(160):
        for x in range(corte[y]): campo.putpixel((x,y),direita.getpixel((x,y)))
    cima = campo.crop((0,0,128,32)).transpose(Image.Transpose.TRANSPOSE)
    baixo = campo.crop((0,128,128,160)).transpose(Image.Transpose.TRANSPOSE)
    corte = corte_minimo(cima,baixo)
    for x in range(128):
        for y in range(corte[x]): campo.putpixel((x,y),baixo.getpixel((y,x)))
    return campo.crop((0,0,128,128)).convert('RGBA')


@lru_cache(maxsize=4)
def campo_nativo(estacao):
    return montar_campo(painel_nativo(estacao),409+estacao)


def montar_campo(fonte,semente):
    rng = random.Random(semente)
    campo = Image.new('RGB',(160,160))
    for y in range(0,97,32):
        for x in range(0,97,32):
            candidatos = []
            for _ in range(40):
                sx,sy = rng.randrange(fonte.width-63),rng.randrange(fonte.height-63)
                parte = fonte.crop((sx,sy,sx+64,sy+64))
                erro = 0
                if x: erro += diferenca(campo.crop((x,y,x+32,y+64)),parte.crop((0,0,32,64)))
                if y: erro += diferenca(campo.crop((x,y,x+64,y+32)),parte.crop((0,0,64,32)))
                candidatos.append((erro,parte))
            candidatos.sort(key=lambda c:c[0])
            parte = candidatos[rng.randrange(3)][1]
            mascara = Image.new('L',(64,64),255)
            if x:
                corte = corte_minimo(campo.crop((x,y,x+32,y+64)),parte.crop((0,0,32,64)))
                for py in range(64):
                    for px in range(corte[py]): mascara.putpixel((px,py),0)
            if y:
                corte = corte_minimo(campo.crop((x,y,x+64,y+32)).transpose(Image.Transpose.TRANSPOSE),parte.crop((0,0,64,32)).transpose(Image.Transpose.TRANSPOSE))
                for px in range(64):
                    for py in range(corte[px]): mascara.putpixel((px,py),0)
            campo.paste(parte,(x,y),mascara)
    return periodico(campo)


def exportar_bancos(N):
    pasta = RAIZ/'assets/cenario/substitutos/grama_continua'
    pasta.mkdir(exist_ok=True)
    for e,nome in enumerate(['spring','summer','autumn','winter']):
        campo = campo_nativo(e)
        atlas = Image.new('RGBA',(128,128*9))
        for banco in range(9):
            atlas.paste(campo,(0,banco*128))
            if banco:
                flor = N.planta(e,True,banco-1)
                for y in range(0,128,16):
                    for x in range(0,128,16): atlas.alpha_composite(flor,(x,banco*128+y))
        atlas.save(pasta/(nome+'.png'))
