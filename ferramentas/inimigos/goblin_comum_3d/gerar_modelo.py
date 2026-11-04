"""Goblin comum: malha 3D própria, roupa simples e mãos vazias.

Blender em background. Reutiliza apenas primitivas geométricas do projeto;
não instancia nem adapta o personagem Goblin King.
"""
import ast
import bpy
import math
import json
import random
import sys
from pathlib import Path
from mathutils import Vector
from mathutils.noise import noise_vector

RAIZ = Path(__file__).resolve().parents[3]
util = RAIZ / 'ferramentas/inimigos/goblin_king/gerar_modelo.py'
modulo = ast.parse(util.read_text())
nomes = {'material', 'registrar', 'aplicar', 'bola', 'malha', 'tubo', 'ponta', 'anel', 'unir'}
helpers = ast.Module(body=[n for n in modulo.body if isinstance(n, ast.FunctionDef) and n.name in nomes], type_ignores=[])
exec(compile(helpers, str(util), 'exec'), globals())
FONTES = RAIZ / 'arte/fontes/inimigos/goblin_comum_3d'
DESTINO = RAIZ / 'assets/inimigos/goblin_comum_3d'
PREVIAS = RAIZ / 'arte/previas/inimigos/goblin_comum_3d'
for pasta in [FONTES, DESTINO, PREVIAS]: pasta.mkdir(parents=True, exist_ok=True)
random.seed(8427)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
PECAS = []
MATERIAIS = {}
OSSO = 'peito'
PELE = material('Pele_oliva', (.20,.265,.060), rugosidade=.84, variacao=.09)
PELE_LUZ = material('Relevo_pele', (.23,.292,.073), rugosidade=.84, variacao=.04)
ORELHA = material('Concha_orelha', (.14,.17,.039), rugosidade=.9, variacao=.05)
SOMBRA = material('Cavidades', (.019,.026,.008), rugosidade=.95)
COURO = material('Couro_castanho', (.09,.037,.016), rugosidade=.86, variacao=.16)
COURO_LUZ = material('Costuras_couro', (.16,.079,.032), rugosidade=.9, variacao=.1)
TECIDO = material('Tecido_ocre', (.37,.205,.053), rugosidade=.98, variacao=.12)
CALCA = material('Calca_carvao', (.039,.033,.027), rugosidade=.98, variacao=.18)
REMEDO = material('Remendo_gasto', (.15,.116,.061), rugosidade=.99, variacao=.12)
CABELO = material('Cabelo_escuro', (.016,.013,.012), rugosidade=.91, variacao=.12)
CABELO_LUZ = material('Mechas_cabelo', (.033,.027,.023), rugosidade=.9, variacao=.1)
MARFIM = material('Presas_marfim', (.76,.64,.41), rugosidade=.6)
OLHO = material('Olho_ambar', (.88,.31,.012), rugosidade=.32)
ESCLERA = material('Esclera_ocre', (.51,.43,.18), rugosidade=.48)
PUPILA = material('Pupila_escura', (.003,.004,.002), rugosidade=.35)
METAL = material('Fivela_ferro', (.08,.085,.081), metal=.65, rugosidade=.6)


def volume(nome, centros, raios, mat, osso, lados=16, dobras=0):
    verts, faces = [], []
    for j,p in enumerate(centros):
        p = Vector(p)
        t = Vector(centros[min(j+1,len(centros)-1)])-Vector(centros[max(j-1,0)])
        q = t.to_track_quat('Z','Y')
        rx,ry = raios[j]
        for k in range(lados):
            a = k*math.tau/lados
            f = 1+dobras*math.sin(a*5+j*.9)
            v = p+q@Vector((rx*math.cos(a)*f,ry*math.sin(a)*f,0))
            verts.append(tuple(v))
    for j in range(len(centros)-1):
        for k in range(lados):
            a=j*lados+k;b=j*lados+(k+1)%lados
            faces.append((a,b,b+lados,a+lados))
    faces += [tuple(reversed(range(lados))), tuple((len(centros)-1)*lados+k for k in range(lados))]
    return malha(nome,verts,faces,mat,osso)


def aro_elipse(nome, centro, rx, ry, raio, mat, osso, n=40):
    x,y,z=centro
    return tubo(nome,[(x+rx*math.cos(i*math.tau/n),y+ry*math.sin(i*math.tau/n),z) for i in range(n+1)],raio,mat,osso,1)


def faixa_torso(nome, zs, larguras, profundidades, mat, osso='peito', n=32, trapos=False):
    verts=[]
    for j,z in enumerate(zs):
        for k in range(n):
            a=k*math.tau/n
            onda=.003*math.sin(k*3+j)
            zz=z
            if trapos and j==0: zz += .026*math.sin(k*2.7)+(.025 if k%3==0 else -.014)
            verts.append((larguras[j]*math.cos(a),-.016+profundidades[j]*math.sin(a)+onda,zz))
    faces=[]
    for j in range(len(zs)-1):
        for k in range(n):
            a=j*n+k;b=j*n+(k+1)%n
            faces.append((a,b,b+n,a+n))
    return malha(nome,verts,faces,mat,osso,espessura=.008)


OSSOS={
 'raiz':((0,0,0),(0,0,.15),None),
 'quadril':((0,.015,.48),(0,.0,.61),'raiz'),
 'peito':((0,0,.61),(0,-.04,.94),'quadril'),
 'cabeca':((0,-.04,.94),(0,-.075,1.24),'peito'),
}
# Corpo de base sob a roupa; pescoço e braços ficam visíveis.
bola('Quadril',(0,.015,.50),(.18,.12,.16),CALCA,'quadril')
bola('Torso',(0,-.008,.75),(.215,.125,.235),PELE,'peito')
bola('Pescoco',(0,-.035,.96),(.095,.087,.115),PELE,'peito')

for s,lado in [(-1,'D'),(1,'E')]:
    ombro=(s*.239,-.023,.884)
    cotovelo=(s*.335,-.042,.683)
    pulso=(s*.377,-.073,.503)
    mao=(s*.388,-.083,.466)
    OSSOS['braco_'+lado]=(ombro,cotovelo,'peito')
    OSSOS['antebraco_'+lado]=(cotovelo,pulso,'braco_'+lado)
    OSSOS['mao_'+lado]=(pulso,(s*.397,-.092,.415),'antebraco_'+lado)
    bracos=[]
    bracos.append(volume('Braco_'+lado,[ombro,Vector(ombro).lerp(Vector(cotovelo),.45),cotovelo],[(.075,.072),(.071,.066),(.052,.051)],PELE,'braco_'+lado))
    bracos.append(bola('Cotovelo_'+lado,cotovelo,(.053,.05,.052),PELE,'antebraco_'+lado))
    bracos.append(volume('Antebraco_'+lado,[cotovelo,Vector(cotovelo).lerp(Vector(pulso),.35),pulso],[(.051,.05),(.057,.048),(.035,.033)],PELE,'antebraco_'+lado))
    bracos.append(bola('Palma_'+lado,mao,(.044,.028,.048),PELE,'mao_'+lado))
    for i in range(4):
        x=mao[0]+(i-1.5)*.020
        z=mao[2]-.025
        p0=(x,mao[1]-.003,z)
        p1=(x+s*.003,mao[1]-.017,z-.031- (.007 if i in [1,2] else 0))
        p2=(x+s*.005,mao[1]-.030,z-.044)
        bracos.append(tubo('Dedo_'+lado,[p0,p1,p2],.013,PELE,'mao_'+lado,2,reto=True))
    bracos.append(tubo('Polegar_'+lado,[(mao[0]-s*.032,mao[1]+.003,mao[2]+.012),(mao[0]-s*.052,mao[1]-.018,mao[2]-.010),(mao[0]-s*.044,mao[1]-.03,mao[2]-.028)],.016,PELE,'mao_'+lado,2,reto=True))
    unido=unir(bracos,'Pele_braco_'+lado,.0035)
    unido['cadeia']=lado
    # Faixas de couro acompanham o pulso; não são manoplas de metal.
    eixo=(Vector(pulso)-Vector(cotovelo)).normalized()
    for f in [.74,.87,.98]:
        p=Vector(cotovelo).lerp(Vector(pulso),f)
        a=anel('Faixa_pulso_'+lado,p,.039,.008,COURO,'antebraco_'+lado)
        a.rotation_mode='QUATERNION';a.rotation_quaternion=eixo.to_track_quat('Z','Y')
    # Pernas curtas, levemente arqueadas, com calça e bota macia.
    quadril=(s*.108,.015,.50)
    joelho=(s*.145,-.030,.292)
    tornozelo=(s*.163,.005,.112)
    OSSOS['coxa_'+lado]=(quadril,joelho,'quadril')
    OSSOS['canela_'+lado]=(joelho,tornozelo,'coxa_'+lado)
    OSSOS['pe_'+lado]=(tornozelo,(s*.163,-.16,.065),'canela_'+lado)
    volume('Calca_coxa_'+lado,[quadril,Vector(quadril).lerp(Vector(joelho),.55),joelho],[(.097,.09),(.09,.081),(.077,.074)],CALCA,'coxa_'+lado,dobras=.045)
    volume('Calca_canela_'+lado,[joelho,Vector(joelho).lerp(Vector(tornozelo),.4),tornozelo],[(.077,.073),(.067,.062),(.054,.055)],CALCA,'canela_'+lado,dobras=.06)
    bola('Bota_'+lado,(s*.163,-.078,.067),(.084,.171,.057),COURO,'pe_'+lado)
    # Sola com base plana no chão.
    n=24;verts=[]
    for z in [0,.022]:
        for k in range(n):
            a=k*math.tau/n
            verts.append((s*.163+.086*math.cos(a),-.078+.170*math.sin(a),z))
    faces=[tuple(reversed(range(n))),tuple(n+k for k in range(n))]+[(k,(k+1)%n,(k+1)%n+n,k+n) for k in range(n)]
    malha('Sola_'+lado,verts,faces,COURO_LUZ,'pe_'+lado,bevel=.003)
    volume('Cano_bota_'+lado,[(s*.163,.001,.06),(s*.163,.003,.12),(s*.163,.005,.168)],[(.057,.058),(.060,.059),(.063,.061)],COURO,'canela_'+lado,dobras=.035)
    for z in [.119,.143,.164]:
        aro_elipse('Dobra_bota_'+lado,(s*.163,.003,z),.061,.06,.006,COURO_LUZ,'canela_'+lado,n=24)
    # Remendo de tecido com pontos de costura reais, discreto e sem placas.
    cx=s*.145;cy=-.106;cz=.304
    cont=[(cx-.041,cy,cz+.044),(cx+.043,cy+.002,cz+.036),(cx+.037,cy-.003,cz-.038),(cx-.039,cy-.002,cz-.045)]
    malha('Remendo_joelho_'+lado,cont,[(0,1,2,3)],REMEDO,'coxa_'+lado,espessura=.0025)
    for j in range(4):
        a=Vector(cont[j]);b=Vector(cont[(j+1)%4])
        for f in [.15,.39,.63,.87]:
            p=a.lerp(b,f)
            v=(b-a).normalized();normal=Vector((-v.z,0,v.x))*.005
            tubo('Ponto_remendo', [p-normal+Vector((0,-.002,0)),p+normal+Vector((0,-.002,0))],.0018,COURO_LUZ,'coxa_'+lado,0,reto=True)

# Camadas simples de roupa: camisa rasgada, colete aberto no pescoço e cinto.
faixa_torso('Tecido_saia',[.395,.52,.58],[.218,.19,.185],[.135,.129,.125],TECIDO,'quadril',trapos=True)
faixa_torso('Colete_couro',[.555,.66,.79,.88,.93],[.189,.187,.223,.227,.13],[.13,.135,.143,.133,.095],COURO)
aro_elipse('Bainha_colete',(0,-.016,.565),.191,.132,.006,COURO_LUZ,'quadril')
# Gola V frontal, sem colar ou metal ornamental.
tubo('Costura_gola',[(-.105,-.086,.93),(-.083,-.142,.868),(0,-.157,.824),(.080,-.142,.868),(.105,-.086,.93)],.006,COURO_LUZ,'peito',1)
for s in [-1,1]:
    # Abas de tecido nos ombros.
    pts=[(s*.127,-.05,.925),(s*.226,-.062,.91),(s*.270,-.06,.865),(s*.237,-.088,.849),(s*.209,-.084,.866),(s*.176,-.085,.851)]
    malha('Manga_rasgada',pts,[(0,1,2,3,4,5)],TECIDO,'peito',espessura=.004)
faixa_torso('Cinto',[.557,.589],[.199,.196],[.137,.137],COURO_LUZ,'quadril')
# Fivela pequena retangular arredondada.
tubo('Fivela',[(-.035,-.159,.557),(.032,-.159,.557),(.032,-.159,.594),(-.035,-.159,.594),(-.035,-.159,.557)],.006,METAL,'quadril',1,reto=True)
tubo('Pino_fivela',[(0,-.166,.576),(.032,-.166,.576)],.003,METAL,'quadril',1,reto=True)
bola('Bolsa_cinto',(.186,.04,.525),(.071,.043,.065),COURO,'quadril')
malha('Aba_bolsa',[(.124,.003,.559),(.239,.003,.559),(.229,-.012,.516),(.164,-.015,.501),(.125,-.004,.523)],[(0,1,2,3,4)],COURO_LUZ,'quadril',espessura=.004)
bola('Botao_bolsa',(.178,-.019,.526),(.008,.004,.008),METAL,'quadril',segmentos=12,aneis=8)
# Costura lateral e poucos riscos de desgaste evitam superfície plástica lisa.
for s in [-1,1]:
    tubo('Costura_lateral',[(s*.165,-.091,.594),(s*.185,-.102,.704),(s*.198,-.081,.825)],.003,COURO_LUZ,'peito',1)

# Cabeça esculpida: nariz comprido/curvado, maçãs marcadas e sobrancelha inclinada.
partes=[bola('Cranio',(0,-.065,1.112),(.205,.158,.205),PELE,'cabeca',segmentos=32,aneis=24),
 bola('Mandibula',(0,-.120,1.005),(.174,.143,.110),PELE,'cabeca'),
 bola('Queixo',(0,-.205,.973),(.126,.102,.068),PELE,'cabeca'),
 bola('Focinho',(0,-.234,1.035),(.151,.090,.060),PELE,'cabeca'),
 bola('Nariz_ponte',(0,-.218,1.160),(.049,.066,.103),PELE,'cabeca'),
 bola('Nariz_gancho',(0,-.313,1.085),(.071,.083,.060),PELE,'cabeca'),
 bola('Nariz_ponta',(0,-.333,1.060),(.046,.051,.043),PELE,'cabeca')]
for s in [-1,1]:
    partes.append(bola('Maca_rosto',(s*.145,-.17,1.065),(.064,.077,.075),PELE,'cabeca'))
    sobrancelha=bola('Sobrancelha',(s*.100,-.19,1.188),(.094,.044,.030),PELE,'cabeca')
    sobrancelha.rotation_euler.y=-s*.15
    partes.append(sobrancelha)
unir(partes,'Rosto_esculpido',.0042)
for s in [-1,1]:
    cont=[(s*.163,-.032,1.235),(s*.282,-.003,1.273),(s*.535,.042,1.333),(s*.415,-.010,1.146),(s*.268,-.075,1.070),(s*.176,-.087,1.105)]
    centro=(s*.291,-.021,1.194)
    malha('Orelha_concha',[centro]+cont,[(0,k+1,(k+1)%6+1) for k in range(6)],PELE,'cabeca',espessura=.019)
    dentro=[(s*.203,-.055,1.224),(s*.296,-.018,1.248),(s*.460,.022,1.302),(s*.363,-.033,1.164),(s*.251,-.087,1.115)]
    malha('Orelha_interna',[(s*.292,-.040,1.204)]+dentro,[(0,k+1,(k+1)%5+1) for k in range(5)],ORELHA,'cabeca',espessura=.006)
    tubo('Borda_orelha',cont+[cont[0]],.005,PELE_LUZ,'cabeca',2,reto=True)
    x=s*.099
    bola('Orbita',(x,-.219,1.147),(.066,.033,.044),SOMBRA,'cabeca')
    bola('Esclera',(x,-.240,1.147),(.056,.023,.032),ESCLERA,'cabeca')
    bola('Iris',(x+s*.003,-.261,1.145),(.023,.006,.025),OLHO,'cabeca',segmentos=24,aneis=16)
    bola('Pupila',(x+s*.003,-.267,1.145),(.0055,.003,.019),PUPILA,'cabeca',segmentos=16,aneis=12)
    bola('Brilho_olho',(x-.006,-.270,1.153),(.004,.002,.004),MARFIM,'cabeca',segmentos=8,aneis=6)
    tubo('Palpebra_superior',[(s*.040,-.242,1.155),(s*.095,-.265,1.176),(s*.155,-.224,1.181)],.012,PELE,'cabeca',1)
    tubo('Palpebra_inferior',[(s*.044,-.241,1.140),(s*.102,-.262,1.126),(s*.154,-.224,1.151)],.007,PELE_LUZ,'cabeca',1)
    bola('Narina',(s*.039,-.378,1.061),(.015,.006,.010),SOMBRA,'cabeca',segmentos=16,aneis=8)
    tubo('Vinco_bochecha',[(s*.076,-.297,1.048),(s*.125,-.260,1.024),(s*.153,-.210,1.030)],.004,ORELHA,'cabeca',1)
    ponta('Presa',(s*.101,-.294,.992),(s*.113,-.318,1.055),.015,.001, MARFIM,'cabeca',vertices=12)
    tubo('Vinco_testa',[(s*.038,-.212,1.229),(s*.094,-.199,1.245),(s*.153,-.162,1.238)],.003,ORELHA,'cabeca',1)
tubo('Boca',[(-.149,-.233,1.014),(-.098,-.294,.993),(0,-.310,.986),(.099,-.292,.996),(.151,-.230,1.025)],.006,SOMBRA,'cabeca',1)
tubo('Labio',[(-.095,-.291,.981),(0,-.301,.977),(.095,-.291,.984)],.006,PELE_LUZ,'cabeca',1)

# Cabelo em mechas volumétricas curvas, em vez de cones soltos sobre a cabeça.
bola('Base_cabelo',(0,-.029,1.285),(.172,.136,.075),CABELO,'cabeca',segmentos=24,aneis=16)
def mecha(nome,a,b,c,raio,mat):
    pts=[Vector(a),Vector(a).lerp(Vector(b),.7),Vector(b),Vector(c)]
    return volume(nome,pts,[(raio,raio*.56),(raio*.88,raio*.48),(raio*.6,raio*.36),(.001,.001)],mat,'cabeca',lados=6)
for j in range(9):
    y=-.145+j*.035
    for k in [-1,0,1]:
        x=k*(.047+random.random()*.008)
        z=1.303-abs(y+.02)*.10
        a=(x,y,z)
        b=(x*1.2,y+.017,z+.037+random.random()*.027)
        c=(x*1.45,y+.064,z+.063+random.random()*.035)
        mecha('Mecha_crista',a,b,c,.028 if k else .034,CABELO_LUZ if (j+k)%4==0 else CABELO)
for s in [-1,1]:
    for j in range(5):
        a=(s*(.122+j*.004),-.02+j*.027,1.285-j*.013)
        mecha('Mecha_lateral',a,(a[0]+s*.014,a[1]+.018,a[2]+.012),(a[0]+s*.035,a[1]+.075,a[2]-.014),.021,CABELO)

# Fonte em escala real: 1,35m de corpo, chão na sola. Todos os ossos acompanham.
altura=max((o.matrix_world@v.co).z for o in PECAS if o.type=='MESH' for v in o.data.vertices)
fator=1.35/altura
for o in PECAS:
    if o.type!='MESH': continue
    mw=o.matrix_world.copy()
    for v in o.data.vertices: v.co=(mw@v.co)*fator
    o.matrix_world.identity()
for nome,(a,b,pai) in list(OSSOS.items()):OSSOS[nome]=(tuple(Vector(a)*fator),tuple(Vector(b)*fator),pai)

bpy.ops.object.select_all(action='DESELECT')
bpy.ops.object.armature_add()
rig=bpy.context.object;rig.name='GoblinComum_Rig'
bpy.ops.object.mode_set(mode='EDIT')
rig.data.edit_bones.remove(rig.data.edit_bones[0])
for nome,(a,b,pai) in OSSOS.items():
    osso=rig.data.edit_bones.new(nome);osso.head=a;osso.tail=b
    if pai:osso.parent=rig.data.edit_bones[pai]
bpy.ops.object.mode_set(mode='OBJECT');rig.show_in_front=True

def distancia_segmento(p,a,b):
    a,b=Vector(a),Vector(b);v=b-a
    return (p-(a+v*max(0,min(1,(p-a).dot(v)/max(v.length_squared,1e-8))))).length
for o in PECAS:
    if o.type!='MESH':continue
    if not o.data.uv_layers:
        uv=o.data.uv_layers.new(name='UVMap')
        for poly in o.data.polygons:
            for loop in poly.loop_indices:
                co=o.data.vertices[o.data.loops[loop].vertex_index].co
                uv.data[loop].uv=(co.x*2+co.y*.6,co.z*2+co.y*.4)
    cadeia=o.get('cadeia')
    if cadeia:
        nomes_cadeia=['braco_'+cadeia,'antebraco_'+cadeia,'mao_'+cadeia]
        grupos={n:o.vertex_groups.new(name=n) for n in nomes_cadeia}
        for v in o.data.vertices:
            pesos=[(n,1/max(.012,distancia_segmento(v.co,*OSSOS[n][:2]))**4) for n in nomes_cadeia]
            pesos=sorted(pesos,key=lambda p:p[1],reverse=True)[:2];total=sum(w for _,w in pesos)
            for n,w in pesos:grupos[n].add([v.index],w/total,'REPLACE')
    else:
        g=o.vertex_groups.new(name=o['osso']);g.add(list(range(len(o.data.vertices))),1,'REPLACE')
    mod=o.modifiers.new('Esqueleto','ARMATURE');mod.object=rig
    o.parent=rig;o.matrix_parent_inverse=rig.matrix_world.inverted()
# Agrupar por material mantém os pesos e reduz a fragmentação do GLB.
objetos=[]
for nome,mat in MATERIAIS.items():
    lista=[o for o in PECAS if o.type=='MESH' and o.data.materials and o.data.materials[0]==mat]
    if lista:
        o=unir(lista,'GoblinComum_'+nome)
        tris=sum(len(p.vertices)-2 for p in o.data.polygons)
        if tris>5000:
            m=o.modifiers.new('Topologia_jogo','DECIMATE');m.ratio=min(1,5000/tris)
            bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=m.name)
        objetos.append(o)
# Respiração apenas, sem prometer os movimentos de combate cancelados.
rig.animation_data_create();acao=bpy.data.actions.new('parado');rig.animation_data.action=acao
for frame,valor in [(1,0),(21,1),(41,0),(61,-1),(81,0)]:
    for nome in ['peito','cabeca']:
        p=rig.pose.bones[nome];p.rotation_mode='XYZ';p.rotation_euler=(valor*(.008 if nome=='peito' else -.006),0,0)
        p.keyframe_insert(data_path='rotation_euler',frame=frame,group=nome)
rig.animation_data.action=None
trilha=rig.animation_data.nla_tracks.new();trilha.name='parado';trilha.strips.new('parado',1,acao)
scene=bpy.context.scene;scene.frame_start=1;scene.frame_end=81;scene.render.fps=30;scene.frame_set(1)
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
for o in objetos:o.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(DESTINO/'goblin_comum.glb'),export_format='GLB',use_selection=True,export_yup=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_skins=True,export_def_bones=True,export_materials='EXPORT',export_image_format='AUTO',export_cameras=False,export_lights=False)
# Luz e câmeras só na fonte editável e nos renders.
scene.render.engine='CYCLES';scene.cycles.samples=24
scene.render.resolution_x=900;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
scene.render.film_transparent=True;scene.world.color=(.16,.16,.16)
scene.view_settings.view_transform='AgX'
for nome,pos,forca,cor,tamanho in [('Principal',(-3,-4,5),500,(1,.91,.78),4),('Preenchimento',(3,-2,3),250,(.74,.84,1),3),('Recorte',(1,3,4),480,(1,.8,.55),2)]:
    d=bpy.data.lights.new(nome,'AREA');d.energy=forca;d.color=cor;d.shape='DISK';d.size=tamanho
    o=bpy.data.objects.new(nome,d);bpy.context.collection.objects.link(o);o.location=pos
    o.rotation_euler=(Vector((0,0,.7))-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(2.6,-4.5,2.15));camera=bpy.context.object;camera.name='Camera_revisao'
camera.rotation_euler=(Vector((0,-.02,.72))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.type='ORTHO';camera.data.ortho_scale=1.85;scene.camera=camera
bpy.ops.wm.save_as_mainfile(filepath=str(FONTES/'goblin_comum.blend'))
triangulos=sum(len(p.vertices)-2 for o in objetos for p in o.data.polygons)
relatorio={'arquivo':'res://assets/inimigos/goblin_comum_3d/goblin_comum.glb','fonte':'arte/fontes/inimigos/goblin_comum_3d/goblin_comum.blend','referencia':'referencia.png','metodo':'modelagem volumétrica própria em Blender, referência de goblin comum; não usa a malha de chefe','altura_m':1.35,'triangulos':triangulos,'ossos':len(OSSOS),'materiais':len(objetos),'animacoes':['parado'],'frente_blender':'-Y','frente_godot':'+Z','limites':['Modelo base, mãos vazias.','Caminhada, ataques, colisões e IA não integrados.','Não perfilado para mobile.']}
(DESTINO/'manifesto.json').write_text(json.dumps(relatorio,ensure_ascii=False,indent=2)+'\n')
print('GOBLIN_COMUM_EXPORTADO',json.dumps(relatorio,ensure_ascii=False),flush=True)
if '--renderizar' in sys.argv:
    scene.render.filepath=str(PREVIAS/'tres_quartos.png');bpy.ops.render.render(write_still=True)
    camera.location=(0,-5,1.6);camera.rotation_euler=(Vector((0,0,.70))-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(PREVIAS/'frente.png');bpy.ops.render.render(write_still=True)
