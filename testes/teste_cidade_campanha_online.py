#!/usr/bin/env python3
"""Duas cidades reais no Godot contra servidor WebSocket local; nunca usa contas públicas."""
from pathlib import Path
import concurrent.futures,json,os,subprocess,sys,tempfile
R=Path(__file__).resolve().parents[1]
def main():
 sys.path.insert(0,str(R/'ferramentas/projeto'))
 from preparar_testes import preparar
 from testar_coop import analisar_log
 with tempfile.TemporaryDirectory(prefix='cidade-campanha-rede-') as pasta:
  base=Path(pasta)
  modulo=(R/'ferramentas/lobby/servidor/servidor.mjs').as_uri()
  codigo='import { criarServidor,CONFIG } from '+json.dumps(modulo)+'; const s=criarServidor({...CONFIG,porta:0,portaAdmin:0,supabaseUrl:"",supabaseChave:"",exigirConta:false});const porta=await s.iniciar();const bot=new WebSocket("ws://127.0.0.1:"+porta);await new Promise((ok,no)=>{bot.onopen=ok;bot.onerror=no});bot.send(JSON.stringify({t:"entrar",codigo:"legado_teste_isolado_abcdefghijklmnop",geracao:"f".repeat(32),estado:{mapa:1,x:100,y:100,apelido:"LEGADO",aparencia:{versao:1}}}));console.log(JSON.stringify({porta}));process.on("SIGTERM",async()=>{await s.parar();process.exit(0)});'
  server=subprocess.Popen(['node','--input-type=module','-e',codigo],stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
  try:
   porta=json.loads(server.stdout.readline())['porta']
   def rodar(papel):
    projeto=preparar(base/papel/'projeto')
    log=Path('/tmp/cidade-campanha-rede-'+papel+'.log')
    args=['flatpak','run','--filesystem='+str(R),'--filesystem=/tmp','--command=env','org.godotengine.Godot','XDG_DATA_HOME='+str(base/papel/'dados'),'godot','--path',str(projeto),'--disable-vsync','--max-fps','60','--script','res://ferramentas/campanha/testar_cidade_online.gd','--','--papel='+papel,'--coordenacao='+str(base),'--lobby-ws=ws://127.0.0.1:'+str(porta)]
    with log.open('w') as f:r=subprocess.run(args,stdout=f,stderr=subprocess.STDOUT,timeout=115)
    texto=log.read_text();_,erros,_=analisar_log(texto)
    for linha in texto.splitlines():
     if linha.startswith(('OK ','FALHA','FALHAS:')):print(linha,flush=True)
    assert r.returncode==0 and not erros and 'FALHAS: 0' in texto,(str(log),erros)
   with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:list(pool.map(rodar,['A','B']))
   import shutil
   saida=Path('/tmp/cidade-campanha-online-previas');saida.mkdir(exist_ok=True)
   for p in base.glob('*.png'):shutil.copy2(p,saida/p.name)
   print('OK dois jogos reais: encontro automático, movimento, saída e retorno à cidade pública')
  finally:
   server.terminate();server.wait(10)
if __name__=='__main__':main()
