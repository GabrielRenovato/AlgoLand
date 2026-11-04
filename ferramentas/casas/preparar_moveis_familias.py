#!/usr/bin/env python3
"""Publica originais transparentes sem repintar; registra escala e pivô por estação."""
from pathlib import Path
import json
import shutil
import subprocess
from PIL import Image
RAIZ=Path(__file__).resolve().parents[2]
ESTACOES=['primavera','verao','outono','inverno']
PECAS=[('mara','balcao_hospedaria',104,'mara'),('cora','bancada_padeiro',80,'cora'),('rosa','bancada_ervas',72,'rosa'),('cora','vitrine_padaria',144,'cora_vitrine')]

def main():
    manifesto={}
    for casa,id,largura,origem in PECAS:
        pasta=RAIZ/'assets/cenario/cidade/interiores_detalhados/familias'/id
        pasta.mkdir(parents=True,exist_ok=True)
        entrada=dict(casa=casa,canvas_logico=[largura,80],texturas=[],quadros=1,fps=0,variantes=[],origem='image_gen nativa; sprite independente; sem Mana Seed/Tiny')
        for indice,estacao in enumerate(ESTACOES):
            fonte=RAIZ/'arte/fontes/cidade/moveis_familias'/origem/(estacao+'.png')
            if id=='vitrine_padaria':
                subprocess.run(['magick',str(fonte.parent/'atlas.png'),'-crop',f'1024x384+0+{indice*384}','+repage',str(fonte)],check=True)
            im=Image.open(fonte).convert('RGBA')
            usado=im.getchannel('A').point(lambda a:255 if a>128 else 0).getbbox()
            assert usado and all(im.getpixel(p)[3]==0 for p in [(0,0),(im.width-1,0),(0,im.height-1),(im.width-1,im.height-1)])
            destino=pasta/(estacao+'.png')
            shutil.copyfile(fonte,destino)
            entrada['texturas'].append('res://'+str(destino.relative_to(RAIZ)))
            entrada['variantes'].append(dict(escala=largura/(usado[2]-usado[0]),pivo=[(usado[0]+usado[2])/2,usado[3]],usado=list(usado),canvas=list(im.size)))
        manifesto['familias/'+id]=entrada
    destino=RAIZ/'codigo/cidade/familias/moveis_exclusivos.json'
    destino.write_text(json.dumps(manifesto,ensure_ascii=False,indent=2)+'\n')
    print('4 móveis exclusivos / 16 texturas; transparência, escala e pivôs registrados.')

if __name__=='__main__':main()
