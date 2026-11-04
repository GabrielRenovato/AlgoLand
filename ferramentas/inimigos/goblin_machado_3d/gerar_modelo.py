"""Modela o machadeiro no Blender; referência canônica em arte/fontes/inimigos.

Frente -Y, chão em Z=0. Exporta GLB estático e a fonte .blend real.
Executar com Blender --background --python <caminho absoluto deste arquivo>.
"""
import ast
import json
import math
import random
from pathlib import Path

import bpy
from mathutils import Vector
from mathutils.geometry import tessellate_polygon

RAIZ = Path(__file__).resolve().parents[3]
FONTES = RAIZ / 'arte/fontes/inimigos/goblin_machado_3d'
DESTINO = RAIZ / 'assets/inimigos/goblin_machado_3d'
PREVIAS = RAIZ / 'arte/previas/inimigos/goblin_machado_3d'
for pasta in [FONTES, DESTINO, PREVIAS]:
    pasta.mkdir(parents=True, exist_ok=True)
random.seed(3271)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
PECAS = []
MATERIAIS = {}
OSSO = 'estatico'
util = RAIZ / 'ferramentas/inimigos/goblin_king/gerar_modelo.py'
nomes = {'registrar', 'aplicar', 'bola', 'malha', 'tubo', 'ponta', 'anel', 'unir'}
exec(compile(ast.Module(body=[n for n in ast.parse(util.read_text()).body
    if isinstance(n, ast.FunctionDef) and n.name in nomes], type_ignores=[]), str(util), 'exec'))

# O atlas gerado orienta as pinceladas. Cada material usa uma faixa de contraste
# controlada; a escultura continua legível sem manchas parecendo furos na pele.
atlas = bpy.data.images.load(str(FONTES / 'materiais_pixel.png'), check_existing=True)
aw, ah = atlas.size
ap = list(atlas.pixels)


def material(nome, cor, quadrante=None, contraste=.12, metal=0, rugosidade=.86):
    m = bpy.data.materials.new(nome)
    m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*cor, 1)
    p.inputs['Metallic'].default_value = metal
    p.inputs['Roughness'].default_value = rugosidade
    p.inputs['Specular IOR Level'].default_value = .26
    if quadrante is not None:
        n = 128
        image = bpy.data.images.new(nome + '_pintura_pixel', width=n, height=n)
        image.colorspace_settings.name = 'sRGB'
        pixels = []
        amostras = []
        qx, qy = quadrante
        for y in range(n):
            for x in range(n):
                ix = min(aw-1, int((qx + (x+.5)/n) * aw/2))
                iy = min(ah-1, int((qy + (y+.5)/n) * ah/2))
                i = (iy*aw+ix)*4
                valor = .2126*ap[i] + .7152*ap[i+1] + .0722*ap[i+2]
                amostras.append(valor)
        ordenadas = sorted(amostras)
        baixo = ordenadas[len(ordenadas)//12]
        alto = ordenadas[len(ordenadas)*11//12]
        for valor in amostras:
            t = max(0,min(.999,(valor-baixo)/max(.001,alto-baixo)))
            faixa = min(4,int(t*5))
            fator = 1 + (faixa-2)*contraste*.22
            linear = [max(0, min(1, c*fator)) for c in cor]
            pixels.extend([*(12.92*v if v <= .0031308 else 1.055*v**(1/2.4)-.055 for v in linear), 1])
        image.pixels.foreach_set(pixels)
        (DESTINO/'texturas').mkdir(exist_ok=True)
        image.filepath_raw = str(DESTINO/'texturas'/(nome+'.png'))
        image.file_format = 'PNG'
        image.save()
        image.pack()
        tex = m.node_tree.nodes.new('ShaderNodeTexImage')
        tex.image = image
        tex.interpolation = 'Closest'
        m.node_tree.links.new(tex.outputs['Color'], p.inputs['Base Color'])
    MATERIAIS[nome] = m
    return m


pele = material('Pele_oliva', (.225,.265,.075), (0,1), .48)
pele_rosto = material('Pele_rosto', (.245,.282,.083), (0,1), .32)
relevo = material('Pele_relevo', (.265,.30,.094), (0,1), .36)
orelha = material('Concha_orelha', (.195,.168,.055), (0,1), .07)
sombra = material('Cavidades', (.018,.023,.009))
couro = material('Couro_castanho', (.092,.043,.022), (1,1), .70)
couro_luz = material('Bordas_couro', (.153,.078,.038), (1,1), .55)
calca = material('Calca_carvao', (.039,.031,.025), (1,0), .50)
pano = material('Pano_castanho', (.107,.051,.026), (1,0), .60)
costura = material('Linha_couro', (.245,.156,.078), (1,1), .08)
ferro = material('Ferro_fosco', (.125,.143,.151), (0,0), .55, .35, .78)
aco = material('Aco_lamina', (.245,.275,.278), (0,0), .45, .42, .74)
fio = material('Fio_gasto', (.40,.43,.41), (0,0), .30, .42, .70)
madeira = material('Madeira_cabo', (.115,.064,.031), (1,1), .17)
cabelo = material('Cabelo_escuro', (.022,.017,.013), (1,0), .12)
cabelo_luz = material('Mechas_castanhas', (.041,.029,.019), (1,0), .13)
marfim = material('Marfim', (.67,.585,.36), rugosidade=.66)
esclera = material('Olho_ocre', (.39,.33,.15), rugosidade=.58)
iris = material('Iris_ambar', (.78,.31,.025), rugosidade=.48)
pupila = material('Pupila', (.003,.004,.002), rugosidade=.52)


def volume(nome, centros, raios, mat, lados=16):
    verts, faces = [], []
    for j, centro in enumerate(centros):
        p = Vector(centro)
        d = Vector(centros[min(j+1,len(centros)-1)]) - Vector(centros[max(j-1,0)])
        q = d.to_track_quat('Z', 'Y')
        rx, ry = raios[j]
        for k in range(lados):
            a = k*math.tau/lados
            verts.append(tuple(p + q @ Vector((rx*math.cos(a), ry*math.sin(a), 0))))
    for j in range(len(centros)-1):
        for k in range(lados):
            a = j*lados+k
            b = j*lados+(k+1)%lados
            faces.append((a,b,b+lados,a+lados))
    faces += [tuple(reversed(range(lados))), tuple((len(centros)-1)*lados+k for k in range(lados))]
    return malha(nome, verts, faces, mat)


def fita(nome, pontos, largura, mat):
    verts = []
    for i, p in enumerate(pontos):
        d = Vector(pontos[min(i+1,len(pontos)-1)]) - Vector(pontos[max(i-1,0)])
        v = Vector((-d.z,0,d.x)).normalized()*largura/2
        verts += [Vector(p)-v,Vector(p)+v]
    return malha(nome, verts, [(2*i,2*i+1,2*i+3,2*i+2) for i in range(len(pontos)-1)], mat, espessura=.009, bevel=.002)


def aro(nome, centro, rx, ry, raio, mat, n=40):
    x,y,z = centro
    return tubo(nome, [(x+rx*math.cos(i*math.tau/n),y+ry*math.sin(i*math.tau/n),z) for i in range(n+1)], raio, mat, resolucao=1)


def chapa(nome, contorno, mat, centro, esp=.012):
    vs = [centro] + contorno
    return malha(nome, vs, [(0,i+1,(i+1)%len(contorno)+1) for i in range(len(contorno))], mat, espessura=esp, bevel=.004)


def inclinar_machado(p):
    """A mesma transformação rígida registra o cabo e as duas empunhaduras."""
    p=Vector(p)
    x=p.x;z=p.z-.749
    p.x=math.cos(.178)*x+math.sin(.178)*z
    p.z=.749-math.sin(.178)*x+math.cos(.178)*z
    return p


def dedo_curvo(nome,pontos,raio,mat):
    """Seções mantêm o eixo X comum ao cabo, sem torcer durante a dobra."""
    vs=[];fs=[];n=12
    for j,p in enumerate(pontos):
        p=Vector(p)
        t=(Vector(pontos[min(j+1,len(pontos)-1)])-Vector(pontos[max(j-1,0)])).normalized()
        u=Vector((1,0,0))
        v=t.cross(u).normalized()
        for k in range(n):
            a=k*math.tau/n
            vs.append(tuple(p+u*(raio*math.cos(a))+v*(raio*math.sin(a))))
    for j in range(len(pontos)-1):
        for k in range(n):
            a=j*n+k;b=j*n+(k+1)%n
            fs.append((a,b,b+n,a+n))
    fs += [tuple(reversed(range(n))),tuple((len(pontos)-1)*n+k for k in range(n))]
    return malha(nome,vs,fs,mat)


# Tronco compacto com peito largo e planos frontais contidos.
vs=[];n=32
camadas=[(.59,.22,.15),(.73,.265,.177),(.90,.312,.19),(1.055,.335,.20),(1.16,.27,.15),(1.22,.13,.105)]
for z,rx,ry in camadas:
    for k in range(n):
        a=k*math.tau/n
        c=math.cos(a);s=math.sin(a)
        vs.append((rx*math.copysign(abs(c)**.78,c),.02+ry*math.copysign(abs(s)**.78,s),z))
faces=[(j*n+k,j*n+(k+1)%n,(j+1)*n+(k+1)%n,(j+1)*n+k) for j in range(len(camadas)-1) for k in range(n)]
faces += [tuple(reversed(range(n))),tuple((len(camadas)-1)*n+k for k in range(n))]
corpo=[malha('Torso_anatomico',vs,faces,pele),bola('Pescoco',(0,.022,1.20),(.12,.11,.12),pele)]
for s in [-1,1]:
    corpo += [bola('Trapezio',(s*.16,.015,1.17),(.19,.13,.085),pele),
              bola('Dorsal',(s*.19,.10,1.035),(.15,.125,.16),pele)]
    cont=[(s*.025,-.18,1.133),(s*.21,-.166,1.15),(s*.283,-.141,1.066),
          (s*.218,-.182,.995),(s*.033,-.187,1.012)]
    corpo.append(chapa('Peitoral_plano',cont,pele,(s*.13,-.226,1.072),.028))
    for z in [.765,.847,.925]:
        corpo.append(bola('Abdomen_relevo',(s*.065,-.168,z),(.065,.035,.04),pele))
    ombro=(s*.335,0,1.135)
    cot=(s*.445,-.09,.908-s*.035)
    pulso=(s*.255,-.315,.765-s*.045)
    corpo += [bola('Deltoide',ombro,(.143,.141,.151),pele),
              volume('Braco',[ombro,(s*.397,-.035,1.025-s*.018),cot],[(.12,.115),(.126,.119),(.087,.084)],pele),
              bola('Cotovelo',cot,(.09,.089,.09),pele),
              volume('Antebraco',[cot,(s*.37,-.19,.83-s*.04),pulso],[(.091,.084),(.107,.085),(.058,.053)],pele)]
unir(corpo,'Corpo_esculpido',.004)

# Calça com caimento e botas moldadas em torno do pé, sem cubos aparentes.
bola('Quadril',(0,.03,.56),(.25,.168,.165),calca)
for s,lado in [(-1,'D'),(1,'E')]:
    x=s*.155
    volume('Coxa_'+lado,[(x,.015,.59),(s*.19,-.012,.43),(s*.195,-.025,.31)],[(.14,.13),(.134,.121),(.10,.095)],calca,20)
    volume('Canela_'+lado,[(s*.195,-.025,.33),(s*.20,.005,.235),(s*.207,.012,.12)],[(.10,.099),(.082,.078),(.063,.067)],calca,18)
    for j in range(3):
        z=.37+j*.06
        tubo('Dobra_calca_'+lado,[(s*.12,-.095,z+.014),(s*.19,-.125,z),(s*.26,-.08,z+.01)],.008,calca,resolucao=1)
    cx=s*.208
    pegada=[(-.108,-.205),(-.077,-.263),(.071,-.263),(.11,-.210),(.10,.055),(.065,.088),(-.067,.088),(-.106,.052)]
    vs=[(cx+x,y,.042) for x,y in pegada]+[(cx+x*.96,y,.115 if y<-.16 else .147) for x,y in pegada]
    n=len(pegada)
    fs=[tuple(reversed(range(n))),tuple(n+k for k in range(n))]+[(k,(k+1)%n,(k+1)%n+n,k+n) for k in range(n)]
    bota=[malha('Peito_bota',vs,fs,couro,bevel=.009),
          volume('Cano_bota',[(s*.207,-.006,.10),(s*.207,.008,.18),(s*.205,.01,.28)],[(.077,.09),(.084,.087),(.095,.092)],couro,14)]
    unir(bota,'Bota_'+lado,.0035)
    verts=[];n=len(pegada)
    for z in [0,.043]:
        for x,y in pegada:
            verts.append((cx+x*1.045,(y+.08)*1.04-.08,z))
    malha('Sola_'+lado,verts,[tuple(reversed(range(n))),tuple(n+k for k in range(n))]+[(k,(k+1)%n,(k+1)%n+n,k+n) for k in range(n)],couro_luz,bevel=.004)
    for z in [.172,.259]:
        volume('Correia_bota_'+lado,[(s*.207,.008,z-.013),(s*.207,.008,z+.013)],[(.095,.098),(.095,.098)],couro_luz,16)
        tubo('Fivela_bota_'+lado,[(cx-.025,-.096,z-.017),(cx+.025,-.096,z-.017),(cx+.025,-.096,z+.017),(cx-.025,-.096,z+.017),(cx-.025,-.096,z-.017)],.004,ferro,resolucao=1,reto=True)
    tubo('Costura_bota_'+lado,[(s*.30,-.03,.047),(s*.303,-.11,.05),(s*.27,-.224,.048),(s*.207,-.264,.045)],.0037,costura,resolucao=1)
    for j in range(3):
        z=.12+j*.025
        tubo('Laco_bota_'+lado,[(s*.175,-.108,z),(s*.238,-.108,z+.018)],.004,couro_luz,resolucao=1,reto=True)
    # Abrir a base de apoio mantendo coxas ligadas ao quadril.
    for o in PECAS:
        if o.type!='MESH' or o.name.startswith('Corpo_') or o.data.materials[0] not in [calca,couro,couro_luz,costura,ferro]:continue
        if o.get('perna_aberta'):continue
        if not (o.name.startswith(('Coxa_'+lado,'Canela_'+lado,'Dobra_calca_'+lado,'Bota_'+lado,'Sola_'+lado,'Correia_bota_'+lado,'Costura_bota_'+lado,'Laco_bota_'+lado,'Fivela_bota_'+lado))):continue
        mw=o.matrix_world.copy()
        for v in o.data.vertices:
            p=mw@v.co
            p.x+=s*.070*max(0,min(1,(.62-p.z)/.37))
            v.co=p
        o.matrix_world.identity();o['perna_aberta']=True

cont=[(.203,-.147,.407),(.286,-.147,.413),(.296,-.147,.339),(.216,-.147,.327)]
malha('Remendo_joelho',cont,[(0,1,2,3)],couro_luz,espessura=.004)
for j in range(4):
    a=Vector(cont[j]);b=Vector(cont[(j+1)%4])
    for t in [.15,.40,.65,.87]:
        p=a.lerp(b,t)
        tubo('Ponto_remendo',[p+Vector((-.005,-.002,.005)),p+Vector((.005,-.002,-.005))],.0028,costura,resolucao=0,reto=True)

# Cabeça compacta, olhos pequenos e nariz curto conforme a referência.
HEAD_START=len(PECAS)
rosto=[bola('Cranio',(0,.005,1.365),(.238,.187,.215),pele_rosto,segmentos=32,aneis=24),
       bola('Mandibula',(0,-.072,1.221),(.222,.166,.132),pele_rosto),
       bola('Queixo',(0,-.163,1.162),(.17,.080,.060),pele_rosto),
       bola('Focinho',(0,-.210,1.245),(.16,.078,.058),pele_rosto)]
nariz_v=[(-.025,-.167,1.394),(.025,-.167,1.394),(-.040,-.227,1.365),(.040,-.227,1.365),
         (-.064,-.257,1.317),(.064,-.257,1.317),(0,-.308,1.306),(-.048,-.262,1.286),(.048,-.262,1.286),(0,-.17,1.31)]
nariz_f=[(0,1,3,2),(2,3,6),(2,6,4),(3,5,6),(4,6,7),(6,5,8),(7,6,8),(0,2,4,7,9),(1,9,8,5,3),(0,9,1),(7,8,9)]
rosto.append(malha('Nariz_angular',nariz_v,nariz_f,pele_rosto))
for s in [-1,1]:
    rosto.append(bola('Maca_rosto',(s*.173,-.10,1.285),(.078,.070,.075),pele_rosto))
    sob=bola('Sobrancelha',(s*.105,-.161,1.414),(.111,.063,.037),pele_rosto)
    sob.rotation_euler.y=-s*.27
    rosto.append(sob)
unir(rosto,'Rosto_esculpido',.003)
for s in [-1,1]:
    # Orelhas com concha e profundidade; ponta inclinada para trás.
    cont=[(s*.177,.014,1.466),(s*.283,.032,1.481),(s*.469,.070,1.542),
          (s*.398,.035,1.356),(s*.270,-.038,1.268),(s*.204,-.052,1.305)]
    chapa('Orelha',cont,pele,(s*.292,-.027,1.406),.025)
    dentro=[(s*.220,-.01,1.448),(s*.414,.043,1.510),(s*.350,-.008,1.371),(s*.266,-.055,1.309)]
    chapa('Concha_orelha',dentro,orelha,(s*.287,-.037,1.403),.006)
    tubo('Rim_orelha',cont+[cont[0]],.008,relevo,resolucao=1,reto=True)
    x=s*.108
    bola('Orbita',(x,-.187,1.363),(.074,.036,.044),sombra)
    bola('Esclera',(x,-.211,1.365),(.047,.025,.023),esclera)
    bola('Iris',(x-s*.003,-.234,1.362),(.018,.006,.021),iris)
    bola('Pupila',(x-s*.003,-.240,1.362),(.006,.003,.016),pupila,segmentos=16,aneis=12)
    bola('Brilho_olho',(x-s*.010,-.243,1.370),(.0034,.0015,.0034),marfim,segmentos=8,aneis=6)
    tubo('Palpebra_superior',[(s*.047,-.217,1.371),(s*.10,-.238,1.385),(s*.17,-.193,1.397)],.012,pele_rosto,resolucao=1)
    tubo('Palpebra_inferior',[(s*.05,-.216,1.351),(s*.111,-.234,1.339),(s*.166,-.192,1.364)],.007,relevo,resolucao=1)
    bola('Narina',(s*.035,-.284,1.294),(.011,.005,.007),sombra,segmentos=16,aneis=8)
    tubo('Sulco_rosto',[(s*.066,-.278,1.257),(s*.127,-.239,1.222),(s*.166,-.183,1.205)],.0045,orelha,resolucao=1)
    tubo('Presa',[(s*.12,-.253,1.178),(s*.143,-.280,1.212),(s*.146,-.291,1.250)],.014,marfim,resolucao=1)
    ponta('Ponta_presa',(s*.146,-.291,1.250),(s*.143,-.288,1.269),.010,.0008,marfim)
    tubo('Vinco_testa',[(s*.026,-.176,1.445),(s*.043,-.158,1.478),(s*.083,-.139,1.483)],.0035,orelha,resolucao=1)
    tubo('Vinco_bochecha',[(s*.172,-.157,1.326),(s*.196,-.124,1.310)],.004,orelha,resolucao=1)
tubo('Boca',[(-.167,-.185,1.204),(-.107,-.259,1.217),(0,-.292,1.229),(.107,-.259,1.217),(.167,-.185,1.204)],.008,sombra,resolucao=1)
tubo('Labio_inferior',[(-.107,-.256,1.197),(0,-.285,1.204),(.107,-.256,1.197)],.009,relevo,resolucao=1)
for x in [-.060,-.024,.024,.060]:
    malha('Dente',[(x-.009,-.290,1.227),(x+.009,-.290,1.227),(x+.007,-.292,1.216),(x-.007,-.292,1.216)],[(0,1,2,3)],marfim,espessura=.005,bevel=.001)

# Cabelo cobre o couro cabeludo até a nuca; a linha frontal deixa a testa livre.
vs=[];n=48;aneis=15
for j in range(aneis):
    for k in range(n):
        a=k*math.tau/n
        fim=.62+1.23*(math.sin(a)+1)/2
        t=.025+(fim-.025)*j/(aneis-1)
        vs.append((.244*math.sin(t)*math.cos(a),.005+.202*math.sin(t)*math.sin(a),1.365+.227*math.cos(t)))
malha('Base_cabelo',vs,[(j*n+k,j*n+(k+1)%n,(j+1)*n+(k+1)%n,(j+1)*n+k) for j in range(aneis-1) for k in range(n)],cabelo,espessura=.008)
def mecha(nome,a,b,c,r,mat):
    o=volume(nome,[a,Vector(a).lerp(Vector(b),.65),b,c],[(r,r*.72),(r*.94,r*.65),(r*.58,r*.40),(.001,.001)],mat,6)
    for p in o.data.polygons:p.use_smooth=False
    return o
# Mechas largas sobrepostas e assimétricas, sem repetição em fileiras.
for i,(x,y,h,dx,dy) in enumerate([(-.12,-.09,.16,-.03,.025),(-.04,-.12,.20,-.03,.035),
    (.04,-.10,.17,.01,.05),(.12,-.07,.15,.055,.02),(-.15,.005,.14,-.07,.03),
    (-.075,.02,.22,-.025,.08),(.025,.025,.23,.025,.07),(.12,.04,.17,.065,.065),
    (-.12,.105,.15,-.05,.10),(-.035,.13,.18,.025,.10),(.075,.12,.16,.05,.11)]):
    z=1.545-abs(x)*.15
    mecha('Mecha_crista',(x,y,z),(x+dx*.4,y+dy*.4,z+h*.65),(x+dx,y+dy,z+h),.063 if i%3 else .07,cabelo_luz if i%3==0 else cabelo)
for s in [-1,1]:
    for j in range(3):
        a=(s*.177,.01+j*.06,1.48-j*.022)
        mecha('Mecha_lateral',a,(s*.226,a[1]+.025,a[2]+.04),(s*.262,a[1]+.075,a[2]-.005),.045,cabelo_luz if j==1 else cabelo)
for j in range(7):
    a=.35+j*(math.pi-.70)/6
    p=(.215*math.cos(a),.005+.185*math.sin(a),1.404)
    mecha('Mecha_nuca',p,(p[0]*1.08,p[1]+.035,p[2]-.02),(p[0]*1.08,p[1]+.055,p[2]-.105),.038,cabelo_luz if j%3==0 else cabelo)
for o in PECAS[HEAD_START:]:
    mw=o.matrix_world.copy()
    for v in o.data.vertices:
        p=mw@v.co;p.x*=.86;p.z=1.16+(p.z-1.16)*.92
        v.co=p
    o.matrix_world.identity()

# Pele das costas exposta e apenas o arreio de couro da referência.
vs=[];n=64
for j in range(3):
    for k in range(n):
        a=k*math.tau/n
        z=[.43,.55,.634][j]
        if j==0:z+=.035*math.sin(a*5)+.018*math.cos(a*9)
        rx=[.27,.26,.252][j];ry=[.18,.176,.172][j]
        vs.append((rx*math.cos(a),.02+ry*math.sin(a),z))
malha('Pano_cintura',vs,[(j*n+k,j*n+(k+1)%n,(j+1)*n+(k+1)%n,(j+1)*n+k) for j in range(2) for k in range(n)],pano,espessura=.008)
cont=[(-.18,-.185,.59),(.17,-.185,.59),(.148,-.208,.421),(.105,-.213,.43),(.045,-.22,.35),
      (.008,-.22,.375),(-.045,-.22,.326),(-.095,-.212,.40),(-.13,-.205,.38),(-.181,-.19,.44)]
malha('Avental_couro',cont,[tuple(range(len(cont)))],couro,espessura=.010)
for z in [.609,.665]:
    aro('Cinto',(0,.02,z),.258,.191,.021,couro_luz)
vs=[];n=64
for z in [.603,.672]:
    for k in range(n):
        a=k*math.tau/n
        vs.append((.261*math.cos(a),.02+.194*math.sin(a),z))
malha('Cinto_continuo',vs,[(k,(k+1)%n,(k+1)%n+n,k+n) for k in range(n)],couro,espessura=.010)
fita('Frente_cinto',[(-.25,-.035,.646),(-.18,-.16,.638),(0,-.181,.632),(.18,-.16,.638),(.25,-.035,.646)],.067,couro)
fita('Tiracolo',[(.27,-.140,1.182),(.23,-.193,1.129),(.18,-.216,1.046),(.05,-.222,.913),(-.11,-.215,.770),(-.24,-.105,.664)],.081,couro_luz)
fita('Tiracolo_costas',[(.26,.14,1.164),(.16,.249,1.04),(0,.237,.89),(-.14,.211,.75),(-.24,.135,.664)],.081,couro_luz)
fita('Correia_ombro_nu',[(-.23,-.148,1.18),(-.24,-.09,1.246),(-.24,.03,1.265),(-.23,.145,1.20),(-.16,.248,1.04),(0,.237,.89)],.070,couro)
for cx,cy,cz,tamanho in [(0,-.215,.637,.040),(.104,-.243,.967,.036)]:
    tubo('Fivela',[(cx-tamanho,cy,cz-.028),(cx+tamanho,cy,cz-.028),(cx+tamanho,cy,cz+.028),(cx-tamanho,cy,cz+.028),(cx-tamanho,cy,cz-.028)],.006,ferro,resolucao=1,reto=True)
    tubo('Pino_fivela',[(cx,cy-.006,cz),(cx+tamanho,cy-.006,cz)],.004,aco,resolucao=1,reto=True)
for j in range(8):
    t=.10+j*.10
    x=.26-.5*t;z=1.164-.5*t
    bola('Rebite_tiracolo',(x,-.233 if .22<t<.8 else -.177,z),(.0045,.003,.0045),ferro,segmentos=8,aneis=6)

# Ombreira angular, com chapa plana central e saia lateral articulada.
for j in range(2):
    dz=-.068*j;dx=.027*j
    cont=[(.222+dx,-.07,1.309+dz),(.29+dx,-.148,1.313+dz),(.41+dx,-.15,1.285+dz),
          (.507+dx,-.075,1.206+dz),(.505+dx,.08,1.207+dz),(.40+dx,.153,1.279+dz),(.27+dx,.12,1.31+dz)]
    centro=(.347+dx,0,1.345+dz)
    o=chapa('Ombreira_angular',cont,ferro,centro,.022)
    for p in o.data.polygons:p.use_smooth=False
    tubo('Ombreira_borda',cont+[cont[0]],.006,aco,resolucao=1,reto=True)
    for k in [1,2,3,5]:
        p=Vector(cont[k]);p.z+=.004
        bola('Rebite_ombro',p,(.010,.008,.010),fio,segmentos=12,aneis=8)

# Braçadeiras em torno do antebraço, com costuras e rebites.
for s,lado in [(-1,'D'),(1,'E')]:
    ARM_START=len(PECAS)
    a=Vector((s*.398,-.165,.858));b=Vector((s*.29,-.279,.786))
    volume('Bracadeira_'+lado,[a,a.lerp(b,.45),b],[(.119,.113),(.112,.103),(.091,.087)],couro,18)
    eixo=(b-a).normalized()
    for t in [.05,.90]:
        o=anel('Correia_braco',a.lerp(b,t),.113 if t<.5 else .090,.009,couro_luz)
        o.rotation_mode='QUATERNION';o.rotation_quaternion=eixo.to_track_quat('Z','Y')
    for t in [.12,.34,.56,.78]:
        p=a.lerp(b,t);r=.119*(1-t)+.094*t
        volume('Tira_bracadeira',[p-eixo*.010,p+eixo*.010],[(r,r*.96),(r,r*.96)],couro_luz,16)
    for t in [.2,.47,.74]:
        p=a.lerp(b,t)+Vector((0,-.086,.017))
        bola('Rebite_braco',p,(.007,.005,.007),ferro,segmentos=10,aneis=8)
    # As braçadeiras acompanham o antebraço; a mão usa o referencial do cabo.
    for o in PECAS[ARM_START:]:
        mw=o.matrix_world.copy()
        for v in o.data.vertices:
            p=mw@v.co;p.z-=s*.045;v.co=p
        o.matrix_world.identity()
    HAND_START=len(PECAS)
    centro=s*.254
    mao=[bola('Palma_'+lado,(centro,-.323,.792),(.070,.045,.044),pele_rosto),
         bola('Dorso_'+lado,(centro,-.365,.803),(.067,.030,.026),pele_rosto),
         bola('Punho_'+lado,(s*.267,-.300,.776),(.056,.043,.044),pele_rosto)]
    for j in range(4):
        x=centro+(j-1.5)*.029
        # O dedo fecha até a face posterior/inferior do cabo. A distância
        # radial inclui a espessura do couro e da polpa, sem atravessar a madeira.
        pontos=[(x,-.344,.811)]
        angulos=[20,55,95,135,175,213+(3-j)*2]
        for angulo in angulos:
            a=math.radians(angulo)
            r=.053 if angulo<135 else .051
            pontos.append((x,-.36-r*math.sin(a),.749+r*math.cos(a)))
        raio=[.0185,.0195,.019,.018][j]
        mao.append(dedo_curvo('Dedo_fechado_'+lado,pontos,raio,pele_rosto))
        mao.append(bola('No_dedo_'+lado,(x,-.379,.802),(.017,.017,.018),pele_rosto,segmentos=16,aneis=10))
    # Polegar em oposição aos quatro dedos, por cima do indicador fechado.
    pontos=[(centro-s*.052,-.325,.810),(centro-s*.074,-.359,.803),
            (centro-s*.066,-.393,.788),(centro-s*.035,-.412,.776)]
    mao.append(volume('Polegar_oposto_'+lado,pontos,[(.024,.023),(.025,.023),(.022,.020),(.014,.013)],pele_rosto,12))
    mao_unida=unir(mao,'Empunhadura_fechada_'+lado,.002)
    # O volume negativo corresponde ao couro do cabo, incluindo as voltas da
    # empunhadura. A palma fica côncava, em vez de atravessar a madeira.
    bpy.ops.mesh.primitive_cylinder_add(vertices=48,radius=.0377,depth=.24,
        location=(centro,-.36,.749),rotation=(0,math.pi/2,0))
    molde=bpy.context.object
    mod=mao_unida.modifiers.new('Encaixe_real_do_cabo','BOOLEAN')
    mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=molde
    bpy.context.view_layer.objects.active=mao_unida
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.data.objects.remove(molde,do_unlink=True)
    mao_unida['familia']='mao_'+lado
    for o in PECAS[HAND_START:]:
        mw=o.matrix_world.copy()
        for v in o.data.vertices:v.co=inclinar_machado(mw@v.co)
        o.matrix_world.identity()

# Machado largo, com seção espessa no olho e fio afilado ao longo da curva.
WEAPON_START=len(PECAS)
ponta('Machado_cabo',(-.76,-.36,.749),(.585,-.36,.749),.030,.028,madeira,vertices=16)
for cx in [-.253,.254]:
    ponta('Machado_empunhadura',(cx-.074,-.36,.749),(cx+.074,-.36,.749),.033,.033,couro,vertices=16)
    for j in range(5):
        x=cx-.067+j*.033
        o=anel('Machado_enrolamento',(x,-.36,.749),.033,.0037,couro_luz)
        o.rotation_euler=(0,math.pi/2,0)
for x in [-.74,.57]:
    ponta('Machado_pomo',(x-.018,-.36,.749),(x+.018,-.36,.749),.037,.037,ferro,vertices=12)
# Olho de ferro atravessado pelo cabo; um único machado de lâmina em meia-lua.
ponta('Machado_olho',(-.79,-.36,.749),(-.64,-.36,.749),.055,.055,ferro,vertices=12)
outline=[(-.84,1.08),(-.72,1.05),(-.73,.99),(-.64,.98),(-.64,.88),(-.71,.85),(-.75,.77),(-.74,.70),
         (-.69,.62),(-.61,.61),(-.61,.51),(-.77,.46),(-.91,.51),(-1.01,.61),(-1.055,.74),(-1.04,.88),(-.99,1.02),(-.88,1.08)]
verts=[(x,-.391,z) for x,z in outline]+[(x,-.329,z) for x,z in outline]
n=len(outline)
tri=tessellate_polygon([[Vector((x,0,z)) for x,z in outline]])
indices={(round(x,6),round(z,6)):i for i,(x,z) in enumerate(outline)}
faces=[]
for t in tri:
    f=tuple(v if isinstance(v,int) else indices[(round(v.x,6),round(v.z,6))] for v in t)
    faces.extend([tuple(reversed(f)),tuple(n+i for i in f)])
faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
malha('Machado_cabeca',verts,faces,aco,bevel=.004)
outer=outline[10:]+outline[:1]
inner=[(x+(-.70-x)*.20,z+(.77-z)*.20) for x,z in outer]
for y in [-.397,-.323]:
    vs=[(x,y,z) for x,z in outer]+[(x,y,z) for x,z in inner]
    malha('Machado_fio',vs,[(i,i+1,i+1+len(outer),i+len(outer)) for i in range(len(outer)-1)],fio,espessura=.004)
for z in [.689,.830]:
    bola('Machado_rebite',(-.74,-.405,z),(.011,.006,.011),ferro,segmentos=12,aneis=8)
for x,z in [(-.95,.64),(-.88,.91),(-.82,.52)]:
    tubo('Machado_marca',[(x,-.403,z),(x+.019,-.403,z+.024)],.0025,fio,resolucao=0,reto=True)
for o in PECAS[WEAPON_START:]:
    o['familia']='machado'
    mw=o.matrix_world.copy()
    for v in o.data.vertices:
        v.co=inclinar_machado(mw@v.co)
    o.matrix_world.identity()

# UVs em projeção por face, com pixels em escala física semelhante entre peças.
for o in PECAS:
    if o.type!='MESH':continue
    mw=o.matrix_world.copy()
    for v in o.data.vertices:v.co=mw@v.co
    o.matrix_world.identity()
    o.data.update()
    # Uma única camada evita UVs vazios quando primitivas e malhas esculpidas
    # são unidas por material no exportador.
    for anterior in list(o.data.uv_layers):
        o.data.uv_layers.remove(anterior)
    uv=o.data.uv_layers.new(name='Pintura_pixel')
    for poly in o.data.polygons:
        normal=poly.normal
        eixo=max(range(3),key=lambda i:abs(normal[i]))
        for li in poly.loop_indices:
            p=o.data.vertices[o.data.loops[li].vertex_index].co
            if eixo==0:co=(p.y,p.z)
            elif eixo==1:co=(p.x,p.z)
            else:co=(p.x,p.y)
            uv.data[li].uv=(co[0]*.85,co[1]*.85)

# Agrupar para exportar poucas superfícies, mantendo o machado independente.
objetos=[]
for nome,mat in MATERIAIS.items():
    for familia in ['corpo','mao_D','mao_E','machado']:
        lista=[o for o in PECAS if o.type=='MESH' and o.data.materials and o.data.materials[0]==mat and o.get('familia','corpo')==familia]
        if not lista:continue
        prefixo='Machado_' if familia=='machado' else ('Mao_'+familia[-1]+'_' if familia.startswith('mao_') else 'Goblin_')
        o=unir(lista,prefixo+nome)
        tris=sum(len(p.vertices)-2 for p in o.data.polygons)
        limite=8500 if mat in [pele,pele_rosto] else 5000
        if tris>limite:
            mod=o.modifiers.new('Topologia_jogo','DECIMATE');mod.ratio=limite/tris
            bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
        objetos.append(o)
bpy.ops.object.select_all(action='DESELECT')
for o in objetos:o.select_set(True)
bpy.context.view_layer.objects.active=objetos[0]
bpy.ops.export_scene.gltf(filepath=str(DESTINO/'goblin_machado.glb'),export_format='GLB',use_selection=True,
    export_animations=False,export_materials='EXPORT',export_cameras=False,export_lights=False)

# Palco de revisão da fonte editável; não participa do GLB de jogo.
world=bpy.data.worlds.new('Estudio');world.use_nodes=True
world.node_tree.nodes['Background'].inputs[0].default_value=(.10,.12,.115,1)
world.node_tree.nodes['Background'].inputs[1].default_value=.5
bpy.context.scene.world=world
for nome,pos,energia,tam,cor in [('Principal',(-3,-4,5),400,4,(1,.92,.79)),('Preenchimento',(3,-2,3),180,3,(.77,.86,1)),('Recorte',(1,3,4),350,3,(1,.86,.68))]:
    bpy.ops.object.light_add(type='AREA',location=pos);o=bpy.context.object;o.name=nome
    o.data.energy=energia;o.data.shape='DISK';o.data.size=tam;o.data.color=cor
    o.rotation_euler=(Vector((0,0,.85))-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(1.6,-5,2.1));camera=bpy.context.object
camera.data.type='ORTHO';camera.data.ortho_scale=2.08
camera.rotation_euler=(Vector((-.06,-.015,.83))-camera.location).to_track_quat('-Z','Y').to_euler()
sc=bpy.context.scene;sc.camera=camera;sc.render.engine='CYCLES';sc.cycles.samples=24
sc.render.resolution_x=1000;sc.render.resolution_y=1000;sc.render.resolution_percentage=100
sc.render.film_transparent=True
bpy.ops.wm.save_as_mainfile(filepath=str(FONTES/'goblin_machado.blend'))
tris=sum(len(p.vertices)-2 for o in objetos for p in o.data.polygons)
altura=max(v.co.z for o in objetos for v in o.data.vertices)
rel={'arquivo':'res://assets/inimigos/goblin_machado_3d/goblin_machado.glb',
     'fonte':'arte/fontes/inimigos/goblin_machado_3d/goblin_machado.blend',
     'referencia':'referencia.png','pintura':'materiais_pixel.png','altura_m':round(altura,3),
     'triangulos':tris,'superficies':len(objetos),'materiais':len(MATERIAIS),
     'metodo':'escultura volumétrica original Blender com UVs e albedos pixelados incorporados',
     'frente_blender':'-Y','frente_godot':'+Z','animacoes':0,'rig':False,
     'limites':['modelo estático','não integrado à campanha','sem perfil de desempenho mobile']}
(DESTINO/'manifesto.json').write_text(json.dumps(rel,ensure_ascii=False,indent=2)+'\n')
print('MACHADO_EXPORTADO',json.dumps(rel,ensure_ascii=False),flush=True)
