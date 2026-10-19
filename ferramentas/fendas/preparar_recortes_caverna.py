#!/usr/bin/env python3
"""Fatia o estudo escolhido em16x16, preservando todos os pixels e a escala.

O atlas deduplica só blocos idênticos. Os padrões são recortes nativos completos
para montagem manual; não constituem um terreno automático de qualquer formato.
"""
import json
import math
from pathlib import Path

from PIL import Image

RAIZ = Path(__file__).resolve().parents[2]
FONTE = RAIZ/'arte/previas/fenda/gruta_nascente/estudo_gaias_navel_v2.png'
DESTINO = RAIZ/'assets/cenario/fendas/caverna_recortada'
FONTES = RAIZ/'arte/fontes/fendas/caverna_recortada'
GRADE = 16
COLUNAS = 64
PASSO = 18
PADROES = {
    'piso': [752,864,816,928],
    'parede_norte': [736,192,864,304],
    'parede_oeste': [128,272,208,384],
    'parede_leste': [1168,480,1248,608],
    'canto_externo_noroeste': [128,192,272,336],
    'canto_externo_nordeste': [304,192,448,336],
    'curva_interna_oeste': [432,352,576,512],
    'curva_interna_leste': [976,240,1120,400],
    'escada': [560,512,640,608],
    'entrada': [1088,32,1264,192],
    'agua': [784,416,880,512],
    'margem_norte': [768,336,960,432],
    'margem_sul': [736,512,960,640],
    'margem_oeste': [704,400,800,560],
    'margem_leste': [896,384,992,544],
    'musgo_alcova': [288,528,384,624],
    'sala_inferior': [480,736,1008,1072],
    'corredor': [432,592,656,816],
    'sala_alcova': [128,192,448,448],
    'patamar_lago': [512,192,1232,656],
}


def executar():
    DESTINO.mkdir(parents=True,exist_ok=True)
    FONTES.mkdir(parents=True,exist_ok=True)
    fonte=Image.open(FONTE).convert('RGBA')
    w,h=fonte.size
    tela=Image.new('RGBA',(math.ceil(w/16)*16,math.ceil(h/16)*16),(0,0,0,255))
    tela.paste(fonte,(0,0))
    unicos={};blocos=[];celulas=[]
    for y in range(0,tela.height,16):
        for x in range(0,tela.width,16):
            bloco=tela.crop((x,y,x+16,y+16))
            chave=bloco.tobytes()
            if chave not in unicos:
                unicos[chave]=len(blocos);blocos.append(bloco)
            celulas.append([x//16,y//16,unicos[chave]])
    atlas=Image.new('RGBA',(COLUNAS*PASSO,math.ceil(len(blocos)/COLUNAS)*PASSO))
    for i,bloco in enumerate(blocos):
        x,y=i%COLUNAS*PASSO+1,i//COLUNAS*PASSO+1
        atlas.paste(bloco,(x,y))
        # Um pixel extrudado em cada lado impede vazamento ao visualizar o atlas.
        atlas.paste(bloco.crop((0,0,1,16)),(x-1,y))
        atlas.paste(bloco.crop((15,0,16,16)),(x+16,y))
        atlas.paste(bloco.crop((0,0,16,1)),(x,y-1))
        atlas.paste(bloco.crop((0,15,16,16)),(x,y+16))
        for dx,dy,sx,sy in [(-1,-1,0,0),(16,-1,15,0),(-1,16,0,15),(16,16,15,15)]:
            atlas.putpixel((x+dx,y+dy),bloco.getpixel((sx,sy)))
    atlas.save(DESTINO/'atlas.png')
    dados={'grade':16,'origem':[w,h],'tamanho':[tela.width,tela.height],
           'colunas_atlas':COLUNAS,'passo_atlas':PASSO,'margem_atlas':1,
           'unicos':len(blocos),'celulas':celulas,'padroes':PADROES}
    (DESTINO/'mapa.json').write_text(json.dumps(dados,separators=(',',':'))+'\n')
    recortes=FONTES/'recortes'
    recortes.mkdir(exist_ok=True)
    for nome,box in PADROES.items():
        assert all(v%16==0 for v in box)
        fonte.crop(box).save(recortes/f'{nome}.png')
    contrato={'fonte':str(FONTE.relative_to(RAIZ)),'grade':[16,16],
              'escala':1,'alteracao_pixels':False,'redimensionamento':False,
              'borda_atlas':1,'separacao_atlas':2,'pivo_celula':[8,8],
              'deduplicacao':'somente blocos exatamente iguais; nenhuma alteração de paleta',
              'variantes':'Uma, conforme pedido explícito do usuário',
              'uso':'Padrões de recortes para montagem manual no Godot',
              'limites':'Recortes preservam contexto da imagem. Não são autotiles e não fecham qualquer planta automaticamente. Cena de arte sem colisão/navegação de jogo.',
              'integracao':'TileSet e cena próprios; campanha e saves não alterados',
              'validacao':'Remontagem e renderização comparadas pixel a pixel com a imagem escolhida',
              'padroes':PADROES}
    (FONTES/'contrato.json').write_text(json.dumps(contrato,ensure_ascii=False,indent=2)+'\n')
    print(f'RECORTES: {len(celulas)} células; {len(blocos)} blocos únicos; {len(PADROES)} padrões; nenhuma mudança nos pixels')


if __name__=='__main__':executar()
