"""Mede descontinuidade de silhueta nas bordas compatíveis do atlas.

Complementa a inspeção real do Godot; não aprova qualidade artística.
"""
from pathlib import Path
import json
from PIL import Image
from preparar_conexoes_caverna import PECAS, ESPELHADAS, RAIZ

BASE = RAIZ / 'assets/cenario/fendas/caverna_conexoes'

def main():
    atlas = Image.open(BASE / 'atlas.png').convert('RGB')
    pecas = {m:atlas.crop((x*64,y*64,(x+1)*64,(y+1)*64))
             for m,(x,y) in PECAS.items() if m}
    for destino,origem in ESPELHADAS.items():
        pecas[destino] = pecas[origem].transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    bordas = []
    for m,a in pecas.items():
        for n,b in pecas.items():
            for eixo in ('horizontal','vertical'):
                compativel = ((m&2)//2 == n&1 and (m&8)//8 == (n&4)//4) if eixo == 'horizontal' else ((m&4)//4 == n&1 and (m&8)//8 == (n&2)//2)
                if not compativel:
                    continue
                aa = [a.getpixel((63,i) if eixo == 'horizontal' else (i,63)) for i in range(64)]
                bb = [b.getpixel((0,i) if eixo == 'horizontal' else (i,0)) for i in range(64)]
                preto = sum((max(p)<18) != (max(q)<18) for p,q in zip(aa,bb))
                cor = sum(abs(p[c]-q[c]) for p,q in zip(aa,bb) for c in range(3))/(64*3)
                bordas.append({'a':m,'b':n,'eixo':eixo,'preto_divergente_px':preto,'diferenca_media_rgb':round(cor,2)})
    piores = sorted(bordas,key=lambda b:(b['preto_divergente_px'],b['diferenca_media_rgb']),reverse=True)
    relatorio = {'pares':len(bordas),'max_descontinuidade_preto_px':piores[0]['preto_divergente_px'],
                 'piores':piores[:12],'criterio':'No máximo 3px divergentes em borda de64; não substitui revisão artística no Godot.'}
    saida = RAIZ/'arte/previas/fenda/caverna_conexoes/avaliacao_bordas.json'
    saida.write_text(json.dumps(relatorio,indent=2)+'\n')
    print(json.dumps(relatorio,ensure_ascii=False))
    return int(piores[0]['preto_divergente_px'] > 3)

if __name__ == '__main__':
    raise SystemExit(main())
