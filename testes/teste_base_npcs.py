"""A base preserva a animação aceita e reproduz todas as saídas do morador."""
import importlib.util
import json
from pathlib import Path
import unittest

from PIL import Image

RAIZ = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('gerar_npc', RAIZ/'ferramentas/npcs/gerar_npc.py')
gerador = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gerador)


class BaseMoradores(unittest.TestCase):
    def setUp(self):
        self.perfil = json.loads((gerador.FONTES/'perfis/ivo.json').read_text())
        self.base = json.loads((gerador.FONTES/self.perfil['base']).read_text())

    def test_saidas_reproduziveis(self):
        gerador.gerar('ivo', verificar=True)

    def test_materiais_preservam_cada_pose_e_pivo(self):
        montada = gerador.montar(self.base, self.perfil)
        referencia = Image.open(gerador.FONTES/'corpo_avental.png').convert('RGBA')
        self.assertEqual(montada.getchannel('A').tobytes(), referencia.getchannel('A').tobytes())
        self.assertFalse(any(c[3] and max(c[:3]) < 40 for c in montada.get_flattened_data()))
        # A nova roupa não converte a caminhada em uma sequência de imagens paradas.
        for linha in range(4):
            quadros = {montada.crop((c*64, linha*64, (c+1)*64, (linha+1)*64)).tobytes() for c in range(1, 7)}
            self.assertGreater(len(quadros), 3)

    def test_sentar_comeca_na_mesma_pose_sem_trocar_personagem(self):
        folha = gerador.montar(self.base, self.perfil)
        for costas, linha in [(False, 0), (True, 2)]:
            sentado = gerador.sentar(folha, self.base, costas)
            self.assertEqual(sentado.crop((0, 0, 64, 64)).tobytes(), folha.crop((0, linha*64, 64, (linha+1)*64)).tobytes())
            self.assertNotEqual(sentado.crop((0, 0, 64, 64)).tobytes(), sentado.crop((512, 0, 576, 64)).tobytes())

    def test_rejeita_base_fora_da_grade_e_id_invalido(self):
        self.base['quadro'] = [32, 64]
        with self.assertRaises(ValueError):
            gerador.montar(self.base, self.perfil)
        with self.assertRaises(ValueError):
            gerador.gerar('../ivo', verificar=True)

    def test_trabalho_nativo_sem_cortar_martelo_ou_deslocar_pes(self):
        for nome, dados in self.perfil['trabalho'].items():
            folha = Image.open(RAIZ/('assets/npcs/cidade/trabalho/ivo_'+nome+'.png')).convert('RGBA')
            self.assertEqual(folha.size, (dados['quadros']*64,64))
            desenhos = set()
            for i in range(dados['quadros']):
                quadro = folha.crop((i*64,0,(i+1)*64,64))
                caixa = quadro.getbbox()
                self.assertTrue(caixa and caixa[0] > 0 and caixa[1] > 0 and caixa[2] < 64)
                self.assertLessEqual(abs(caixa[3]-self.base['pes_y']),1)
                self.assertTrue(all(c[3] in (0,255) for c in quadro.get_flattened_data()))
                desenhos.add(quadro.tobytes())
            self.assertGreaterEqual(len(desenhos),3)


if __name__ == '__main__':
    unittest.main()
