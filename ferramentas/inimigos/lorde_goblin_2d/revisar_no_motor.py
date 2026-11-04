"""Abre a revisão gráfica com configuração e saves exclusivos em /tmp."""
from pathlib import Path
import re
import subprocess
import sys

RAIZ=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(RAIZ/'ferramentas/projeto'))
from preparar_testes import preparar
from harness import motor_godot

def revisar():
    base=Path('/tmp/algoland-lorde2d-revisao')
    projeto=preparar(base/'projeto')
    p=projeto/'project.godot'
    texto=re.sub(r'^config/(?:use_custom_user_dir|custom_user_dir_name)=.*\n','',p.read_text(),flags=re.M)
    texto=texto.replace('[application]','[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="AlgoLand testes lorde2d"',1)
    p.write_text(texto.replace('window/size/mode=3','window/size/mode=0'))
    motor,_=motor_godot(base)
    with (base/'godot.log').open('w') as log:
        resultado=subprocess.run(motor+['--path',str(projeto),'--rendering-method','gl_compatibility',
                                '--script','res://ferramentas/inimigos/lorde_goblin_2d/revisar_animacao.gd'],
                                cwd=RAIZ,stdout=log,stderr=subprocess.STDOUT,timeout=100)
    print('Godot:',resultado.returncode,'; log:',base/'godot.log')
    return resultado.returncode

if __name__=='__main__': raise SystemExit(revisar())
