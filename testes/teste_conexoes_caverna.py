"""Regressões de encaixe e renderização; não aprovam direção artística."""
import json
from pathlib import Path
import sys
import unittest
from PIL import Image, ImageChops

RAIZ = Path(__file__).resolve().parents[1]
sys.path.insert(0,str(RAIZ/'ferramentas/fendas'))
from preparar_conexoes_caverna import PECAS


class ConexoesCaverna(unittest.TestCase):
    def test_mascaras_e_padroes_sem_ambiguidade_diagonal(self):
        dados = json.loads((RAIZ/'assets/cenario/fendas/caverna_conexoes/bancada.json').read_text())
        self.assertEqual(set(dados['mascaras']),set(PECAS))
        self.assertEqual(dados['grade'],16)
        self.assertEqual(dados['modulo']%dados['grade'],0)
        cena=(RAIZ/'cenas/fendas/previa_conexoes_caverna.tscn').read_text()
        self.assertIn('CanvasItemMaterial',cena)

    def test_limite_de_descontinuidade_da_silhueta(self):
        dados=json.loads((RAIZ/'arte/previas/fenda/caverna_conexoes/avaliacao_bordas.json').read_text())
        self.assertEqual(dados['pares'],86)
        self.assertLessEqual(dados['max_descontinuidade_preto_px'],3)

    def test_captura_godot_respeita_pixels_e_espelhamento(self):
        base=RAIZ/'assets/cenario/fendas/caverna_conexoes'
        dados=json.loads((base/'bancada.json').read_text())
        atlas=Image.open(base/'atlas.png').convert('RGB')
        esperado=Image.new('RGB',tuple(dados['tamanho']),(0,0,0))
        for x,y,ax,ay,alternativa in dados['celulas']:
            recorte=atlas.crop((ax*16,ay*16,(ax+1)*16,(ay+1)*16))
            if alternativa:
                self.assertEqual(alternativa,4096)
                recorte=recorte.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
            esperado.paste(recorte,(x*16,y*16))
        real=Image.open(RAIZ/'arte/previas/fenda/caverna_conexoes/bancada_godot.png').convert('RGB')
        self.assertIsNone(ImageChops.difference(esperado,real).getbbox())


if __name__=='__main__':
    unittest.main()
