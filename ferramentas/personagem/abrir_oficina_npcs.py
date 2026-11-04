#!/usr/bin/env python3
"""Abre a oficina de NPCs com dados de teste isolados da partida do usuário."""
from pathlib import Path
import sys
import subprocess
import re
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'projeto'))
from preparar_testes import preparar
from harness import motor_godot
from testar_coop import executar

def main():
    base=Path('/tmp/algoland-oficina-npcs')
    projeto=preparar(base/'projeto')
    config=projeto/'project.godot'
    texto=re.sub(r'^config/(?:use_custom_user_dir|custom_user_dir_name)=.*\n','',config.read_text(),flags=re.M)
    config.write_text(texto.replace('[application]','[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="AlgoLand testes oficina npcs"',1))
    motor,_=motor_godot(base)
    r=executar(motor+['--headless','--editor','--path',str(projeto),'--import','--quit'],base/'importacao.log',180)
    if not r['aprovado']:
        print('Falha na importação:',base/'importacao.log');return 1
    print('Oficina isolada; dados e logs:',base,flush=True)
    return subprocess.call(motor+['--path',str(projeto),'res://cenas/npcs/oficina_npcs.tscn'])
if __name__=='__main__':raise SystemExit(main())
