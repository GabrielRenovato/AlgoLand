"""O campo preserva os tufos desenhados e não introduz emendas na grade16px."""
from pathlib import Path
import sys
from PIL import Image

RAIZ=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(RAIZ/'ferramentas/cenario'))
from grama_do_topo import campo_nativo, painel_nativo
for estacao,nome in enumerate(['spring','summer','autumn','winter']):
    campo=campo_nativo(estacao)
    assert campo.size==(128,128)
    cores=set(painel_nativo(estacao).get_flattened_data())
    assert set(campo.convert('RGB').get_flattened_data())<=cores,('cor fora da folha de tufos',estacao)
    # Igualar pixels opostos cria faixas espelhadas; uma emenda boa conserva
    # diferenças locais semelhantes às demais linhas do material.
    for eixo in range(2):
        erros=[]
        for linha in range(128):
            soma=0
            for i in range(128):
                a,b=(((linha,i),((linha+1)%128,i)) if eixo==0 else ((i,linha),(i,(linha+1)%128)))
                soma+=sum((v-w)**2 for v,w in zip(campo.getpixel(a)[:3],campo.getpixel(b)[:3]))
            erros.append(soma/128)
        media=sum(erros)/len(erros)
        for linha in range(15,128,16):
            assert erros[linha]<media*2.5,('costura anormal',estacao,eixo,linha,erros[linha],media)
    assert campo.crop((0,0,64,128)).transpose(Image.Transpose.FLIP_LEFT_RIGHT).tobytes()!=campo.crop((64,0,128,128)).tobytes(),('campo espelhado',estacao)
    atlas=Image.open(RAIZ/'assets/cenario/substitutos/grama_continua'/f'{nome}.png').convert('RGBA')
    # A remontagem das64 células mantém o campo inteiro, em vez de sortear recortes incompatíveis.
    reconstruido=Image.new('RGBA',(128,128))
    for y in range(8):
        for x in range(8):reconstruido.paste(atlas.crop((x*16,y*16,x*16+16,y*16+16)),(x*16,y*16))
    assert reconstruido.tobytes()==campo.tobytes(),('campo fragmentado',estacao)
    assert atlas.size==(128,1152),('bancos de flores',estacao)
print('ENCAIXE GRAMA: 0 falhas; campo contínuo, tufos, costuras, ausência de espelhamento e quatro estações.')
