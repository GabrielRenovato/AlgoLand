"""Calcula vetores de movimento; não modifica os sprites ou a paleta.

Requer opencv-python-headless. A renderização usa amostragem de pixels
originais, sem crossfade, e cada pose-chave continua idêntica à fonte.
"""
from pathlib import Path
import hashlib
import json

import cv2
import numpy as np

RAIZ = Path(__file__).resolve().parents[2]
SAIDA = RAIZ / 'arte/fontes/inimigos/medusa/fluidez/campos'


def rodar():
    SAIDA.mkdir(parents=True, exist_ok=True)
    manifesto = {'algoritmo': 'OpenCV DIS medium; campos bidirecionais',
                 'versao_opencv': cv2.__version__, 'celula': 160,
                 'celula_campo': 80, 'codificacao': '(byte-128)*64/127 pixels',
                 'amostragem': 'pixel original mais próximo, sem crossfade',
                 'fontes_sha256': {}}
    for pagina in ['movimento', 'garras', 'cauda', 'bote', 'olhar']:
        caminho = RAIZ / f'assets/inimigos/medusa/{pagina}.png'
        manifesto['fontes_sha256'][pagina] = hashlib.sha256(caminho.read_bytes()).hexdigest()
        imagem = cv2.imread(str(caminho), cv2.IMREAD_UNCHANGED)
        assert imagem.shape == (640, 960, 4), (pagina, imagem.shape)
        quadros = []
        for linha in range(4):
            poses = []
            for coluna in range(6):
                q = imagem[linha*160:(linha+1)*160, coluna*160:(coluna+1)*160]
                cinza = cv2.cvtColor(q, cv2.COLOR_BGRA2GRAY)
                cinza[q[:, :, 3] == 0] = 0
                # O campo acompanha volumes, sem perseguir cada escama.
                poses.append(cv2.resize(cinza, (80, 80), interpolation=cv2.INTER_AREA))
            quadros.append(poses)
        for sentido in ['frente', 'volta']:
            campo = np.full((320, 480, 2), 128, np.uint8)
            for linha in range(4):
                for coluna in range(6):
                    a, b = quadros[linha][coluna], quadros[linha][(coluna+1) % 6]
                    if sentido == 'volta':
                        a, b = b, a
                    estimador = cv2.DISOpticalFlow_create(cv2.DISOPTICAL_FLOW_PRESET_MEDIUM)
                    fluxo = estimador.calc(a, b, None) * 2.0
                    fluxo = cv2.GaussianBlur(fluxo, (5, 5), 0.8)
                    dados = np.clip(np.rint(fluxo * (127.0 / 64.0) + 128.0), 0, 255).astype(np.uint8)
                    campo[linha*80:(linha+1)*80, coluna*80:(coluna+1)*80] = dados
            (SAIDA / f'{pagina}_{sentido}.bin').write_bytes(campo.tobytes())
        print(pagina, 'campos frente/volta gerados; sprite preservado')
    (SAIDA / 'manifesto.json').write_text(json.dumps(manifesto, ensure_ascii=False, indent=2)+'\n')


if __name__ == '__main__':
    rodar()
