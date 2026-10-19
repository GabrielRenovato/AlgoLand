#!/usr/bin/env python3
"""Empacota peças nativas Wang32 em grade16, sem reduzir a ilustração de referência."""
import json
import math
from pathlib import Path

from PIL import Image

RAIZ = Path(__file__).resolve().parents[2]
FONTES = RAIZ / 'arte/fontes/fendas/gruta_nascente/tiles'
DESTINO = RAIZ / 'assets/cenario/fendas/gruta_nascente'


def sala(x, y):
    return ((x-10)/8.5)**2 + ((y-7)/5.25)**2 < 1 or (9 <= x <= 11 and y >= 10)


def lago(x, y):
    return ((x-13.5)/2.6)**2 + ((y-6)/2)**2 < 1 and not (x < 12.7 and y > 5.6)


def periodizar(imagem):
    """Fecha as extremidades do material, sem alterar escala ou silhueta."""
    resultado = imagem.copy()
    w, h = imagem.size
    for y in range(h):
        for k in range(3):
            a, b = imagem.getpixel((k,y)), imagem.getpixel((w-1-k,y))
            medio = tuple((a[i]+b[i])//2 for i in range(4))
            resultado.putpixel((k,y),medio)
            resultado.putpixel((w-1-k,y),medio)
    imagem = resultado.copy()
    for x in range(w):
        for k in range(3):
            a, b = imagem.getpixel((x,k)), imagem.getpixel((x,h-1-k))
            medio = tuple((a[i]+b[i])//2 for i in range(4))
            resultado.putpixel((x,k),medio)
            resultado.putpixel((x,h-1-k),medio)
    return resultado


def materiais_continuos():
    """Aplica os materiais gerados às máscaras nativas, com vértices compartilhados.

    A edição livre de imagem alterou os contornos Wang. A máscara técnica original
    recupera o piso e a água usa a mesma função bilinear em todos os dezesseis casos.
    """
    parede = Image.open(FONTES/'paredes_revisadas.png').convert('RGBA')
    guia = Image.open(FONTES/'paredes.png').convert('RGBA')
    cores_rocha = {guia.getpixel((x,y))[:3] for y in range(192,224) for x in range(32)}
    piso = periodizar(parede.crop((64,64,96,96)))
    for y in range(256):
        for x in range(128):
            r,g,b,a = guia.getpixel((x,y))
            # Os dois tons de solo do guia são distintos de toda a pedra.
            if (r,g,b) in [(234,181,50),(229,176,48)]:
                parede.putpixel((x,y),piso.getpixel((x%32,y%32)))
            # Massa rochosa fora da face visível é vazio preto, como na referência.
            elif (r,g,b) in cores_rocha:
                parede.putpixel((x,y),(0,0,0,255))
    agua_original = Image.open(FONTES/'agua.png').convert('RGBA')
    agua = periodizar(agua_original.crop((0,0,32,32)))
    for y in range(32):
        for x in range(32):
            r,g,b,a=agua.getpixel((x,y))
            agua.putpixel((x,y),(int(18+r*.45),int(20+g*.48),int(12+b*.35),a))
    margens = Image.new('RGBA',(128,128))
    face = periodizar(parede.crop((96,12,128,36)))
    for ident in range(16):
        bits = [(ident>>k)&1 for k in range(4)]
        for y in range(32):
            for x in range(32):
                u,v = x/31,y/31
                valor = bits[0]*(1-u)*(1-v)+bits[1]*u*(1-v)+bits[2]*(1-u)*v+bits[3]*u*v
                gx = (bits[1]-bits[0])*(1-v)+(bits[3]-bits[2])*v
                gy = (bits[2]-bits[0])*(1-u)+(bits[3]-bits[1])*u
                gradiente = abs(gy) if x in (0,31) else abs(gx) if y in (0,31) else math.hypot(gx,gy)
                distancia = (valor-.5)*32/max(gradiente,.01)
                cor = piso.getpixel((x,y)) if valor>=.5 else agua.getpixel((x,y))
                # Acabamento baixo da margem: sombra em contato, topo ocre e reflexo.
                # A distância usa os mesmos vértices nas duas faces de cada junção.
                if 0 <= distancia < 3.0:
                    r,g,b,a = cor
                    if distancia<1:
                        cor = (48,31,24,255)
                    elif distancia<2:
                        cor = (102,75,44,255)
                    else:
                        cor = (min(255,r+14),min(255,g+8),b,255)
                elif -6<distancia<0:
                    cor = face.getpixel((x, min(23,int(-distancia)*3)))
                margens.putpixel((ident%4*32+x,ident//4*32+y),cor)
    return parede, margens, piso


def executar():
    DESTINO.mkdir(parents=True, exist_ok=True)
    paredes = json.loads((FONTES / 'paredes.json').read_text())
    agua = json.loads((FONTES / 'agua.json').read_text())
    # Metadados do serviço mantidos integralmente; nenhuma coordenada adivinhada.
    conjuntos = [('paredes', paredes, 0), ('agua', agua, 256)]
    atlas = Image.new('RGBA', (256, 512))
    parede_corrigida, agua_corrigida, piso = materiais_continuos()
    for nome, _, deslocamento in conjuntos:
        folha = parede_corrigida if nome == 'paredes' else agua_corrigida
        assert folha.width <= 256 and folha.height <= 256, folha.size
        atlas.alpha_composite(folha, (0, deslocamento))
    for i in range(8):
        variante = Image.new('RGBA',(32,32))
        for y in range(32):
            for x in range(32):
                variante.putpixel((x,y),piso.getpixel(((x+(i%4)*8)%32,(y+(i//4)*16)%32)))
        if i>=4:
            variante=variante.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        for y in range(32):
            for x in range(32):
                if min(x,y,31-x,31-y)<4:
                    variante.putpixel((x,y),piso.getpixel((x,y)))
        atlas.alpha_composite(variante,(128+i%4*32,i//4*32))
    objetos = []
    for i, nome in enumerate(['estalagmite', 'caixote', 'lanterna', 'nascente']):
        imagem = Image.open(FONTES / f'{nome}.png').convert('RGBA')
        assert imagem.width <= 32 and imagem.height <= 64
        # Preserva margem de transparência e tamanho nativo; pivô pela base visível.
        caixa = imagem.getbbox()
        atlas.alpha_composite(imagem, (128 + 32*i, 448))
        objetos.append({'nome': nome, 'regiao': [128+32*i, 448, imagem.width, imagem.height],
                        'pivo': [imagem.width/2, caixa[3] if caixa else imagem.height]})
    atlas.save(DESTINO / 'base.png')
    dados = {'tamanho': [640, 448], 'grade': 16, 'grade_wang': 32,
             'conjuntos': {}, 'objetos': objetos,
             'instancias': []}
    for nome, metadados, deslocamento in conjuntos:
        dados['conjuntos'][nome] = {'deslocamento_y': deslocamento, 'metadados': metadados}
    dados['vertices_sala'] = [[int(sala(x, y)) for x in range(21)] for y in range(15)]
    dados['vertices_lago'] = [[int(lago(x, y)) for x in range(21)] for y in range(15)]
    def terreno(x, y):
        if sala(x, y):
            return 0
        return 2 if sala(x, y+1) else 1

    def escolher_parede(x, y):
        candidatos = []
        for tile in paredes['tileset_data']['tiles']:
            padrao = tile['pattern_4x4']
            erro = 0
            especificidade = 0
            for j in range(4):
                for i in range(4):
                    valor = padrao[f'row_{j}'][i]
                    if valor == 255:
                        continue
                    peso = 20 if i in (1, 2) and j in (1, 2) else 3
                    erro += peso * int(terreno(x+i-1, y+j-1) != valor)
                    especificidade += 1
            candidatos.append((erro, -especificidade, str(tile['id']), tile))
        return min(candidatos, key=lambda v:v[:3])[-1]

    celulas = []
    navegaveis = []
    for y in range(14):
        for x in range(20):
            tile = escolher_parede(x, y)
            regiao = tile['bounding_box']
            puros = all(terreno(x+dx, y+dy) == 0 for dx, dy in [(0, 0), (1, 0), (0, 1), (1, 1)])
            if puros:
                variante = ((x*73856093) ^ (y*19349663))%8
                regiao = {'x':128+variante%4*32,'y':variante//4*32}
            bits = sum((0 if lago(x+dx, y+dy) else 1) << b for b, (dx, dy) in enumerate([(0,0),(1,0),(0,1),(1,1)]))
            agua_tile = puros and bits != 15
            for sy in range(2):
                for sx in range(2):
                    pos = [x*2+sx, y*2+sy]
                    celulas.append({'posicao': pos, 'atlas': [regiao['x']//16+sx, regiao['y']//16+sy], 'camada': 'Chao'})
                    if agua_tile:
                        celulas.append({'posicao': pos, 'atlas': [bits%4*2+sx, 16+bits//4*2+sy], 'camada': 'Agua'})
                    for fy in range(2):
                        for fx in range(2):
                            # Grade física8px: regiões mistas seguem o material visível.
                            ix = x*32+sx*16+fx*8
                            iy = y*32+sy*16+fy*8
                            seguro = puros
                            if not puros:
                                guia = Image.open(FONTES/'paredes.png').convert('RGBA')
                                amostra = guia.crop((regiao['x']+sx*16+fx*8, regiao['y']+sy*16+fy*8,
                                                     regiao['x']+sx*16+fx*8+8, regiao['y']+sy*16+fy*8+8))
                                solo = sum(amostra.getpixel((px,py))[:3] in [(234,181,50),(229,176,48)] for py in range(8) for px in range(8))
                                seguro = solo >= 53 and (sala((ix+4)/32,(iy+4)/32) or terreno(x,y)==2)
                            if agua_tile:
                                u = (sx*16+fx*8+4)/32
                                v = (sy*16+fy*8+4)/32
                                cantos = [(bits>>k)&1 for k in range(4)]
                                terra = cantos[0]*(1-u)*(1-v)+cantos[1]*u*(1-v)+cantos[2]*(1-u)*v+cantos[3]*u*v
                                seguro = seguro and terra>.65
                            if seguro:
                                navegaveis.append([ix//8, iy//8])
    dados['celulas'] = celulas
    dados['navegaveis_8px'] = navegaveis
    (DESTINO / 'mapa.json').write_text(json.dumps(dados, ensure_ascii=False, indent=2)+'\n')
    print('Atlas nativo e planta preparados:', DESTINO)


if __name__ == '__main__':
    executar()
