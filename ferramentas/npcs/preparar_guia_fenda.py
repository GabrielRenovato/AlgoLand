#!/usr/bin/env python3
"""Reproduz Orion pela base compartilhada, sem alterar moradores da vila."""
import json
from pathlib import Path
from gerar_npc import montar, RAIZ, FONTES
from PIL import Image
from gerar_npc import validar_folha

def preparar_mago(caminho, base):
    """Importa a grade gerada com transformação única, sem recortar poses separadamente."""
    origem = Image.open(caminho).convert('RGBA')
    if origem.size != (1659, 948):
        raise ValueError('Folha do mago fora da grade 7×4 de 237 pixels.')
    folha = Image.new('RGBA', (448, 256))
    for linha in range(4):
        for coluna in range(7):
            quadro = origem.crop((coluna*237, linha*237, (coluna+1)*237, (linha+1)*237))
            quadro = quadro.resize((52,52), Image.Resampling.NEAREST)
            quadro.putalpha(quadro.getchannel('A').point(lambda a: 255 if a >= 128 else 0))
            folha.alpha_composite(quadro, (coluna*64+6, linha*64-2))
    validar_folha(folha, base)
    return folha

def preparar():
    perfil=json.loads((FONTES/'perfis/orion.json').read_text())
    base=json.loads((FONTES/perfil['base']).read_text())
    destino=RAIZ/'assets/npcs/fendas'
    destino.mkdir(parents=True,exist_ok=True)
    folha = preparar_mago(RAIZ/perfil['folha_mago'],base) if 'folha_mago' in perfil else montar(base,perfil)
    folha.save(destino/'orion.png')
    dados={k:base[k] for k in ['quadro','grade','pes_y','altura','direcoes']}
    dados.update(escala_mapa=1,perfil='res://arte/fontes/npcs/base_vila/perfis/orion.json')
    if 'folha_mago' in perfil:
        dados.update(altura=40, fonte='res://'+perfil['folha_mago'], cajado_integrado=True)
    (destino/'orion.json').write_text(json.dumps(dados,ensure_ascii=False,indent=2)+'\n')
    print('Orion: 28 poses; braço, mão e cajado de madeira integrados à folha.')

if __name__=='__main__': preparar()
