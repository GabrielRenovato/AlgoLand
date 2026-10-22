"""Enseada pintada4×: conserva plantas, costa, bases e áreas de interação."""
from pathlib import Path
import sys
import json
from PIL import Image, ImageEnhance

RAIZ = Path(__file__).resolve().parents[2]
sys.path.insert(0,str(RAIZ/'ferramentas/cidade'))
sys.path.insert(0,str(RAIZ/'ferramentas/fazenda'))
from preparar_complementos import salvar, recortar
from preparar_chao_detalhado import periodizar
from preparar_natureza_detalhada import neve_apoios

FONTES=RAIZ/'arte/fontes/praia/padrao_novo'
SAIDA=RAIZ/'assets/cenario/praia/detalhada'
NOMES=['primavera','verao','outono','inverno']


def sazonal(im,e,neve=False):
    """Palmeiras perenes: inverno esfria as folhas sem torná-las caducas."""
    im=im.copy()
    fatores=[(1,1,1),(1.025,1.01,.98),(.98,.97,.94),(.88,.94,1.02)][e]
    canais=list(im.split())
    for c,f in enumerate(fatores):canais[c]=canais[c].point(lambda v:min(255,round(v*f)))
    im=Image.merge(im.mode,canais)
    if e==3 and neve:im=neve_apoios(im,3)
    return im


def encaixar(im,tamanho,raiz=.5,alvo=None):
    # A copa nunca determina a linha dos pés; raiz e base física são explícitas.
    escala=min((tamanho[0]-4)/im.width,(tamanho[1]-2)/im.height)
    if alvo is not None:
        escala=min(escala,(alvo-2)/(im.width*raiz),(tamanho[0]-alvo-2)/(im.width*(1-raiz)))
    im=im.resize((round(im.width*escala),round(im.height*escala)),Image.Resampling.LANCZOS)
    x=round((tamanho[0]*.5 if alvo is None else alvo)-raiz*im.width)
    assert x>=0 and x+im.width<=tamanho[0],('Raiz fora do canvas',x,im.size,tamanho)
    out=Image.new('RGBA',tamanho);out.alpha_composite(im,(x,tamanho[1]-im.height))
    return out


def main():
    manifesto={}
    # Tamanhos originais e bases de colisão: palmeiraA +6px; B -18px.
    for nome,w,h,raiz,alvo in [('coqueiro_a',65,88,.77,38.5),('coqueiro_b',63,84,.20,13.5),
                              ('pedras',33,24,.5,None),('madeira',24,15,.5,None),
                              ('capim',25,20,.5,None),('banco',44,26,.5,None),('vasos',16,22,.5,None),
                              ('estrela_mar',16,16,.5,None)]:
        original=recortar(FONTES/(nome+'.png'))
        base=encaixar(original,(w*4,h*4),raiz,None if alvo is None else alvo*4)
        caminhos=[]
        for e,estacao in enumerate(NOMES):
            p=SAIDA/'adornos'/nome/(estacao+'.png')
            salvar(sazonal(base,e,neve=nome in ['pedras','banco','vasos']),p)
            caminhos.append('res://'+str(p.relative_to(RAIZ)))
        manifesto[nome]={'texturas':caminhos,'resolucao':4,'quadros':1,'fps':0,
                         'canvas_logico':[w,h],'offset':[-w/2,-h],
                         'fonte':str((FONTES/(nome+'.png')).relative_to(RAIZ))}
    # Fonte sazonal já aceita na praça: só ajustar à mesma tela do canteiro antigo.
    for nome,categoria in [('canteiro','mobiliario/canteiro')]:
        dados=json.loads((RAIZ/'assets/cenario/cidade/enfeites_detalhados/manifesto.json').read_text())[categoria]
        antigo=Image.open(RAIZ/'assets/cenario/cidade/decoracao/mobiliario/canteiro.png')
        w,h=antigo.size
        caminhos=[]
        for e,estacao in enumerate(NOMES):
            im=Image.open(RAIZ/dados['texturas'][e].removeprefix('res://')).convert('RGBA')
            im=encaixar(im.crop(im.getbbox()),(w*4,h*4))
            p=SAIDA/'adornos'/nome/(estacao+'.png');salvar(im,p);caminhos.append('res://'+str(p.relative_to(RAIZ)))
        manifesto[nome]={'texturas':caminhos,'resolucao':4,'quadros':1,'fps':0,'canvas_logico':[w,h],'offset':[-w/2,-h],
                         'fonte':dados['fonte']}
    # Mesma bancada e suporte pintados da palafita; dimensões físicas preservadas.
    interiores=json.loads((RAIZ/'assets/cenario/cidade/interiores_detalhados/manifesto.json').read_text())
    for nome in ['caixas_peixes','equipamento_pesca']:
        dado=interiores['palafita/'+nome].copy()
        w,h=dado['canvas_logico'];dado['offset']=[-(w//2),-h]
        caminhos=[]
        for e,estacao in enumerate(NOMES):
            base=Image.open(RAIZ/dado['texturas'][0].removeprefix('res://')).convert('RGBA')
            p=SAIDA/'adornos'/nome/(estacao+'.png');salvar(sazonal(base,e,neve=True),p)
            caminhos.append('res://'+str(p.relative_to(RAIZ)))
        dado['texturas']=caminhos;manifesto[nome]=dado
    for nome,fonte in [('areia','areia'),('madeira','madeira_cais')]:
        base=periodizar(Image.open(FONTES/(fonte+'.png')).convert('RGB').resize((512,512),Image.Resampling.LANCZOS)).convert('RGBA')
        for e,estacao in enumerate(NOMES):
            im=sazonal(base,e)
            if nome=='areia':im=ImageEnhance.Contrast(im).enhance(.38)
            if nome=='madeira':im=ImageEnhance.Brightness(im).enhance(.88)
            salvar(im,SAIDA/'materiais'/estacao/(nome+'.png'))
    # A viga e as estacas vêm do mesmo kit estrutural da ponte aceita.
    for e,estacao in enumerate(NOMES):
        apoios=Image.open(RAIZ/f'assets/cenario/cidade/ponte_detalhada/{estacao}/apoios.png').convert('RGBA')
        salvar(apoios,SAIDA/'estrutura'/estacao/'apoios.png')
        salvar(apoios.crop((43,0,109,15)),SAIDA/'estrutura'/estacao/'viga.png')
        salvar(apoios.crop((14,4,38,120)),SAIDA/'estrutura'/estacao/'estaca.png')
        corrimao=Image.open(RAIZ/f'assets/cenario/cidade/ponte_detalhada/{estacao}/corrimao.png').convert('RGBA')
        salvar(corrimao.crop((0,0,12,40)),SAIDA/'estrutura'/estacao/'cabeco.png')
    fachada=recortar(FONTES/'palafita.png')
    # Canvas160×160; soleira80,128 na mesma porta e no mesmo recorte físico.
    fachada=fachada.resize((576,480),Image.Resampling.LANCZOS)
    for e,estacao in enumerate(NOMES):
        im=sazonal(fachada,e)
        if e==3:
            im=neve_apoios(im,8)
        tela=Image.new('RGBA',(640,640));tela.alpha_composite(im,(32,32))
        salvar(tela,SAIDA/'palafita'/(estacao+'.png'))
    manifesto['palafita']={'texturas':['res://'+str((SAIDA/'palafita'/(e+'.png')).relative_to(RAIZ)) for e in NOMES],
                           'resolucao':4,'quadros':1,'fps':0,'canvas_logico':[160,160],'offset':[0,0],
                           'fonte':'arte/fontes/praia/padrao_novo/palafita.png'}
    (SAIDA/'manifesto.json').write_text(json.dumps(manifesto,ensure_ascii=False,indent=2)+'\n')
    print('Praia: onze props e fachada pintados, areia e madeira, quatro estações e apoios da ponte.')


if __name__=='__main__':main()
