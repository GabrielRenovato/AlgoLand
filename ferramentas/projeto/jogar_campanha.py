#!/usr/bin/env python3
"""Abre o percurso experimental numa cópia do projeto com dados separados em /tmp."""
import argparse
import os
import socket
import time
from pathlib import Path
import re
import subprocess
from preparar_testes import preparar
from harness import motor_godot, encerrar
from testar_coop import executar


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--pasta', type=Path, default=Path('/tmp/algoland-campanha-jogavel'))
    parser.add_argument('--regiao', help='Abre direto nesta região (chegada, estrada, vila ou pomar), sem passar pelo seletor.')
    parser.add_argument('--lobby-ws', help='Servidor compartilhado; usa o endereço público do jogo por padrão.')
    parser.add_argument('--local', action='store_true', help='Usa um servidor local descartável para desenvolvimento.')
    args = parser.parse_args()
    base = args.pasta.expanduser().resolve()
    projeto = preparar(base / 'projeto')
    p = projeto / 'project.godot'
    texto = re.sub(r'^config/(?:use_custom_user_dir|custom_user_dir_name)=.*\n', '', p.read_text(), flags=re.M)
    texto = texto.replace('[application]', '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="AlgoLand testes campanha jogavel"', 1)
    p.write_text(texto)
    motor, _ = motor_godot(base)
    log = base / 'importacao.log'
    resultado = executar(motor + ['--headless', '--editor', '--path', str(projeto), '--import', '--quit'], log, 180)
    if not resultado['aprovado']:
        print('Falha na importação; log:', log)
        return 1
    print('Protótipo isolado; dados e logs:', base, flush=True)
    servidor = None
    fluxo = None
    url = args.lobby_ws or (None if args.local else 'wss://algoland-duelo.fly.dev')
    try:
        if not url:
            with socket.socket() as reserva:
                reserva.bind(('127.0.0.1', 0))
                porta = reserva.getsockname()[1]
            fluxo = (base / 'salas.log').open('w')
            ambiente = dict(os.environ, PORTA=str(porta), ADMIN_PORTA='0', EXIGIR_CONTA='0', SUPABASE_URL='', SUPABASE_CHAVE='')
            servidor = subprocess.Popen(['node', str(Path(__file__).resolve().parents[1] / 'lobby/servidor/servidor.mjs')], env=ambiente, stdout=fluxo, stderr=subprocess.STDOUT, start_new_session=True)
            prazo = time.monotonic()+10
            while True:
                if servidor.poll() is not None: raise RuntimeError('Servidor local encerrou; consulte salas.log')
                try:
                    with socket.create_connection(('127.0.0.1',porta),timeout=0.2): break
                except OSError:
                    if time.monotonic()>prazo: raise RuntimeError('Servidor local não iniciou')
                    time.sleep(0.1)
            url = 'ws://127.0.0.1:'+str(porta)
            print('Salas locais:',url,'• outra instância pode usar --pasta diferente --lobby-ws',url,flush=True)
        cena = 'res://cenas/campanha/percurso_prototipo.tscn' if args.regiao else 'res://cenas/campanha/seletor_campanha.tscn'
        extra = ['--destino='+args.regiao] if args.regiao else []
        if url.startswith('wss://'): extra.append('--campanha-online')
        return subprocess.call(motor + ['--path', str(projeto), cena, '--', '--lobby-ws='+url] + extra)
    finally:
        if servidor is not None: encerrar(servidor)
        if fluxo is not None: fluxo.close()


if __name__ == '__main__':
    raise SystemExit(main())
