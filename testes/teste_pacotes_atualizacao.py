"""Testa o formato de publicação e prepara um jogo mínimo para a prova no motor."""
import base64
import hashlib
import json
import re
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
from types import SimpleNamespace
from contextlib import redirect_stdout
import io

RAIZ = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(RAIZ / 'ferramentas/atualizacao'))
from pacotes import Entrada, area, dividir, escrever_pck, ler_pck
import gerar_atualizacao as gerador


class Pacotes(unittest.TestCase):
    def test_roundtrip_remocao_e_binario(self):
        with tempfile.TemporaryDirectory() as pasta:
            p = Path(pasta) / 'teste.pck'
            entradas = {'codigo/a.gdc': Entrada(bytes(range(256))), 'removido.txt': Entrada(b'', 2)}
            escrever_pck(p, entradas)
            self.assertEqual(ler_pck(p), entradas)
            primeiro = p.read_bytes()
            escrever_pck(p, dict(reversed(list(entradas.items()))))
            self.assertEqual(p.read_bytes(), primeiro)

    def test_corrupcao(self):
        with tempfile.TemporaryDirectory() as pasta:
            p = Path(pasta) / 'teste.pck'
            escrever_pck(p, {'a': Entrada(b'1234')})
            b = bytearray(p.read_bytes()); b[-16] ^= 1; p.write_bytes(b)
            with self.assertRaises(ValueError): ler_pck(p)

    def test_areas_e_importados(self):
        base = {'assets/cenario/fazenda/a.png.import': Entrada(b'path="res://.godot/imported/a.ctex"'),
                'codigo/ui/a.gd.remap': Entrada(b'path="res://codigo/ui/a.gdc"')}
        grupos = dividir({'.godot/imported/a.ctex': Entrada(b'a'), 'codigo/ui/a.gdc': Entrada(b'b'),
                          'cenas/fendas/andar_02.tscn': Entrada(b'c')}, base)
        self.assertEqual(set(grupos), {'fazenda', 'interface', 'andar_02'})

    def test_hash_area_estavel(self):
        with tempfile.TemporaryDirectory() as pasta:
            a = {'codigo/ui/a.gdc': Entrada(b'interface'), 'cenas/fendas/andar_01.tscn': Entrada(b'antes')}
            hashes = []
            for valor in (b'antes', b'depois'):
                a['cenas/fendas/andar_01.tscn'] = Entrada(valor)
                p = Path(pasta) / 'interface.pck'
                escrever_pck(p, dividir(a)['interface'])
                hashes.append(hashlib.sha256(p.read_bytes()).hexdigest())
            self.assertEqual(*hashes)

    def test_nucleo_minimo(self):
        self.assertIn('res://codigo/globais/inicializacao_patches.gd', gerador.carregados_na_inicializacao())
        self.assertNotIn('res://codigo/globais/fazenda_dados.gd', gerador.carregados_na_inicializacao())
        projeto = (RAIZ / 'project.godot').read_text().split('[autoload]')[1].strip()
        self.assertTrue(projeto.startswith('InicializacaoPatches='))

    def test_publicacao_cumulativa_e_nucleo(self):
        with tempfile.TemporaryDirectory() as pasta:
            raiz = Path(pasta)
            base = raiz / 'base-linux-teste.pck'
            escrever_pck(base, {})
            base.with_suffix('.json').write_text('{}')
            privada = raiz / 'privada'; privada.touch()
            mudados = {'codigo/ui/a.gdc': Entrada(b'interface'), 'cenas/fendas/andar_01.tscn': Entrada(b'antes')}
            def exportar(args): escrever_pck(Path(args[2]), mudados)
            argumentos = SimpleNamespace(publicacao=str(raiz / 'publico'), app=None, url_app=None, apk=None, url_apk=None)
            with patch.multiple(gerador, BASES=raiz, PRIVADA=privada, PRESET='Linux',
                                checar_versoes=lambda: 'teste', nucleo_atual=lambda: {},
                                exportar=exportar, assinar=lambda p: 'assinatura-de-teste'), redirect_stdout(io.StringIO()):
                gerador.cmd_patch(argumentos)
                registro = raiz / 'publico/versao.json'
                primeira = json.loads(json.loads(registro.read_text())['pacotes']['linux']['teste']['dados'])
                mudados['cenas/fendas/andar_01.tscn'] = Entrada(b'depois')
                gerador.cmd_patch(argumentos)
                segunda = json.loads(json.loads(registro.read_text())['pacotes']['linux']['teste']['dados'])
                self.assertEqual(segunda['conteudo'], 2)
                self.assertEqual([p for p in primeira['pacotes'] if p['id'] == 'interface'],
                                 [p for p in segunda['pacotes'] if p['id'] == 'interface'])
                self.assertNotEqual(primeira['pacotes'][0]['sha256'], segunda['pacotes'][0]['sha256'])
                anterior = registro.read_bytes()
                mudados['addon/nativo.so'] = Entrada(b'nativo')
                with self.assertRaises(SystemExit): gerador.cmd_patch(argumentos)
                self.assertEqual(registro.read_bytes(), anterior)
                mudados.clear()
                gerador.cmd_patch(argumentos)
                terceira = json.loads(json.loads(registro.read_text())['pacotes']['linux']['teste']['dados'])
                self.assertEqual(terceira['pacotes'], [])
                base.with_suffix('.json').write_text('{"nucleo":"diferente"}')
                with self.assertRaises(SystemExit): gerador.cmd_patch(argumentos)


def preparar_motor(destino):
    destino.mkdir(parents=True, exist_ok=True)
    pasta = destino / 'codigo/globais'; pasta.mkdir(parents=True, exist_ok=True)
    for nome in ('inicializacao_patches.gd', 'atualizacao.gd'):
        (pasta / nome).write_text((RAIZ / 'codigo/globais' / nome).read_text())
    ui = destino / 'codigo/ui'; ui.mkdir(parents=True, exist_ok=True)
    for nome in ('estilo_inicio_detalhado.gd', 'estilo_interface.gd', 'fundo_interface_opaco.gdshader'):
        (ui / nome).write_text((RAIZ / 'codigo/ui' / nome).read_text())
    for alvo, origem in [(destino / 'assets', RAIZ / 'assets'),
                         (destino / '.godot/imported', RAIZ / '.godot/imported')]:
        alvo.parent.mkdir(parents=True, exist_ok=True)
        if not alvo.exists(): alvo.symlink_to(origem, target_is_directory=True)
    # Fixtures já usadas pelo editor têm diretório imported próprio. Vincula
    # apenas os binários referidos pelos estilos usados nesta tela.
    estilos = [pasta / 'atualizacao.gd', ui / 'estilo_inicio_detalhado.gd', ui / 'estilo_interface.gd']
    for estilo in estilos:
        for recurso in re.findall(r'preload\("res://([^"\n]+)"\)', estilo.read_text()):
            arquivo_import = RAIZ / (recurso + '.import')
            if not arquivo_import.exists(): continue
            for binario in re.findall(r'res://(\.godot/imported/[^"\n]+)', arquivo_import.read_text()):
                alvo = destino / binario
                if not alvo.exists() and (RAIZ / binario).exists():
                    alvo.symlink_to(RAIZ / binario)
    privada = destino / 'chave-teste.pem'
    subprocess.run(['openssl', 'genpkey', '-algorithm', 'RSA', '-pkeyopt', 'rsa_keygen_bits:2048', '-out', str(privada)], check=True, capture_output=True)
    publica = subprocess.run(['openssl', 'pkey', '-in', str(privada), '-pubout'], check=True, capture_output=True).stdout.decode()
    (pasta / 'atualizacao_chave.gd').write_text('extends RefCounted\nconst PUBLICA = """' + publica + '"""\n')
    def assinar(dados):
        arquivo = destino / 'assinar'; arquivo.write_bytes(dados)
        return base64.b64encode(subprocess.run(['openssl', 'dgst', '-sha256', '-sign', str(privada), str(arquivo)], check=True, capture_output=True).stdout).decode()
    servidor = destino / 'servidor'; servidor.mkdir(exist_ok=True)
    escrever_pck(servidor / 'area.pck', {'sentinela.gd': Entrada(b'extends Node\nconst VALOR = "patch antes dos autoloads"\n'),
        'tema.tres': Entrada(b'[gd_resource type="Theme" format=3]\n[resource]\ndefault_font_size = 18\n')})
    pacote = servidor / 'area.pck'
    descritor = {'id': 'interface', 'arquivo': 'area.pck', 'sha256': hashlib.sha256(pacote.read_bytes()).hexdigest(),
                 'tamanho': pacote.stat().st_size, 'assinatura': assinar(pacote.read_bytes())}
    def envelope(pacotes, numero=1):
        dados = json.dumps({'formato': 2, 'app_base': 'teste', 'plataforma': 'linux', 'conteudo': numero, 'pacotes': pacotes})
        return {'dados': dados, 'assinatura': assinar(dados.encode())}
    (servidor / 'envelope.json').write_text(json.dumps(envelope([descritor])))
    faltante = dict(descritor, id='faltante', arquivo='ausente.pck')
    (servidor / 'incompleto.json').write_text(json.dumps(envelope([descritor, faltante], 2)))
    invalidos = [envelope([dict(descritor, arquivo='../invalido.pck')]), envelope([descritor, descritor])]
    (servidor / 'invalidos.json').write_text(json.dumps(invalidos))
    (destino / 'tema.tres').write_text('[gd_resource type="Theme" format=3]\n[resource]\ndefault_font_size = 16\n')
    (destino / 'sentinela.gd').write_text('extends Node\nconst VALOR = "base"\n')
    (destino / 'project.godot').write_text('''config_version=5
[application]
config/name="AlgoLand testes pacotes"
config/version="teste"
config/use_custom_user_dir=true
config/custom_user_dir_name="AlgoLand testes pacotes CHAVE_TESTE"
[autoload]
InicializacaoPatches="*res://codigo/globais/inicializacao_patches.gd"
Sentinela="*res://sentinela.gd"
[display]
window/size/viewport_width=576
window/size/viewport_height=324
[gui]
theme/custom="res://tema.tres"
[rendering]
renderer/rendering_method="gl_compatibility"
'''.replace('CHAVE_TESTE', hashlib.sha256(publica.encode()).hexdigest()[:12]))
    (destino / 'atualizador_teste.gd').write_text('extends "res://codigo/globais/atualizacao.gd"\nvar encerrou := false\nvar remoto_teste := {}\nfunc _ready() -> void: _montar_interface()\nfunc _encerrar() -> void: encerrou = true\nfunc _ativa() -> bool: return true\nfunc _baixar_json(_url: String) -> Dictionary: return remoto_teste\n')
    (destino / 'teste.gd').write_text((RAIZ / 'ferramentas/atualizacao/teste_motor.gd').read_text())
    print('Projeto mínimo preparado:', destino)


if __name__ == '__main__':
    if len(sys.argv) == 3 and sys.argv[1] == '--preparar-motor':
        preparar_motor(Path(sys.argv[2]))
    else:
        unittest.main()
