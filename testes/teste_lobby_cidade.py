#!/usr/bin/env python3
"""Dois jogos reais, saves separados e servidor HTTP local; nunca entra no Supabase real."""
from pathlib import Path
import importlib.util,json,subprocess,tempfile,threading,time,uuid,concurrent.futures
from http.server import BaseHTTPRequestHandler,ThreadingHTTPServer
R=Path(__file__).resolve().parents[1]

def main():
    dados={};chat=[];encerradas=set();pedidos=[];trava=threading.Lock()
    class Servidor(BaseHTTPRequestHandler):
        def log_message(self,*_args):pass
        def do_POST(self):
            p=json.loads(self.rfile.read(int(self.headers['Content-Length'])));codigo=p['p_codigo'];geracao=p['p_geracao']
            # Latência real entre cliente e servidor; a cadência não deve somá-la novamente.
            time.sleep(0.08)
            with trava:
                pedidos.append((codigo,self.path,time.monotonic()))
                if self.path.endswith('/lobby_cidade_sair'):
                    encerradas.add((codigo,geracao));dados.pop(codigo,None);resultado=None
                elif self.path.endswith(('/lobby_cidade','/chat_global')):
                    if (codigo,geracao) in encerradas:resultado={'erro':'sessao_encerrada'}
                    elif codigo in dados and time.time()-dados[codigo]['instante']<0.5:resultado={'erro':'aguarde'}
                    else:
                        estado=p['p_estado'];s=dados.setdefault(codigo,{'id':str(uuid.uuid4()),'revisao':1})
                        s['instante']=time.time()
                        if estado.get('aparencia') and estado['aparencia']!=s.get('aparencia'):s['aparencia']=estado['aparencia'];s['revisao']+=1
                        for k in ['x','y','direcao','andando','apelido']:s[k]=estado[k]
                        s['mapa']=estado.get('mapa',1 if estado.get('cidade',True) else 0)
                        confirmado=None
                        if p.get('p_mensagem'):
                            if not any(m['envio']==p['p_envio'] for m in chat):chat.append({'id':len(chat)+1,'jogador':s['id'],'apelido':s['apelido'],'texto':p['p_mensagem'],'envio':p['p_envio']})
                            confirmado=p['p_envio']
                        pessoas=[]
                        for v in dados.values():
                            mapa=estado.get('mapa',1 if estado.get('cidade',True) else 0)
                            if mapa==0 or v.get('mapa',1)!=mapa:continue
                            v=v.copy()
                            if p['p_conhecidos'].get(v['id'])==v['revisao']:v['aparencia']=None
                            pessoas.append(v)
                        resultado={'eu':s['id'],'jogadores':pessoas,'mensagens':[{k:v for k,v in m.items() if k!='envio'} for m in chat if m['id']>p['p_depois']],'confirmado':confirmado,'aviso':''}
                else:raise AssertionError(self.path)
            b=json.dumps(resultado).encode()
            try:
                self.send_response(200);self.send_header('Content-Type','application/json');self.send_header('Content-Length',str(len(b)));self.end_headers();self.wfile.write(b)
            except (BrokenPipeError,ConnectionResetError):pass
    servidor=ThreadingHTTPServer(('127.0.0.1',0),Servidor);threading.Thread(target=servidor.serve_forever,daemon=True).start()
    # --ws: os clientes falam WebSocket com o servidor próprio (ferramentas/lobby/servidor) em vez do servidor HTTP falso
    sys=__import__('sys');ws_url=None;no=None
    if '--ws-morto' in sys.argv:
        # Servidor próprio fora do ar: os clientes devem cair no canal reserva (servidor HTTP falso) e seguir funcionando
        ws_url='ws://127.0.0.1:1'
    if '--ws' in sys.argv:
        import os,shutil,socket,urllib.request
        sock=socket.socket();sock.bind(('127.0.0.1',0));porta=sock.getsockname()[1];sock.close()
        node=shutil.which('node') or next(iter(sorted(Path.home().glob('.var/app/com.visualstudio.code/config/nvm/versions/node/*/bin/node'))),None)
        assert node,'node não encontrado'
        no=subprocess.Popen([str(node),'servidor.mjs'],cwd=R/'ferramentas/lobby/servidor',env={**os.environ,'PORTA':str(porta),'EXPIRA_MS':'20000'},stdout=subprocess.DEVNULL,stderr=subprocess.STDOUT)
        for _ in range(50):
            try:urllib.request.urlopen(f'http://127.0.0.1:{porta}/saude',timeout=1);break
            except Exception:time.sleep(0.1)
        ws_url=f'ws://127.0.0.1:{porta}'
    spec=importlib.util.spec_from_file_location('preparar',R/'ferramentas/projeto/preparar_testes.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
    with tempfile.TemporaryDirectory(prefix='algoland-lobby-rede-') as temp:
        projetos=[]
        for papel in ['A','B']:
            p=m.preparar(Path(temp)/papel);c=p/'project.godot';s=c.read_text().replace('[application]','[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="AlgoLand testes lobby rede %d %s"' % (__import__('os').getpid(),papel));c.write_text(s);projetos.append((papel,p))
        def rodar(item):
            papel,p=item
            log=Path('/tmp/algoland-lobby-rede-'+papel+'.log')
            with log.open('w') as saida:
                r=subprocess.run(['flatpak','run','--filesystem=/tmp','org.godotengine.Godot','--display-driver','x11','--disable-vsync','--max-fps','60','--path',str(p),'--script','res://testes/'+('teste_chat_global.gd' if '--global' in __import__('sys').argv else 'teste_lobby_cidade.gd'),'--','--papel='+papel,'--lobby-url=http://127.0.0.1:'+str(servidor.server_port)]+(['--lobby-ws='+ws_url] if ws_url else []),stdout=saida,stderr=subprocess.STDOUT,text=True,timeout=120)
            texto=log.read_text()
            linhas=[l for l in texto.splitlines() if l.startswith(('LOBBY ','FALHA '))]
            print('\n'.join(linhas),flush=True)
            assert r.returncode==0 and 'SCRIPT ERROR' not in texto and 'Parse Error' not in texto and 'Parent node is busy' not in texto and 'ERR_UNCONFIGURED' not in texto, '/tmp/algoland-lobby-rede-'+papel+'.log'
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as e:list(e.map(rodar,projetos))
    servidor.shutdown()
    if no is not None:
        time.sleep(1.0)
        restantes=json.loads(urllib.request.urlopen(f'http://127.0.0.1:{porta}/saude',timeout=2).read())['jogadores']
        no.terminate();no.wait(5)
        assert restantes==0,f'servidor próprio ficou com {restantes} jogadores após os clientes saírem'
        assert not pedidos,'com --ws nenhum cliente deveria usar o servidor HTTP falso'
        print('LOBBY REDE WS: dois clientes, presença por mapa, chat e saída OK');return
    if dados:
        print('LOBBY sessões restantes:',len(dados),[(s.get('apelido'),sum(1 for c,p,_ in pedidos if c==codigo and p.endswith('_sair'))) for codigo,s in dados.items()],flush=True)
    assert len(chat)==3 and not dados
    for codigo in {c for c,_,_ in pedidos}:
        saidas=[t for c,p,t in pedidos if c==codigo and p.endswith('_sair')]
        assert saidas
    print('LOBBY REDE: dois clientes, movimento, chat, preferência e offline OK')
if __name__=='__main__':main()
