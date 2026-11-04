#!/usr/bin/env python3
"""Plantas e montagem modular; somente materiais próprios detalhados do AlgoLand."""
from pathlib import Path
import json
from xml.sax.saxutils import escape
RAIZ=Path(__file__).resolve().parents[2]

def geo(w,h,porta,sul,areas,janelas):
 return dict(recorte=[0,0,w,h],porta=porta,chao_sul=sul,chegada=[sum(porta)/2,sul-24],saida=[sum(porta)/2,sul+8],areas=[dict(nome=n,retangulo=r,piso=p) for n,r,p in areas]+[dict(nome='Saída',retangulo=[porta[0],sul,porta[1]-porta[0],h-sul],piso='medio')],janelas=janelas)

def mov(chave,x,y,col=None,**extra):
 return dict(chave=chave,x=x,y=y,col=col or [24,12],**extra)
CAMA='interior/casa_bento/cama';BAU='interior/venda/bau';EST='interior/sede/estante';CADEIRA='interior/sede/cadeira';MESA='interior/pousada/mesa';LAREIRA='interior/casa_bento/lareira';LAV='interior/enfermaria/lavatorio';PLANTA='interior/venda/planta';BALCAO='interior/venda/balcao';POCOES='interior/mistica/pocoes';SACOS='interior/venda/sacos';PRAT='interior/pousada/prateleira';BANCO='interior/sede/banco_reuniao'

# A pousada tem ala de hóspedes profunda e um salão de recepção/refeições.
# As portas familiares ficam no corredor dos fundos, fora da recepção.
casas={}
a=[('Quarto da Mara',[32,64,160,144],'claro'),
 ('Quarto do Téo',[224,64,160,144],'claro'),
 ('Hóspedes 1',[480,64,128,192],'claro'),
 ('Hóspedes 2',[640,64,128,192],'claro'),
 ('Passagem',[96,208,48,40],'medio'),('Passagem',[288,208,48,40],'medio'),
 ('Corredor',[96,248,384,48],'medio'),
 ('Corredor',[480,296,288,40],'medio'),
 ('Passagem',[432,248,48,88],'medio'),
 ('Passagem',[520,256,48,40],'medio'),('Passagem',[680,256,48,40],'medio'),
 ('Cozinha da pousada',[32,336,192,128],'escuro'),
 ('Passagem',[96,296,48,40],'medio'),
 ('Recepção e salão',[256,376,512,216],'medio'),
 ('Passagem',[432,336,48,40],'medio'),('Passagem',[224,416,32,48],'medio')]
casas['mara']=dict(nome='Pousada de Mara e Téo',familia=['mara','teo'],
 geometria=geo(800,640,[448,496],592,a,[[40,64],[232,64],[552,64],[704,64],[40,336],[720,376]]),
 areas_publicas=['Recepção e salão'],quartos=['Quarto da Mara','Quarto do Téo','Hóspedes 1','Hóspedes 2'],
 itens=[mov(CAMA,80,144,[28,48],id='CamaResponsavel'),mov(EST,160,128,[30,12]),mov(BAU,152,192,[26,12]),
 mov(CAMA,272,144,[28,48],id='CamaCrianca'),mov(MESA,344,152,[40,14],id='MesaCrianca'),mov(CADEIRA,344,192,[12,8]),
 mov(CAMA,512,152,[28,48],id='CamaHospede1'),mov(BAU,584,232,[26,12]),mov(MESA,568,192,[40,14]),
 mov(CAMA,672,152,[28,48],id='CamaHospede2'),mov(BAU,744,232,[26,12]),mov(MESA,728,192,[40,14]),
 mov(LAREIRA,64,400,[44,12]),mov(BALCAO,136,376,[58,14],id='BancadaCozinha'),mov(LAV,184,376,[24,12],id='PiaCozinha'),
 mov(PRAT,64,456,[32,12]),
 mov('familias/balcao_hospedaria',544,456,[96,20],id='BalcaoDeMara'),
 mov(EST,704,440,[30,12],id='ArmarioRecepcao'),
 mov(BANCO,304,504,[30,10]),mov(BANCO,352,504,[30,10]),
 mov(MESA,320,552,[44,14]),mov(CADEIRA,280,552,[12,8]),mov(CADEIRA,360,552,[12,8]),
 mov(MESA,640,552,[44,14]),mov(CADEIRA,600,552,[12,8]),mov(CADEIRA,680,552,[12,8]),
 mov('interior/pousada/tapete',472,576,[0,0],id='TapeteEntrada',sem_colisao=True,no_chao=True),mov(PLANTA,736,568,[16,10])])

# Padaria: loja ampla na frente, produção à esquerda e quartos em sequência
# na ala direita dos fundos. Pia e bancada de massas formam o mesmo posto.
a=[('Produção da padaria',[32,64,208,264],'escuro'),
 ('Quarto da Cora',[320,64,256,112],'claro'),('Quarto da Bia',[320,216,256,112],'claro'),
 ('Corredor',[256,112,32,216],'claro'),
 ('Passagem',[288,128,32,48],'claro'),('Passagem',[288,264,32,48],'claro'),
 ('Passagem',[112,328,48,40],'escuro'),('Passagem',[256,328,32,40],'claro'),
 ('Loja da padaria',[32,368,544,208],'medio')]
casas['cora']=dict(nome='Padaria de Cora e Bia',familia=['cora','bia'],
 geometria=geo(608,624,[432,480],576,a,[[40,64],[488,64],[488,216],[40,368],[528,368]]),
 areas_publicas=['Loja da padaria'],quartos=['Quarto da Cora','Quarto da Bia'],
 itens=[mov(CAMA,352,144,[28,48],id='CamaResponsavel'),mov(EST,520,128,[30,12]),mov(BAU,552,160,[26,12]),
 mov(CAMA,384,296,[28,48],id='CamaCrianca'),mov(MESA,488,280,[40,14],id='MesaCrianca'),mov(CADEIRA,488,312,[12,8]),
 mov('interior/forja/fornalha',72,144,[44,14],recorte=[0,0,50,56],id='FornoSemBigorna'),
 mov('familias/bancada_padeiro',152,112,[72,20],id='BancadaDeCora'),mov(LAV,208,112,[24,12],id='PiaProducao'),
 mov(SACOS,192,304,[48,16],id='FarinhaProducao'),mov(PRAT,72,304,[32,12],id='DespensaProducao'),
 mov('familias/vitrine_padaria',368,448,[136,22],id='VitrineDePaes'),mov(BALCAO,472,448,[58,14],id='EmbalagemDaLoja'),
 mov(PRAT,80,432,[32,12],id='ProdutosLoja1'),mov(PRAT,168,432,[32,12],id='ProdutosLoja2'),
 mov(BANCO,88,552,[30,10]),mov(BANCO,136,552,[30,10]),mov(PLANTA,552,552,[16,8])])

# Rosa: consultório atrás da loja e casa em uma ala lateral reservada.
# O preparo doméstico fica junto à parede do fundo; a espera fica na loja.
a=[('Quarto da Rosa',[32,64,176,144],'claro'),('Quarto da Nina',[32,248,176,128],'claro'),
 ('Corredor',[224,128,32,248],'claro'),('Passagem',[208,152,16,48],'claro'),('Passagem',[208,304,16,48],'claro'),
 ('Cozinha da família',[288,64,256,144],'escuro'),('Passagem',[256,128,32,48],'claro'),
 ('Consultório',[288,248,256,128],'escuro'),
 ('Passagem',[224,376,32,40],'claro'),('Passagem',[448,376,48,40],'escuro'),
 ('Loja de ervas e espera',[32,416,512,176],'medio')]
casas['rosa']=dict(nome='Casa e botica de Rosa e Nina',familia=['rosa','nina'],
 geometria=geo(576,640,[400,448],592,a,[[40,64],[40,248],[472,64],[472,248],[40,416]]),
 areas_publicas=['Loja de ervas e espera'],quartos=['Quarto da Rosa','Quarto da Nina'],
 itens=[mov(CAMA,80,144,[28,48],id='CamaResponsavel'),mov(EST,168,128,[30,12]),mov(BAU,152,192,[26,12]),
 mov(CAMA,80,328,[28,48],id='CamaCrianca'),mov(MESA,160,312,[40,14],id='MesaCrianca'),mov(CADEIRA,160,352,[12,8]),
 mov(BALCAO,336,104,[58,14],id='BancadaCozinha'),mov(LAV,384,104,[24,12],id='PiaCozinha'),mov(LAREIRA,448,128,[44,12],id='FogaoDaFamilia'),
 mov(PRAT,512,144,[32,12]),mov(MESA,464,192,[40,14]),mov(CADEIRA,504,192,[12,8]),
 mov('interior/enfermaria/cama',496,344,[24,34],id='MacaConsultorio'),mov('interior/enfermaria/armario',328,312,[34,12]),
 mov('interior/enfermaria/mesa',400,320,[28,14],id='MesaConsulta'),mov(CADEIRA,400,352,[12,8]),
 mov(POCOES,80,488,[40,14],id='ProdutosBotica1'),mov(POCOES,176,488,[40,14],id='ProdutosBotica2'),
 mov('familias/bancada_ervas',392,496,[64,20],id='BalcaoDeRosa'),mov(BALCAO,320,496,[58,14],id='BalcaoBoticaEsquerda'),mov(BALCAO,464,496,[58,14],id='BalcaoBoticaDireita'),
 mov(BANCO,104,568,[30,10]),mov(BANCO,152,568,[30,10]),mov(PLANTA,512,568,[16,8])])

if __name__=='__main__':
 pasta=RAIZ/'codigo/cidade/familias';pasta.mkdir(exist_ok=True)
 (pasta/'plantas.json').write_text(json.dumps(dict(grade=8,corredor_minimo=32,fontes_permitidas=['assets/cenario/cidade/interiores_detalhados/'],casas=casas),ensure_ascii=False,indent=2)+'\n')
 for id,casa in casas.items():
  g=casa['geometria'];w,h=g['recorte'][2:];partes=[f'<svg xmlns="http://www.w3.org/2000/svg" width="{w+64}" height="{h+112}" viewBox="-32 -64 {w+64} {h+112}"><rect x="-32" y="-64" width="{w+64}" height="{h+112}" fill="#172e35"/><style>text{{font-family:DejaVu Sans,sans-serif;fill:#f1e6c9;text-anchor:middle}}</style><text x="{w/2}" y="-35" font-size="22">{escape(casa["nome"])}</text><text x="{w/2}" y="-10" font-size="12">Planta em grade de 8 px · portas de 48 px · móveis montados separadamente</text>']
  for area in g['areas']:
   x,y,rw,rh=area['retangulo'];passagem=area['nome'] in ['Passagem','Corredor','Saída'];cor='#375662' if passagem else '#456c70';partes.append(f'<rect x="{x}" y="{y}" width="{rw}" height="{rh}" fill="{cor}" stroke="#c6c2a5" stroke-width="2"/>')
   if not passagem:partes.append(f'<text x="{x+rw/2}" y="{y+rh/2}" font-size="14">{escape(area["nome"])}</text>')
  for it in casa['itens']:
   cw,ch=it['col'];partes.append(f'<rect x="{it["x"]-cw/2}" y="{it["y"]-ch}" width="{cw}" height="{ch}" rx="2" fill="#d5b477" opacity=".45"/>')
  partes.append(f'<text x="{w/2}" y="{h+30}" font-size="12">Entrada ao sul · quartos privativos · circulação contínua · dourado = base dos móveis</text></svg>')
  (RAIZ/f'arte/previas/cidade/casas_familias/planta_{id}.svg').write_text(''.join(partes))
 print('3 plantas e SVGs gerados, sem recursos Mana Seed ou Tiny.')
