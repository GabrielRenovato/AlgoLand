#!/usr/bin/env python3
"""Onze layouts de fenda e dez plantas seguintes, com recursos nativos sazonais."""
import argparse
import json
import math
from pathlib import Path
import random
import re
import subprocess
import sys
from xml.sax.saxutils import escape

RAIZ = Path(__file__).resolve().parents[2]
sys.path.insert(0,str(RAIZ / 'ferramentas/fendas'))
import gerar_bosque as B
import detalhar_biomas as D
import gentle_forest as F
import construir_cavernas as C
import construir_pedreiras as P
import colisoes_andares as K
G,T = B.G,B.T
PLANTAS = [json.loads(p.read_text()) for p in sorted((RAIZ/'codigo/fendas/plantas').glob('andar_*.json'))]
PREVIAS = RAIZ/'arte/previas/fenda/jornada'
CORES = {'bosque':('#193b30','#6c8b54'),'pedreira':('#342e30','#ad9778'),'caverna_mina':('#09090c','#857668'),'caverna':('#22202f','#787085'),'brejo':('#163c3f','#749b74'),'ruinas':('#333938','#a5a58b'),'caverna_agua':('#172d40','#6e91a3')}


def desenho(p,x,y,w,h):
    bg,fg=CORES[p['bioma']]
    x0,y0,pw,ph=p['limites']
    escala=min((w-30)/pw,(h-100)/ph)
    ox=x+(w-pw*escala)/2-x0*escala
    oy=y+68+(h-100-ph*escala)/2-y0*escala
    partes=[f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="12" fill="{bg}" stroke="#6b6e62"/>',f'<text x="{x+18}" y="{y+28}" font-size="19" font-weight="bold">{p["andar"]:02} · {escape(p["nome"])}</text>',f'<text x="{x+18}" y="{y+52}" font-size="13">{pw} × {ph} px · meta {p["combate"]["meta"]} pontos</text>']
    partes.append(f'<g transform="translate({ox},{oy}) scale({escala})">')
    if p['bioma']=='caverna_agua':
        for lago in p['lago']['lobos']:
            cx,cy,rx,ry=lago
            partes.append(f'<ellipse cx="{cx}" cy="{cy}" rx="{rx+64}" ry="{ry+64}" fill="{fg}"/>')
            inicio,fim=C.ponto_margem(p,lago)
            partes.append(f'<line x1="{inicio[0]}" y1="{inicio[1]}" x2="{fim[0]}" y2="{fim[1]}" stroke="{fg}" stroke-width="144" stroke-linecap="round"/>')
    for t in p['trilhas']:
        pts=' '.join(f'{a},{b}' for a,b in t['pontos'])
        partes.append(f'<polyline points="{pts}" stroke="{fg}" stroke-width="{2*t["raio"]}" fill="none" stroke-linecap="round" stroke-linejoin="round"/>')
    for s in p['setores']:
        cx,cy=s['centro'];rx,ry=s['raios']
        if s.get('formato')=='patio':
            partes.append(f'<rect x="{cx-rx}" y="{cy-ry}" width="{rx*2}" height="{ry*2}" rx="16" fill="{fg}"/>')
        else:
            partes.append(f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="{fg}"/>')
        cor='#7de0c2' if s['id']=='entrada' else '#ef986e' if s['id']=='guardiao' else '#ead496'
        partes.append(f'<circle cx="{cx}" cy="{cy}" r="{16/escala}" fill="{cor}"/>')
        rotulo='E' if s['id']=='entrada' else 'B' if s['id']=='guardiao' else str(s['grupos'])
        partes.append(f'<text x="{cx}" y="{cy+5/escala}" text-anchor="middle" fill="#202923" font-size="{14/escala}">{rotulo}</text>')
    for cx,cy,rx,ry in p['lago']['lobos']:
        partes.append(f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="#4b8b9d"/>')
    partes.append('</g>')
    partes.append(f'<text x="{x+18}" y="{y+h-14}" font-size="12">E: entrada · números: grupos · B: guardião</text>')
    return '\n'.join(partes)


def plantas():
    PREVIAS.mkdir(parents=True,exist_ok=True)
    cab='<svg xmlns="http://www.w3.org/2000/svg" width="1560" height="1900"><rect width="100%" height="100%" fill="#111e1b"/><g font-family="DejaVu Sans" fill="#f5e3ba">'
    board=[cab,'<text x="30" y="42" font-size="28">ALGOLAND · PLANTAS DOS ANDARES 2 A 11</text>']
    for i,p in enumerate(PLANTAS[1:]):
        board.append(desenho(p,24+(i%2)*768,68+(i//2)*360,744,342))
        svg='<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="680"><g font-family="DejaVu Sans" fill="#f5e3ba">'+desenho(p,0,0,1200,680)+'</g></svg>'
        out=PREVIAS/f'planta_{p["andar"]:02}.svg';out.write_text(svg)
        subprocess.run(['magick',str(out),str(out.with_suffix('.png'))],check=True)
    board.append('</g></svg>')
    out=PREVIAS/'dez_plantas.svg';out.write_text('\n'.join(board))
    subprocess.run(['magick',str(out),str(out.with_suffix('.png'))],check=True)
    print('Dez plantas:',out)


class LagoOpcional(G.Lagoa):
    def dist(self,x,y):
        return super().dist(x,y) if self.lobos else 1e9


def rocha(texto,p,m):
    """Materiais em resolução nativa; alternância espelhada elimina cortes na repetição."""
    celulas=[]
    for x,y in m.chao:
        if B.distancia_caminhavel(x*16+8,y*16+8)<=0 or (x,y) in m.agua: continue
        ax,ay=x%4,y%16
        if (x//4)%2: ax=3-ax
        if (y//16)%2: ay=15-ay
        alternativa=(4096 if (x//4)%2 else 0)|(8192 if (y//16)%2 else 0)
        celulas.append((x,y,0,ax,ay,alternativa))
    material='rocha_clara' if p['bioma']=='pedreira' else 'rocha'
    ext=f'[ext_resource type="Texture2D" path="res://assets/cenario/fendas/materiais/{material}.png" id="rocha_textura"]\n[ext_resource type="Script" path="res://codigo/fendas/rocha_sazonal.gd" id="rocha_script"]\n'
    texto=texto.replace('[sub_resource',ext+'\n[sub_resource',1)
    sub='[sub_resource type="TileSetAtlasSource" id="fonte_rocha"]\ntexture = ExtResource("rocha_textura")\n'
    for y in range(16):
        for x in range(4): sub+=f'{x}:{y}/0 = 0\n'
    sub+='\n[sub_resource type="TileSet" id="tiles_rocha"]\nsources/0 = SubResource("fonte_rocha")\n'
    texto=texto.replace('[node name="Terrains"',sub+'\n[node name="Terrains"',1)
    texto+='\n[node name="Rocha" type="TileMapLayer" parent="."]\nz_index = -999\ntexture_filter = 1\ntile_map_data = %s\ntile_set = SubResource("tiles_rocha")\nscript = ExtResource("rocha_script")\n'%T.codificar_tiles(celulas)
    texto=texto.replace('script = ExtResource("rocha_script")','script = ExtResource("rocha_script")\nbrilho = '+('0.60' if p['bioma']=='pedreira' else '0.32'))
    return texto


def calcamento(texto,p):
    """Bordas por máscara de quatro cantos, no contrato 4×6 da vila."""
    celulas=[]
    x0,y0,w,h=p['limites']
    def pedra(x,y):
        return min(G.dist_segmento((x,y),a,b) for t in p['trilhas'] for a,b in zip(t['pontos'],t['pontos'][1:]))<64 or any(max(abs(x-z['centro'][0])/128,abs(y-z['centro'][1])/104)<1 for z in p['setores'])
    for cy in range(y0//16,(y0+h)//16):
        for cx in range(x0//16,(x0+w)//16):
            mask=sum((8>>i) for i,(dx,dy) in enumerate([(0,0),(16,0),(0,16),(16,16)]) if pedra(cx*16+dx,cy*16+dy))
            if mask==0: continue
            ax,ay=(0,5) if mask==15 else (mask%4,mask//4)
            celulas.append((cx,cy,0,ax,ay,0))
    ext='[ext_resource type="Texture2D" path="res://assets/cenario/algoland_original/inverno/grama_pedra.png" id="pedra_vila"]\n[ext_resource type="Script" path="res://codigo/fendas/calcamento_sazonal.gd" id="pedra_script"]\n'
    texto=texto.replace('[sub_resource',ext+'\n[sub_resource',1)
    sub='[sub_resource type="TileSetAtlasSource" id="fonte_calcamento"]\ntexture = ExtResource("pedra_vila")\n'
    for y in range(6):
        for x in range(4): sub+=f'{x}:{y}/0 = 0\n'
    sub+='\n[sub_resource type="TileSet" id="tiles_calcamento"]\nsources/0 = SubResource("fonte_calcamento")\n'
    texto=texto.replace('[node name="Terrains"',sub+'\n[node name="Terrains"',1)
    texto+='\n[node name="Calcamento" type="TileMapLayer" parent="."]\nz_index = -999\ntexture_filter = 1\ntile_map_data = %s\ntile_set = SubResource("tiles_calcamento")\nscript = ExtResource("pedra_script")\n'%T.codificar_tiles(celulas)
    return texto


def cena_jogavel(p):
    n=p['andar']
    s=(RAIZ/'cenas/cenario.tscn').read_text()
    s=re.sub(r' uid="[^\"]+"','',s)
    s=s.replace('res://codigo/logica/cenario.gd','res://codigo/fendas/cenario_andar.gd').replace('res://cenas/terreno.tscn',f'res://cenas/fendas/terreno_{n:02}.tscn')
    s=s.replace('[node name="cenario" type="Node2D"]','[ext_resource type="Script" path="res://codigo/fendas/gerenciador_andar.gd" id="fenda_gerente"]\n[ext_resource type="Script" path="res://codigo/fendas/gerador_encontros.gd" id="fenda_gerador"]\n\n[node name="cenario" type="Node2D"]\nmetadata/andar_fenda = true\nmetadata/planta_andar = %d\nmetadata/bioma = "%s"'%(n,p['bioma']))
    s=s.replace('position = Vector2(215, 176)','position = Vector2(215, 176)\nscript = ExtResource("fenda_gerador")')
    s=s.replace('[node name="Terrains" parent="." instance=ExtResource("2_rmsv3")]','script = ExtResource("fenda_gerente")\n\n[node name="Terrains" parent="." instance=ExtResource("2_rmsv3")]')
    s=s.replace('position = Vector2(557, 232)','position = Vector2(%d, %d)'%(p['entrada'][0]-10,p['entrada'][1]+14))
    s=re.sub(r'load_steps=\d+','load_steps=13',s,count=1)
    (RAIZ/f'cenas/fendas/andar_{n:02}.tscn').write_text(s)


def gerar(p):
    B.PLANTA=p
    B.RNG.seed(20261017+p['andar'])
    G.RNG.seed(20261017+p['andar'])
    # O construtor original mantém sua lagoa; aqui cada planta pode ter água ou não.
    original=G.Lagoa
    G.Lagoa=LagoOpcional
    florestal=not (p['bioma']=='pedreira' or p['bioma'].startswith('caverna'))
    m=B.construir(folga_limite=48 if florestal else 0,limite_retangular=p['andar'] in [6,10])
    G.Lagoa=original
    bioma=p['bioma']
    rochoso=bioma=='pedreira' or bioma.startswith('caverna')
    if rochoso:
        m.sprites_novos=[]
        m.detalhes={}
        m.terra={}
        # Chão auxiliar próprio; galerias preservam o piso e as paredes RPGW.
        # Parede e colisão compartilham o contorno da planta, sem obstáculos invisíveis no piso.
        for cel in m.chao:
            m.chao[cel]=G.RNG.choice(G.CENTRO_TERRA)
        m.penhasco={}
        # Vegetação não existe nas galerias: remove suas pequenas colisões de margem.
        m.obstaculos=[o for o in m.obstaculos if B.area(o)>300]
    if p['andar']==8:
        for i,sprite in enumerate(m.sprites_novos):
            if sprite['tipo']=='abeto' and i%2==0 and B.distancia_caminhavel(sprite['x'],sprite['y']-60)>56: sprite['tipo']='carvalho'
    if bioma=='ruinas':
        m.sprites_novos=[s for i,s in enumerate(m.sprites_novos) if i%4==0]
    if bioma=='brejo':
        # Lâminas de água ficam fora das passagens; a borda de terra mantém os caminhos legíveis.
        m.sprites_novos=[s for i,s in enumerate(m.sprites_novos) if i%3==0]
    if bioma.startswith('caverna') or bioma=='pedreira': C.construir_geometria(m,p,B,G,T)
    if rochoso: D.fragmentos(m,p,B,G)
    if p['andar'] in F.PALETAS:F.compor(m,p,B,G)
    elif bioma not in ['pedreira','ruinas']: D.relevo_nativo(m,p,B,G)
    m.colisoes_terreno_finais=list(m.obstaculos)
    pontos_decoracao=P.ambientar(m,p,B,G) if bioma in ['pedreira','caverna_mina'] else C.ambientar(m,p,B,G) if bioma.startswith('caverna') else D.objetos(p,B,m)
    if p['andar'] in [6,10]: K.fechar_mata_externa(m,p)
    pasta=RAIZ/f'assets/cenario/fendas/andar_{p["andar"]:02}'
    G.PASTA_FOLHAS=str(pasta)
    for e in G.ESTACOES:
        G.gerar_folha_estacao(e,m.tiles_margem)
        if p['andar'] not in [3,4,7,11]:
            from preparar_arte_original import guardar_margens
            guardar_margens(p['andar'],m.tiles_margem)
        if p['andar'] in F.PALETAS:F.preparar_folha(pasta/f'{e}.png',p,e,m,G)
        elif bioma.startswith('caverna'): C.preparar_margens(pasta/f'{e}.png',m.tiles_margem,G,e)
        elif rochoso: D.preparar_piso(pasta/f'{e}.png',p,e)
    K.reconstruir(m,p,pontos_decoracao,B,G)
    texto=K.identificar(G.escrever_cena(m),m)
    texto=texto.replace('name="Penhasco" type="TileMapLayer" parent="."]\ntexture_filter = 1\nz_index = -1000','name="Penhasco" type="TileMapLayer" parent="."]\ntexture_filter = 1\nz_index = -997')
    texto=texto.replace('res://codigo/logica/navegacao_arena.gd','res://codigo/fendas/navegacao_fenda.gd')
    texto=re.sub(r' uid="[^"]+"','',texto)
    texto=texto.replace('res://assets/cenario/Seasonal Forest/arena/',f'res://assets/cenario/fendas/andar_{p["andar"]:02}/')
    blocos=re.split(r'\n(?=\[)',texto)
    blocos=[b for b in blocos if not (b.startswith('[node ') and any(a in b for a in ['name="PassagemCaverna"','parent="PassagemCaverna"','name="Chegada_caverna"']))]
    texto='\n'.join(blocos)
    extras='\n'.join(f'[ext_resource type="Texture2D" path="res://assets/cenario/fendas/andar_{p["andar"]:02}/{e}.png" id="fenda_{i}"]' for i,e in enumerate(G.ESTACOES))
    texto=texto.replace('[sub_resource',extras+'\n\n[sub_resource',1)
    refs=', '.join(f'ExtResource("fenda_{i}")' for i in range(4))
    x0,y0,w,h=p['limites']
    texto=texto.replace('estacao_inicial = 3',f'estacao_inicial = 3\nseguir_calendario = true\nfolhas_personalizadas = Array[Texture2D]([{refs}])\narea_clima_centro = Vector2({x0+w/2}, {y0+h/2})\narea_clima_extensao = Vector2({w/2}, {h/2})')
    if bioma.startswith('caverna'):
        texto=texto.replace('seguir_calendario = true','seguir_calendario = true\nambiente_interno = true')
    for nome,pos in [('Chegada_portal',p['entrada']),('ClareiraGuardiao',p['guardiao'])]:
        grupo=' groups=["chegada"]' if nome=='Chegada_portal' else ''
        texto+=f'\n[node name="{nome}" type="Marker2D" parent="."{grupo}]\nposition = Vector2({pos[0]}, {pos[1]})\n'
    texto+='\n[node name="Setores" type="Node2D" parent="."]\n'
    for s in p['setores']:
        texto+=f'\n[node name="{s["id"]}" type="Marker2D" parent="Setores"]\nposition = Vector2({s["centro"][0]}, {s["centro"][1]})\nmetadata/grupos = {s["grupos"]}\n'
    texto+='\n[node name="GruposCombate" type="Node2D" parent="."]\n'
    restantes=p['combate']['elites']
    for s in reversed(p['setores']):
        for i in range(s['grupos']):
            angulo=2*math.pi*i/max(s['grupos'],1)+.5
            x=s['centro'][0]+round(math.cos(angulo)*60)
            y=s['centro'][1]+round(math.sin(angulo)*48)
            elite=restantes>0 and i==0
            if elite: restantes-=1
            texto+=f'\n[node name="{s["id"]}_{i}" type="Marker2D" parent="GruposCombate"]\nposition = Vector2({x}, {y})\nmetadata/elite = {str(elite).lower()}\n'
    if bioma=='pedreira': P.preparar()
    texto=D.integrar_objetos(texto,p,pontos_decoracao)
    if bioma=='pedreira': texto=P.integrar(texto,p,m,B,T,C)
    elif bioma.startswith('caverna'):
        texto=C.integrar(texto,p,m,B,T)
        texto=C.integrar_sombra(texto,p,m)
    elif bioma!='ruinas': texto=D.integrar_paredes(texto,p,D.paredes(p,B))
    if p['andar'] in F.PALETAS:texto=F.integrar(texto,p)
    texto=texto.replace('script = ExtResource("navegacao")','script = ExtResource("navegacao")\nfolga_adicional = '+'4.0')
    texto=re.sub(r'load_steps=\d+',f'load_steps={texto.count("[ext_resource")+texto.count("[sub_resource")+1}',texto,count=1)
    pasta_cenas=RAIZ/'cenas/fendas';pasta_cenas.mkdir(exist_ok=True)
    (pasta_cenas/f'terreno_{p["andar"]:02}.tscn').write_text(texto)
    cena_jogavel(p)
    print(p['andar'],p['nome'],len(m.chao),'tiles',len(m.sprites_novos),'vegetacao;',len(pontos_decoracao),'marcos',flush=True)


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--plantas',action='store_true')
    parser.add_argument('--andar',type=int)
    args=parser.parse_args()
    if args.plantas: plantas()
    else:
        for p in PLANTAS:
            if args.andar is None or args.andar==p['andar']: gerar(p)
        sys.path.insert(0,str(RAIZ/'ferramentas/cenario'))
        from preparar_terra_mascarada import preparar as preparar_mascaras_terra
        preparar_mascaras_terra()
        from preparar_arte_original import preparar as integrar_arte_original
        integrar_arte_original([args.andar] if args.andar else None)
