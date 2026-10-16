#!/usr/bin/env python3
"""Valida resolução, todos os quadros e o encaixe da base refinada nas peças existentes."""
import json
from pathlib import Path
from PIL import Image, ImageChops

RAIZ = Path(__file__).resolve().parents[2]
PAGINAS = {'andar', 'fazenda', 'forja', 'sentado', 'espada', 'lanca',
           'reacao_um_mao', 'reacao_lanca', 'reacao_arco', 'arco_p2', 'arco_p3'}


def validar():
    cadastro = json.loads((RAIZ/'assets/personagens/refinado/manifesto.json').read_text())
    erros = []
    if set(cadastro) != PAGINAS:
        erros.append('Cadastro deve ter as 11 páginas obrigatórias.')
    quadros = 0
    for pagina, dados in cadastro.items():
        nova = Image.open(RAIZ/dados['folha'].removeprefix('res://')).convert('RGBA')
        antiga = Image.open(RAIZ/dados['molde'].removeprefix('res://')).convert('RGBA')
        if nova.size != (1024, 1024) or dados['escala'] != 0.5:
            erros.append(f'Resolução/escala inválida: {pagina}')
            continue
        alfa = nova.getchannel('A')
        if set(alfa.get_flattened_data()) - {0, 255}:
            erros.append(f'Transparência intermediária: {pagina}')
        referencia = antiga.getchannel('A').point(lambda a: 255 if a >= 128 else 0)
        referencia = referencia.resize(nova.size, Image.Resampling.NEAREST)
        # Regressão dos artefatos encontrados: pele coberta por preto e olhos
        # deslocados pelo recorte de uma cabeça pertencente a outra pose.
        pixels = nova.load()
        for y in range(antiga.height):
            for x in range(antiga.width):
                r, g, b, a = antiga.getpixel((x, y))
                if a < 128:
                    continue
                bloco = [pixels[x*2+sx, y*2+sy] for sy in range(2) for sx in range(2)]
                if (r, g, b) == (24, 24, 24):
                    if any(max(c[:3]) > 50 for c in bloco):
                        erros.append(f'Contorno/olho apagado: {pagina}/{x},{y}')
                elif (r, g, b) in {(136, 88, 72), (216, 152, 120), (248, 216, 184)}:
                    if any(c[0] < 120 or c[0] <= c[1] or c[1] <= c[2] for c in bloco):
                        erros.append(f'Mancha ou mudança de pele: {pagina}/{x},{y}')
        for quadro in range(64):
            x, y = quadro % 8 * 128, quadro // 8 * 128
            area = (x, y, x+128, y+128)
            if ImageChops.difference(alfa.crop(area), referencia.crop(area)).getbbox():
                erros.append(f'Encaixe mudou: {pagina}/{quadro}')
            quadros += 1
    print(f'{len(cadastro)} páginas, {quadros} quadros verificados.')
    for erro in erros:
        print('FALHA:', erro)
    print('FALHAS:', len(erros))
    return len(erros)


if __name__ == '__main__':
    raise SystemExit(validar())
