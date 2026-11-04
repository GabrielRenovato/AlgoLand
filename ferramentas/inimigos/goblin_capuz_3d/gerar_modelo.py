"""Modelagem estática original baseada na referência do usuário; Blender background."""
import ast, math, json, random
from pathlib import Path
import bpy
from mathutils import Vector
from mathutils.noise import noise_vector
RAIZ=Path(__file__).resolve().parents[3]
util=RAIZ/'ferramentas/inimigos/goblin_king/gerar_modelo.py'
nomes={'material','registrar','aplicar','bola','malha','tubo','ponta','anel','unir'}
exec(compile(ast.Module(body=[n for n in ast.parse(util.read_text()).body if isinstance(n,ast.FunctionDef) and n.name in nomes],type_ignores=[]),str(util),'exec'))
random.seed(43)
PECAS=[];MATERIAIS={};OSSO='estatico'
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
pele=material('Pele_musgo',(.29,.37,.095),variacao=.07)
luz=material('Relevo_pele',(.35,.42,.12),variacao=.05)
sombra=material('Cavidades',(.025,.032,.012))
orelha=material('Interior_orelha',(.26,.18,.065))
verde=material('Capuz_verde',(.055,.115,.080),variacao=.12)
verde_luz=material('Dobras_verdes',(.085,.155,.105),variacao=.10)
forro=material('Forro_capuz',(.018,.036,.025))
couro=material('Couro_marrom',(.105,.048,.025),variacao=.15)
borda=material('Couro_desgastado',(.19,.102,.052),variacao=.12)
calca=material('Calca_castanha',(.075,.059,.042),variacao=.12)
metal=material('Ferro',(.24,.26,.25),metal=.7,rugosidade=.4)
aco=material('Aco_lamina',(.49,.54,.55),metal=.8,rugosidade=.28)
fio=material('Fio_claro',(.73,.77,.76),metal=.8,rugosidade=.22)
dente=material('Marfim',(.78,.69,.44))
olho=material('Olho_dourado',(.57,.49,.20),rugosidade=.35)
preto=material('Pupila',(.004,.006,.002))
# Silhueta baixa, tronco largo, pernas curtas e pés descalços.
bola('Tronco',(0,0,.80),(.255,.155,.27),couro)
bola('Quadril',(0,.01,.53),(.225,.15,.16),calca)
for s in [-1,1]:
    ponta('Coxa',(s*.14,0,.56),(s*.18,.005,.30),.12,.103,calca,vertices=24)
    bola('Joelho',(s*.18,-.015,.30),(.103,.106,.09),calca)
    ponta('Canela',(s*.18,0,.30),(s*.20,-.005,.10),.085,.069,calca,vertices=24)
    bola('Pe',(s*.20,-.075,.064),(.103,.16,.055),pele)
    for j in range(4):
        x=s*.20+(j-1.5)*.044
        bola('Dedo_pe',(x,-.193,.044),(.024,.060,.030),pele)
        ponta('Unha_pe',(x,-.23,.052),(x,-.266,.026),.017,.002,borda)
    for j in range(6):
        z=.105+j*.022
        tubo('Faixa_tornozelo',[(s*.20+.077*math.cos(a*math.tau/24),.072*math.sin(a*math.tau/24),z+.006*math.sin(a*math.tau/24)) for a in range(25)],.013,couro if j%2 else borda, resolucao=1)
    ombro=(s*.25,0,.96);cot=(s*.36,-.025,.76);pulso=(s*.40,-.085,.55)
    bola('Ombro',ombro,(.11,.115,.12),verde)
    ponta('Braco',ombro,cot,.084,.067,pele,vertices=24)
    bola('Cotovelo',cot,(.071,.073,.076),pele)
    ponta('Antebraco',cot,pulso,.076,.052,couro,vertices=24)
    for j in range(8):
        p=Vector(cot).lerp(Vector(pulso),.1+j*.105)
        tubo('Atadura_braco',[(p.x+.072*math.cos(a*math.tau/24)*(1-j*.025),p.y+.064*math.sin(a*math.tau/24)*(1-j*.025),p.z+.008*math.sin(a*math.tau/24)) for a in range(25)],.009,borda,resolucao=1)
    bola('Mao',(s*.41,-.09,.50),(.071,.058,.071),pele)
    for j in range(4):
        bola('Dedos_mao',(s*.41+(j-1.5)*.026,-.132,.477),(.017,.031,.037),pele)
    bola('Polegar',(s*.355,-.135,.524),(.027,.033,.042),luz)
# Pele contínua: volumes unidos por voxel, evitando aparência de peças coladas.
rosto=[bola('Cranio',(0,-.018,1.20),(.215,.16,.215),pele),bola('Mandibula',(0,-.09,1.08),(.18,.142,.105),pele),bola('Queixo',(0,-.165,1.043),(.122,.078,.054),pele),bola('Focinho',(0,-.191,1.116),(.127,.063,.051),pele),bola('Ponte_nariz',(0,-.173,1.244),(.048,.058,.091),pele),bola('Nariz',(0,-.265,1.177),(.075,.081,.056),pele)]
for s in [-1,1]:
    rosto.append(bola('Maca',(s*.145,-.13,1.155),(.060,.066,.070),pele))
    o=bola('Supercilio',(s*.085,-.158,1.292),(.094,.061,.041),pele)
    o.rotation_euler.y=-s*.32;rosto.append(o)
unir(rosto,'Rosto_escultura',.0035)
for s in [-1,1]:
    x=s*.089
    bola('Orbita',(x,-.17,1.239),(.067,.040,.043),sombra)
    bola('Olho',(x,-.194,1.242),(.047,.022,.028),olho)
    bola('Iris',(x-s*.007,-.215,1.243),(.019,.005,.020),orelha)
    bola('Pupila',(x-s*.007,-.220,1.244),(.009,.003,.015),preto)
    bola('Reflexo',(x-s*.012,-.224,1.253),(.004,.002,.004),dente,segmentos=12,aneis=8)
    tubo('Palpebra',[(s*.039,-.204,1.249),(s*.088,-.215,1.263),(s*.137,-.185,1.27)],.010,pele)
    tubo('Olheira',[(s*.046,-.203,1.227),(s*.096,-.212,1.215),(s*.145,-.176,1.236)],.008,luz)
    bola('Narina',(s*.043,-.320,1.165),(.017,.008,.012),sombra)
    tubo('Vinco_rosto',[(s*.066,-.259,1.149),(s*.119,-.218,1.125),(s*.146,-.165,1.10)],.004,orelha)
    ponta('Presa',(s*.10,-.228,1.083),(s*.112,-.244,1.126),.013,.001,dente)
    cont=[(s*.172,.015,1.305),(s*.285,.025,1.337),(s*.422,.054,1.433),(s*.356,.02,1.267),(s*.242,-.025,1.184),(s*.182,-.045,1.215)]
    centro=(s*.264,-.025,1.28)
    malha('Orelha',[centro]+cont,[(0,j+1,(j+1)%6+1) for j in range(6)],pele,espessura=.017)
    interno=[(s*.222,-.030,1.297),(s*.386,.033,1.402),(s*.314,-.011,1.269),(s*.242,-.043,1.224)]
    malha('Concha_orelha',interno,[(0,1,2,3)],orelha,espessura=.004)
    tubo('Relevo_orelha',cont+[cont[0]],.008,luz,reto=True)
tubo('Boca',[(-.14,-.195,1.083),(-.09,-.246,1.106),(0,-.257,1.115),(.085,-.243,1.108),(.14,-.192,1.087)],.008,sombra)
tubo('Labio',[(-.098,-.238,1.088),(0,-.25,1.093),(.098,-.235,1.088)],.010,luz)
# Capuz: casca com abertura frontal real, topo arredondado e ponta traseira.
verts=[];faces=[];n=40
for j in range(15):
    t=j/14
    # anéis desde a abertura frontal até o fundo do capuz.
    y=-.19+t*.415
    rx=.251*math.sqrt(max(.002,1-t*t*.998));rz=(.223+.043*t)*math.sqrt(max(.002,1-t*t*.998))
    for k in range(n):
        a=k*math.tau/n
        verts.append((rx*math.sin(a),y,1.212+rz*math.cos(a)))
for j in range(14):
    for k in range(n):
        a=j*n+k;b=j*n+(k+1)%n;faces.append((a,b,b+n,a+n))
faces.append(tuple(14*n+k for k in range(n)))
malha('Capuz',verts,faces,verde,espessura=.014)
tubo('Borda_capuz',[(.251*math.sin(k*math.tau/n),-.196,1.212+.223*math.cos(k*math.tau/n)) for k in range(n+1)],.008,verde_luz)
# Manto curto sobre os ombros, borda irregular e pregas sobrepostas.
verts=[];faces=[];n=64
for j in range(5):
    t=j/4
    for k in range(n):
        a=k*math.tau/n
        z=1.075-.18*t
        if j==4:z+=.020*math.sin(k*2.2)+.014*math.cos(k*3.5)
        r=.14+.19*t+.009*math.sin(k*1.6)
        verts.append((r*math.cos(a),r*.63*math.sin(a),z))
for j in range(4):
    for k in range(n):
        a=j*n+k;b=j*n+(k+1)%n;faces.append((a,b,b+n,a+n))
malha('Manto_rasgado',verts,faces,verde,espessura=.012)
for j in range(4):
    z=1.07-j*.037
    tubo('Prega_gola',[(-.21,-.10,z+.04),(-.12,-.20,z-.008),(0,-.225,z-.035),(.14,-.18,z+.006),(.23,-.08,z+.05)],.021,verde_luz if j%2 else verde)
# Continuidade dos cintos nas costas.
for z in [.605,.674]:
    tubo('Cinto_costas',[(.232*math.cos(k*math.pi/32),.165*math.sin(k*math.pi/32),z) for k in range(33)],.024,couro,resolucao=1)
# Avental de tecido com ponta e pregas verticais.
malha('Pano_frontal',[(-.13,-.165,.66),(.13,-.165,.66),(.10,-.18,.40),(.02,-.20,.29),(-.08,-.185,.38)],[(0,1,2,3,4)],verde,espessura=.01)
for x in [-.07,-.025,.03,.07]:tubo('Prega_avental',[(x,-.178,.63),(x*.8,-.192,.48),(x*.4,-.201,.36+abs(x))],.009,verde_luz)
# Cintos largos e tiracolo, fivelas e rebites geométricos.
def fita(nome,pontos,largura,mat):
    vs=[]
    for i,p in enumerate(pontos):
        d=Vector(pontos[min(i+1,len(pontos)-1)])-Vector(pontos[max(i-1,0)])
        v=Vector((-d.z,0,d.x)).normalized()*largura/2
        vs.extend([Vector(p)-v,Vector(p)+v])
    return malha(nome,vs,[(2*i,2*i+1,2*i+3,2*i+2) for i in range(len(pontos)-1)],mat,espessura=.01)
fita('Tiracolo',[(-.23,-.115,1.00),(-.14,-.204,.89),(-.03,-.19,.78),(.17,-.165,.67)],.065,couro)
for z in [.605,.674]:
    fita('Cinto',[(-.22,-.08,z+.02),(-.15,-.164,z),(0,-.178,z-.01),(.16,-.16,z-.04),(.23,-.06,z-.05)],.047,borda)
for x,z in [(-.04,.612),(.02,.66),(-.065,.82)]:
    tubo('Fivela',[(x-.027,-.205,z-.024),(x+.027,-.205,z-.024),(x+.027,-.205,z+.024),(x-.027,-.205,z+.024),(x-.027,-.205,z-.024)],.006,metal,reto=True)
    tubo('Lingueta',[(x,-.212,z),(x+.023,-.212,z)],.003,metal,reto=True)
for s in [-1,1]:
    bola('Bolsa',(s*.24,-.07,.55),(.073,.057,.09),couro)
    tubo('Costura_bolsa',[(s*.29,-.10,.59),(s*.26,-.13,.52),(s*.20,-.12,.52)],.004,borda)
# Lâmina curva de seção espessa, fio separado e empunhadura na mão direita.
ponta('Cabo_lamina',(-.43,-.16,.54),(-.31,-.18,.40),.026,.026,couro)
ponta('Guarda',(-.39,-.19,.44),(-.28,-.19,.52),.016,.016,metal)
externo=[(-.34,-.20,.43),(-.28,-.23,.32),(-.16,-.24,.235),(.005,-.24,.19),(.18,-.23,.22),(.27,-.22,.29)]
interno=[(-.28,-.20,.47),(-.20,-.23,.395),(-.08,-.24,.33),(.06,-.24,.29),(.20,-.23,.29),(.27,-.22,.29)]
vs=externo+interno
malha('Lamina_curva',vs,[(i,i+1,i+7,i+6) for i in range(5)],aco,espessura=.015)
fita('Fio_lamina',externo,.014,fio)
# Costuras do capuz e couro: detalhes de escala média, sem ruído superficial.
for k in range(4,37,2):
    a=k*math.tau/40
    p=Vector((.248*math.sin(a),-.204,1.212+.222*math.cos(a)))
    tubo('Ponto_capuz',[p+Vector((-.003,0,.004)),p+Vector((.003,0,-.004))],.0018,borda,resolucao=0,reto=True)
for j in range(8):
    t=.14+j*.09
    x=-.23+.40*t;z=1.00-.33*t
    bola('Rebite_tiracolo',(x,-.211,z),(.004,.003,.004),metal,segmentos=8,aneis=6)
for s in [-1,1]:
    tubo('Ruga_testa',[(s*.025,-.18,1.335),(s*.055,-.166,1.35),(s*.105,-.143,1.345)],.0035,orelha)
    tubo('Dobra_canto_olho',[(s*.14,-.176,1.25),(s*.17,-.151,1.26)],.0035,orelha)
# Exportação estática: nenhuma armature, animação ou recurso do jogador.
FONTES=RAIZ/'arte/fontes/inimigos/goblin_capuz_3d';DESTINO=RAIZ/'assets/inimigos/goblin_capuz_3d';PREVIAS=RAIZ/'arte/previas/inimigos/goblin_capuz_3d'
bpy.ops.object.select_all(action='DESELECT')
for o in PECAS:o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(DESTINO/'goblin_capuz.glb'),export_format='GLB',use_selection=True,export_animations=False,export_materials='EXPORT',export_cameras=False,export_lights=False)
# Palco de revisão Blender; as luzes e câmeras não entram no GLB.
world=bpy.data.worlds.new('Estudio');bpy.context.scene.world=world;world.use_nodes=True;world.node_tree.nodes['Background'].inputs[0].default_value=(.07,.09,.085,1);world.node_tree.nodes['Background'].inputs[1].default_value=.45
for pos,energia,tam in [((-3,-4,5),420,4),((3,-2,3),240,3),((1,3,4),450,3)]:
    bpy.ops.object.light_add(type='AREA',location=pos);o=bpy.context.object;o.data.energy=energia;o.data.shape='DISK';o.data.size=tam;o.rotation_euler=(Vector((0,0,.8))-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(2.2,-5,2.1));cam=bpy.context.object;cam.data.type='ORTHO';cam.data.ortho_scale=1.8;cam.rotation_euler=(Vector((0,0,.76))-cam.location).to_track_quat('-Z','Y').to_euler();bpy.context.scene.camera=cam
sc=bpy.context.scene;sc.render.engine='CYCLES';sc.cycles.samples=32;sc.render.resolution_x=900;sc.render.resolution_y=1000;sc.render.resolution_percentage=100
bpy.ops.wm.save_as_mainfile(filepath=str(FONTES/'goblin_capuz.blend'))
sc.render.filepath=str(PREVIAS/'blender.png');bpy.ops.render.render(write_still=True)
rel={'referencia':'referencia.webp','metodo':'geometria original; primitivas utilitárias compartilhadas, sem malhas de outros personagens','animacoes':0,'rig':False,'altura_m':1.48,'limites':['estático','não integrado ao mapa','não perfilado para mobile']}
(FONTES/'manifesto.json').write_text(json.dumps(rel,ensure_ascii=False,indent=2))
print('GOBLIN_CAPUZ_EXPORTADO',flush=True)
