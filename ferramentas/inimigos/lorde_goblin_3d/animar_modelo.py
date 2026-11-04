"""Entrada compatível: transferir os clipes gratuitos KayKit, sem gerar ataques próprios."""
import runpy
from pathlib import Path
runpy.run_path(str(Path(__file__).with_name('retarget_kaykit.py')),run_name='__main__')
