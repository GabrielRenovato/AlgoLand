#!/usr/bin/env python3
"""Empacota elmos nativos para edição exata no PixelLab, sem mudar outros slots."""
import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image

RAIZ = Path(__file__).resolve().parents[2]
IDS = ['carrasco', 'cavaleiro_rubro', 'cavalheiro', 'sentinela', 'batedor',
       'guardiao_geada', 'templario_solar', 'arauto_trovao', 'guardiao_esmeralda', 'soberano_astral']
ACOES = json.loads((RAIZ/'assets/personagens/raven_fantasy/camadas/acoes.json').read_text())
PAGINAS = {'andar':'correr','fazenda':'enxada','forja':'forjar','sentado':'sentado',
           'espada':'espada','lanca':'lanca','reacao_um_mao':'ferido',
           'reacao_lanca':'ferido','reacao_arco':'ferido','arco_p2':'parado','arco_p3':'arco'}

def hash_arquivo(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def pasta_fonte(id): return RAIZ/'arte/fontes/armaduras'/id/'contorno_pixellab'
def pasta_set(id): return RAIZ/'assets/personagens/conjuntos'/id

def preparar(id):
    pasta = pasta_fonte(id); pasta.mkdir(parents=True, exist_ok=True)
    raiz = pasta_set(id)
    entradas = [raiz/'raven_elmo.png'] + [raiz/'raven_elmo'/f'{a}.png' for a in ['correr','plantar','colher']]
    itens = []; fontes = {}
    for arquivo in entradas:
        im = Image.open(arquivo).convert('RGBA')
        nome = str(arquivo.relative_to(raiz))
        fontes[nome] = hash_arquivo(arquivo)
        im.save(pasta/arquivo.name.replace('.png','_antes.png'))
        for y in range(0,im.height,80):
            for x in range(0,im.width,80):
                celula = im.crop((x,y,x+80,y+80)); bbox = celula.getbbox()
                if not bbox: continue
                w,h = bbox[2]-bbox[0],bbox[3]-bbox[1]
                assert w <= 22 and h <= 22, (id, nome, bbox)
                itens.append({'arquivo':nome, 'celula':[x,y], 'bbox':list(bbox), 'imagem':celula.crop(bbox)})
    unicos = {}; regioes = []; posicoes=[]
    for item in itens:
        im = item.pop('imagem'); w,h = im.size
        chave=(im.size,im.tobytes())
        if chave in unicos:
            item['destino']=unicos[chave]
            continue
        i=len(unicos)
        px,py = (i%32)*24+(24-w)//2,(i//32)*24+(24-h)//2
        item['destino']=[px,py];unicos[chave]=[px,py];posicoes.append((im,(px,py)))
        # A borda extra vinha só dos dois terços inferiores da calota. Preserva
        # cristas/chifres finos; nas quedas laterais a mesma região gira com ela.
        if w > h*1.2:
            direita = (item['celula'][1]//80)%4 == 1
            regioes.append([px if direita else px+w//3,py,px+(2*w)//3 if direita else px+w-1,py+h-1])
        else: regioes.append([px,py+h//3,px+w-1,py+h-1])
    folha = Image.new('RGBA',(768,24*((len(unicos)+31)//32)))
    for im,posicao in posicoes: folha.paste(im,posicao)
    folha.save(pasta/'elmos_antes.png')
    manifesto = RAIZ/('ferramentas/armaduras/modelos/carrasco.json' if id=='carrasco' else f'ferramentas/armaduras/em_preparacao/{id}/manifesto.json')
    config = json.loads(manifesto.read_text()); paleta=config['paleta']
    mudancas = []
    if config['recortes'].get('borda_calota') == 1:
        for i,regiao in enumerate(regioes):
            mudancas.append({'operation':'select_mask','layer':'image','frames':[1],
                'name':'calotas','combine':'replace' if i==0 else 'add',
                'selector':{'kind':'rectangle','region':regiao},'reason':'Preservar adornos finos fora da calota.'})
        mudancas.append({'operation':'outline','mode':'erase','layer':'image','frames':[1],
            'mask':'calotas','colors':['#'+paleta[0]+'ff'],'width':1,'connectivity':8,
            'reason':'Retirar somente a borda escura adicional da calota; preservar o desenho anterior.'})
        mudancas.append({'operation':'outline','mode':'recolor','layer':'image','frames':[1],
            'mask':'calotas','colors':['#'+paleta[0]+'ff'],'color':'#'+paleta[1]+'ff',
            'width':2,'connectivity':8,'reason':'Suavizar o contorno restante sem recolorir o visor interior.'})
    else:
        mudancas.append({'operation':'outline','mode':'recolor','layer':'image','frames':[1],
            'colors':['#'+paleta[0]+'ff'],'color':'#'+paleta[1]+'ff','width':1,'connectivity':8,
            'reason':'Suavizar apenas o contorno externo original, mantendo silhueta e detalhes.'})
    (pasta/'edicao.json').write_text(json.dumps(mudancas,ensure_ascii=False,indent=2)+'\n')
    dados={'fontes':fontes,'itens':itens,'paleta':paleta,'outros_slots':{str(p.relative_to(raiz)):hash_arquivo(p)
        for parte in ['peitoral','luvas','botas'] for p in [raiz/f'raven_{parte}.png',*(raiz/f'raven_{parte}').glob('*.png'),*(raiz/parte).glob('*.png')]}}
    (pasta/'encaixes.json').write_text(json.dumps(dados,ensure_ascii=False,indent=2)+'\n')
    print(id,len(itens),'poses /',len(unicos),'elmos únicos, sem redimensionamento',folha.size)

def aplicar(id, resultado):
    pasta = pasta_fonte(id); raiz = pasta_set(id)
    dados = json.loads((pasta/'encaixes.json').read_text()); corrigida = Image.open(resultado).convert('RGBA')
    assert corrigida.size == Image.open(pasta/'elmos_antes.png').size
    imagens={}
    for nome,h in dados['fontes'].items():
        assert hash_arquivo(raiz/nome)==h, 'Fonte mudou: '+nome
        imagens[nome]=Image.open(raiz/nome).convert('RGBA')
    for item in dados['itens']:
        x,y=item['celula']; bx,by,ex,ey=item['bbox']; px,py=item['destino']
        recorte=corrigida.crop((px,py,px+ex-bx,py+ey-by))
        imagens[item['arquivo']].paste(recorte,(x+bx,y+by))
    # Cabeça opaca precisa continuar cobrindo a pele nas poses. O validador
    # identifica qualquer recorte que precise de um reparo pontual no PixelLab.
    for nome,im in imagens.items():
        im.save(raiz/nome)
        im.save(pasta/(Path(nome).stem+'_depois.png'))
    atlas = imagens['raven_elmo.png']
    for i,acao in enumerate(ACOES):
        if acao not in ['correr','plantar','colher']:
            atlas.crop((0,i*320,320,(i+1)*320)).save(raiz/'raven_elmo'/f'{acao}.png')
    for pagina,acao in PAGINAS.items():
        folha=Image.new('RGBA',(512,512))
        for d in range(4):
            for q in range(8):
                sprite=atlas.crop(((q%4)*80+8,ACOES.index(acao)*320+d*80+4,(q%4)*80+72,ACOES.index(acao)*320+d*80+68))
                for bloco in [0,4]: folha.paste(sprite,(q*64,([0,2,1,3][d]+bloco)*64))
        folha.save(raiz/'elmo'/f'{pagina}.png')
        for parte in ['peitoral','luvas','botas']:
            folha=Image.alpha_composite(folha,Image.open(raiz/parte/f'{pagina}.png').convert('RGBA'))
        folha.save(raiz/f'{pagina}.png')
    for nome,h in dados['outros_slots'].items(): assert hash_arquivo(raiz/nome)==h, 'Outra peça alterada: '+nome
    print(id,'elmos aplicados; peitoral, luvas e botas idênticos byte a byte')

def reparos(id, resultado):
    """Propõe ao PixelLab pixels de contorno que ainda precisam cobrir a cabeça."""
    pasta=pasta_fonte(id); dados=json.loads((pasta/'encaixes.json').read_text())
    corrigida=Image.open(resultado).convert('RGBA')
    antes=Image.open(pasta/'elmos_antes.png').convert('RGBA')
    corpos={
        'raven_elmo.png':RAIZ/'assets/personagens/raven_fantasy/camadas/corpo_0.png',
        'raven_elmo/correr.png':RAIZ/'assets/personagens/raven_fantasy/corrida_mana_seed/corpo_0.png',
        **{f'raven_elmo/{a}.png':RAIZ/f'assets/personagens/raven_fantasy/acoes_fazenda/{a}/corpo_0.png' for a in ['plantar','colher']}}
    corpos={n:Image.open(p).convert('RGBA') for n,p in corpos.items()}
    pixels={}
    for item in dados['itens']:
        x,y=item['celula']; bx,by,ex,ey=item['bbox']; px,py=item['destino']
        for dy in range(ey-by):
            for dx in range(ex-bx):
                p=px+dx,py+dy
                if antes.getpixel(p)[3]>127 and corrigida.getpixel(p)[3]==0 and corpos[item['arquivo']].getpixel((x+bx+dx,y+by+dy))[3]>127:
                    pixels[p]=[*p,'#'+''.join(f'{v:02x}' for v in corrigida.getpixel(p)),'#'+dados['paleta'][1]+'ff']
    mudancas=[] if not pixels else [{'operation':'patch_pixels','layer':'image','frames':[1],
        'pixels':list(pixels.values()),'reason':'Preservar cobertura da cabeça nativa com uma linha suave de um pixel nas bordas necessárias.'}]
    (pasta/'reparos.json').write_text(json.dumps(mudancas,ensure_ascii=False,indent=2)+'\n')
    print(id,len(pixels),'pixels de cobertura propostos para reparo no PixelLab')

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('acao',choices=['preparar','aplicar','reparos']);p.add_argument('id',choices=IDS+['todos']);p.add_argument('resultado',nargs='?');a=p.parse_args()
    for id in IDS if a.id=='todos' else [a.id]:
        if a.acao=='preparar': preparar(id)
        elif a.acao=='aplicar': aplicar(id,Path(a.resultado))
        else: reparos(id,Path(a.resultado))
