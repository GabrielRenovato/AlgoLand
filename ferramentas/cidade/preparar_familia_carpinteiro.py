"""Integra folhas próprias geradas: grade 7×4, pés/rodas alinhados, sem alterar outros NPCs."""
from pathlib import Path
from PIL import Image
import json

RAIZ = Path(__file__).resolve().parents[2]
FONTE = RAIZ/'arte/fontes/npcs/familia_carpinteiro/revisao'
DESTINO = RAIZ/'assets/npcs/cidade'

def preparar():
    caminho = DESTINO/'manifesto.json'
    manifesto = json.loads(caminho.read_text())
    for nome in ['osvaldo','helena','clara']:
        fonte = Image.open(FONTE/f'{nome}.png').convert('RGBA')
        quadros=[]
        for y in range(4):
            for x in range(7):
                im=fonte.crop((x*fonte.width//7,y*fonte.height//4,(x+1)*fonte.width//7,(y+1)*fonte.height//4))
                alpha=im.getchannel('A').point(lambda a: 255 if a>=128 else 0)
                im.putalpha(alpha)
                quadros.append(im.crop(im.getbbox()))
        fator=31/max(im.height for im in quadros)
        folha=Image.new('RGBA',(448,256))
        for i,im in enumerate(quadros):
            im=im.resize((max(1,round(im.width*fator)),max(1,round(im.height*fator))),Image.Resampling.NEAREST)
            folha.alpha_composite(im,(i%7*64+(64-im.width)//2,i//7*64+45-im.height))
        folha.save(DESTINO/f'{nome}.png')
        # A capa compartilhada nunca substitui a cadeira por um corpo em pé.
        folha.save(DESTINO/'capas_chuva'/f'{nome}.png')
        altura_parado = folha.crop((0,0,64,64)).getbbox()
        altura_parado = altura_parado[3]-altura_parado[1]
        manifesto[nome]={'fonte':f'res://arte/fontes/npcs/familia_carpinteiro/revisao/{nome}.png','folha':f'res://assets/npcs/cidade/{nome}.png','grade':[7,4],'quadro':[64,64],'pes_y':45,'altura_parado':altura_parado,'altura_mapa':altura_parado,'escala_mapa':1.0,'direcoes':['baixo','direita','cima','esquerda'],'quadros_andar':6,'folha_chuva':f'res://assets/npcs/cidade/capas_chuva/{nome}.png','traje_chuva':'roupa propria; abrigo na chuva'}
        # Retrato estático próprio: não simula uma animação de boca inexistente.
        quadro=folha.crop((0,0,64,64))
        x0,y0,x1,y1=quadro.getbbox()
        rosto=quadro.crop((x0,y0,x1,min(y0+12,y1)))
        rosto.thumbnail((96,88),Image.Resampling.NEAREST)
        rosto=rosto.resize((round(rosto.width*5),round(rosto.height*5)),Image.Resampling.NEAREST)
        retrato=Image.new('RGBA',(256,128))
        retrato.alpha_composite(rosto,((128-rosto.width)//2,(128-rosto.height)//2));retrato.alpha_composite(rosto,(128+(128-rosto.width)//2,(128-rosto.height)//2))
        retrato.save(RAIZ/'assets/npcs/retratos'/f'{nome}.png')
    caminho.write_text(json.dumps(manifesto,ensure_ascii=False,indent='\t')+'\n')
    preparar_dupla()

def preparar_dupla():
    fonte=Image.open(FONTE/'clara_empurrando_helena.png').convert('RGBA')
    # Âncoras medidas na cadeira, não nos pés da filha nem no limite da dupla.
    ancoras=[(122,235),(158,218),(120,206),(92,184)]
    escala=0.21
    folha=Image.new('RGBA',(7*96,4*96))
    for y in range(4):
        for x in range(7):
            im=fonte.crop((x*fonte.width//7,y*fonte.height//4,(x+1)*fonte.width//7,(y+1)*fonte.height//4))
            im.putalpha(im.getchannel('A').point(lambda a:255 if a>=128 else 0))
            im=im.resize((round(im.width*escala),round(im.height*escala)),Image.Resampling.NEAREST)
            ax,ay=ancoras[y]
            folha.alpha_composite(im,(x*96+48-round(ax*escala),y*96+64-round(ay*escala)))
    folha.save(DESTINO/'clara_empurrando_helena.png')
    contrato={'fonte':'clara_empurrando_helena.png','grade':[7,4],'quadro':[96,96],'ancora_cadeira':[48,64],'ancoras_fonte':ancoras,'escala':escala,'ordem':['baixo','direita','cima','esquerda'],'mae':'sentada com bracos apoiados','filha':'seis fases andando com as maos nos apoios traseiros'}
    (FONTE/'dupla_encaixe.json').write_text(json.dumps(contrato,ensure_ascii=False,indent=2)+'\n')

if __name__ == '__main__': preparar()
