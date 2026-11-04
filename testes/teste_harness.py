"""Regressões do harness: reuso inválido, processos órfãos e publicação adulterada."""
import base64
import hashlib
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'ferramentas/projeto'))
import harness
import harness_publicacao as pub


class Harness(unittest.TestCase):
    def setUp(self):
        self.temporario = tempfile.TemporaryDirectory()
        self.pasta = Path(self.temporario.name)
        self.addCleanup(self.temporario.cleanup)

    def repositorio(self):
        raiz = self.pasta / 'repo'
        raiz.mkdir()
        for args in [['init', '-q'], ['config', 'user.name', 'Teste'], ['config', 'user.email', 'teste@localhost']]:
            subprocess.run(['git', '-C', str(raiz), *args], check=True)
        (raiz / 'codigo').mkdir()
        (raiz / 'codigo/a.gd').write_text('base')
        subprocess.run(['git', '-C', str(raiz), 'add', '.'], check=True)
        subprocess.run(['git', '-C', str(raiz), 'commit', '-qm', 'base'], check=True)
        return raiz

    def test_perfil_selecionado_exige_escopo_e_preserva_selecao(self):
        with self.assertRaises(SystemExit) as erro:
            with patch('sys.stderr', new_callable=io.StringIO):
                harness.main(['testar', '--perfil', 'selecionado'])
        self.assertEqual(erro.exception.code, 2)
        with patch.object(harness, 'testar', return_value=0) as executar:
            self.assertEqual(harness.main(['testar', '--perfil', 'selecionado', '--teste', 'inventario']), 0)
            self.assertEqual(executar.call_args.args[0].teste, ['inventario'])

    def test_resumo_nao_sobrescreve_trabalho_nem_certifica_teste_antigo(self):
        destino = self.pasta / 'retomar.txt'
        with patch.object(harness, 'alterados', return_value=['codigo/a.gd']), patch.object(harness, 'git', return_value=b'abc123\n'):
            self.assertEqual(harness.main(['retomar', '--objetivo', 'Corrigir inventário', '--pendente', 'Revisar tela', '--saida', str(destino)]), 0)
            texto = destino.read_text()
            self.assertIn('Revisar tela', texto)
            self.assertIn('confirmação do harness', texto)
            self.assertIn('não transfere autorização', texto)
            with patch('sys.stderr', new_callable=io.StringIO):
                self.assertEqual(harness.main(['retomar', '--objetivo', 'Outro', '--saida', str(destino)]), 1)
            self.assertEqual(destino.read_text(), texto)

    def test_cache_invalida_conteudo_staged_recurso_novo_e_motor(self):
        raiz = self.repositorio()
        fp = lambda motor='Godot 4': harness.assinatura(raiz, motor, {'perfil': 'web'})
        original = fp()
        (raiz / 'codigo/a.gd').write_text('alterado')
        alterado = fp()
        self.assertNotEqual(original, alterado)
        subprocess.run(['git', '-C', str(raiz), 'add', 'codigo/a.gd'], check=True)
        self.assertEqual(alterado, fp())
        subprocess.run(['git', '-C', str(raiz), 'commit', '-qm', 'alterado'], check=True)
        self.assertEqual(alterado, fp(), 'Commit dos mesmos bytes não deve repetir o teste')
        (raiz / 'assets').mkdir()
        (raiz / 'assets/fonte nova.ttf').write_bytes(b'recurso')
        self.assertNotEqual(alterado, fp())
        self.assertNotEqual(fp(), fp('Godot outro'))
        (raiz / 'assets/fonte nova.ttf').unlink()
        (raiz / 'codigo/a.gd').unlink()
        self.assertNotEqual(alterado, fp())

    def test_cache_nao_aceita_falha_relatorio_ausente_ou_captura_perdida(self):
        indice, relatorio, foto = [self.pasta / n for n in ['indice.json', 'relatorio.json', 'foto.png']]
        r = {'assinatura': 'abc', 'aprovado': True, 'estado_preservado': True, 'revisao_visual': 'pendente', 'capturas': [str(foto)]}
        harness.gravar(indice, {'assinatura': 'abc', 'aprovado': True, 'relatorio': str(relatorio)})
        self.assertIsNone(harness.cache_valido(indice, 'abc'))
        harness.gravar(relatorio, r)
        self.assertIsNone(harness.cache_valido(indice, 'abc'))
        foto.write_bytes(b'png')
        self.assertIsNotNone(harness.cache_valido(indice, 'abc'))
        self.assertIsNone(harness.cache_valido(indice, 'outra'))
        harness.gravar(relatorio, dict(r, aprovado=False))
        self.assertIsNone(harness.cache_valido(indice, 'abc'))
        harness.gravar(relatorio, dict(r, estado_preservado=False))
        self.assertIsNone(harness.cache_valido(indice, 'abc'))

    def test_falha_fatal_interrompe_par_sem_deixar_ator_esperando(self):
        comandos = {
            'host': [sys.executable, '-c', 'print("SCRIPT ERROR: falha simulada",flush=True); import time; time.sleep(30)'],
            'convidado': [sys.executable, '-c', 'print("OK iniciou",flush=True); import time; time.sleep(30)'],
        }
        inicio = time.monotonic()
        resultados = harness.executar_par(comandos, self.pasta, 10)
        self.assertLess(time.monotonic() - inicio, 5)
        self.assertTrue(all(not r['aprovado'] and r['interrompido'] for r in resultados))
        self.assertTrue(any(r['erros'] for r in resultados))

    def test_timeout_e_saida_sem_verificacao_nao_passam(self):
        resultados = harness.executar_par({'host': [sys.executable, '-c', 'import time; time.sleep(30)']}, self.pasta, 0.2)
        self.assertTrue(resultados[0]['timeout'])
        self.assertFalse(resultados[0]['aprovado'])
        resultados = harness.executar_par({'host': [sys.executable, '-c', 'pass']}, self.pasta, 2)
        self.assertFalse(resultados[0]['aprovado'])


class Publicacao(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.chaves = tempfile.TemporaryDirectory()
        cls.privada = Path(cls.chaves.name) / 'privada.pem'
        subprocess.run(['openssl', 'genpkey', '-algorithm', 'RSA', '-pkeyopt', 'rsa_keygen_bits:1024', '-out', str(cls.privada)], check=True, capture_output=True)
        cls.publica = subprocess.check_output(['openssl', 'pkey', '-in', str(cls.privada), '-pubout'], text=True)

    @classmethod
    def tearDownClass(cls):
        cls.chaves.cleanup()

    def assinar(self, dados):
        r = subprocess.run(['openssl', 'dgst', '-sha256', '-sign', str(self.privada)], input=dados, check=True, capture_output=True)
        return base64.b64encode(r.stdout).decode()

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.raiz = Path(self.temp.name) / 'jogo'
        self.wiki = Path(self.temp.name) / 'wiki'
        self.publicos = self.wiki / 'public/jogar'
        (self.raiz / 'codigo/globais').mkdir(parents=True)
        (self.publicos / 'atualizacao').mkdir(parents=True)
        (self.raiz / 'project.godot').write_text('config/version="1.0"\n')
        (self.raiz / 'codigo/globais/atualizacao_chave.gd').write_text('const PUBLICA := """' + self.publica + '"""')
        dados = b'GDPC' + b'x' * 80
        (self.publicos / 'atualizacao/area.pck').write_bytes(dados)
        pacote = {'id': 'area', 'arquivo': 'area.pck', 'tamanho': len(dados), 'sha256': hashlib.sha256(dados).hexdigest(), 'assinatura': self.assinar(dados)}
        self.manifestos = {p: {'formato': 2, 'app_base': '1.0', 'plataforma': p, 'conteudo': 3, 'pacotes': [pacote]} for p in ['android', 'windows', 'linux']}
        self.gravar_envelopes()
        dados_web = b'jogo web'
        (self.publicos / 'dados.part').write_bytes(dados_web)
        h = hashlib.sha256(dados_web).hexdigest()
        (self.publicos / 'manifesto.json').write_text(json.dumps({'versao': h[:12], 'sha256': h, 'pacote': len(dados_web), 'partes': [{'arquivo': 'dados.part', 'tamanho': len(dados_web)}]}))
        for n in ['carregar.js', 'sw.js', 'index.js', 'index.wasm']:
            (self.publicos / n).write_text(h[:12])

    def gravar_envelopes(self):
        envelopes = {'pacotes': {}}
        for p, m in self.manifestos.items():
            dados = json.dumps(m)
            envelopes['pacotes'][p] = {'1.0': {'dados': dados, 'assinatura': self.assinar(dados.encode())}}
        (self.publicos / 'atualizacao/versao.json').write_text(json.dumps(envelopes))

    def test_publicacao_integra_passou_com_assinaturas_reais(self):
        r, _, _ = pub.validar_local(self.raiz, self.wiki)
        self.assertEqual(r['conteudo'], 3)
        self.assertEqual(len(r['plataformas']), 3)

    def test_hash_web_adulterado_e_casca_nao_processada_falham(self):
        (self.publicos / 'dados.part').write_bytes(b'Jogo web')
        with self.assertRaisesRegex(ValueError, 'Hash/tamanho'): pub.validar_local(self.raiz, self.wiki)
        (self.publicos / 'dados.part').write_bytes(b'jogo web')
        (self.publicos / 'sw.js').write_text('__REVISAO_CASCA__')
        with self.assertRaisesRegex(ValueError, 'marcador'): pub.validar_local(self.raiz, self.wiki)

    def test_assinatura_invalida_nao_e_aceita(self):
        p = self.publicos / 'atualizacao/versao.json'
        j = json.loads(p.read_text())
        j['pacotes']['android']['1.0']['dados'] += ' '
        p.write_text(json.dumps(j))
        with self.assertRaisesRegex(ValueError, 'Assinatura RSA'): pub.validar_local(self.raiz, self.wiki)

    def test_geracao_desalinhada_e_caminho_fora_da_pasta_falham(self):
        self.manifestos['linux']['conteudo'] = 4
        self.gravar_envelopes()
        with self.assertRaisesRegex(ValueError, 'números de conteúdo diferentes'): pub.validar_local(self.raiz, self.wiki)
        self.manifestos['android']['pacotes'][0]['arquivo'] = '../fora.pck'
        self.gravar_envelopes()
        with self.assertRaisesRegex(ValueError, 'Nome de arquivo'): pub.validar_local(self.raiz, self.wiki)

    def test_pacote_corrompido_e_remoto_diferente_falham(self):
        (self.publicos / 'atualizacao/area.pck').write_bytes(b'corrompido')
        with self.assertRaisesRegex(ValueError, 'Tamanho/hash'): pub.validar_local(self.raiz, self.wiki)
        with patch.object(pub.urllib.request, 'urlopen', return_value=io.BytesIO(b'outro')):
            with self.assertRaisesRegex(ValueError, 'remoto divergente'):
                pub.verificar_remotos('http://localhost/', {'a': {'tamanho': 5, 'sha256': '0' * 64}})


if __name__ == '__main__':
    unittest.main()
