#!/usr/bin/env python3
"""Recorta peças independentes sem ampliar a arte e gera máscaras de transição 16px/64px."""
from pathlib import Path
import argparse,json
from PIL import Image,ImageFilter,ImageChops
RAIZ=Path(__file__).resolve().parents[2]
ESTACOES=['primavera','verao','outono','inverno']
GRUPOS={'arvores':['carvalho','jovem','pinheiro','arbustos'],'natureza':['pedras','tronco','toco','raizes'],'ruinas':['muro','pilar','arco','resgate'],'chao':['grama','terra_raizes','pedra','agua'],'equipamentos':['poste_resgate','bau_resgate','espada_chao','escudo_chao'],'complementos':['ponte','estela','broto','suprimentos']}
# Recortes seguem os vãos reais entre silhuetas, sem cortar raízes que passam do meio do atlas.
RECORTES={'arvores':[(0,0,.542,.510),(.542,0,1,.510),(0,.510,.494,1),(.494,.510,1,1)],'natureza':[(0,0,.45,.455),(.45,0,1,.455),(0,.455,.44,1),(.44,.455,1,1)],'ruinas':[(0,0,.57,.485),(.57,0,1,.485),(0,.485,.517,1),(.517,.485,1,1)],'chao':[(0,0,.5,.5),(.5,0,1,.5),(0,.5,.5,1),(.5,.5,1,1)],'equipamentos':[(0,0,.5,.54),(.5,0,1,.54),(0,.54,.5,1),(.5,.54,1,1)],'complementos':[(0,0,.5,.51),(.47,0,1,.51),(0,.51,.49,1),(.49,.51,1,1)]}

def separar_peca(quadro):
    """Separa o componente principal dos restos da célula vizinha, sem reamostrar a arte."""
    alfa=quadro.getchannel('A');grade=alfa.copy();grade.thumbnail((160,160))
    w,h=grade.size;ativos=bytearray(v>32 for v in grade.tobytes());maior=[]
    for inicio in range(len(ativos)):
        if not ativos[inicio]:continue
        fila=[inicio];ativos[inicio]=0;componente=[]
        while fila:
            k=fila.pop();componente.append(k)
            for vizinho in [k-w,k+w,k-1 if k%w else -1,k+1 if k%w<w-1 else -1]:
                if 0<=vizinho<len(ativos) and ativos[vizinho]:ativos[vizinho]=0;fila.append(vizinho)
        if len(componente)>len(maior):maior=componente
    mascara=Image.new('L',(w,h));dados=bytearray(w*h)
    for k in maior:dados[k]=255
    mascara.frombytes(bytes(dados))
    # A margem inclui contornos semitransparentes e pequenos detalhes da própria peça.
    mascara=mascara.resize(quadro.size,Image.Resampling.NEAREST).filter(ImageFilter.MaxFilter(9))
    quadro.putalpha(ImageChops.multiply(alfa,mascara))
    return quadro

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--parcial',action='store_true');args=parser.parse_args()
    destino=RAIZ/'assets/cenario/campanha/clareiras_modulares';destino.mkdir(parents=True,exist_ok=True)
    pecas={}
    for grupo,nomes in GRUPOS.items():
        for estacao in ESTACOES:
            fonte=RAIZ/'arte/fontes/campanha/clareiras_modulares'/grupo/(estacao+'.png')
            if not fonte.exists():
                if args.parcial:continue
                raise FileNotFoundError(fonte)
            imagem=Image.open(fonte).convert('RGBA');w,h=imagem.size
            pasta=destino/estacao;pasta.mkdir(parents=True,exist_ok=True)
            for i,nome in enumerate(nomes):
                r=RECORTES[grupo][i];quadro=imagem.crop((round(r[0]*w),round(r[1]*h),round(r[2]*w),round(r[3]*h)))
                if grupo=='complementos' and i<2:quadro=separar_peca(quadro)
                quadro.save(pasta/(nome+'.png'))
                bbox=quadro.getchannel('A').point(lambda a:255 if a>100 else 0).getbbox()
                if bbox is None:raise ValueError('Peça vazia: '+nome)
                item=pecas.setdefault(nome,{'grupo':grupo,'variantes':{}})
                item['variantes'][estacao]={'textura':f'res://assets/cenario/campanha/clareiras_modulares/{estacao}/{nome}.png','quadro':list(quadro.size),'pivo':[(bbox[0]+bbox[2])/2,bbox[3]-1],'largura_visivel':bbox[2]-bbox[0]}
    (destino/'pecas.json').write_text(json.dumps(pecas,ensure_ascii=False,indent=2)+'\n')
    # R grama, G terra, B pedra; água = 1-R-G-B. Alpha opaco preserva a máscara na importação.
    atlas=Image.new('RGBA',(1024,1024))
    for indice in range(256):
        pixels=[]
        for y in range(64):
            for x in range(64):
                u=(x+.5)/64;v=(y+.5)/64
                pesos=[(1-u)*(1-v),u*(1-v),(1-u)*v,u*v]
                canais=[0.,0.,0.,0.]
                for canto in range(4):canais[(indice>>(canto*2))&3]+=pesos[canto]
                canais=[max(peso-.18,0)**2 for peso in canais];total=max(sum(canais),.001)
                pixels.append(tuple(round(peso/total*255) for peso in canais[:3])+(255,))
        quadro=Image.new('RGBA',(64,64));quadro.putdata(pixels)
        atlas.paste(quadro,(indice%16*64,indice//16*64))
    atlas.save(destino/'mascaras.png')
    linhas=['[gd_resource type="TileSet" load_steps=3 format=3]','[ext_resource type="Texture2D" path="res://assets/cenario/campanha/clareiras_modulares/mascaras.png" id="1"]','[sub_resource type="TileSetAtlasSource" id="Cantos"]','resource_name = "GRAMA • TERRA • PEDRA • AGUA"','texture = ExtResource("1")','texture_region_size = Vector2i(64, 64)']
    linhas += [f'{x}:{y}/0 = 0' for y in range(16) for x in range(16)]
    linhas += ['[resource]','tile_size = Vector2i(64, 64)','sources/0 = SubResource("Cantos")']
    (destino/'tileset.tres').write_text('\n'.join(linhas)+'\n')

if __name__=='__main__':main()
