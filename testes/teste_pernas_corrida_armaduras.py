"""Os pés recolhidos devem pertencer às botas, com o resto da arte preservado."""
from pathlib import Path
import json
import unittest
from PIL import Image
from testes.apoio_base_elmos import revisar_base

RAIZ=Path(__file__).resolve().parents[1]
IDS=['sentinela','batedor','guardiao_geada','templario_solar',
     'arauto_trovao','guardiao_esmeralda','soberano_astral']
PECAS=['elmo','peitoral','luvas','botas']

def ler(id):
    pasta=RAIZ/'arte/fontes/armaduras'/id/'corrida_pernas'
    antes={p:Image.open(pasta/f'antes_{p}.png').convert('RGBA') for p in PECAS}
    antes['elmo']=revisar_base(id,antes['elmo'])
    depois={p:Image.open(RAIZ/'assets/personagens/conjuntos'/id/f'raven_{p}/correr.png').convert('RGBA') for p in PECAS}
    return pasta,antes,depois

class PernasCorrida(unittest.TestCase):
    def test_elmo_tronco_e_outras_direcoes_intactos(self):
        corpo=Image.open(RAIZ/'assets/personagens/raven_fantasy/corrida_mana_seed/corpo_0.png').convert('RGBA')
        for id in IDS:
            pasta,antes,depois=ler(id)
            guia=json.loads((pasta/'contrato.json').read_text())
            with self.subTest(conjunto=id):
                self.assertEqual(antes['elmo'].tobytes(),depois['elmo'].tobytes())
                for p in PECAS:
                    self.assertEqual(antes[p].crop((0,80,480,320)).tobytes(),depois[p].crop((0,80,480,320)).tobytes(),'Não alterar outras direções')
                    for q,quadril in enumerate(guia['limites_quadril']):
                        reg=(q*80,0,(q+1)*80,quadril+1)
                        self.assertEqual(antes[p].crop(reg).tobytes(),depois[p].crop(reg).tobytes(),'Preservar peito, rosto e braços acima do quadril')
                    for y in range(80):
                        for x in range(480):
                            if antes[p].getpixel((x,y))!=depois[p].getpixel((x,y)):
                                self.assertTrue(corpo.getpixel((x,y))[3]>0,'Não adicionar rastro fora do corpo')

    def test_solado_recolhido_nao_pertence_ao_peitoral_ou_luvas(self):
        for id in IDS:
            _,_,depois=ler(id)
            with self.subTest(conjunto=id):
                for q in [2,5]:
                    for x,y in [(39,39),(40,39),(39,40),(40,40)]:
                        pos=(q*80+x,y)
                        self.assertGreater(depois['botas'].getpixel(pos)[3],0,'O pé central é uma bota')
                        self.assertEqual(depois['peitoral'].getpixel(pos)[3],0,'Sem faixa do peitoral esticada na canela')
                        self.assertEqual(depois['luvas'].getpixel(pos)[3],0,'O solado não pode receber a textura da manopla')

    def test_silhueta_composta_preservada_e_pecas_exclusivas(self):
        for id in IDS:
            _,antes,depois=ler(id)
            with self.subTest(conjunto=id):
                a=Image.new('RGBA',(480,320));b=Image.new('RGBA',(480,320))
                for p in PECAS:
                    a=Image.alpha_composite(a,antes[p]);b=Image.alpha_composite(b,depois[p])
                self.assertEqual(a.getchannel('A').tobytes(),b.getchannel('A').tobytes(),'Preservar a pose, sem engrossar ou apagar pernas')
                for y in range(80):
                    for x in range(480):
                        self.assertLessEqual(sum(depois[p].getpixel((x,y))[3]>0 for p in PECAS),1,'Uma peça por pixel')

if __name__=='__main__':unittest.main()
