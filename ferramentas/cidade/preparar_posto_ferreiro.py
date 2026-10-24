"""Integra os objetos independentes do posto de forja; quatro estações e pivôs fixos."""
from pathlib import Path
from PIL import Image
RAIZ = Path(__file__).resolve().parents[2]
FONTES = RAIZ / 'arte/fontes/forja/posto'
DESTINO = RAIZ / 'assets/cenario/cidade/interiores_detalhados/posto_ferreiro'
ESTACOES = ('primavera','verao','outono','inverno')
def preparar():
    for nome,tamanho in [('fornalha',(288,256)),('fornalha_fraca',(288,256)),('bigorna',(120,96))]:
        im=Image.open(FONTES/(nome+'.png')).convert('RGBA')
        referencia=Image.open(FONTES/'fornalha.png').convert('RGBA') if nome=='fornalha_fraca' else im
        caixa=referencia.getchannel('A').point(lambda a:255 if a>32 else 0).getbbox()
        if referencia.size!=im.size:
            caixa=tuple(round(v*(im.width/referencia.width if i%2==0 else im.height/referencia.height)) for i,v in enumerate(caixa))
        base=im.crop(caixa).resize(tamanho,Image.Resampling.LANCZOS)
        pasta=DESTINO/nome;pasta.mkdir(parents=True,exist_ok=True)
        for estacao,fatores in zip(ESTACOES,[(1,1,1),(1.012,1,.985),(.985,.975,.96),(.965,.985,1.015)]):
            canais=list(base.split())
            for i,fator in enumerate(fatores):canais[i]=canais[i].point(lambda v:min(255,round(v*fator)))
            Image.merge('RGBA',canais).save(pasta/(estacao+'.png'))
if __name__=='__main__':preparar()
