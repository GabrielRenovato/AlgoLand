#!/usr/bin/env python3
"""Gera patches cumulativos por área para Android, Windows e Linux.

Registre a base por plataforma junto do aplicativo exportado. Depois publique
os pacotes e versao.json assinados. O núcleo fixo exige novo aplicativo.
"""
import argparse
import base64
import hashlib
import json
import re
import shutil
import subprocess
import sys
from pacotes import ler_pck, escrever_pck, dividir
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
PRIVADA = Path.home() / '.config/algoland/atualizacao_privada.pem'
CHAVE_GD = RAIZ / 'codigo/globais/atualizacao_chave.gd'
BASES = RAIZ / 'builds/atualizacao'
PUBLICACAO = RAIZ.parent / 'AlgoLand-wiki/public/jogar/atualizacao'
GODOT = ['flatpak', 'run', '--filesystem=/tmp', 'org.godotengine.Godot']
PRESET = 'Android'


def versao_projeto() -> str:
    m = re.search(r'^config/version="([^"]*)"', (RAIZ / 'project.godot').read_text(), re.M)
    if not m:
        sys.exit('project.godot não tem application/config/version')
    return m.group(1)


def versao_preset() -> str:
    t = (RAIZ / 'export_presets.cfg').read_text()
    i = t.index(f'name="{PRESET}"')
    m = re.search(r'^version/name="([^"]*)"', t[i:], re.M)
    return m.group(1) if m else ''


def checar_versoes() -> str:
    v = versao_projeto()
    if PRESET == "Android" and versao_preset() != v:
        sys.exit(f'Versões diferentes: project.godot={v} e preset {PRESET}={versao_preset()}. Deixe as duas iguais antes de exportar.')
    return v


def exportar(args: list[str]) -> None:
    subprocess.run(GODOT + ['--headless', '--path', str(RAIZ)] + args, check=True)


def listar_pck(caminho: Path) -> list[str]:
    """Caminhos dos arquivos de um .pck (formatos 2, 3 e 4 do Godot 4)."""
    return list(ler_pck(caminho))


def normalizar(caminho: str) -> str:
    """Do que está no pacote para o arquivo-fonte do projeto."""
    for sufixo in ('.remap', '.import'):
        if caminho.endswith(sufixo):
            caminho = caminho[:-len(sufixo)]
    return caminho


NUCLEO = {
    'res://codigo/globais/inicializacao_patches.gd',
    'res://codigo/globais/atualizacao.gd',
    'res://codigo/globais/atualizacao_chave.gd',
    'res://cenas/atualizacao.tscn',
    'res://project.godot', 'res://project.binary',
    'res://default_bus_layout.tres',
}


def carregados_na_inicializacao() -> set[str]:
    # O primeiro autoload monta a geração ANTES de carregar os demais scripts.
    return NUCLEO.copy()


def identidade() -> str:
    return {'Android': 'android', 'Windows Desktop': 'windows', 'Linux': 'linux'}[PRESET]


def caminho_base(v: str) -> Path:
    return BASES / f'base-{identidade()}-{v}.pck'


def nucleo_atual() -> dict[str, str]:
    caminhos = [RAIZ / nome.removeprefix('res://') for nome in NUCLEO]
    caminhos.append(RAIZ / 'export_presets.cfg')
    return {str(p.relative_to(RAIZ)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in caminhos if p.is_file()}


def cmd_chave(_: argparse.Namespace) -> None:
    if not PRIVADA.exists():
        PRIVADA.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(['openssl', 'genpkey', '-algorithm', 'RSA', '-pkeyopt', 'rsa_keygen_bits:2048', '-out', str(PRIVADA)], check=True)
        PRIVADA.chmod(0o600)
        print('Chave privada criada em', PRIVADA, '(guarde um backup; sem ela não há como assinar patches)')
    publica = subprocess.run(['openssl', 'pkey', '-in', str(PRIVADA), '-pubout'], check=True, capture_output=True, text=True).stdout
    CHAVE_GD.write_text('extends RefCounted\n\n## Chave pública que confere a assinatura dos patches (gerada por ferramentas/atualizacao/gerar_atualizacao.py chave).\n'
                        'const PUBLICA := """' + publica.strip() + '\n"""\n')
    print('Chave pública gravada em', CHAVE_GD.relative_to(RAIZ), '— o próximo APK precisa dela.')


def cmd_base(_: argparse.Namespace) -> None:
    v = checar_versoes()
    BASES.mkdir(parents=True, exist_ok=True)
    destino = caminho_base(v)
    exportar(['--export-pack', PRESET, str(destino)])
    destino.with_suffix('.json').write_text(json.dumps(nucleo_atual(), sort_keys=True))
    print('Base guardada:', destino)


def assinar(arquivo: Path) -> str:
    return base64.b64encode(subprocess.run(['openssl', 'dgst', '-sha256', '-sign', str(PRIVADA), str(arquivo)], check=True, capture_output=True).stdout).decode()


def cmd_patch(a: argparse.Namespace) -> None:
    v = checar_versoes()
    if not PRIVADA.exists():
        sys.exit('Falta a chave privada: rode "chave" primeiro.')
    base = caminho_base(v)
    if not base.exists():
        sys.exit(f'Falta {base}: rode "base" na hora de exportar o aplicativo dessa versão.')
    registro_base = base.with_suffix('.json')
    if not registro_base.exists() or json.loads(registro_base.read_text()) != nucleo_atual():
        sys.exit('Núcleo/configuração diferente da base: exporte um aplicativo novo e registre a base novamente.')
    destino_pub = Path(a.publicacao)
    destino_pub.mkdir(parents=True, exist_ok=True)
    registro = destino_pub / 'versao.json'
    versao = json.loads(registro.read_text()) if registro.exists() else {'apk': v, 'url_apk': '', 'patches': {}}
    anterior = versao.setdefault('pacotes', {}).get(identidade(), {}).get(v, {})
    numero = int(json.loads(anterior.get('dados', '{}')).get('conteudo', 0)) + 1
    nome = f'patch-{identidade()}-{v}-{numero}.pck'
    temporario = BASES / nome
    exportar(['--export-patch', PRESET, str(temporario), '--patches', str(base)])
    with base.open('rb') as origem, temporario.open('rb') as novo:
        if origem.read(20) != novo.read(20):
            temporario.unlink()
            sys.exit('Versão/formato do motor diferente da base: exporte um aplicativo novo.')
    mudados = {normalizar('res://' + c.removeprefix('res://')) for c in listar_pck(temporario)}
    if not mudados and not anterior:
        temporario.unlink()
        sys.exit('Nada mudou em relação à base: sem patch.')
    bloqueados = sorted((mudados & carregados_na_inicializacao()) |
                        {p for p in mudados if p.endswith(('.dll', '.so', '.dylib', '.gdextension'))})
    if bloqueados:
        temporario.unlink()
        print('Este patch altera arquivos carregados na inicialização, do núcleo fixo:')
        for b in bloqueados[:40]:
            print('  ', b)
        sys.exit('Gere um aplicativo novo (e rode "base" de novo) ou desfaça essas mudanças.')
    entradas = ler_pck(temporario)
    pacotes = []
    for area_id, arquivos in sorted(dividir(entradas, ler_pck(base)).items()):
        provisoria = BASES / f'area-{area_id}.pck'
        escrever_pck(provisoria, arquivos)
        hash_pacote = hashlib.sha256(provisoria.read_bytes()).hexdigest()
        nome_area = f'{identidade()}-{v}-{area_id}-{hash_pacote}.pck'
        publicado = destino_pub / nome_area
        shutil.move(str(provisoria), str(publicado))
        pacotes.append({'id': area_id, 'arquivo': nome_area, 'tamanho': publicado.stat().st_size,
                        'sha256': hash_pacote, 'assinatura': assinar(publicado)})
    temporario.unlink()
    manifesto = {'formato': 2, 'app_base': v, 'plataforma': identidade(), 'conteudo': numero, 'pacotes': pacotes}
    dados_manifesto = json.dumps(manifesto, sort_keys=True, separators=(',', ':'))
    arquivo_manifesto = BASES / 'manifesto-assinar.json'
    arquivo_manifesto.write_bytes(dados_manifesto.encode())
    versao.setdefault('pacotes', {}).setdefault(identidade(), {})[v] = {
        'dados': dados_manifesto, 'assinatura': assinar(arquivo_manifesto),
    }
    arquivo_manifesto.unlink()

    if a.app or a.url_app:
        versao.setdefault('aplicativos', {})[identidade()] = {'versao': a.app or v, 'url': a.url_app or ''}
    if a.apk:
        versao['apk'] = a.apk
    if a.url_apk is not None:
        versao['url_apk'] = a.url_apk
    temporario_json = registro.with_suffix('.tmp')
    temporario_json.write_text(json.dumps(versao, indent=2) + '\n')
    temporario_json.replace(registro)
    print(f'Conteúdo {numero} ({identidade()}) para {v}: {len(mudados)} arquivos em {len(pacotes)} pacotes')
    print('Publicado em', destino_pub, '— falta enviar o site (wiki) para a hospedagem.')


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest='cmd', required=True)
    sub.add_parser('chave').set_defaults(f=cmd_chave)
    b = sub.add_parser('base')
    b.add_argument('--preset', choices=['Android', 'Windows Desktop', 'Linux'], default='Android')
    b.set_defaults(f=cmd_base)
    q = sub.add_parser('patch')
    q.add_argument('--preset', choices=['Android', 'Windows Desktop', 'Linux'], default='Android')
    q.add_argument('--publicacao', default=str(PUBLICACAO))
    q.add_argument('--app', help='versão mais nova do aplicativo desta plataforma')
    q.add_argument('--url-app', help='link do instalador desta plataforma')
    q.add_argument('--apk', help='versão do APK mais novo disponível (avisa quem está numa versão antiga)')
    q.add_argument('--url-apk', dest='url_apk', help='link para baixar o APK mais novo')
    q.set_defaults(f=cmd_patch)
    a = p.parse_args()
    global PRESET
    PRESET = getattr(a, 'preset', 'Android')
    a.f(a)


if __name__ == '__main__':
    main()
