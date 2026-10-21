#!/usr/bin/env python3
"""Prepara materiais contínuos 4x; preserva originais e a grade física de16px."""
from pathlib import Path
import json
from PIL import Image, ImageFilter

RAIZ = Path(__file__).resolve().parents[2]
FONTES = RAIZ / 'arte/fontes/cidade/chao_detalhado'
SAIDA = RAIZ / 'assets/cenario/cidade/chao_detalhado'
ESTACOES = ['primavera', 'verao', 'outono', 'inverno']


def periodizar(im):
    # Corrige somente a variação lenta de exposição entre bordas, sem
    # espelhar tufos/pedras ou desfocar seus contornos internos.
    im = im.convert('RGB')
    w, h = im.size
    p = im.load()
    saida = Image.new('RGB', im.size)
    q = saida.load()
    def peso(borda):
        t = min(1, borda/24)
        return .5*(1-t*t*(3-2*t))
    def suavizar(diferencas):
        faixa = Image.new('RGB', (len(diferencas),1))
        faixa.putdata([tuple(round((c+255)/2) for c in d) for d in diferencas])
        faixa = faixa.resize((len(diferencas),64)).filter(ImageFilter.GaussianBlur(20))
        return [tuple(c*2-255 for c in faixa.getpixel((i,32))) for i in range(len(diferencas))]
    diferencas = [[p[w-1,y][k]-p[0,y][k] for k in range(3)] for y in range(h)]
    suaves = suavizar(diferencas)
    for y in range(h):
        for x in range(w):
            ajuste = peso(x)-peso(w-1-x)
            q[x,y] = tuple(max(0,min(255,round(p[x,y][k]+suaves[y][k]*(.5-x/(w-1))+(diferencas[y][k]-suaves[y][k])*ajuste))) for k in range(3))
    im = saida.copy(); p = im.load()
    diferencas = [[p[x,h-1][k]-p[x,0][k] for k in range(3)] for x in range(w)]
    suaves = suavizar(diferencas)
    for x in range(w):
        for y in range(h):
            ajuste = peso(y)-peso(h-1-y)
            q[x,y] = tuple(max(0,min(255,round(p[x,y][k]+suaves[x][k]*(.5-y/(h-1))+(diferencas[x][k]-suaves[x][k])*ajuste))) for k in range(3))
    return saida


def salvar(im, nome):
    p = SAIDA / (nome+'.png')
    im.save(p)
    importacao = p.with_suffix('.png.import')
    if importacao.exists():
        s = importacao.read_text().replace('mipmaps/generate=false', 'mipmaps/generate=true')
    else:
        s = '[remap]\nimporter="texture"\ntype="CompressedTexture2D"\n\n[deps]\nsource_file="res://'+str(p.relative_to(RAIZ))+'"\n\n[params]\nmipmaps/generate=true\n'
    importacao.write_text(s)


def main():
    SAIDA.mkdir(parents=True, exist_ok=True)
    medidas = {}
    for e, estacao in enumerate(ESTACOES):
        grama = Image.open(FONTES/(estacao+'.png')).convert('RGB').resize((512, 512), Image.Resampling.LANCZOS)
        grama = periodizar(grama)
        salvar(grama, 'grama_'+estacao)
        pedra = Image.open(FONTES/'pedra.png').convert('RGB').resize((512, 512), Image.Resampling.LANCZOS)
        pedra = periodizar(pedra)
        if e:
            pixels = []
            for rgb in pedra.get_flattened_data():
                if e == 1:
                    cor = [c*f for c, f in zip(rgb, [1.015, 1.005, .985])]
                elif e == 2:
                    cor = [c*f for c, f in zip(rgb, [.97, .955, .94])]
                else:
                    # Neve nas juntas; faces das pedras continuam legíveis.
                    neve = max(0, min(.68, (125-sum(rgb)/3)/50))
                    cor = [(c*(1-neve)+n*neve)*f for c,n,f in zip(rgb,[218,230,232],[.97,.995,1.025])]
                pixels.append(tuple(max(0,min(255,round(c))) for c in cor))
            pedra.putdata(pixels)
        salvar(pedra, 'pedra_'+estacao)
        w,h = grama.size
        medidas[estacao] = {
            'costura_x': sum(abs(a-b) for y in range(h) for a,b in zip(grama.getpixel((0,y)),grama.getpixel((w-1,y))))/(h*3),
            'costura_y': sum(abs(a-b) for x in range(w) for a,b in zip(grama.getpixel((x,0)),grama.getpixel((x,h-1))))/(w*3)}
    (SAIDA/'manifesto.json').write_text(json.dumps({'resolucao':4, 'periodo_logico':128,
        'estacoes':ESTACOES, 'costuras':medidas}, indent=2)+'\n')
    print('Chão detalhado: grama e pedra512×512, quatro estações, período lógico128px.')


if __name__ == '__main__':
    main()
