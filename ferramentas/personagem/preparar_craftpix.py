"""Lê tempos e direções nativos do Aseprite, sem alterar os PNGs."""
from pathlib import Path
import json, struct
from PIL import Image
RAIZ=Path(__file__).resolve().parents[2]
fonte=RAIZ/'arte/fontes/personagens/craftpix_base_masculina/original/ASEPRITE'
dados={}
for pasta in sorted(fonte.iterdir()):
 if not pasta.is_dir():continue
 nome=pasta.name
 destino=next((p for p in (RAIZ/'assets/personagens/craftpix_base_masculina').iterdir() if p.name.lower()==nome.lower()),None)
 if destino is None:continue
 folha=next(destino.glob('*full.png'))
 linhas={}
 for arquivo in pasta.glob('*.aseprite'):
  direcao=next((n for n in ['side_left','side_right','front','back'] if arquivo.stem.endswith(n)),None)
  if direcao is None:continue
  conteudo=arquivo.read_bytes(); quantidade=struct.unpack_from('<H',conteudo,6)[0]
  pos=128; duracoes=[]
  for i in range(quantidade):
   tamanho=struct.unpack_from('<I',conteudo,pos)[0]
   duracoes.append(struct.unpack_from('<H',conteudo,pos+8)[0]/1000)
   pos+=tamanho
  linhas[direcao]={'linha':['front','side_left','side_right','back'].index(direcao),'duracoes':duracoes}
 dados[nome.lower()]={'folha':'res://'+folha.relative_to(RAIZ).as_posix(),'direcoes':linhas}
saida=RAIZ/'assets/personagens/craftpix_base_masculina/animacoes.json'
saida.write_text(json.dumps(dados,ensure_ascii=False,indent=2)+'\n')
print(len(dados),'animações com durações nativas nas quatro direções')

# Mesma geometria para corpo, cabeça, arma e efeito; nunca redimensionar
# poses ou camadas separadamente pelo seu contorno.
origem=RAIZ/'assets/personagens/craftpix_base_masculina'
destino=RAIZ/'assets/personagens/craftpix_npcs'
destino.mkdir(parents=True,exist_ok=True)
for arquivo in sorted(origem.rglob('*.png')):
 imagem=Image.open(arquivo).convert('RGBA')
 # O arco do ataque correndo ultrapassa a célula por um pixel: margem
 # adicional preserva o efeito inteiro sem mudar a escala de nenhuma camada.
 margem=1 if arquivo.parent.name=='Sword_Run_Attack' else 0
 celula=64+2*margem
 corte=(13-margem,18-margem,77+margem,82+margem)
 folha=Image.new('RGBA',(imagem.width//64*celula,4*celula))
 for linha_nova,linha_original in enumerate([0,2,3,1]):
  for coluna in range(imagem.width//64):
   quadro=imagem.crop((coluna*64,linha_original*64,coluna*64+64,linha_original*64+64))
   ampliado=quadro.resize((90,90),Image.Resampling.NEAREST)
   ampliado.putalpha(ampliado.getchannel('A').point(lambda a:255 if a>=128 else 0))
   # Transforma o pivô (32,44) para (32,44) na célula nativa.
   area=ampliado.getbbox()
   if area:
    assert area[0]>=corte[0] and area[1]>=corte[1] and area[2]<=corte[2] and area[3]<=corte[3],(arquivo,coluna,linha_original,area)
   folha.alpha_composite(ampliado.crop(corte),(coluna*celula,linha_nova*celula))
 alvo=destino/arquivo.relative_to(origem)
 alvo.parent.mkdir(parents=True,exist_ok=True)
 folha.save(alvo)
for animacao in dados.values():
 animacao['folha']=animacao['folha'].replace('craftpix_base_masculina/','craftpix_npcs/')
 animacao['quadro']=66 if '/Sword_Run_Attack/' in animacao['folha'] else 64
 animacao['pivo']=[33,45] if animacao['quadro']==66 else [32,44]
 for direcao,info in animacao['direcoes'].items():
  info['linha']=['front','side_right','back','side_left'].index(direcao)
(destino/'animacoes.json').write_text(json.dumps(dados,ensure_ascii=False,indent=2)+'\n')
contrato={'quadro':[64,64],'pes_y':44,'pivo':[32,44],'altura_parado':31,'escala_jogo':1,'direcoes':['baixo','direita','cima','esquerda'],'referencia':'arte/fontes/npcs/base_vila/adulto_avental.json','transformacao':{'tela_intermediaria':[90,90],'recorte':[13,18,77,82],'filtro':'nearest'},'excecoes':{'Sword_Run_Attack':{'quadro':[66,66],'pivo':[33,45],'motivo':'margem para preservar arco do golpe'}},'originais':'assets/personagens/craftpix_base_masculina/'}
(destino/'contrato.json').write_text(json.dumps(contrato,ensure_ascii=False,indent=2)+'\n')
print('75 camadas normalizadas para NPC: altura31, pés44, escala1, direções baixo/direita/cima/esquerda; sem recortes de silhueta.')
