"""Baixa os quadros originais de um job PixelLab; não modifica os pixels."""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from urllib.request import urlopen
import argparse
import json


def baixar(job, quantidade, destino):
    destino.mkdir(parents=True, exist_ok=True)

    def quadro(indice):
        url = f'https://api.pixellab.ai/mcp/images/{job}/download?index={indice}'
        dados = urlopen(url, timeout=60).read()
        if not dados.startswith(b'\x89PNG\r\n\x1a\n'):
            raise ValueError(f'Resposta não é PNG: {indice}')
        (destino / f'quadro_{indice:02d}.png').write_bytes(dados)
        return len(dados)

    with ThreadPoolExecutor(max_workers=4) as executor:
        tamanhos = list(executor.map(quadro, range(quantidade)))
    (destino / 'origem.json').write_text(json.dumps({
        'servico': 'PixelLab', 'job_id': job, 'quadros': quantidade,
        'download': f'https://api.pixellab.ai/mcp/images/{job}/download?index=INDICE',
        'alteracao_pixels': False,
    }, ensure_ascii=False, indent=2)+'\n')
    print(f'{quantidade} quadros originais baixados; {sum(tamanhos)} bytes')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('job')
    parser.add_argument('quadros', type=int)
    parser.add_argument('destino', type=Path)
    args = parser.parse_args()
    baixar(args.job, args.quadros, args.destino)
