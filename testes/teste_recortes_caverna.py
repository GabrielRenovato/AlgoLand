#!/usr/bin/env python3
"""A imagem escolhida precisa sobreviver ao fatiamento sem mudança de um pixel."""
import json
import unittest
from pathlib import Path

from PIL import Image, ImageChops

RAIZ = Path(__file__).resolve().parents[1]
BASE = RAIZ/'assets/cenario/fendas/caverna_recortada'
FONTE = RAIZ/'arte/previas/fenda/gruta_nascente/estudo_gaias_navel_v2.png'


class RecortesCaverna(unittest.TestCase):
    def test_recomposicao_preserva_todos_os_pixels(self):
        dados=json.loads((BASE/'mapa.json').read_text())
        atlas=Image.open(BASE/'atlas.png').convert('RGBA')
        resultado=Image.new('RGBA',tuple(dados['tamanho']))
        for x,y,indice in dados['celulas']:
            ax,ay=indice%64*18+1,indice//64*18+1
            resultado.paste(atlas.crop((ax,ay,ax+16,ay+16)),(x*16,y*16))
        fonte=Image.open(FONTE).convert('RGBA')
        self.assertEqual(resultado.crop((0,0,*fonte.size)).tobytes(),fonte.tobytes())

    def test_padroes_sao_recortes_nativos_validos(self):
        dados=json.loads((BASE/'mapa.json').read_text())
        self.assertEqual(len(dados['padroes']),20)
        for nome,(x0,y0,x1,y1) in dados['padroes'].items():
            self.assertTrue(all(v%16==0 for v in (x0,y0,x1,y1)),nome)
            self.assertTrue(0<=x0<x1<=dados['origem'][0] and 0<=y0<y1<=dados['origem'][1],nome)

    def test_andar_08_preserva_planta_e_utiliza_somente_recortes(self):
        planta=json.loads((RAIZ/'codigo/fendas/plantas/andar_08.json').read_text())
        mapa=json.loads((BASE/'andar_08.json').read_text())
        origem=json.loads((BASE/'mapa.json').read_text())
        self.assertEqual(mapa['setores'],planta['setores'])
        self.assertEqual(mapa['trilhas'],planta['trilhas'])
        self.assertEqual(mapa['entrada'],planta['entrada'])
        self.assertEqual(mapa['guardiao'],planta['guardiao'])
        self.assertTrue(all(0<=c[2]<origem['unicos'] for c in mapa['celulas']))
        self.assertEqual(len(mapa['celulas']),mapa['limites'][2]//16*(mapa['limites'][3]//16))

    def test_degraus_nao_sao_usados_como_fragmentos_de_parede(self):
        mapa=json.loads((BASE/'andar_08.json').read_text())
        origem=json.loads((BASE/'mapa.json').read_text())
        caixas=[(544,496,656,624),(1032,400,1144,528),(720,960,832,1088)]
        proibidos={i for x,y,i in origem['celulas'] if any(x*16<b[2] and x*16+16>b[0]
                   and y*16<b[3] and y*16+16>b[1] for b in caixas)}
        self.assertFalse({c[2] for c in mapa['celulas']} & proibidos)


if __name__=='__main__':unittest.main()
