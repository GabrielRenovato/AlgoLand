#!/usr/bin/env python3
"""Monta folhas, preservando originais e normalizando pivôs do contrato da forja."""
from pathlib import Path
import subprocess
import sys
from PIL import Image

RAIZ = Path(__file__).resolve().parents[2]
FONTES = RAIZ / 'arte/fontes/forja'
ESTACOES = ('primavera', 'verao', 'outono', 'inverno')


def salvar(imagem, caminho):
    caminho = RAIZ / caminho
    caminho.parent.mkdir(parents=True, exist_ok=True)
    imagem.save(caminho)


def quadro(imagem, coluna, linha, colunas, linhas):
    w, h = imagem.size
    return imagem.crop((round(coluna*w/colunas), round(linha*h/linhas),
                        round((coluna+1)*w/colunas), round((linha+1)*h/linhas)))


def estacoes(nome, medida, pasta):
    origem = Image.open(FONTES / nome).convert('RGBA')
    for i, estacao in enumerate(ESTACOES):
        imagem = quadro(origem, i % 2, i // 2, 2, 2).resize(medida, Image.Resampling.NEAREST)
        salvar(imagem, pasta+'/'+estacao+'.png')



if __name__ == '__main__':
    # O morador usa a base nativa compartilhada; os estudos antigos ficam só como histórico.
    subprocess.run([sys.executable, str(RAIZ / 'ferramentas/npcs/gerar_npc.py'), 'ivo'], check=True)
    estacoes('forja_estacoes.png', (128, 112), 'assets/cenario/cidade/ambientes/fachada/forja')
    estacoes('bancada_forja_estacoes.png', (80, 56), 'assets/cenario/cidade/ambientes/interior/forja/fornalha')
    primavera = Image.open(RAIZ/'assets/cenario/cidade/ambientes/fachada/forja/primavera.png')
    salvar(primavera, 'assets/cenario/cidade/casas/exterior/forja.png')
    # Mesmo porte e telhado em duas águas: reutiliza a máscara artística da venda.
    salvar(Image.open(RAIZ/'assets/cenario/cidade/sombras/casas/venda.png'),
           'assets/cenario/cidade/sombras/casas/forja.png')
