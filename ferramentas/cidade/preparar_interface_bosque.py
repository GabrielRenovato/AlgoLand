#!/usr/bin/env python3
"""Prepara o atlas gerado para recortes nativos e bordas de nove partes."""
from pathlib import Path
import json
from PIL import Image
RAIZ = Path(__file__).resolve().parents[2]
DESTINO = RAIZ/'assets/ui/bosque'
ORIGEM = RAIZ/'arte/fontes/interface_bosque/atlas_original.png'
fonte = Image.open(ORIGEM).convert('RGBA')
nomes = ['painel_titulo','painel','pergaminho','slot','botao','botao_hover',
         'botao_pressionado','botao_desabilitado','primario','primario_hover',
         'primario_pressionado','campo']
xs = [(0,375),(375,740),(740,1100),(1100,1448)]
ys = [(140,520),(540,740),(760,960)]
recortes = {}
for i,nome in enumerate(nomes):
    xa,xb=xs[i%4]; ya,yb=ys[i//4]
    recorte=fonte.crop((xa,ya,xb,yb))
    bbox=recorte.getchannel('A').point(lambda a:255 if a>150 else 0).getbbox()
    recorte=recorte.crop(bbox)
    tamanho=(24,24) if nome=='slot' else ((48,48) if i<3 else (48,20))
    recorte=recorte.resize(tamanho,Image.Resampling.NEAREST)
    # Quantização de paleta e alpha rígido: o recurso nativo não usa pixels suavizados.
    alpha=recorte.getchannel('A').point(lambda a:255 if a>=128 else 0)
    recorte=recorte.convert('RGB').quantize(colors=18,method=Image.Quantize.MEDIANCUT).convert('RGBA')
    recorte.putalpha(alpha)
    if nome == 'painel_titulo':
        # A faixa completa cabe nos 16 pixels reservados no contrato dos painéis.
        topo=recorte.crop((0,0,48,18)).resize((48,16),Image.Resampling.NEAREST)
        corpo=recorte.crop((0,18,48,48)).resize((48,32),Image.Resampling.NEAREST)
        recorte.paste(topo,(0,0)); recorte.paste(corpo,(0,16))
    recorte.save(DESTINO/(nome+'.png'))
    recortes[nome]={'tamanho':tamanho,'celula_fonte':[xa,ya,xb,yb],'bbox':bbox}
# Folha de compatibilidade: apenas o painel usado pelas telas. O cadeado é um recurso separado.
folha=Image.new('RGBA',(256,128))
folha.paste(Image.open(DESTINO/'painel_titulo.png'),(96,64))
folha.paste(Image.open(DESTINO/'botao.png').resize((48,16),Image.Resampling.NEAREST),(192,0))
folha.save(DESTINO/'paineis.png')
contrato={'tipo':'sprites de interface, sem cenário sazonal','referencias':['assets/cenario/cidade/decoracao/mobiliario/caixas_legumes.png','arte/previas/forja/dialogo_ivo.png'],'estilo':'madeira quente, bronze, pergaminho e verde sálvia; clusters nativos sem suavização','grade':'painéis 48x48, botões48x20, slots24x24; bordas nove partes','encaixe':'UI frontal, pivô superior esquerdo, sem colisão; margens preservadas pelos StyleBoxTexture','variantes':nomes,'fonte':str(ORIGEM.relative_to(RAIZ)),'destino':str(DESTINO.relative_to(RAIZ)),'recortes':recortes,'integracao':'temas globais/menu/sidebar, telas, criação, diálogo, slots e HUD','gerador':'image_gen: atlas de 4x3 com formas vazias, cantos madeira/bronze e centros legíveis'}
(RAIZ/'arte/fontes/interface_bosque/geracao.json').write_text(json.dumps(contrato,ensure_ascii=False,indent=2)+'\n')
previa=Image.new('RGBA',(256,192),(25,20,18,255))
for i,nome in enumerate(nomes):
    im=Image.open(DESTINO/(nome+'.png')); previa.paste(im,(i%4*64+8,i//4*64+8),im)
previa.resize((1024,768),Image.Resampling.NEAREST).save(RAIZ/'arte/previas/interface_bosque/sprites.png')
# Barras: três segmentos de 16x8, compartilhados pela vida, estamina e energia.
barras=Image.open(RAIZ/'arte/fontes/interface_bosque/barras_original.png').convert('RGBA')
for nome,limites in [('vida',(280,510)),('vazia',(510,750)),('neutra',(750,990))]:
    recorte=barras.crop((0,limites[0],barras.width,limites[1]))
    bbox=recorte.getchannel('A').point(lambda a:255 if a>150 else 0).getbbox()
    recorte=recorte.crop(bbox).resize((48,8),Image.Resampling.NEAREST)
    recorte.putalpha(recorte.getchannel('A').point(lambda a:255 if a>=128 else 0))
    recorte.save(DESTINO/f'barra_{nome}.png')
    for i in range(3):recorte.crop((16*i,0,16*(i+1),8)).save(DESTINO/f'barra_{nome}_{i}.png')
contrato['barras']={'fonte':'arte/fontes/interface_bosque/barras_original.png','quadro':[48,8],'segmentos':3,'variantes':['vida','vazia','neutra'],'integracao':'codigo/ui/desenho_barra.gd; energia reutiliza as peças giradas'}
(RAIZ/'arte/fontes/interface_bosque/geracao.json').write_text(json.dumps(contrato,ensure_ascii=False,indent=2)+'\n')
