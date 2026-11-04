#!/usr/bin/env python3
"""Recorta as peças geradas sem repintar; preserva a tela e o pivô sazonais.

Contrato e pedidos ficam em arte/fontes/cidade/arquitetura_familias/.
ImageMagick só recorta e adequa os materiais ao contrato 4× da sala.
"""
import json
from pathlib import Path
import subprocess
from PIL import Image

RAIZ = Path(__file__).resolve().parents[2]
FONTES = RAIZ / 'arte/fontes/cidade/arquitetura_familias'
SAIDA = RAIZ / 'assets/cenario/cidade/interiores_detalhados/familias/arquitetura'
ESTACOES = ['primavera', 'verao', 'outono', 'inverno']


def recortar(fonte, destino, retangulo, tamanho=None, tela=None):
    destino.parent.mkdir(parents=True, exist_ok=True)
    x, y, w, h = retangulo
    comando = ['magick', str(fonte), '-crop', f'{w}x{h}+{x}+{y}', '+repage']
    if tamanho:
        comando += ['-filter', 'Lanczos', '-resize', f'{tamanho[0]}x{tamanho[1]}!']
    if tela:
        comando += ['-background', 'none', '-gravity', 'northwest', '-extent', f'{tela[0]}x{tela[1]}']
    subprocess.run(comando + [str(destino)], check=True)


def main():
    contrato = json.loads((FONTES / 'contrato.json').read_text())
    manifesto = {}
    for id, ficha in contrato.items():
        fonte = FONTES / id / 'atlas.png'
        entrada = dict(pivo=ficha['pivo'], texturas=[], largura_fonte=0,
                       materiais=[], origem='image_gen nativa; sem Mana Seed/Tiny')
        limites = []
        for i, estacao in enumerate(ESTACOES):
            pasta = SAIDA / id / estacao
            fachada = pasta / 'fachada.png'
            recortar(fonte, fachada, ficha['exteriores'][i], tela=(ficha['exteriores'][0][2], 384))
            im = Image.open(fachada).convert('RGBA')
            limites.append(im.getchannel('A').point(lambda a: 255 if a > 128 else 0).getbbox())
            assert limites[-1], f'Fachada vazia: {id}/{estacao}'
            recortar(fonte, pasta / 'parede.png', ficha['paredes'][i], (256, 128))
            entrada['texturas'].append('res://' + str(fachada.relative_to(RAIZ)))
            entrada['materiais'].append('res://' + str((pasta / 'parede.png').relative_to(RAIZ)))
        # Uma escala comum: neve e folhas não redimensionam a casa a cada estação.
        entrada['largura_fonte'] = max(b[2] for b in limites) - min(b[0] for b in limites)
        manifesto[id] = entrada
    (RAIZ / 'codigo/cidade/familias/arquitetura.json').write_text(
        json.dumps(manifesto, ensure_ascii=False, indent=2) + '\n')
    print('Arquitetura: 3 famílias, 12 fachadas e 12 paredes; telas e pivôs fixos.')


if __name__ == '__main__':
    main()
