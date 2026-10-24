#!/usr/bin/env python3
"""Integração HTTP real com servidor local: nunca usa credenciais nem dados do Supabase."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import sys
import time
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

RAIZ = Path(__file__).resolve().parents[1]


def main():
    fluxo = '--fluxo' in sys.argv
    estado = {'linha': None, 'pedidos': []}
    class Servidor(BaseHTTPRequestHandler):
        def log_message(self, *_args): pass
        def responder(self, codigo, dados):
            corpo = json.dumps(dados).encode()
            self.send_response(codigo)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(corpo)))
            self.end_headers()
            self.wfile.write(corpo)
        def do_GET(self):
            estado['pedidos'].append(('GET', self.path))
            if self.path.startswith('/falhar/'):
                return self.responder(503, {'message': 'offline'})
            assert 'aparencia' in self.path and 'atualizado_em.asc' in self.path and 'temporada=eq.1' in self.path
            self.responder(200, [estado['linha']] if estado['linha'] else [])
        def do_POST(self):
            dados = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
            assert dados['p_temporada']==1
            estado['pedidos'].append(('POST', self.path))
            if self.path.startswith('/falhar/'):
                return self.responder(503, {'message': 'offline'})
            if fluxo: time.sleep(0.04)
            if self.path.endswith('/iniciar_partida_ranking'):
                return self.responder(204, None)
            if self.path.endswith('/enviar_pontuacao_ranking'):
                estado['linha'] = {'apelido': dados['p_apelido'], 'andar': dados['p_andar']}
            elif self.path.endswith('/atualizar_perfil_ranking'):
                assert estado['linha'] is not None
                assert 'codigo' not in dados['p_aparencia']
                estado['linha']['aparencia'] = dados['p_aparencia']
                contagens = dados['p_armas_usadas']
                estado['linha']['arma_mais_usada'] = min(contagens, key=lambda k: (-contagens[k], k)) if contagens else ''
            else:
                raise AssertionError(self.path)
            self.responder(200, {'armas_usadas': contagens, 'arma_mais_usada': estado['linha']['arma_mais_usada']} if self.path.endswith('/atualizar_perfil_ranking') else None)
    servidor = ThreadingHTTPServer(('127.0.0.1', 0), Servidor)
    tarefa = threading.Thread(target=servidor.serve_forever, daemon=True)
    tarefa.start()
    spec = importlib.util.spec_from_file_location('preparar', RAIZ/'ferramentas/projeto/preparar_testes.py')
    modulo = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(modulo)
    with tempfile.TemporaryDirectory(prefix='algoland-ranking-http-') as temp:
        projeto = modulo.preparar(Path(temp))
        p = projeto/'project.godot'
        s = p.read_text().replace('[application]', '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="AlgoLand testes ranking HTTP %d"' % os.getpid())
        p.write_text(s)
        comando = ['flatpak','run','--filesystem=/tmp','org.godotengine.Godot',*([] if '--visual' in sys.argv else ['--headless']),'--path',str(projeto),'--script','res://testes/teste_ranking_automatico.gd' if fluxo else 'res://testes/teste_ranking_http.gd','--',str(servidor.server_port)]
        if '--pacote' in sys.argv:
            pacote = Path(sys.argv[sys.argv.index('--pacote')+1]).resolve()
            script = projeto/'teste_exportado.gd'
            script.write_text((RAIZ/'testes/teste_ranking_automatico.gd').read_text().replace('OS.get_user_data_dir().get_file().begins_with("AlgoLand testes")','OS.get_user_data_dir().begins_with("/tmp/algoland-ranking-pacote-")'))
            dados = '/tmp/algoland-ranking-pacote-%d' % os.getpid()
            comando = ['flatpak','run','--filesystem=/tmp','--command=env','org.godotengine.Godot','XDG_DATA_HOME='+dados,'APPDATA='+dados,'/app/bin/godot-bin','--headless','--main-pack',str(pacote),'--script',str(script),'--',str(servidor.server_port)]
        r = subprocess.run(comando, capture_output=True, text=True, timeout=70)
        log = Path('/tmp/algoland-ranking-automatico.log' if fluxo else '/tmp/algoland-ranking-http.log')
        log.write_text(r.stdout+r.stderr)
        print('\n'.join(l for l in r.stdout.splitlines() if l.startswith(('OK ','FALHA ','RANKING HTTP:','RANKING AUTOMATICO:'))))
        assert r.returncode == 0 and 'SCRIPT ERROR' not in r.stderr and 'Parse Error' not in r.stderr, str(log)
    servidor.shutdown()
    pontuacoes = [p for m,p in estado['pedidos'] if m=='POST' and p.endswith('/enviar_pontuacao_ranking')]
    if fluxo:
        assert len(pontuacoes)==4, 'Vitória, morte e dois andares pendentes são enviados'
        assert estado['linha']['apelido']=='sem apelido' and estado['linha']['andar']==4
        print('OK vitória e morte reais, apelido automático, fila e pausa')
        return
    assert len(pontuacoes)==1, 'Trocar aparência não reenvia a pontuação'
    assert len([p for m,p in estado['pedidos'] if m=='GET'])==3, 'Consultas simultâneas são agrupadas'
    assert estado['linha']['aparencia']['cabelo']==7
    print('OK transporte HTTP local, repetição, concorrência, cache e persistência')

if __name__ == '__main__':
    main()
