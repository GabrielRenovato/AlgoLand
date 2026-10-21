#!/usr/bin/env python3
"""Exporta as rampas do acabamento Raven para código incluído no jogo exportado."""
from pathlib import Path
import json

RAIZ = Path(__file__).resolve().parents[2]
FONTE = RAIZ / 'arte/fontes/personagens/raven_fantasy/acabamento/paleta.json'
SAIDA = RAIZ / 'codigo/dados/paleta_raven.gd'


def preparar():
    dados = json.loads(FONTE.read_text())
    cores = dados['cores']
    assert len(cores) <= 64
    assert len(set(cores.values())) == len(cores), 'Não fundir as rampas de sombra.'
    texto = 'extends RefCounted\n## Gerado por preparar_acabamento_raven.py. Muda apenas cores, nunca a geometria.\nconst CORES := {\n'
    texto += ''.join(f'\t"{a}": "{b}",\n' for a, b in cores.items())
    SAIDA.write_text(texto + '}\n')
    print(f'{len(cores)} correspondências de cor exportadas; nenhuma textura alterada.')


if __name__ == '__main__':
    preparar()
