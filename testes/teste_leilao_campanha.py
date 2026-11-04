#!/usr/bin/env python3
"""RPCs reais em PostgreSQL descartável + cliente Godot; sem acessar o serviço público."""
import concurrent.futures, importlib.util, json, os, re, subprocess, sys, tempfile, threading, time, uuid
from pathlib import Path
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
RAIZ=Path(__file__).resolve().parents[1]
NOME='algoland-leilao-teste-'+uuid.uuid4().hex[:8]
PSQL=['podman','exec','-i',NOME,'psql','-X','-q','-t','-A','-v','ON_ERROR_STOP=1','-U','postgres','-d','algoland']
def sql(texto):
 r=subprocess.run(PSQL,input=texto,text=True,capture_output=True)
 if r.returncode:raise RuntimeError(r.stderr.strip())
 return r.stdout.strip()
def literal(v):
 if isinstance(v,(dict,list)):return "'"+json.dumps(v,ensure_ascii=False).replace("'","''")+"'::jsonb"
 if isinstance(v,bool):return 'true' if v else 'false'
 if isinstance(v,int):return str(v)
 if v is None:return 'null'
 return "'"+str(v).replace("'","''")+"'"
def main():
 servidor=None
 try:
  subprocess.run(['podman','run','--rm','-d','--name',NOME,'-e','POSTGRES_PASSWORD=teste_local','-e','POSTGRES_DB=algoland','docker.io/library/postgres:17-alpine'],check=True,capture_output=True)
  for i in range(80):
   # A conexão TCP só fica disponível no servidor definitivo, após o initdb.
   r=subprocess.run(['podman','exec',NOME,'pg_isready','-h','127.0.0.1','-U','postgres','-d','algoland'],capture_output=True)
   if r.returncode==0:break
   time.sleep(.1)
  else:raise RuntimeError('PostgreSQL descartável não iniciou no prazo')
  sql("create role anon;create role authenticated;create function public.apelido_proibido(text) returns boolean language sql immutable as $$ select false $$;")
  for arquivo in ['20261025120000_mercado.sql','20261025170000_mercado_seguranca.sql','tipos_mercado.sql','20261104090000_campanha_ouro.sql','teste_campanha_ouro.sql']:
   sql((RAIZ/'ferramentas/mercado'/arquivo).read_text())
  print('OK SQL: anúncios, compra, expiração, devolução, limites, permissões e idempotência',flush=True)
  class Servidor(BaseHTTPRequestHandler):
   def log_message(self,*_args):pass
   def do_POST(self):
    try:
     func=self.path.rsplit('/',1)[-1]
     if not re.fullmatch(r'campanha_mercado_[a-z_]+',func):raise ValueError('RPC fora da campanha')
     dados=json.loads(self.rfile.read(int(self.headers['Content-Length'])))
     if not all(re.fullmatch('p_[a-z_]+',k) for k in dados):raise ValueError('Parâmetro inválido')
     args=','.join(k+' => '+literal(v) for k,v in dados.items())
     texto=sql('select public.'+func+'('+args+');')
     corpo=(texto or 'null').encode();status=200
    except Exception as e:
     corpo=json.dumps({'erro':str(e)}).encode();status=500
    self.send_response(status);self.send_header('Content-Type','application/json');self.send_header('Content-Length',str(len(corpo)));self.end_headers();self.wfile.write(corpo)
  servidor=ThreadingHTTPServer(('127.0.0.1',0),Servidor)
  threading.Thread(target=servidor.serve_forever,daemon=True).start()
  sys.path.insert(0,str(RAIZ/'ferramentas/projeto'))
  from preparar_testes import preparar
  from testar_coop import analisar_log
  with tempfile.TemporaryDirectory(prefix='algoland-leilao-') as pasta:
   base=Path(pasta);projeto=preparar(base/'projeto')
   log=Path('/tmp/algoland-leilao-campanha-cliente.log')
   cmd=['flatpak','run','--filesystem='+str(RAIZ),'--filesystem=/tmp','--command=env','org.godotengine.Godot','XDG_DATA_HOME='+str(base/'dados'),'godot','--headless','--path',str(projeto),'--script','res://ferramentas/campanha/testar_leilao.gd','--','--mercado-local=http://127.0.0.1:'+str(servidor.server_port)]
   with log.open('w') as f:r=subprocess.run(cmd,stdout=f,stderr=subprocess.STDOUT,timeout=90)
   texto=log.read_text();_,erros,_=analisar_log(texto)
   for linha in texto.splitlines():
    if linha.startswith(('OK ','FALHA','FALHAS:')):print(linha,flush=True)
   assert r.returncode==0 and not erros and 'FALHAS: 0' in texto,(str(log),erros)
 finally:
  if servidor:servidor.shutdown();servidor.server_close()
  subprocess.run(['podman','stop','-t','2',NOME],capture_output=True)
if __name__=='__main__':main()
