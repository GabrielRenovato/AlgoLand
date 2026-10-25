"""O encaixe não pode reinterpretar a arte aprovada nem alterar os sets antigos."""
import hashlib
import json
import unittest
from pathlib import Path
from PIL import Image, ImageChops

RAIZ = Path(__file__).resolve().parents[1]
NOVOS = ['sentinela','batedor','guardiao_geada','templario_solar',
         'arauto_trovao','guardiao_esmeralda','soberano_astral']
ANTIGOS = ['carrasco','cavaleiro_rubro','cavalheiro']

class ElmosAprovados(unittest.TestCase):
    def test_fontes_identicas_a_imagem_aprovada(self):
        referencia=Image.open(RAIZ/'arte/previas/armaduras/elmos_aprovados/referencia_aprovada.png').convert('RGB')
        for i,id in enumerate(NOVOS):
            with self.subTest(conjunto=id):
                pasta=RAIZ/'arte/fontes/armaduras'/id/'elmos_originais'
                contrato=json.loads((pasta/'contrato.json').read_text())
                fonte=Image.open(pasta/'elmos_nativos.png').convert('RGBA')
                self.assertEqual(hashlib.sha256((pasta/'elmos_nativos.png').read_bytes()).hexdigest(),contrato['sha256_elmos_aprovados'])
                ampliada=Image.new('RGBA',fonte.size,(0,0,0,255))
                ampliada=Image.alpha_composite(ampliada,fonte).convert('RGB').resize((576,144),Image.Resampling.NEAREST)
                esperada=referencia.crop((0,i*144,576,(i+1)*144))
                self.assertIsNone(ImageChops.difference(ampliada,esperada).getbbox(),'A integração não pode retocar os visores ou alterar as cores aprovadas')
                cfg=json.loads((RAIZ/'ferramentas/armaduras/em_preparacao'/id/'manifesto.json').read_text())
                self.assertTrue(cfg['recortes']['elmo_nativo'])
                self.assertEqual(cfg['recortes']['borda_calota'],0)
                for d in range(4):
                    b=fonte.crop((d*24,0,(d+1)*24,24)).getbbox()
                    self.assertIsNotNone(b)
                    self.assertLessEqual(b[2]-b[0],14)
                    self.assertLessEqual(b[3]-b[1],16)

    def test_luvas_e_botas_anteriores_preservadas(self):
        for id in ANTIGOS+NOVOS:
            dados=json.loads((RAIZ/'arte/fontes/armaduras'/id/'contorno_pixellab/encaixes.json').read_text())
            for nome,esperado in dados['outros_slots'].items():
                if 'peitoral' in nome:continue
                revisao=RAIZ/'arte/fontes/armaduras'/id/'corrida_pernas/contrato.json'
                if revisao.exists():
                    esperado=json.loads(revisao.read_text())['arquivos_corrigidos'].get(nome,esperado)
                with self.subTest(conjunto=id,arquivo=nome):
                    self.assertEqual(hashlib.sha256((RAIZ/'assets/personagens/conjuntos'/id/nome).read_bytes()).hexdigest(),esperado)

    def test_escopo_nao_altera_conjuntos_antigos(self):
        dados=json.loads((RAIZ/'arte/fontes/armaduras/elmos_aprovados_escopo.json').read_text())
        for nome,esperado in dados.items():
            with self.subTest(arquivo=nome):
                self.assertEqual(hashlib.sha256((RAIZ/nome).read_bytes()).hexdigest(),esperado)

if __name__=='__main__':unittest.main()
