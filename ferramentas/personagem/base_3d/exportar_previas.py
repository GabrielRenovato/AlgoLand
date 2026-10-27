#!/usr/bin/env python3
"""Organiza capturas do Godot, sem pintar nem retocar os sprites renderizados."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json
R=Path(__file__).resolve().parents[3]
P=R/'arte/previas/personagens/base_3d'
F=ImageFont.load_default(size=19)

def recorte(nome):
    im=Image.open(P/nome).convert('RGBA')
    escala=im.width/160
    return im.crop(tuple(round(v*escala) for v in (48,43,112,116)))

def exportar():
    dados=json.loads((P/'revisao_roupas.json').read_text())
    assert dados['falhas']==0
    poster=Image.new('RGB',(1680,360),'#58645f')
    d=ImageDraw.Draw(poster)
    for i,(mascara,nome) in enumerate([(0,'BASE'),(1,'CAMISA'),(2,'CALÇA'),(4,'BOTAS'),(8,'CABELO'),(15,'CONJUNTO')]):
        im=recorte(f'pecas_{mascara:02d}.png').resize((256,292),Image.Resampling.LANCZOS)
        poster.paste(im,(i*280+12,48),im)
        caixa=d.textbbox((0,0),nome,font=F);largura=caixa[2]-caixa[0]
        d.text((i*280+(280-largura)//2,15),nome,font=F,fill='white')
    poster.save(P/'pecas_separadas.png')
    vistas=Image.new('RGB',(1024,360),'#58645f')
    desenho=ImageDraw.Draw(vistas)
    for direcao,nome in enumerate(['FRENTE','DIREITA','COSTAS','ESQUERDA']):
        im=recorte(f'vestido_parado_{direcao}.png').resize((256,292),Image.Resampling.LANCZOS)
        vistas.paste(im,(direcao*256,48),im)
        caixa=desenho.textbbox((0,0),nome,font=F)
        desenho.text((direcao*256+(256-caixa[2]+caixa[0])//2,15),nome,font=F,fill='white')
    vistas.save(P/'roupas_corrigidas_vistas.png')
    contato=Image.new('RGB',(1728,1008),'#58645f')
    quadros=[]
    for q in range(12):
        quadro=Image.new('RGB',(512,632),'#58645f')
        for direcao,nome in enumerate(['FRENTE','DIREITA','COSTAS','ESQUERDA']):
            im=recorte(f'vestido_correr_{direcao}_{q:02d}.png')
            pequeno=im.resize((128,146),Image.Resampling.LANCZOS)
            contato.paste(pequeno,(q*144+8,direcao*252+50),pequeno)
            ImageDraw.Draw(contato).text((q*144+6,direcao*252+15),f'{nome} {q+1:02d}',font=ImageFont.load_default(size=13),fill='white')
            grande=im.resize((256,292),Image.Resampling.LANCZOS)
            x,y=(direcao%2)*256,(direcao//2)*316
            quadro.paste(grande,(x,y+24),grande)
            ImageDraw.Draw(quadro).text((x+75,y+3),nome,font=F,fill='white')
        quadros.append(quadro)
    contato.save(P/'roupas_corrida_quadros.png')
    duracao=round(dados['duracao_corrida']*1000/12/10)*10
    quadros[0].save(P/'roupas_corrida.gif',save_all=True,append_images=quadros[1:],duration=duracao,loop=0,disposal=2)
    print(f"{dados['verificacoes']} verificações sem falhas; seis combinações e 48 amostras reais de corrida.")
if __name__=='__main__':exportar()
