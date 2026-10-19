#!/usr/bin/env python3
"""Planta e terreno da fenda, derivados do mesmo manifesto; não regrava a arena original."""
import argparse
import json
import math
from pathlib import Path
import random
import re
import sys

RAIZ = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(RAIZ / "ferramentas/arena"))
import gerar_arena as G
import tscn as T

PLANTA = json.loads((RAIZ / "codigo/fendas/planta_bosque.json").read_text())
PREVIAS = RAIZ / "arte/previas/fenda"
RNG = random.Random(20261017)


def planta():
    PREVIAS.mkdir(parents=True, exist_ok=True)
    partes = ['''<svg xmlns="http://www.w3.org/2000/svg" width="1440" height="1100" viewBox="-1280 -1040 2560 1955">
<rect x="-1280" y="-1040" width="2560" height="1955" fill="#172a25"/>
<style>text {font-family:DejaVu Sans,sans-serif;fill:#f5e3ba} .nome{font-size:28px;font-weight:bold} .nota{font-size:25px;fill:#b7cbb5}</style>
<text x="-1190" y="-930" font-size="54" font-weight="bold">FENDA DO BOSQUE — PLANTA DO ANDAR</text>
<text x="-1190" y="-873" class="nota">2.400 × 1.632 px de terreno • grade 16 px • escala nativa preservada</text>''']
    for trilha in PLANTA["trilhas"]:
        pts = " ".join(f"{x},{y}" for x, y in trilha["pontos"])
        partes.append(f'<polyline points="{pts}" stroke="#496449" stroke-width="{trilha["raio"]*2}" fill="none" stroke-linecap="round" stroke-linejoin="round"/>')
    for s in PLANTA["setores"]:
        x, y = s["centro"]
        rx, ry = s["raios"]
        partes.append(f'<ellipse cx="{x}" cy="{y}" rx="{rx}" ry="{ry}" fill="#526e4d" stroke="#80976a" stroke-width="3"/>')
    for trilha in PLANTA["trilhas"]:
        pts = " ".join(f"{x},{y}" for x, y in trilha["pontos"])
        partes.append(f'<polyline points="{pts}" stroke="#d2ae74" stroke-width="14" fill="none" stroke-linecap="round" stroke-dasharray="20 14"/>')
    for x,y,rx,ry in PLANTA["lago"]["lobos"]:
        partes.append(f'<ellipse cx="{x}" cy="{y}" rx="{rx}" ry="{ry}" fill="#366b7a" stroke="#75acac" stroke-width="6"/>')
    for s in PLANTA["setores"]:
        x,y=s["centro"]
        partes.append(f'<text x="{x}" y="{y-24}" text-anchor="middle" class="nome">{s["nome"]}</text>')
        legenda = "ENTRADA SEGURA" if s["grupos"]==0 else f'{s["grupos"]} grupos de combate'
        if s["id"]=="guardiao": legenda="BOSS APÓS COMPLETAR A BARRA"
        partes.append(f'<text x="{x}" y="{y+16}" text-anchor="middle" font-size="21">{legenda}</text>')
        if s["grupos"]:
            for i in range(s["grupos"]):
                partes.append(f'<circle cx="{x+(i-(s["grupos"]-1)/2)*30}" cy="{y+58}" r="9" fill="#efb974"/>')
    partes += ['''<text x="-1190" y="760" class="nota">Rotas alternativas: margem do lago ou trilha central; circuito pelo bosque leste.</text>
<text x="-1190" y="810" class="nota">11 grupos + 2 elites • inimigos de sobra para a barra • clareira final livre para o guardião.</text>
<text x="-1190" y="860" class="nota">Bosque fechado delimita passagens; sem ampliar os sprites. Arena anterior preservada.</text></svg>''']
    saida=PREVIAS / "planta_bosque.svg"
    saida.write_text("\n".join(partes))
    import subprocess
    subprocess.run(["magick", "-background", "none", str(saida), str(PREVIAS / "planta_bosque.png")], check=True)
    print(saida)


def distancia_caminhavel(x, y):
    valores = []
    for setor in PLANTA["setores"]:
        cx, cy = setor["centro"]
        rx, ry = setor["raios"]
        if setor.get("formato")=="patio":
            # Pátios com cantos chanfrados, ligados pelas mesmas trilhas da planta.
            valores.append(max(abs(x-cx)-rx,abs(y-cy)-ry,(abs(x-cx)+abs(y-cy)-rx-ry+16)*.7071))
        else:
            valores.append((math.hypot((x-cx)/rx, (y-cy)/ry)-1)*min(rx,ry))
    for trilha in PLANTA["trilhas"]:
        pts=trilha["pontos"]
        valores.append(min(G.dist_segmento((x,y),a,b) for a,b in zip(pts,pts[1:]))-trilha["raio"])
    return min(valores)


def area(anel):
    return abs(sum(a[0]*b[1]-b[0]*a[1] for a,b in zip(anel,anel[1:]+anel[:1])))/2


def construir(folga_limite=0, limite_retangular=False):
    base=G.Base(G.BASE)
    # Apenas estrutura e recursos da referência, sem copiar o layout pequeno.
    nomes={"Terrains","Objetos3D","LimiteArena","LimiteArena/Contorno","Obstaculos","Navegacao"}
    base.nos=[n for n in base.nos if n["caminho"] in nomes]
    base.nos[0]["bloco"]='[node name="Terrains" type="Node2D"]\ntexture_filter = 1\n'
    m=G.Mundo(base)
    x0,y0,w,h=PLANTA["limites"]
    # Nas fendas florestais, a planta orienta salas/trilhas; o limite físico fica
    # dentro da mata, para não bloquear a faixa de grama livre antes dos troncos.
    aneis=G.contornos(lambda x,y:distancia_caminhavel(x,y)-folga_limite,
                      x0-folga_limite,y0-folga_limite,
                      x0+w+folga_limite,y0+h+folga_limite,8)
    aneis=[G.simplificar_anel(a,2) for a in aneis]
    aneis.sort(key=area,reverse=True)
    if limite_retangular:
        # Sem muros ou calçamento, a grama entre as salas também é caminhável.
        aneis=[G.poligono_retangulo(x0,y0,x0+w,y0+h)]
    m.poli=aneis[0]
    m.obstaculos.extend(aneis[1:])
    for n in base.nos:
        if n["caminho"]=="LimiteArena/Contorno":
            n["bloco"]='[node name="Contorno" type="CollisionPolygon2D" parent="LimiteArena"]\nbuild_mode = 1\npolygon = %s\n' % T.poligono(m.poli)
    m.props_mantidos=[]
    m.lagoa.lobos=PLANTA["lago"]["lobos"]
    m.lagoa.pe=None
    # Água com as mesmas margens nativas da arena, em folhas privadas da fenda.
    lobos=m.lagoa.lobos
    agua_x0=int(min((c[0]-c[2]-24 for c in lobos),default=0)//16)
    agua_x1=int(max((c[0]+c[2]+24 for c in lobos),default=0)//16)+1
    agua_y0=int(min((c[1]-c[3]-24 for c in lobos),default=0)//16)
    agua_y1=int(max((c[1]+c[3]+24 for c in lobos),default=0)//16)+1
    for cy in range(agua_y0,agua_y1):
        for cx in range(agua_x0,agua_x1):
            grade=[m.lagoa.dist(cx*16+x+.5,cy*16+y+.5) for y in range(16) for x in range(16)]
            if max(grade)<-3:
                m.agua[cx,cy]=RNG.choice(G.AGUA)
                if RNG.random()<.3: m.brilho[cx,cy]=(0,RNG.randrange(3))
            elif min(grade)<1:
                k=len(m.tiles_margem)
                m.tiles_margem.append((grade,RNG.choice(G.GRAMA),RNG.choice(G.AGUA)))
                m.agua[cx,cy]=(k%16,16+k//16)
    for a in G.contornos(m.lagoa.dist,agua_x0*16,agua_y0*16,agua_x1*16,agua_y1*16,4,1.5):
        m.obstaculos.append(G.simplificar_anel(a,1.2))
    # Separar água/ilhas dos objetos: a composição pode remover ou trocar sprites.
    m.obstaculos_terreno = list(m.obstaculos)
    terra=set()
    proibido=set()
    for cy in range(y0//16-12,(y0+h)//16+13):
        for cx in range(x0//16-16,(x0+w)//16+17):
            x,y=cx*16+8,cy*16+8
            m.chao[cx,cy]=RNG.choice(G.FLORES if RNG.random()<.025 else G.GRAMA)
            if m.lagoa.dist(x,y)<32 or distancia_caminhavel(x,y)>-30:
                proibido.add((cx,cy))
                continue
            distancia=min(G.dist_segmento((x,y),a,b) for t in PLANTA["trilhas"] for a,b in zip(t["pontos"],t["pontos"][1:]))
            mancha=any(math.hypot((x-s["centro"][0])/(s["raios"][0]*.62),(y-s["centro"][1])/(s["raios"][1]*.52)) < 1 for s in PLANTA["setores"] if s["id"] in ["entrada","central","guardiao"])
            if distancia<26+G.ruido(x,y,60,77)*10 or mancha:
                terra.add((cx,cy))
    m.terra=G.tiles_terra(G.regularizar_terra(terra,proibido))
    # Floresta densa acompanha o limite e as ilhas; troncos fora da área caminhável.
    # Copas não encobrem o centro das trilhas ou a área do boss.
    i=0
    for y in range(y0-120,y0+h+160,48):
        for x in range(x0-160,x0+w+160,44):
            px=x+RNG.randint(-10,10)+(22 if (y//48)%2 else 0)
            py=y+RNG.randint(-8,8)
            d=distancia_caminhavel(px,py)
            if d<12 or m.lagoa.dist(px,py)<28: continue
            i+=1
            m.sprites_novos.append({"nome":f"AbetoBorda{i}","x":px,"y":py,"tipo":"carvalho" if RNG.random()<.13 else "abeto"})
    # Vegetação de margem e detalhes baixos, sem invadir os corredores de combate.
    for i in range(220):
        x=RNG.randrange(x0+80,x0+w-80)
        y=RNG.randrange(y0+80,y0+h-80)
        d=distancia_caminhavel(x,y)
        if not -48<d<-16 or m.lagoa.dist(x,y)<40: continue
        if any(math.dist((x,y),s["centro"])<s["raios"][0]*.85 for s in PLANTA["setores"]): continue
        m.sprites_novos.append({"nome":f"ArbustoMargem{i}","x":x,"y":y,"tipo":"arbusto_m"})
        m.obstaculos.append(G.poligono_retangulo(x-5,y-8,x+5,y))
    for i in range(100):
        x=RNG.randrange(x0,x0+w)//16
        y=RNG.randrange(y0,y0+h)//16
        if distancia_caminhavel(x*16+8,y*16+8)<-45 and (x,y) not in m.terra and m.lagoa.dist(x*16,y*16)>45:
            m.detalhes[x,y]=RNG.choice(G.PLANTAS)
    return m


def gerar():
    RNG.seed(20261017)
    G.RNG.seed(20261017)
    m=construir()
    # Não chamar gerar_arena.main: o original e seus atlas nunca são sobrescritos.
    G.PASTA_FOLHAS=str(RAIZ / "assets/cenario/fenda_bosque")
    for estacao in G.ESTACOES:
        G.gerar_folha_estacao(estacao,m.tiles_margem)
    texto=G.escrever_cena(m)
    texto=texto.replace("res://codigo/logica/navegacao_arena.gd","res://codigo/fendas/navegacao_fenda.gd")
    texto=re.sub(r' uid="[^"]+"','',texto)
    texto=texto.replace('res://assets/cenario/Seasonal Forest/arena/','res://assets/cenario/fenda_bosque/')
    # A fenda tem uma única saída no portal, com a confirmação de encerramento existente.
    blocos=re.split(r"\n(?=\[)",texto)
    blocos=[b for b in blocos if not (b.startswith('[node ') and ('name="PassagemCaverna"' in b or 'parent="PassagemCaverna"' in b or 'name="Chegada_caverna"' in b))]
    texto="\n".join(blocos)
    folhas=', '.join('ExtResource("fenda_%d")'%i for i in range(4))
    extras='\n'.join('[ext_resource type="Texture2D" path="res://assets/cenario/fenda_bosque/%s.png" id="fenda_%d"]'%(e,i) for i,e in enumerate(G.ESTACOES))
    texto=texto.replace('[sub_resource',extras+'\n\n[sub_resource',1)
    texto=texto.replace('estacao_inicial = 3','estacao_inicial = 3\nseguir_calendario = true\nfolhas_personalizadas = Array[Texture2D]([%s])\narea_clima_centro = Vector2(0, -16)\narea_clima_extensao = Vector2(1200, 816)'%folhas)
    for nome,pos in [('Chegada_portal',PLANTA['entrada']),('ClareiraGuardiao',PLANTA['guardiao'])]:
        grupo=' groups=["chegada"]' if nome=='Chegada_portal' else ''
        texto+='\n[node name="%s" type="Marker2D" parent="."%s]\nposition = Vector2(%d, %d)\n'%(nome,grupo,*pos)
    texto+='\n[node name="Setores" type="Node2D" parent="."]\n'
    for setor in PLANTA['setores']:
        texto+='\n[node name="%s" type="Marker2D" parent="Setores"]\nposition = Vector2(%d, %d)\nmetadata/grupos = %d\n'% (setor['id'],*setor['centro'],setor['grupos'])
    texto+='\n[node name="GruposCombate" type="Node2D" parent="."]\n'
    # Posições de encontro são parte da planta; inimigos permanecem em pequenos grupos.
    for setor in PLANTA['setores']:
        for i in range(setor['grupos']):
            angulo=2*math.pi*i/max(setor['grupos'],1)+.5
            x=setor['centro'][0]+round(math.cos(angulo)*72)
            y=setor['centro'][1]+round(math.sin(angulo)*64)
            elite=setor['id'] in ['leste','norte'] and i==0
            texto+='\n[node name="%s_%d" type="Marker2D" parent="GruposCombate"]\nposition = Vector2(%d, %d)\nmetadata/elite = %s\n'%(setor['id'],i,x,y,str(elite).lower())
    texto=re.sub(r'load_steps=\d+', 'load_steps=%d'%(texto.count('[ext_resource')+texto.count('[sub_resource')+1),texto,count=1)
    (RAIZ / 'cenas/terreno_fenda.tscn').write_text(texto)
    print('Terreno:',len(m.chao),'tiles;',len(m.sprites_novos),'props;',len(m.obstaculos),'obstaculos')


if __name__ == "__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("--planta", action="store_true")
    args=parser.parse_args()
    planta()
    if not args.planta: gerar()
