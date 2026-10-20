"""Recortes e encaixes determinísticos das folhas geradas para as obras de Osvaldo."""
from pathlib import Path
from PIL import Image
import json

RAIZ = Path(__file__).resolve().parents[2]
FONTE = RAIZ/'arte/fontes/fazenda/obras'
DESTINO = RAIZ/'assets/cenario/fazenda/galinheiro/obra'
ESTACOES = ['primavera','verao','outono','inverno']

def preparar():
    DESTINO.mkdir(parents=True,exist_ok=True)
    for estacao in ESTACOES:
        caminho=FONTE/(estacao+'.png')
        if not caminho.exists(): continue
        fonte=Image.open(caminho).convert('RGBA')
        # Bases medidas na folha gerada: as três fileiras não têm altura uniforme.
        # A variante sazonal é normalizada para a mesma tela antes dos recortes.
        fonte=fonte.resize((1484,1060),Image.Resampling.NEAREST)
        for linha,(topo,fundo,base_y,escala) in enumerate([(0,420,394,.26),(420,720,694,.33),(720,1060,1013,.42)]):
            for coluna in range(3):
                esquerda=round(coluna*1484/3)
                direita=round((coluna+1)*1484/3)
                im=fonte.crop((esquerda,topo,direita,fundo))
                im.putalpha(im.getchannel('A').point(lambda a:255 if a>=128 else 0))
                im=im.resize((round(im.width*escala),round(im.height*escala)),Image.Resampling.NEAREST)
                quadro=Image.new('RGBA',(224,160))
                quadro.alpha_composite(im,(112-round((direita-esquerda)*escala/2),144-round((base_y-topo)*escala)))
                quadro.save(DESTINO/f'nivel_{linha+1}_etapa_{coluna}_{estacao}.png')
    preparar_ator()
    contrato={'referencias':['assets/npcs/cidade/osvaldo.png','assets/cenario/fazenda/galinheiro/nivel_1_primavera.png','assets/cenario/fazenda/galinheiro/nivel_2_primavera.png','assets/cenario/fazenda/galinheiro/nivel_3_primavera.png'],
        'cenario':{'grade':[3,3],'quadro':[224,160],'pivo':[112,144],'tile':16,'linhas':'inicial; expansão nível2; expansão nível3','colunas':['fundacao','estrutura','acabamento'],'estacoes':ESTACOES,'ampliacoes':'sobreposição transparente preserva prédio anterior e acesso'},
        'ator':{'grade':[6,4],'quadro':[64,64],'pes_y':45,'direcoes':['baixo','direita','cima','esquerda'],'acao':'preparar, levantar, armar, descer, golpear, recuperar','base_fonte':[128,222],'fonte_revisada':'osvaldo_construindo_revisado.png','contorno':'seletivo marrom/roxo, sem matte preto','bases_fonte_y':[220,462,702,938],'escala_revisada':31/146},
        'origem':'imagegen integrado; somente recorte, alfa e encaixe determinísticos no preparador',
        'integracao':['codigo/fazenda/galinheiro_exterior.gd','codigo/fazenda/trabalho_carpinteiro.gd','codigo/fazenda/ambiente_obra.gd']}
    (FONTE/'manifesto.json').write_text(json.dumps(contrato,ensure_ascii=False,indent=2)+'\n')
def preparar_ator():
    # Fonte revisada: contorno seletivo, sem matte preto; pés fixos por fileira.
    fonte=Image.open(FONTE/'osvaldo_construindo_revisado.png').convert('RGBA')
    folha=Image.new('RGBA',(384,256))
    escala=31/146
    bases=[220,462,702,938]
    for y in range(4):
        for x in range(6):
            im=fonte.crop((x*256,y*256,(x+1)*256,(y+1)*256))
            im.putalpha(im.getchannel('A').point(lambda a:255 if a>=200 else 0))
            im=im.resize((round(256*escala),round(256*escala)),Image.Resampling.NEAREST)
            folha.alpha_composite(im,(x*64+32-round(128*escala),y*64+45-round((bases[y]-y*256)*escala)))
    folha.save(RAIZ/'assets/npcs/cidade/osvaldo_construindo.png')

if __name__=='__main__':
    import sys
    preparar_ator() if '--somente-ator' in sys.argv else preparar()
