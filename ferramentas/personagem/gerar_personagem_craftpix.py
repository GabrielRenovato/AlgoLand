#!/usr/bin/env python3
"""Gera folhas pelas camadas nativas do CraftPix, sem alterar poses ou saves."""
import argparse
import json
import re
from pathlib import Path
from PIL import Image

RAIZ = Path(__file__).resolve().parents[2]
FONTES = RAIZ / 'arte/fontes/personagens/gerador_craftpix'

def carregar_json(caminho):
    return json.loads(caminho.read_text())

def rgba(cor):
    if not re.fullmatch(r'[0-9a-fA-F]{6}', cor):
        raise ValueError('Cor deve conter seis dígitos hexadecimais: ' + str(cor))
    return tuple(bytes.fromhex(cor)) + (255,)

def compor(base, materiais, perfil, acao):
    if len(perfil['pele']) != 6 or len(perfil['olhos']) != 2:
        raise ValueError('Perfil precisa de seis tons de pele e dois de olhos.')
    trocas = dict(zip(map(rgba, materiais['pele_original']), map(rgba, perfil['pele'])))
    trocas.update(zip(map(rgba, materiais['olhos_originais']), map(rgba, perfil['olhos'])))
    animacao = base['animacoes'][acao]
    referencia = Image.open(RAIZ / animacao['folha'].removeprefix('res://')).convert('RGBA')
    folha = Image.new('RGBA', referencia.size)
    for dados in animacao['camadas']:
        if '_shadow' in dados['arquivo']:
            continue  # A sombra é independente do personagem e não integra as folhas full.
        camada = Image.open(RAIZ / dados['arquivo'].removeprefix('res://')).convert('RGBA')
        if camada.size != folha.size:
            raise ValueError('Camada fora da grade: ' + dados['arquivo'])
        if dados['material'] == 'pele':
            camada.putdata([trocas.get(cor, cor) for cor in camada.get_flattened_data()])
        folha.alpha_composite(camada)
    return folha

def previa(folha, animacao, destino):
    # Reamostragem temporal só na prévia: exportação mantém tempos nativos exatos.
    nomes = ['front', 'side_right', 'back', 'side_left']
    totais = [sum(animacao['direcoes'][d]['duracoes']) for d in nomes]
    passos = max(1, round(max(totais) / 0.04))
    quadros = []
    for i in range(passos):
        quadro = Image.new('RGBA', (256, 64), '#18212b')
        for j, direcao in enumerate(nomes):
            dados = animacao['direcoes'][direcao]
            tempo = (i * 0.04) % sum(dados['duracoes'])
            coluna = 0
            while coluna < len(dados['duracoes']) - 1 and tempo >= dados['duracoes'][coluna]:
                tempo -= dados['duracoes'][coluna]
                coluna += 1
            x, y = coluna * 64, dados['linha'] * 64
            quadro.alpha_composite(folha.crop((x, y, x + 64, y + 64)), (j * 64, 0))
        quadros.append(quadro.resize((768, 192), Image.Resampling.NEAREST).convert('RGB'))
    quadros[0].save(destino, save_all=True, append_images=quadros[1:], duration=40, loop=0, disposal=2)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--nome', required=True, help='Nome da pasta do personagem, sem espaços.')
    parser.add_argument('--perfil', default='original', help='original, morena ou escura')
    parser.add_argument('--perfil-json', type=Path, help='Perfil próprio com nome, pele[6] e olhos[2].')
    parser.add_argument('--destino', type=Path, help='Pasta nova de saída; padrão assets/personagens/gerados/NOME.')
    args = parser.parse_args()
    if not re.fullmatch(r'[a-z0-9_-]+', args.nome):
        parser.error('--nome aceita letras minúsculas, números, _ e -')
    base = carregar_json(FONTES / 'base.json')
    materiais = carregar_json(FONTES / 'paletas.json')
    if not args.perfil_json and args.perfil not in materiais['perfis']:
        parser.error('Perfil desconhecido: ' + args.perfil)
    perfil = carregar_json(args.perfil_json) if args.perfil_json else materiais['perfis'][args.perfil]
    destino = args.destino or RAIZ / 'assets/personagens/gerados' / args.nome
    if destino.exists() and any(destino.iterdir()):
        parser.error('A pasta de saída contém arquivos. Use outro nome para preservar a versão anterior.')
    # Compor antes de criar arquivos de saída para falhar sem entrega parcial.
    folhas = {acao: compor(base, materiais, perfil, acao) for acao in base['animacoes']}
    destino.mkdir(parents=True, exist_ok=True)
    manifesto = json.loads(json.dumps(base))
    manifesto.update(nome=args.nome, perfil=perfil, origem='CraftPix / Free Game Assets', licenca='https://craftpix.net/file-licenses/')
    for acao, imagem in folhas.items():
        imagem.save(destino / (acao + '.png'))
        manifesto['animacoes'][acao]['folha'] = acao + '.png'
        manifesto['animacoes'][acao].pop('camadas')
    (destino / 'manifesto.json').write_text(json.dumps(manifesto, ensure_ascii=False, indent=2) + '\n')
    for acao in ['unarmed_walk', 'unarmed_run']:
        previa(folhas[acao], base['animacoes'][acao], destino / (acao + '.gif'))
    # Contato dos seis quadros de caminhada: cada direção segue a mesma ordem do GIF.
    im = folhas['unarmed_walk']
    contato = Image.new('RGBA', im.size)
    for nova, antiga in enumerate([0, 2, 3, 1]):
        contato.alpha_composite(im.crop((0, antiga * 64, im.width, antiga * 64 + 64)), (0, nova * 64))
    contato.resize((im.width * 3, im.height * 3), Image.Resampling.NEAREST).save(destino / 'contato_andar.png')
    print(f'{args.nome}: {len(folhas)} folhas, manifesto e prévias em {destino}')

if __name__ == '__main__':
    main()
