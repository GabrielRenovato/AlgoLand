#!/usr/bin/env python3
"""Impede o retorno de costuras nas dezesseis margens Wang da gruta."""
import sys
import unittest
from pathlib import Path

from PIL import Image

RAIZ = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(RAIZ/'ferramentas/fendas'))
from preparar_gruta_nascente import materiais_continuos


class ContinuidadeGruta(unittest.TestCase):
    def test_margens_compartilham_todos_os_pixels_da_juncao(self):
        _, folha, _ = materiais_continuos()
        pares = 0
        for a in range(16):
            for b in range(16):
                if (a>>1)&1 == b&1 and (a>>3)&1 == (b>>2)&1:
                    for y in range(32):
                        self.assertEqual(folha.getpixel((a%4*32+31, a//4*32+y)),
                                         folha.getpixel((b%4*32, b//4*32+y)), ('horizontal',a,b,y))
                    pares += 1
                if (a>>2)&1 == b&1 and (a>>3)&1 == (b>>1)&1:
                    for x in range(32):
                        self.assertEqual(folha.getpixel((a%4*32+x, a//4*32+31)),
                                         folha.getpixel((b%4*32+x, b//4*32)), ('vertical',a,b,x))
                    pares += 1
        self.assertEqual(pares, 128)

    def test_atlas_consumido_conserva_as_margens_validadas(self):
        _, margens, _ = materiais_continuos()
        atlas = Image.open(RAIZ/'assets/cenario/fendas/gruta_nascente/base.png').convert('RGBA')
        self.assertEqual(atlas.crop((0,256,128,384)).tobytes(), margens.tobytes())


if __name__ == '__main__':
    unittest.main()
