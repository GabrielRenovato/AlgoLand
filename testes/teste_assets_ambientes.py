"""Regressões visuais nos PNGs reais: madeira imóvel, recortes e estações."""
from pathlib import Path
import sys
import unittest

from PIL import Image

RAIZ = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(RAIZ / 'ferramentas/cidade'))
import preparar_ambientes as P


class AssetsAmbientes(unittest.TestCase):
    def original(self, nome):
        return P.carregar(RAIZ / 'assets/cenario/cidade/decoracao/mobiliario' / (nome + '.png'))

    def quadro(self, nome, estacao, quadro=0):
        im = Image.open(P.SAIDA / 'externo' / nome / (estacao + '.png')).convert('RGBA')
        w = im.width // 4
        return im.crop((quadro * w, 0, (quadro + 1) * w, im.height))

    def test_madeira_e_base_nao_balancam(self):
        for nome in ['canteiro', 'horta']:
            im = self.original(nome)
            limite = int(im.height * .48)
            for q in range(4):
                with self.subTest(nome=nome, quadro=q):
                    nova = P.folhagem(im, q)
                    self.assertEqual(nova.size, im.size)
                    self.assertEqual(nova.crop((0, limite, im.width, im.height)).tobytes(),
                                     im.crop((0, limite, im.width, im.height)).tobytes())
                    for y in range(im.height):
                        for x in range(im.width):
                            r, g, b, a = im.getpixel((x, y))
                            if a and r > g * 1.12 and g > b * 1.1:
                                self.assertEqual(nova.getpixel((x, y)), (r, g, b, a))

    def test_vento_nao_corta_as_extremidades(self):
        im = self.original('canteiro')
        for q in range(4):
            nova = P.folhagem(im, q)
            for x in [0, im.width - 1]:
                self.assertEqual([nova.getpixel((x, y)) for y in range(im.height)],
                                 [im.getpixel((x, y)) for y in range(im.height)])
        self.assertNotEqual(P.folhagem(im, 1).tobytes(), im.tobytes())

    def test_suporte_das_ervas_do_interior_nao_balanca(self):
        folha = Image.open(P.SAIDA / 'interior/enfermaria/ervas/primavera.png').convert('RGBA')
        w = folha.width // 4
        base = folha.crop((0, 0, w, folha.height))
        for q in range(1, 4):
            quadro = folha.crop((q * w, 0, (q + 1) * w, folha.height))
            for y in range(base.height):
                for x in range(w):
                    r, g, b, a = base.getpixel((x, y))
                    if a and r > g * 1.12 and g > b * 1.1:
                        self.assertEqual(quadro.getpixel((x, y)), (r, g, b, a))

    def test_sprites_revisados_sem_resampling_e_sem_galinha_embutida(self):
        for nome in ['banco', 'galinheiro']:
            pasta = 'topdown' if nome == 'banco' else 'revisados'
            fonte = P.carregar(RAIZ / 'assets/cenario/cidade/decoracao/mobiliario' / pasta / (nome + '.png'))
            self.assertEqual(self.quadro(nome, 'primavera').tobytes(), fonte.tobytes())
            self.assertEqual(self.quadro(nome, 'inverno').size, fonte.size)
            self.assertNotEqual(self.quadro(nome, 'inverno').tobytes(), fonte.tobytes())
        # Os animais ficam num sprite próprio. O antigo canto com galinha
        # e palha agora é transparente; a construção ocupa o centro da fonte.
        coop = Image.open(RAIZ / 'assets/cenario/cidade/decoracao/mobiliario/revisados/galinheiro.png').convert('RGBA')
        self.assertIsNone(coop.crop((0, 36, 19, 64)).getbbox())

    def test_fachada_sem_buracos_no_jardim(self):
        original = Image.open(RAIZ / 'assets/cenario/cidade/casas/exterior/casa_bento.png').convert('RGBA')
        for estacao in ['primavera', 'verao', 'outono']:
            im = Image.open(P.SAIDA / 'fachada/casa_bento' / (estacao + '.png')).convert('RGBA')
            quadro = im.crop((0, 0, original.width, original.height))
            self.assertEqual(quadro.getchannel('A').tobytes(), original.getchannel('A').tobytes())

    def test_frente_detalhada_do_canteiro_preservada_no_frio(self):
        im = self.original('canteiro')
        inverno = P.canteiro_em_repouso(im)
        for y in range(round(im.height * .85), im.height):
            for x in range(im.width):
                r, g, b, a = im.getpixel((x, y))
                if a and r > g * 1.12 and g > b * 1.1:
                    self.assertEqual(inverno.getpixel((x, y)), (r, g, b, a))

    def test_plantas_e_buque_mudam_nas_quatro_estacoes(self):
        for nome in ['horta', 'canteiro', 'cerca']:
            with self.subTest(nome=nome):
                imagens = [self.quadro(nome, estacao).tobytes() for estacao in P.ESTACOES]
                self.assertEqual(len(set(imagens)), 4)

    def test_madeira_topdown_nao_recebe_tinta_de_folhagem(self):
        for nome in ['banco', 'mesa_piquenique', 'banco_piquenique_esquerdo', 'banco_piquenique_direito']:
            primavera = self.quadro(nome, 'primavera')
            for estacao in ['verao', 'outono']:
                self.assertEqual(self.quadro(nome, estacao).tobytes(), primavera.tobytes())

    def test_cadeira_mana_seed_nativa(self):
        fonte = Image.open(RAIZ / 'assets/cenario/Starter Pack/cozy furnishings sampler.png').convert('RGBA')
        cadeira = fonte.crop((16, 0, 32, 32))
        cadeira = cadeira.crop(cadeira.getbbox())
        nova = Image.open(P.MOVEIS_TOPDOWN / 'cadeira.png').convert('RGBA')
        nova = nova.crop(nova.getbbox())
        self.assertEqual(nova.getchannel('A').tobytes(), cadeira.getchannel('A').tobytes())
        for y in range(cadeira.height):
            for x in range(cadeira.width):
                if cadeira.getpixel((x, y))[3]:
                    self.assertEqual(nova.getpixel((x, y)), cadeira.getpixel((x, y)))


if __name__ == '__main__':
    unittest.main()
