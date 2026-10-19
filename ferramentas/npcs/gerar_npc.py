#!/usr/bin/env python3
"""Monta um morador a partir de uma base nativa e de um perfil de materiais.

Uso: python3 ferramentas/npcs/gerar_npc.py ivo [--verificar]
Não usa IA, não amplia/reduz o corpo e não altera dados de rotina ou saves.
"""
import argparse
import json
from pathlib import Path

from PIL import Image

RAIZ = Path(__file__).resolve().parents[2]
FONTES = RAIZ / 'arte/fontes/npcs/base_vila'


def carregar(caminho):
    imagem = Image.open(caminho).convert('RGBA')
    imagem.putalpha(imagem.getchannel('A').point(lambda a: 255 if a >= 128 else 0))
    return imagem


def aplicar_paleta(imagem, paleta):
    def rgba(cor):
        return tuple(bytes.fromhex(cor.lstrip('#'))) + (255,)
    trocas = {rgba(a): rgba(b) for a, b in paleta.items()}
    saida = imagem.copy()
    saida.putdata([trocas.get(cor, cor) for cor in imagem.get_flattened_data()])
    return saida


def montar(base, perfil):
    tamanho = tuple(a * b for a, b in zip(base['quadro'], base['grade']))
    folha = Image.new('RGBA', tamanho)
    cobertura = Image.new('L', tamanho)
    for nome, caminho in base['camadas'].items():
        camada = carregar(FONTES / caminho)
        if camada.size != tamanho:
            raise ValueError('Camada fora da grade: ' + caminho)
        # Cada pixel pertence a um material; uma camada não pode esconder outra.
        if any(a and b for a, b in zip(cobertura.get_flattened_data(), camada.getchannel('A').get_flattened_data())):
            raise ValueError('Materiais sobrepostos: ' + nome)
        cobertura.paste(camada.getchannel('A'), mask=camada.getchannel('A'))
        camada = aplicar_paleta(camada, perfil.get('contorno', {}))
        camada = aplicar_paleta(camada, perfil.get('paletas', {}).get(nome, {}))
        folha.alpha_composite(camada)
    for caminho in perfil.get('acessorios', []):
        acessorio = carregar(FONTES / caminho)
        if acessorio.size != tamanho:
            raise ValueError('Acessório fora da grade: ' + caminho)
        folha.alpha_composite(acessorio)
    validar_folha(folha, base)
    return folha


def validar_folha(folha, base):
    largura, altura = base['quadro']
    for linha in range(base['grade'][1]):
        for coluna in range(base['grade'][0]):
            quadro = folha.crop((coluna*largura, linha*altura, (coluna+1)*largura, (linha+1)*altura))
            caixa = quadro.getbbox()
            if not caixa or caixa[0] <= 0 or caixa[2] >= largura or caixa[1] <= 0:
                raise ValueError('Quadro vazio ou cortado: ' + str((coluna, linha)))
            if abs(caixa[3] - base['pes_y']) > 3:
                raise ValueError('Pés desalinhados: ' + str((coluna, linha)))


def sentar(folha, base, costas=False):
    """Mesma articulação usada pelo Caio e pelas poses de costas dos moradores."""
    largura, altura = base['quadro']
    linha = 2 if costas else 0
    origem = folha.crop((0, linha*altura, largura, (linha+1)*altura))
    dados = base['sentar']
    quantidade = dados['quadros']
    saida = Image.new('RGBA', (largura*quantidade, altura))
    for i in range(quantidade):
        progresso = i / (quantidade-1)
        descida = round(dados['descida'] * progresso)
        escala = 1 - dados['compressao_pernas'] * progresso
        for y in range(altura):
            origem_y = y-descida if y < dados['quadril_y']+descida else dados['quadril_y']+int((y-dados['quadril_y']-descida)/escala)
            if 0 <= origem_y < altura:
                saida.paste(origem.crop((0, origem_y, largura, origem_y+1)), (i*largura, y))
    return saida


def preparar_retrato(perfil):
    origem = carregar(FONTES / perfil['retrato'])
    if origem.size != (256, 128):
        raise ValueError('Retrato deve ter dois quadros nativos de 128×128.')
    fechada = origem.crop((0, 0, 128, 128))
    aberta = fechada.copy()
    x, y, w, h = perfil['boca']
    if not (0 <= x < x+w <= 128 and 0 <= y < y+h <= 128):
        raise ValueError('Região da boca fora do retrato.')
    aberta.paste(origem.crop((128+x, y, 128+x+w, y+h)), (x, y))
    saida = Image.new('RGBA', (256, 128))
    saida.paste(fechada, (0, 0))
    saida.paste(aberta, (128, 0))
    return saida


def gerar(identificador, verificar=False):
    if not identificador or any(c not in 'abcdefghijklmnopqrstuvwxyz_0123456789' for c in identificador):
        raise ValueError('Identificador inválido.')
    perfil = json.loads((FONTES / 'perfis' / (identificador+'.json')).read_text())
    if perfil['id'] != identificador:
        raise ValueError('Identificador não corresponde ao perfil.')
    base = json.loads((FONTES / perfil['base']).read_text())
    normal = montar(base, perfil)
    chuva = carregar(FONTES / perfil.get('chuva', base['chuva']))
    if chuva.size != normal.size:
        raise ValueError('Capa de chuva fora da grade.')
    validar_folha(chuva, base)
    destinos = {
        'assets/npcs/cidade/'+identificador+'.png': normal,
        'assets/npcs/cidade/capas_chuva/'+identificador+'.png': chuva,
        'assets/npcs/cidade/sentados/'+identificador+'.png': sentar(normal, base),
        'assets/npcs/cidade/sentados/'+identificador+'_costas.png': sentar(normal, base, True),
        'assets/npcs/retratos/'+identificador+'.png': preparar_retrato(perfil),
    }
    for nome, dados_animacao in perfil.get('trabalho', {}).items():
        origem = carregar(FONTES / dados_animacao['fonte'])
        colunas = dados_animacao['colunas']
        quantidade = dados_animacao['quadros']
        if origem.size != (colunas*64, ((quantidade+colunas-1)//colunas)*64):
            raise ValueError('Animação de trabalho fora da grade: '+nome)
        folha = Image.new('RGBA', (quantidade*64,64))
        for i in range(quantidade):
            x,y = i%colunas*64, i//colunas*64
            folha.paste(origem.crop((x,y,x+64,y+64)),(i*64,0))
        destinos['assets/npcs/cidade/trabalho/'+identificador+'_'+nome+'.png'] = folha
    manifesto_caminho = RAIZ / 'assets/npcs/cidade/manifesto.json'
    manifesto = json.loads(manifesto_caminho.read_text())
    dados = dict(manifesto.get(identificador, {}))
    dados.update({'altura_mapa': base['altura'], 'altura_parado': base['altura'],
                  'escala_mapa': 1.0, 'pes_y': base['pes_y'], 'grade': base['grade'],
                  'quadro': base['quadro'], 'quadros_andar': base['grade'][0]-1,
                  'direcoes': base['direcoes'], 'fonte': 'res://arte/fontes/npcs/base_vila/perfis/'+identificador+'.json',
                  'folha': 'res://assets/npcs/cidade/'+identificador+'.png',
                  'folha_chuva': 'res://assets/npcs/cidade/capas_chuva/'+identificador+'.png',
                  'quadro_chuva': base['quadro'], 'margem_chuva': [0, 0], 'traje_chuva': 'capa'})
    if verificar:
        diferentes = [p for p, im in destinos.items() if not (RAIZ/p).exists() or Image.open(RAIZ/p).convert('RGBA').tobytes() != im.tobytes()]
        if diferentes or manifesto.get(identificador) != dados:
            raise ValueError('Saída desatualizada: ' + ', '.join(diferentes or ['manifesto']))
        print(identificador+': '+str(len(destinos))+' folhas reproduzíveis e manifesto coerente.')
        return
    # Toda preparação e validação acontece antes de substituir recursos em uso.
    for destino, imagem in destinos.items():
        caminho = RAIZ / destino
        caminho.parent.mkdir(parents=True, exist_ok=True)
        imagem.save(caminho)
    manifesto[identificador] = dados
    manifesto_caminho.write_text(json.dumps(manifesto, ensure_ascii=False, indent='\t')+'\n')
    print(identificador+': '+str(len(destinos))+' folhas preparadas, incluindo poses e animações de trabalho.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('id')
    parser.add_argument('--verificar', action='store_true', help='Compara as saídas sem escrever arquivos.')
    args = parser.parse_args()
    gerar(args.id, args.verificar)
