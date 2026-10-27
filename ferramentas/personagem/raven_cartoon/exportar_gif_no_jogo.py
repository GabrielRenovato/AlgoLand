#!/usr/bin/env python3
"""Exporta a gravação real do viewport; não recompõe personagens ou cenário."""
from pathlib import Path
import json
import shutil
import subprocess
from PIL import Image, ImageDraw, ImageSequence

RAIZ = Path(__file__).resolve().parents[3]
PREVIA = RAIZ/'arte/previas/personagens/raven_cartoon/no_jogo'


def contato_porte(capturas, acao='correr'):
    """Quatro poses por direção, recortadas do viewport real em torno do jogador."""
    if not all('ancora_tela' in q for q in capturas):
        return
    folha = Image.new('RGB', (1280, 1376), '#26352e')
    desenho = ImageDraw.Draw(folha)
    for linha, direcao in enumerate(['frente', 'costas', 'direita', 'esquerda']):
        for quadro in range(4):
            captura = next(q for q in capturas if q['acao'] == acao
                           and q['direcao'] == direcao and q['quadro'] == quadro)
            x, y = map(round, captura['ancora_tela'])
            with Image.open(PREVIA/'quadros'/f'quadro_{captura["indice"]:04d}.png') as im:
                recorte = im.crop((x-80, y-100, x+80, y+60)).resize((320, 320), Image.Resampling.NEAREST)
            folha.paste(recorte, (quadro*320, linha*344+24))
            desenho.text((quadro*320+12, linha*344+6), f'{direcao.upper()} - QUADRO {quadro+1}', fill='white')
    nome = 'porte_espada_quatro_direcoes.png' if acao == 'correr' else f'{acao}_quatro_direcoes.png'
    folha.save(PREVIA/nome)


def exportar(tela_inteira=False):
    assert not (PREVIA/'gravacao_em_andamento.json').exists(), 'Aguardar a gravação completa; capturas interrompidas não podem ser misturadas.'
    dados = json.loads((PREVIA/'gravacao.json').read_text())
    assert dados['falhas'] == 0, 'Corrigir a integração antes de exportar.'
    capturas = dados['capturas']
    if tela_inteira:
        for acao in ['correr', 'espada1', 'espada2']:
            contato_porte(capturas, acao)
    for direcao in ['frente', 'costas', 'direita', 'esquerda']:
        for golpe in [1, 2]:
            assert {q['quadro'] for q in capturas if q['acao'] == f'espada{golpe}' and q['direcao'] == direcao} == {0, 1, 2, 3}
    lista = Path('/tmp/algoland-cartoon-fazenda-frames.ffconcat')
    linhas = ['ffconcat version 1.0']
    fotos = PREVIA/'fotos'
    fotos.mkdir(exist_ok=True)
    for i, quadro in enumerate(capturas):
        arquivo = PREVIA/'quadros'/f'quadro_{quadro["indice"]:04d}.png'
        assert arquivo.stat().st_mtime_ns <= (PREVIA/'gravacao.json').stat().st_mtime_ns, 'Captura mais recente que o registro: concluir a gravação antes de exportar.'
        with Image.open(arquivo) as im:
            assert im.size == ((960, 600) if tela_inteira else (1152, 720))
        fim = capturas[i+1]['tempo_ms'] if i+1 < len(capturas) else quadro['tempo_ms']+40
        linhas += [f"file '{arquivo}'", 'option framerate 100', f'duration {(fim-quadro["tempo_ms"])/1000:.3f}']
    lista.write_text('\n'.join(linhas)+'\n')
    destino = PREVIA/('raven_cartoon_fazenda_tela_inteira.gif' if tela_inteira else 'raven_andando_e_atacando_na_fazenda.gif')
    filtro = 'fps=20,' if tela_inteira else 'fps=25,crop=768:480:192:120,'
    with Path('/tmp/algoland-cartoon-fazenda-gif.log').open('w') as log:
        subprocess.run(['ffmpeg', '-y', '-hide_banner', '-loglevel', 'warning', '-f', 'concat', '-safe', '0',
                        '-i', str(lista), '-filter_complex',
                        filtro+'split[a][b];[a]palettegen=stats_mode=diff:reserve_transparent=0[p];[b][p]paletteuse=dither=none',
                        '-loop', '0', str(destino)], check=True, stdout=log, stderr=log)
    for direcao in ['frente', 'costas', 'direita', 'esquerda']:
        for acao, q in [('correr', 2), ('espada1', 1), ('espada2', 2)]:
            quadro = next(c for c in capturas if c['direcao'] == direcao and c['acao'] == acao and c['quadro'] == q)
            shutil.copy2(PREVIA/'quadros'/f'quadro_{quadro["indice"]:04d}.png', fotos/f'{direcao}_{acao}.png')
    with Image.open(destino) as gif:
        duracao = sum(im.info['duration'] for im in ImageSequence.Iterator(gif))
        assert gif.size == ((960, 600) if tela_inteira else (768, 480)) and gif.info['loop'] == 0
        assert abs(duracao-capturas[-1]['tempo_ms']-40) <= 100
        frames = gif.n_frames
    (PREVIA/('gif_tela_inteira.json' if tela_inteira else 'gif.json')).write_text(json.dumps({'arquivo': destino.name, 'quadros': frames,
        'duracao_ms': duracao, 'resolucao': [960, 600] if tela_inteira else [768, 480], 'fps': 20 if tela_inteira else 25, 'origem': 'capturas reais do Godot, com física e controles',
        'recorte_do_viewport': None if tela_inteira else [192, 120, 768, 480], 'redimensionamento': False,
        'direcoes': 4, 'golpes': 2, 'fases_observadas_por_golpe': 4,
        'verificacoes': dados['verificacoes'], 'falhas': dados['falhas']}, ensure_ascii=False, indent=2)+'\n')
    print(f'GIF real da fazenda: {frames} quadros, {duracao}ms; tela inteira={tela_inteira}, sem redimensionar; quatro direções e dois golpes completos.')


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('--tela-inteira', action='store_true')
    exportar(parser.parse_args().tela_inteira)
