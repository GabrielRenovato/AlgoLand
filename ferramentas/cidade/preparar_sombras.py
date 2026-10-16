#!/usr/bin/env python3
"""Recorta as máscaras geradas no PixelLab; preserva os pixels e a transparência das fontes.

Reexecutar não consome gerações. Os jobs e as fontes ficam em arte/fontes/cenario/sombras.
A origem de cada máscara exportada é o centro inferior, usada por sombra_cidade.gd.
"""
from pathlib import Path
import json
from PIL import Image

RAIZ = Path(__file__).resolve().parents[2]
FONTES = RAIZ / 'arte/fontes/cenario/sombras'
SAIDA = RAIZ / 'assets/cenario/cidade/sombras'
GRUPOS = {
    'casas': ('casas_pixellab.png', 128, ['venda', 'sede', 'enfermaria', 'pousada', 'mistica', 'casa_bento']),
    'objetos': ('objetos_pixellab_limpos.png', 96, ['coreto', 'fonte', 'feira', 'banco', 'poste', 'cerca', 'horta', 'galinheiro', 'arvore', 'arbusto', 'feno', 'mesa']),
}


def main():
    manifesto = {}
    for grupo, (fonte, lado, nomes) in GRUPOS.items():
        folha = Image.open(FONTES / fonte).convert('RGBA')
        pasta = SAIDA / grupo
        pasta.mkdir(parents=True, exist_ok=True)
        for i, nome in enumerate(nomes):
            x, y = (i % 3) * lado, (i // 3) * lado
            celula = folha.crop((x, y, x + lado, y + lado))
            limites = celula.getbbox()
            if limites is None:
                raise ValueError(f'Máscara vazia: {grupo}/{nome}')
            mascara = celula.crop(limites)
            mascara.save(pasta / f'{nome}.png')
            manifesto[f'{grupo}/{nome}'] = {'fonte': fonte, 'celula': [x, y, lado, lado], 'recorte': list(limites), 'tamanho': list(mascara.size)}
    (SAIDA / 'manifesto.json').write_text(json.dumps(manifesto, indent=2) + '\n')
    print(f'{len(manifesto)} máscaras do PixelLab preparadas.')


if __name__ == '__main__':
    main()
