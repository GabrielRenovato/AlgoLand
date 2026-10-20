"""Recorta a folha sazonal própria na grade lógica e registra os encaixes do motor."""
from pathlib import Path
import json
from PIL import Image

RAIZ = Path(__file__).resolve().parents[2]
FONTE = RAIZ/'arte/fontes/cidade/carpintaria'
PASTA = RAIZ/'assets/cenario/cidade/ambientes/fachada/carpintaria'
ESTACOES = ['primavera','verao','outono','inverno']

def preparar():
    original = Image.open(FONTE/'estacoes.png').convert('RGBA')
    PASTA.mkdir(parents=True,exist_ok=True)
    caminhos=[]
    for i,estacao in enumerate(ESTACOES):
        x,y=i%2*original.width//2,i//2*original.height//2
        quadro=original.crop((x,y,x+original.width//2,y+original.height//2)).resize((192,128),Image.Resampling.NEAREST)
        quadro.putalpha(quadro.getchannel('A').point(lambda a: 255 if a>=128 else 0))
        destino=PASTA/(estacao+'.png');quadro.save(destino)
        caminhos.append('res://'+str(destino.relative_to(RAIZ)))
        if i==0:
            quadro.save(RAIZ/'assets/cenario/cidade/casas/exterior/carpintaria.png')
            mascara=Image.new('RGBA',quadro.size,(255,255,255,0));mascara.putalpha(quadro.getchannel('A'))
            mascara.save(RAIZ/'assets/cenario/cidade/sombras/casas/carpintaria.png')
    p=RAIZ/'assets/cenario/cidade/ambientes/manifesto.json';dados=json.loads(p.read_text())
    dados['fachada/carpintaria']={'texturas':caminhos,'quadros':1,'fps':0,'usado':[4,2,186,117],'escala_origem':1.0}
    p.write_text(json.dumps(dados,ensure_ascii=False,indent=1)+'\n')
    p=RAIZ/'assets/cenario/cidade/casas/exteriores.json';dados=json.loads(p.read_text())
    dados['carpintaria']={'ancora':[80,116],'usado':[4,2,186,117],'colisoes':[[-70,-23,98,6]],'chamine':[38,-111],'janelas':[[-40,-28],[0,-69],[34,-28]],'placa':{'texto':'CARPINTARIA','pos':[0,30],'poste':False}}
    p.write_text(json.dumps(dados,ensure_ascii=False,indent=1)+'\n')
    contrato={'tipo':'casa familiar com oficina','referencia':'assets/cenario/cidade/casas/exterior/casa_bento.png','fonte':'estacoes.png','folha':[1536,1024],'grade_folha':[2,2],'quadro_fonte':[768,512],'quadro_logico':[192,128],'escala_integracao':0.25,'pivo_porta':[80,116],'base_mapa':json.loads((RAIZ/'codigo/cidade/layout_vila.json').read_text())['predios']['carpintaria']['base'],'estacoes':ESTACOES,'colisoes':[[-70,-23,98,6]],'integracao':'casa_exterior.gd e DetalheAmbiente; planta e portas em layout_vila.json'}
    (FONTE/'manifesto.json').write_text(json.dumps(contrato,ensure_ascii=False,indent=2)+'\n')

if __name__=='__main__': preparar()
