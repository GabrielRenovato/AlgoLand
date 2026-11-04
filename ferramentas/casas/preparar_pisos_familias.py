#!/usr/bin/env python3
"""Publica nove materiais próprios usando o preparo contínuo/sazonal dos interiores."""
from pathlib import Path
import json
import sys
from PIL import Image, ImageChops, ImageFilter, ImageStat

RAIZ = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(RAIZ / 'ferramentas/cidade'))
from preparar_interiores_detalhados import tom
from preparar_complementos import salvar

FONTES = RAIZ / 'arte/fontes/cidade/pisos_familias'
SAIDA = RAIZ / 'assets/cenario/cidade/interiores_detalhados/familias/arquitetura'
ESTACOES = ['primavera', 'verao', 'outono', 'inverno']
CASAS = ['mara', 'cora', 'rosa']
USOS = ['medio', 'claro', 'escuro']
PERIODOS = {
    'mara/medio': (318, 344), 'mara/claro': (400, 408), 'mara/escuro': (236, 212),
    'cora/medio': (282, 280), 'cora/claro': (292, 276), 'cora/escuro': (320, 318),
    'rosa/medio': (266, 262), 'rosa/claro': (390, 384), 'rosa/escuro': (265, 304)}
REPETIR = {'cora/medio', 'cora/claro', 'cora/escuro', 'rosa/medio', 'rosa/escuro'}


def recorte_periodico(im, tamanho):
    """Localiza a mesma fase das juntas; não repinta nem mistura os ladrilhos."""
    w, h = tamanho
    suave = im.filter(ImageFilter.GaussianBlur(1.2))

    def erro(a, b):
        return sum(ImageStat.Stat(ImageChops.difference(a, b)).mean)

    x = min(range(2, im.width-w-2), key=lambda x: erro(
        suave.crop((x-2, 2, x+2, im.height-2)),
        suave.crop((x+w-2, 2, x+w+2, im.height-2))))
    y = min(range(2, im.height-h-2), key=lambda y: erro(
        suave.crop((x, y-2, x+w, y+2)),
        suave.crop((x, y+h-2, x+w, y+h+2))))
    return im.crop((x, y, x+w, y+h)), [x, y, w, h]


def main():
    atlas = Image.open(FONTES / 'atlas.png').convert('RGB')
    assert atlas.width == atlas.height and atlas.width % 3 == 0
    celula = atlas.width // 3
    manifesto = dict(resolucao=4, periodo_logico=128, estacoes=ESTACOES, materiais={})
    for x, casa in enumerate(CASAS):
        for y, uso in enumerate(USOS):
            recorte = atlas.crop((x*celula, y*celula, (x+1)*celula, (y+1)*celula))
            limites = [0, 0, celula, celula]
            if casa + '/' + uso in PERIODOS:
                recorte, limites = recorte_periodico(recorte, PERIODOS[casa + '/' + uso])
            # Materiais estruturados já trazem módulos completos. Não aplicar
            # a compensação contínua de bordas usada para chão orgânico: ela
            # mistura ladrilhos claros e escuros e cria faixas nas juntas.
            repeticoes = 2 if casa + '/' + uso in REPETIR else 1
            modulo = recorte.resize((512//repeticoes, 512//repeticoes), Image.Resampling.LANCZOS)
            base = Image.new('RGB', (512, 512))
            for my in range(repeticoes):
                for mx in range(repeticoes):
                    base.paste(modulo, (mx*modulo.width, my*modulo.height))
            entrada = dict(recorte=[x*celula+limites[0], y*celula+limites[1], limites[2], limites[3]], repeticoes=repeticoes, texturas=[])
            for i, estacao in enumerate(ESTACOES):
                destino = SAIDA / casa / estacao / ('piso_' + uso + '.png')
                salvar(tom(base, i), destino)
                entrada['texturas'].append('res://' + str(destino.relative_to(RAIZ)))
            manifesto['materiais'][casa + '/' + uso] = entrada
    (FONTES / 'manifesto.json').write_text(json.dumps(manifesto, ensure_ascii=False, indent=2)+'\n')
    print('Pisos: 9 materiais, 36 texturas sazonais; grade, paredes e colisões preservadas.')


if __name__ == '__main__':
    main()
