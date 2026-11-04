"""Empacota poses existentes sem mudar escala, pivô, ordem ou pixels dos atores."""
from pathlib import Path
import json
from PIL import Image

RAIZ = Path(__file__).resolve().parents[2]
FONTES = RAIZ / 'arte/fontes/inimigos/goblins_moinho_integracao/armadura'


def montar(familia, direcao):
    pasta = RAIZ / 'assets/inimigos' / ('goblin_adaga' if familia == 'adaga' else 'goblin_machado_2d')
    registro = json.loads((pasta / 'registro_animacoes.json').read_text())
    nomes = ['correr', 'combo' if familia == 'adaga' else 'ataque', 'ferido', 'morte']
    linhas = sum(registro['animacoes'][f'{n}_{direcao}']['grade'][1] for n in nomes)
    folha = Image.new('RGBA', (2560, linhas*640))
    linha = 0
    plano = {'familia': familia, 'direcao': direcao, 'celula': 640, 'linhas': linhas, 'acoes': []}
    for nome in nomes:
        acao = f'{nome}_{direcao}'
        ficha = registro['animacoes'][acao]
        imagem = Image.open(pasta / f'{acao}.png').convert('RGBA')
        folha.alpha_composite(imagem, (0, linha*640))
        plano['acoes'].append({'nome': acao, 'linha': linha, 'quadros': len(ficha['duracoes_ms']), 'linhas': ficha['grade'][1]})
        linha += ficha['grade'][1]
    folha.save(FONTES / f'{familia}_{direcao}_base.png')
    (FONTES / f'{familia}_{direcao}.json').write_text(json.dumps(plano, ensure_ascii=False, indent=2)+'\n')


if __name__ == '__main__':
    FONTES.mkdir(parents=True, exist_ok=True)
    for familia in ['adaga', 'machado']:
        for direcao in ['direita', 'baixo', 'cima']:
            montar(familia, direcao)
