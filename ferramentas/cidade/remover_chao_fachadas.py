#!/usr/bin/env python3
"""Aplica só a máscara de transparência da edição do PixelLab, preservando os pixels originais das casas.

Os originais e as edições ficam em arte/fontes/cenario/casas. Canvas, âncoras e colisões não mudam.
A parte acima da faixa de chão fica protegida contra qualquer alteração da geração.
"""
from pathlib import Path
import json
from PIL import Image

RAIZ = Path(__file__).resolve().parents[2]
FONTES = RAIZ / 'arte/fontes/cenario/casas'
MEDIDAS = RAIZ / 'assets/cenario/cidade/casas/exteriores.json'
SAIDA = RAIZ / 'assets/cenario/cidade/casas/exterior'


def main():
    for nome, dados in json.loads(MEDIDAS.read_text()).items():
        original = Image.open(FONTES / 'antes_remover_chao' / f'{nome}.png').convert('RGBA')
        recorte = Image.open(FONTES / 'sem_chao_pixellab' / f'{nome}.png').convert('RGBA')
        if recorte.size != original.size:
            raise ValueError(f'O PixelLab mudou o canvas de {nome}')
        resultado = original.copy()
        inicio_chao = dados['ancora'][1] - 14
        apagados = 0
        for y in range(inicio_chao, original.height):
            for x in range(original.width):
                r, g, b, a = original.getpixel((x, y))
                if a and recorte.getpixel((x, y))[3] < 128:
                    resultado.putpixel((x, y), (r, g, b, 0))
                    apagados += 1
        # Garante que só a transparência foi editada e que o topo da casa foi preservado integralmente.
        assert original.crop((0, 0, original.width, inicio_chao)).tobytes() == resultado.crop((0, 0, original.width, inicio_chao)).tobytes()
        assert all(a[:3] == b[:3] for a, b in zip(original.get_flattened_data(), resultado.get_flattened_data()))
        resultado.save(SAIDA / f'{nome}.png')
        print(f'{nome}: {apagados} pixels de chão removidos; cores e posição preservadas.')


if __name__ == '__main__':
    main()
