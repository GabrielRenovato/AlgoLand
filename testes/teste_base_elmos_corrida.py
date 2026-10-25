"""As linhas da base somem sem mudar crista, visor ou outras direções."""
import hashlib
import json
import unittest
from PIL import Image
from testes.apoio_base_elmos import RAIZ, revisar_base

IDS=['sentinela','batedor','guardiao_geada','templario_solar','arauto_trovao','guardiao_esmeralda','soberano_astral']

class BasesElmos(unittest.TestCase):
    def test_revisao_costas_preserva_frente_e_perfis(self):
        for id in IDS:
            pasta=RAIZ/'arte/fontes/armaduras'/id
            anterior=Image.open(pasta/'base_elmo_frente/elmos_base_limpa.png').convert('RGBA')
            caminho=pasta/'base_elmo_costas/elmos_base_limpa.png'
            nova=Image.open(caminho).convert('RGBA')
            dados=json.loads((pasta/'base_elmo_costas/contrato.json').read_text())
            self.assertEqual(hashlib.sha256(caminho.read_bytes()).hexdigest(),dados['sha256_fonte_revisada'])
            for y in range(24):
                for x in range(96):
                    a,b=anterior.getpixel((x,y)),nova.getpixel((x,y))
                    if a!=b:
                        self.assertTrue(24<=x<48 and y>=16,'Somente a base da vista de costas pode mudar')
                        self.assertEqual(a[3],255)
                        self.assertEqual(b[3],0)
            for y,esquerda,direita in [(16,7,16),(17,8,15),(18,9,14),(19,10,13)]:
                for x in range(24):
                    if not esquerda<=x<=direita:self.assertEqual(nova.getpixel((24+x,y))[3],0,'Sem barra larga sob a nuca: '+id)

    def test_revisao_limitada_as_pontas_da_base_frontal(self):
        for id in IDS:
            pasta=RAIZ/'arte/fontes/armaduras'/id
            original=Image.open(pasta/'elmos_originais/elmos_nativos.png').convert('RGBA')
            nova=Image.open(pasta/'base_elmo_frente/elmos_base_limpa.png').convert('RGBA')
            dados=json.loads((pasta/'base_elmo_frente/contrato.json').read_text())
            self.assertEqual(hashlib.sha256((pasta/'base_elmo_frente/elmos_base_limpa.png').read_bytes()).hexdigest(),dados['sha256_fonte_revisada'])
            self.assertEqual(original.size,nova.size)
            for y in range(24):
                for x in range(96):
                    a,b=original.getpixel((x,y)),nova.getpixel((x,y))
                    if a!=b:
                        self.assertLess(x,24)
                        self.assertGreaterEqual(y,16)
                        self.assertEqual(a[3],255)
                        self.assertEqual(b[3],0)
            for y,esquerda,direita in [(16,7,16),(17,8,15),(18,9,14),(19,10,13)]:
                for x in range(24):
                    if not esquerda<=x<=direita:self.assertEqual(nova.getpixel((x,y))[3],0,'Sem barra larga sob a chapa: '+id)

    def test_seis_quadros_sem_mudar_pivo_ou_outras_poses(self):
        for id in IDS:
            pasta=RAIZ/'arte/fontes/armaduras'/id
            antes=Image.open(pasta/'corrida_pernas/antes_elmo.png').convert('RGBA')
            depois=Image.open(RAIZ/'assets/personagens/conjuntos'/id/'raven_elmo/correr.png').convert('RGBA')
            self.assertEqual(revisar_base(id,antes).tobytes(),depois.tobytes(),id)
            for d in [1,3]:
                self.assertEqual(antes.crop((0,d*80,480,(d+1)*80)).tobytes(),depois.crop((0,d*80,480,(d+1)*80)).tobytes())
            for d in [0,2]:
                for q in range(6):
                    a=antes.crop((q*80,d*80,(q+1)*80,(d+1)*80)).getbbox()
                    b=depois.crop((q*80,d*80,(q+1)*80,(d+1)*80)).getbbox()
                    self.assertEqual(a[:3],b[:3],'Limpar a base não pode recentralizar ou subir a cabeça')
