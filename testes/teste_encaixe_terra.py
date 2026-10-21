"""Confere fase do material e máscaras reais de todas as bordas sazonais."""
from pathlib import Path
import sys
from PIL import Image

RAIZ=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(RAIZ/'ferramentas/cenario'))
from preparar_terra_natural import campo_nativo,BORDAS,NOMES

for e,nome in enumerate(NOMES):
    atlas=Image.open(RAIZ/f'assets/cenario/substitutos/terra_continua/{nome}.png').convert('RGBA')
    modelo=Image.open(RAIZ/f'assets/cenario/substitutos/natureza/{nome}.png').convert('RGBA')
    campo=campo_nativo(e)
    assert atlas.size==(128,1664)
    assert atlas.crop((0,0,128,128)).tobytes()==campo.tobytes(),('campo base',nome)
    for banco,(tx,ty) in enumerate(BORDAS,1):
        for y in range(128):
            for x in range(128):
                a=atlas.getpixel((x,banco*128+y))
                b=modelo.getpixel((tx*16+x%16,ty*16+y%16))
                assert a[3]==b[3],('máscara de borda alterada',nome,banco,x,y)
    # O fechamento periódico não pode introduzir uma costura de alto contraste.
    for eixo in range(2):
        erros=[]
        for linha in range(128):
            soma=0
            for i in range(128):
                a,b=(((linha,i),((linha+1)%128,i)) if eixo==0 else ((i,linha),(i,(linha+1)%128)))
                soma+=sum((v-w)**2 for v,w in zip(campo.getpixel(a)[:3],campo.getpixel(b)[:3]))
            erros.append(soma/128)
        media=sum(erros)/128
        assert erros[-1]<media*3,('costura externa',nome,eixo)
print('ENCAIXE TERRA: 0 falhas; quatro estações, campo e doze máscaras de borda.')
