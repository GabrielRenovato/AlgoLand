"""A revisão dos peitorais preserva os elmos aprovados e a geometria animada."""
import hashlib
import json
import unittest
from pathlib import Path
from PIL import Image

RAIZ=Path(__file__).resolve().parents[1]
IDS=['sentinela','batedor','guardiao_geada','templario_solar',
     'arauto_trovao','guardiao_esmeralda','soberano_astral']

class PeitoraisRevisados(unittest.TestCase):
    def test_outras_pecas_preservadas_pixel_a_pixel(self):
        for id in IDS:
            dados=json.loads((RAIZ/'arte/fontes/armaduras'/id/'peitorais_originais/contrato.json').read_text())
            for nome,esperado in dados['preservados'].items():
                revisao=RAIZ/'arte/fontes/armaduras'/id/'corrida_pernas/contrato.json'
                if revisao.exists():
                    esperado=json.loads(revisao.read_text())['arquivos_corrigidos'].get(nome,esperado)
                base=RAIZ/'arte/fontes/armaduras'/id/'base_elmo_frente/contrato.json'
                if nome=='raven_elmo/correr.png' and base.exists():
                    esperado=json.loads(base.read_text())['sha256_corrida_revisada']
                costas=RAIZ/'arte/fontes/armaduras'/id/'base_elmo_costas/contrato.json'
                if nome=='raven_elmo/correr.png' and costas.exists():
                    esperado=json.loads(costas.read_text())['sha256_corrida_revisada']
                with self.subTest(conjunto=id,arquivo=nome):
                    self.assertEqual(hashlib.sha256((RAIZ/'assets/personagens/conjuntos'/id/nome).read_bytes()).hexdigest(),esperado,'A revisão não pode alterar elmos, luvas ou botas')

    def test_mascara_de_todas_as_poses_preservada(self):
        for id in IDS:
            dados=json.loads((RAIZ/'arte/fontes/armaduras'/id/'peitorais_originais/contrato.json').read_text())
            for nome,esperado in dados['mascaras_peitoral'].items():
                revisao=RAIZ/'arte/fontes/armaduras'/id/'corrida_pernas/contrato.json'
                if nome=='raven_peitoral/correr.png' and revisao.exists():
                    esperado=json.loads(revisao.read_text())['mascara_peitoral_corrigida']
                with self.subTest(conjunto=id,arquivo=nome):
                    alfa=Image.open(RAIZ/'assets/personagens/conjuntos'/id/nome).convert('RGBA').getchannel('A').tobytes()
                    self.assertEqual(hashlib.sha256(alfa).hexdigest(),esperado,'Não deformar o corpo nem mudar o encaixe com as outras peças')

    def test_fontes_nativas_integradas_e_paleta_consistente(self):
        for id in IDS:
            with self.subTest(conjunto=id):
                pasta=RAIZ/'arte/fontes/armaduras'/id/'peitorais_originais'
                dados=json.loads((pasta/'contrato.json').read_text())
                self.assertEqual(hashlib.sha256((pasta/'peitorais_nativos.png').read_bytes()).hexdigest(),dados['sha256_fonte'])
                fonte=Image.open(pasta/'peitorais_nativos.png').convert('RGBA')
                self.assertEqual(fonte.size,(128,32))
                cores={tuple(bytes.fromhex(c))+(255,) for c in dados['paleta']}
                for cor in fonte.get_flattened_data():
                    self.assertTrue(cor[3]==0 or cor in cores)
                cfg=json.loads((RAIZ/'ferramentas/armaduras/em_preparacao'/id/'manifesto.json').read_text())
                self.assertEqual(cfg['arte_peitoral'],'res://'+str((pasta/'peitorais_nativos.png').relative_to(RAIZ)))
                for d in range(4):self.assertIsNotNone(fonte.crop((d*32,0,(d+1)*32,32)).getbbox())

if __name__=='__main__':unittest.main()
