#!/usr/bin/env python3
"""Monta comparações com as capturas do Godot; o efeito é aplicado pelo motor."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import json
R=Path(__file__).resolve().parents[3]
P=R/'arte/previas/personagens/base_3d/teste_pixel_art'
F=ImageFont.load_default(size=17)

def quadro(modo,nome):
    im=Image.open(P/f'{modo}_{nome}.png').convert('RGBA')
    escala=im.width/160
    im=im.crop(tuple(round(v*escala) for v in (48,43,112,116)))
    return im.resize((256,292),Image.Resampling.NEAREST if modo.endswith('pixel') else Image.Resampling.LANCZOS)

def validar_paleta():
    fonte=json.loads((R/'arte/fontes/personagens/base_3d/paleta_pixel_art.json').read_text())
    cores={tuple(bytes.fromhex(c[1:])) for c in fonte['cores']}
    usadas=set()
    arquivos=sorted(P.glob('pixel_parado_*.png'))+sorted(P.glob('pixel_correr_*.png'))
    assert len(arquivos)==52, 'Faltam capturas nativas das quatro direções.'
    for arquivo in arquivos:
        im=Image.open(arquivo).convert('RGBA')
        for quantidade,cor in im.getcolors(maxcolors=im.width*im.height):
            assert cor[3] in (0,255), f'Halo alfa em {arquivo.name}: {cor}'
            if cor[3]==0:continue
            assert cor[:3] in cores, f'Cor fora da paleta em {arquivo.name}: {cor}'
            usadas.add(cor[:3])
    dados={'definidas':len(cores),'usadas':len(usadas),'quadros':len(arquivos),'fora_da_paleta':0}
    (P/'validacao_paleta.json').write_text(json.dumps(dados,indent=2)+'\n')
    return dados

def exportar():
    validacao=validar_paleta()
    dados=json.loads((P/'revisao.json').read_text())
    poster=Image.new('RGB',(1024,360),'#58645f');d=ImageDraw.Draw(poster)
    for i,(modo,direcao,titulo) in enumerate([('suave',0,'3D SUAVE / FRENTE'),('pixel',0,'PIXEL / FRENTE'),('suave',1,'3D SUAVE / PERFIL'),('pixel',1,'PIXEL / PERFIL')]):
        im=quadro(modo,f'parado_{direcao}')
        poster.paste(im,(i*256,48),im)
        caixa=d.textbbox((0,0),titulo,font=F)
        d.text((i*256+(256-caixa[2]+caixa[0])//2,15),titulo,font=F,fill='white')
    poster.save(P/'comparacao.png')
    frames=[]
    for q in range(12):
        frame=Image.new('RGB',(512,340),'#58645f');d=ImageDraw.Draw(frame)
        for i,modo in enumerate(['suave','pixel']):
            im=quadro(modo,f'correr_1_{q:02d}');frame.paste(im,(i*256,40),im)
            d.text((i*256+85,10),'3D SUAVE' if i==0 else 'PIXEL',font=F,fill='white')
        frames.append(frame)
    duracao=dados['duracao_corrida']
    tempos=[round((q+1)*duracao*100/12)*10-round(q*duracao*100/12)*10 for q in range(12)]
    frames[0].save(P/'corrida_comparacao.gif',save_all=True,append_images=frames[1:],duration=tempos,loop=0,disposal=2)
    contato=Image.new('RGB',(1728,1008),'#58645f')
    for direcao in range(4):
        for q in range(12):
            im=quadro('pixel',f'correr_{direcao}_{q:02d}').resize((128,146),Image.Resampling.NEAREST)
            contato.paste(im,(q*144+8,direcao*252+50),im)
            ImageDraw.Draw(contato).text((q*144+8,direcao*252+15),f'{direcao} / {q+1:02d}',font=F,fill='white')
    contato.save(P/'pixel_corrida_quadros.png')
    if (P/'antes_paleta/pixel_parado_0.png').exists():
        poster=Image.new('RGB',(1024,360),'#58645f');d=ImageDraw.Draw(poster)
        for i,(modo,direcao,titulo) in enumerate([('antes_paleta/pixel',0,'ANTES / FRENTE'),('pixel',0,'PALETA / FRENTE'),('antes_paleta/pixel',1,'ANTES / PERFIL'),('pixel',1,'PALETA / PERFIL')]):
            im=quadro(modo,f'parado_{direcao}');poster.paste(im,(i*256,48),im)
            caixa=d.textbbox((0,0),titulo,font=F)
            d.text((i*256+(256-caixa[2]+caixa[0])//2,15),titulo,font=F,fill='white')
        poster.save(P/'paleta_comparacao.png')
        frames=[]
        for q in range(12):
            frame=Image.new('RGB',(512,340),'#58645f');d=ImageDraw.Draw(frame)
            for i,(modo,titulo) in enumerate([('antes_paleta/pixel','ANTES'),('pixel','PALETA PIXEL')]):
                im=quadro(modo,f'correr_1_{q:02d}');frame.paste(im,(i*256,40),im)
                caixa=d.textbbox((0,0),titulo,font=F)
                d.text((i*256+(256-caixa[2]+caixa[0])//2,10),titulo,font=F,fill='white')
            frames.append(frame)
        frames[0].save(P/'paleta_corrida.gif',save_all=True,append_images=frames[1:],duration=tempos,loop=0,disposal=2)
    print(f"Paleta: {validacao['usadas']}/{validacao['definidas']} cores usadas em {validacao['quadros']} capturas, sem cores externas nem halos alfa.")
    print('Comparação, GIF de corrida e quatro direções exportados das capturas do motor.')
if __name__=='__main__':exportar()
