#!/usr/bin/env python3
"""Camadas Raven: mesma translação fixa para corpo, cabelo e peças, sem escala."""
from preparar_raven import SAIDA, pacote, imagem, ACOES
from PIL import Image
import json

ROUPAS = [
    ('calca_marrom','Pants/Brown Pants.png'),('calca_jeans','Pants/Jeans Pants.png'),
    ('camisa_azul','Shirt/Blue Shirt.png'),('camisa_verde','Shirt/Green Shirt.png'),
    ('botas','Boots/Leather Boots.png'),('luvas','Gloves/Leather Gloves.png'),
    ('capa','Cape/Adventurer Cape.png'),
]

def exportar():
    base, roupa, cabelos = (pacote(k) for k in ['base','roupa','cabelos'])
    fontes = {'corpo_%d'%i: imagem(base,'Base/Skin %d.png'%(i+1)) for i in range(3)}
    fontes.update({'cabelo_%d'%i: imagem(cabelos,'Hair/hair (%d).png'%i) for i in range(1,29)})
    fontes.update({nome:imagem(roupa,fim) for nome,fim in ROUPAS})
    vazio = Image.new('RGBA',(320,320))
    ferramentas = Image.new('RGBA',(320,320*len(ACOES)))
    escudos = Image.new('RGBA',ferramentas.size)
    for indice,nome in enumerate(ACOES):
        # Recupera ferramentas sem embutir o corpo na camada.
        x,y,extra = ACOES[nome]
        if extra is None: continue
        im=imagem(base,'Extras/'+extra)
        largura,altura=(80,80) if nome=='lanca' else (48,64)
        for direcao in range(4):
            for q in range(4):
                quadro=2 if nome=='pescar' and direcao==2 and q==3 else q
                ex,ey=(16,16) if nome=='lanca' else (48,64)
                if nome in ['espada_2','andar_escudo']:ex+=240
                recorte=im.crop((ex+direcao*largura,ey+quadro*altura,ex+(direcao+1)*largura,ey+(quadro+1)*altura))
                destino=(q*80+(0 if nome=='lanca' else 16),indice*320+direcao*80)
                (escudos if nome in ['bloquear','andar_escudo'] else ferramentas).alpha_composite(recorte,destino)
    (SAIDA/'camadas').mkdir(exist_ok=True)
    (SAIDA/'previas').mkdir(exist_ok=True)
    ferramentas.save(SAIDA/'camadas/ferramentas.png')
    escudos.save(SAIDA/'camadas/escudo_frente.png')
    for id,origem in fontes.items():
        atlas=Image.new('RGBA',(320,320*len(ACOES)))
        previa=Image.new('RGBA',(512,512))
        for indice,(nome,(x,y,extra)) in enumerate(ACOES.items()):
            largura,altura=(80,80) if nome=='lanca' else (48,64)
            for direcao in range(4):
                for q in range(4):
                    quadro=2 if nome=='pescar' and direcao==2 and q==3 else q
                    recorte=origem.crop((x+direcao*largura,y+quadro*altura,x+(direcao+1)*largura,y+(quadro+1)*altura))
                    atlas.alpha_composite(recorte,(q*80+(0 if nome=='lanca' else 16),indice*320+direcao*80))
                    if nome=='parado':
                        # Compatibilidade geométrica com as miniaturas atuais da interface.
                        linha=[0,2,1,3][direcao]
                        celula=Image.new('RGBA',(64,64));celula.paste(recorte,(8,-4))
                        previa.alpha_composite(celula,(q*64,linha*64))
        atlas.save(SAIDA/'camadas'/f'{id}.png')
        previa.save(SAIDA/'previas'/f'{id}.png')
    Image.new('RGBA',(512,512)).save(SAIDA/'previas/vazio.png')
    Image.new('RGBA',(320,320*len(ACOES))).save(SAIDA/'camadas/vazio.png')
    (SAIDA/'camadas/acoes.json').write_text(json.dumps(list(ACOES))+'\n')
    from preparar_armamento_raven import preparar as preparar_armamento
    preparar_armamento()
    from preparar_complementos_raven import preparar as preparar_complementos
    preparar_complementos()
    from preparar_paginas_raven import preparar as preparar_paginas
    preparar_paginas()
    print(f'{len(fontes)} camadas originais exportadas para {len(ACOES)} ações; prévias com o mesmo pivô.')

if __name__=='__main__':exportar()
