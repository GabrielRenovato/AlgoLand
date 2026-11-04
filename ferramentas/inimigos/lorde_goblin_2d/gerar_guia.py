"""Registra articulações e desenha o guia técnico da martelada 2D."""
import json
from pathlib import Path
from PIL import Image, ImageDraw

RAIZ = Path(__file__).resolve().parents[3]
PASTA = RAIZ / 'arte/fontes/inimigos/lorde_goblin_2d'

# Cabeça, ombros, quadril, cotovelos, mãos, joelhos, pés e extremos do martelo.
CHAVES = ['cabeca', 'ombro_d', 'ombro_e', 'quadril', 'cotovelo_d', 'cotovelo_e',
          'mao_d', 'mao_e', 'joelho_d', 'joelho_e', 'pe_d', 'pe_e', 'cabo', 'marreta']
FASES = [
    ('guarda', 100, [(258,160),(222,217),(277,211),(250,332),(182,270),(305,257),(174,315),(330,289),(222,385),(286,385),(212,450),(302,450),(130,323),(404,275)]),
    ('preparacao', 150, [(242,167),(210,221),(264,214),(244,340),(180,247),(293,223),(190,266),(324,210),(220,390),(285,390),(212,450),(302,450),(146,285),(385,183)]),
    ('elevacao', 180, [(245,163),(218,219),(270,210),(250,328),(190,161),(289,159),(328,94),(231,76),(224,384),(286,383),(212,450),(302,450),(369,102),(153,61)]),
    ('descida', 50, [(280,180),(241,230),(293,226),(254,339),(255,162),(322,192),(299,100),(355,153),(224,389),(287,388),(212,450),(302,450),(269,75),(405,204)]),
    ('impacto', 80, [(305,245),(253,281),(306,286),(247,349),(246,321),(329,338),(280,310),(365,384),(221,400),(290,398),(212,450),(302,450),(240,275),(429,438)]),
    ('absorcao', 110, [(310,255),(256,291),(308,295),(243,359),(251,332),(330,351),(288,322),(371,390),(220,404),(289,403),(212,450),(302,450),(249,290),(431,439)]),
    ('recuperacao', 160, [(277,202),(236,250),(287,244),(247,342),(210,296),(312,299),(218,328),(351,342),(220,392),(288,391),(212,450),(302,450),(175,322),(421,350)]),
    ('guarda', 170, [(258,160),(222,217),(277,211),(250,332),(182,270),(305,257),(174,315),(330,289),(222,385),(286,385),(212,450),(302,450),(130,323),(404,275)]),
]

# Revisão solicitada: punhos adjacentes na ponta do cabo, como no golpe vertical real.
# Ordem: cotovelo direito, cotovelo esquerdo, mão direita, mão esquerda.
PEGADA_FECHADA = [
    [(180,269),(250,267),(174,315),(203,310)],
    [(182,239),(268,233),(190,266),(216,256)],
    [(240,148),(310,153),(328,94),(300,89)],
    [(253,169),(325,191),(299,100),(322,122)],
    [(251,318),(329,316),(280,310),(303,330)],
    [(258,327),(331,332),(288,322),(311,342)],
    [(208,292),(291,291),(218,328),(247,330)],
    [(180,269),(250,267),(174,315),(203,310)],
]

def gerar():
    contato = Image.new('RGB', (2048, 1024), '#e6e3d6')
    quadros = []
    for indice, (fase, duracao, coords) in enumerate(FASES):
        pontos = dict(zip(CHAVES, coords))
        pontos.update(dict(zip(['cotovelo_d','cotovelo_e','mao_d','mao_e'], PEGADA_FECHADA[indice])))
        quadro = Image.new('RGB', (512,512), '#e6e3d6')
        d = ImageDraw.Draw(quadro)
        d.line((30,450,480,450), fill='#b8b49f', width=2)
        d.text((16,14), f'{indice+1} / {fase} / {duracao}ms', fill='#242c30')
        for a,b in [('ombro_d','ombro_e'),('ombro_d','quadril'),('ombro_e','quadril'),('cabeca','ombro_d'),('quadril','joelho_d'),('joelho_d','pe_d'),('quadril','joelho_e'),('joelho_e','pe_e')]:
            d.line((pontos[a],pontos[b]),fill='#5a6b70',width=7)
        for lado,cor in [('d','#ba4141'),('e','#326ba0')]:
            for a,b in [('ombro','cotovelo'),('cotovelo','mao')]:
                d.line((pontos[a+'_'+lado],pontos[b+'_'+lado]), fill=cor,width=7)
        d.line((pontos['cabo'],pontos['marreta']),fill='#776041',width=10)
        x,y=pontos['marreta']; d.ellipse((x-25,y-22,x+25,y+22),fill='#393d43')
        x,y=pontos['cabeca']; d.ellipse((x-24,y-27,x+24,y+27),outline='#73753d',width=5)
        for nome in ['mao_d','mao_e','quadril','pe_d','pe_e']:
            x,y=pontos[nome]; d.ellipse((x-5,y-5,x+5,y+5), fill='#f7b33e')
        contato.paste(quadro,(indice%4*512,indice//4*512))
        quadros.append({'indice':indice,'fase':fase,'duracao_ms':duracao,'apoio':'dois pes plantados','pontos':pontos})
    contato.save(PASTA/'guia_martelada.png')
    (PASTA/'guia_martelada.json').write_text(json.dumps({'celula':[512,512],'pivo':[256,450],'quadros':quadros},indent=2)+'\n')

if __name__=='__main__': gerar()
