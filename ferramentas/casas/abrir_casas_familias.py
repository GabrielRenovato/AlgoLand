#!/usr/bin/env python3
"""Abre a bancada das três casas em projeto e save isolados."""
from pathlib import Path
import subprocess
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'projeto'))
from preparar_testes import preparar
from harness import motor_godot
from testar_coop import executar


def main():
    base=Path('/tmp/algoland-casas-familias')
    projeto=preparar(base/'projeto')
    motor,_=motor_godot(base)
    resultado=executar(motor+['--headless','--editor','--path',str(projeto),'--import','--quit'],base/'importacao.log',180)
    if not resultado['aprovado']:
        print('Falha ao importar:',base/'importacao.log')
        return 1
    return subprocess.call(motor+['--path',str(projeto),'res://cenas/cidade/familias/previa_casas.tscn'])

if __name__=='__main__':
    raise SystemExit(main())
