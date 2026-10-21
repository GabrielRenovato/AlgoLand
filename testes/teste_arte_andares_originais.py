"""Audita fontes e detecta tiles comerciais copiados, mesmo após recoloração."""
from pathlib import Path
import json
import re
import sys
from PIL import Image

RAIZ=Path(__file__).resolve().parents[1]


def desenhos(im):
    im=im.convert('RGBA')
    for y in range(0,im.height-15,16):
        for x in range(0,im.width-15,16):
            cores={};indices=[];opacos=0
            for r,g,b,a in im.crop((x,y,x+16,y+16)).get_flattened_data():
                cor=(r,g,b) if a>=128 else None
                if cor is not None:opacos+=1
                if cor not in cores:cores[cor]=len(cores)
                indices.append(cores[cor])
            # Não acusa fundos planos, máscaras ou coincidências geométricas simples.
            if len(cores)>=5 and opacos>=128:yield tuple(indices)


fontes=list((RAIZ/'assets/cenario/Seasonal Forest').glob('seasonal sample (*.png'))
fontes+=list((RAIZ/'arte/fontes/fendas/gentle_forest').glob('gentle forest v*.png'))
legados={d for p in fontes for d in desenhos(Image.open(p))}
assert legados,'fontes de auditoria ausentes'
vistos=set()
for andar in range(1,12):
    cena=RAIZ/f'cenas/fendas/terreno_{andar:02}.tscn'
    texto=cena.read_text()
    caminhos=re.findall(r'\[ext_resource type="Texture2D" path="res://([^"]+)"',texto)
    for caminho in caminhos:
        assert '/substitutos/' in caminho or '/rpgw_caves/' in caminho or caminho.endswith('/oclusao.png'),('textura sem origem auditada',andar,caminho)
        assert (RAIZ/caminho).exists(),('recurso ausente',caminho)
        if '/substitutos/' in caminho and caminho not in vistos:
            vistos.add(caminho)
            assert not set(desenhos(Image.open(RAIZ/caminho)))&legados,('tile comercial copiado/recolorido',andar,caminho)
    for estacao in ['spring','summer','autumn','winter']:
        assert f'substitutos/fendas/andar_{andar:02}/{estacao}.png' in texto,('estação sem atlas próprio',andar,estacao)
    for bloco in re.split(r'\n(?=\[)',texto):
        if bloco.startswith('[node ') and any(f'texture = SubResource("{i}")' in bloco for i in ['Atlas_arbusto_m','Atlas_arbusto_g']):
            raise AssertionError(('arbusto legado ou base invisível',andar))
    assert not any(t in texto for t in ['Seasonal Forest','gentle_forest/','terreno/mana_seed','Starter Pack']),('referência legada',andar)
# Regressão visual: a água não pode preencher o retângulo inteiro de uma célula
# de margem. O oráculo é o campo físico da lagoa, sem ler a máscara exportada.
sys.path.insert(0,str(RAIZ/'ferramentas/arena'))
import gerar_arena as G
from tscn import decodificar_tiles
amostras=0
for andar in [1,2,5,6,8,9,10]:
    p=json.loads((RAIZ/f'codigo/fendas/plantas/andar_{andar:02}.json').read_text())
    lagoa=G.Lagoa();lagoa.lobos=p['lago']['lobos'];lagoa.pe=None
    texto=(RAIZ/f'cenas/fendas/terreno_{andar:02}.tscn').read_text()
    camada=next(b for b in re.split(r'\n(?=\[)',texto) if b.startswith('[node name="Agua"'))
    dados=re.search(r'tile_map_data = (PackedByteArray\([^\n]+\))',camada)
    if not dados:continue
    celulas=decodificar_tiles(dados[1])
    for estacao in ['spring','summer','autumn','winter']:
        im=Image.open(RAIZ/f'assets/cenario/substitutos/fendas/andar_{andar:02}/{estacao}.png')
        for cx,cy,_,ax,ay,_ in celulas:
            if ay<16:continue
            for x,y in [(0,0),(8,0),(0,8),(8,8),(15,15)]:
                d=lagoa.dist(cx*16+x+.5,cy*16+y+.5)
                alfa=im.getpixel((ax*16+x,ay*16+y))[3]
                assert (alfa==0)==(d>=0),('água invade grama ou margem com fresta',andar,estacao,cx,cy,x,y)
                amostras+=1
print(f'ARTE ANDARES: 0 falhas; 11 mapas, quatro estações, {len(vistos)} texturas próprias; {amostras} amostras das margens.')
