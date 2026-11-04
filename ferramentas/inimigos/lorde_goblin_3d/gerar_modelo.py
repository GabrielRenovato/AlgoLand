"""Lorde Goblin: geometria original baseada no conceito, sem importar outros goblins.

Blender: Z para cima, frente -Y, pés no chão. Materiais de pixel art gerados
como atlas e separados sem repintura; referência e prompts ficam nas fontes.
"""
import bpy
import json
import math
import random
from pathlib import Path
from mathutils import Vector

RAIZ = Path(__file__).resolve().parents[3]
FONTES = RAIZ / 'arte/fontes/inimigos/lorde_goblin_3d'
DESTINO = RAIZ / 'assets/inimigos/lorde_goblin_3d'
PREVIAS = RAIZ / 'arte/previas/inimigos/lorde_goblin_3d'
ESCALA_CHEFE = 1.5
random.seed(41102)
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
PECAS = []


def material(nome, textura=None, cor=(.2, .2, .2), metal=0):
    mat = bpy.data.materials.new(nome)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = (*cor, 1)
    bsdf.inputs['Roughness'].default_value = .9
    bsdf.inputs['Metallic'].default_value = metal
    if textura:
        tex = mat.node_tree.nodes.new('ShaderNodeTexImage')
        tex.image = bpy.data.images.load(str(DESTINO / (textura + '.png')), check_existing=True)
        tex.image.pack()
        tex.interpolation = 'Closest'
        mat.node_tree.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
    return mat


PELE = material('Pele_oliva_pixel', 'pele')
FERRO = material('Ferro_forjado_pixel', 'ferro', metal=.12)
COURO = material('Couro_gasto_pixel', 'couro')
MANTO = material('Manto_petroleo_pixel', 'manto')
PEDRA = material('Granito_pixel', 'pedra')
MARFIM = material('Marfim_pixel', 'marfim')
MADEIRA = material('Madeira_pixel', 'madeira')
CORDA = material('Ataduras_pixel', 'corda')
ORELHA = material('Concha_terracota', cor=(.25, .11, .045))
NARIZ = material('Nariz_ocre', cor=(.34, .16, .085))
SOMBRA = material('Cavidades', cor=(.018, .021, .009))
OLHO = material('Olho_ambar', cor=(.95, .43, .025))
PUPILA = material('Pupilas', cor=(.008, .006, .002))
BORDA = material('Ferro_desgaste', cor=(.20, .19, .16), metal=.15)
UNHA = material('Unhas_carvao', cor=(.065,.071,.053))


def registrar(obj, mat, osso, suave=False):
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    for face in obj.data.polygons:
        face.use_smooth = suave
    obj['osso'] = osso
    PECAS.append(obj)
    return obj


def aplicar(obj):
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    for mod in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=mod.name)
    obj.select_set(False)
    return obj


def esfera(nome, centro, raios, mat=PELE, osso='peito', n=20):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=n, ring_count=12, location=centro)
    obj = bpy.context.object
    obj.name = nome
    obj.scale = raios
    registrar(obj, mat, osso, True)
    return aplicar(obj)


def malha(nome, verts, faces, mat, osso='peito', espessura=0, bevel=0):
    dados = bpy.data.meshes.new(nome)
    dados.from_pydata(verts, [], faces)
    dados.update()
    obj = bpy.data.objects.new(nome, dados)
    bpy.context.collection.objects.link(obj)
    registrar(obj, mat, osso)
    if espessura:
        obj.modifiers.new('Espessura', 'SOLIDIFY').thickness = espessura
    if bevel:
        mod = obj.modifiers.new('Chanfro', 'BEVEL')
        mod.width = bevel
        mod.segments = 1
    return aplicar(obj)


def cone(nome, inicio, fim, raio1, raio2, mat, osso='peito', n=12):
    d = Vector(fim) - Vector(inicio)
    bpy.ops.mesh.primitive_cone_add(vertices=n, radius1=raio1, radius2=raio2,
                                  depth=d.length, location=(Vector(inicio)+Vector(fim))/2)
    obj = bpy.context.object
    obj.name = nome
    obj.rotation_mode = 'QUATERNION'
    obj.rotation_quaternion = d.to_track_quat('Z', 'Y')
    return registrar(obj, mat, osso, True)


def tubo(nome, pontos, raio, mat, osso='peito', lados=8):
    vs, fs = [], []
    for i, ponto in enumerate(pontos):
        delta = Vector(pontos[min(i+1, len(pontos)-1)])-Vector(pontos[max(i-1, 0)])
        q = delta.to_track_quat('Z', 'Y')
        for k in range(lados):
            a = k*math.tau/lados
            vs.append(Vector(ponto)+q@Vector((raio*math.cos(a), raio*math.sin(a), 0)))
    for i in range(len(pontos)-1):
        for k in range(lados):
            a, b = i*lados+k, i*lados+(k+1)%lados
            fs.append((a, b, b+lados, a+lados))
    fs.extend([tuple(reversed(range(lados))), tuple((len(pontos)-1)*lados+k for k in range(lados))])
    return malha(nome, vs, fs, mat, osso)


def unir(lista, nome, voxel=0, reducao=.30, limite_triangulos=0):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in lista:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = lista[0]
    bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = nome
    if voxel:
        mod = obj.modifiers.new('Pele_continua', 'REMESH')
        mod.mode = 'VOXEL'
        mod.voxel_size = voxel
        mod.use_smooth_shade = True
        bpy.ops.object.modifier_apply(modifier=mod.name)
        mod = obj.modifiers.new('Escultura', 'SMOOTH')
        mod.factor = .7
        mod.iterations = 3
        bpy.ops.object.modifier_apply(modifier=mod.name)
        mod = obj.modifiers.new('Planos_jogo', 'DECIMATE')
        triangulos=sum(len(face.vertices)-2 for face in obj.data.polygons)
        mod.ratio = min(reducao,limite_triangulos/triangulos) if limite_triangulos else reducao
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return obj


def dedo_curvo(nome, pontos, raios, osso):
    """Falanges curvas com afilamento, em vez de tubos retos de seção constante."""
    centros=[];larguras=[]
    for i in range(len(pontos)-1):
        p0,p1,p2,p3=[Vector(pontos[max(0,min(len(pontos)-1,j))]) for j in [i-1,i,i+1,i+2]]
        for q in range(6):
            t=q/6
            centros.append(.5*((2*p1)+(-p0+p2)*t+(2*p0-5*p1+4*p2-p3)*t*t+(-p0+3*p1-3*p2+p3)*t*t*t))
            larguras.append(raios[i]*(1-t)+raios[i+1]*t)
    centros.append(Vector(pontos[-1]));larguras.append(raios[-1])
    vs=[];fs=[];n=12
    for i,(p,r) in enumerate(zip(centros,larguras)):
        tangente=centros[min(i+1,len(centros)-1)]-centros[max(0,i-1)]
        rotacao=tangente.to_track_quat('Z','Y')
        for j in range(n):
            a=j*math.tau/n
            vs.append(p+rotacao@Vector((r*math.cos(a),r*.94*math.sin(a),0)))
    for i in range(len(centros)-1):
        for j in range(n):
            a=i*n+j;b=i*n+(j+1)%n
            fs.append((a,b,b+n,a+n))
    fs.extend([tuple(reversed(range(n))),tuple((len(centros)-1)*n+j for j in range(n))])
    obj=malha(nome,vs,fs,PELE,osso)
    for face in obj.data.polygons: face.use_smooth=True
    ponta=esfera(nome+'_polpa',pontos[-1],(raios[-1],)*3,PELE,osso,12)
    return [obj,ponta]


def modelar_mao_direita():
    """Quatro dedos recolhidos, polegar oposto e concavidade real para o cabo."""
    partes=[esfera('Palma_D',(-.884,-.163,1.108),(.108,.087,.143),PELE,'mao_D'),
            esfera('Tenar_D',(-.858,-.218,1.188),(.067,.061,.072),PELE,'mao_D')]
    for i,(z,r) in enumerate([(1.213,.033),(1.146,.034),(1.079,.031),(1.018,.026)]):
        recuo=.014 if i==3 else 0
        pontos=[(-.87,-.12,z),(-1.015+recuo,-.112,z+.006),
                (-1.074+recuo,-.19,z-.004),(-1.055+recuo,-.281,z-.019),
                (-.987+recuo,-.307,z-.024),(-.937+recuo,-.271,z-.023)]
        partes+=dedo_curvo('Dedo_D_'+str(i+1),pontos,[r,r*1.06,r,r*.95,r*.87,r*.74],'mao_D')
    partes+=dedo_curvo('Polegar_D',[(-.853,-.198,1.235),(-.865,-.274,1.245),
                                   (-.915,-.326,1.216),(-.983,-.331,1.174)],
                       [.044,.043,.037,.029],'mao_D')
    mao=unir(partes,'Mao_D_escultura',.0032,.55,6000)
    # Retira a interseção com o cabo e preserva o apoio côncavo da palma.
    bpy.ops.mesh.primitive_cylinder_add(vertices=48,radius=.0615,depth=.8,
                                       location=(-.98,-.22,1.10))
    molde=bpy.context.object;molde.name='Molde_temporario_cabo'
    bpy.context.view_layer.objects.active=mao
    mod=mao.modifiers.new('Apoio_do_cabo','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=molde
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.data.objects.remove(molde,do_unlink=True)
    return mao


def modelar_mao_esquerda():
    partes=[esfera('Palma_E',(.84,-.125,.714),(.124,.088,.114),PELE,'mao_E'),
            esfera('Tenar_E',(.737,-.145,.748),(.064,.063,.075),PELE,'mao_E')]
    for i,(z,r) in enumerate([(.703,.037),(.710,.038),(.695,.035),(.680,.031)]):
        x=.84+(i-1.5)*.060
        falange=esfera('Falange_recolhida_E_'+str(i+1),(x,-.213,z),(r,.058,.077),PELE,'mao_E')
        falange.rotation_euler.x=.28
        partes.append(falange)
        partes.append(esfera('Articulacao_E_'+str(i+1),(x,-.185,z+.052),(r*1.07,.046,.043),PELE,'mao_E'))
        partes.append(esfera('Polpa_recolhida_E_'+str(i+1),(x,-.151,z-.042),(r*.90,.052,.037),PELE,'mao_E'))
    partes+=dedo_curvo('Polegar_E',[(.712,-.137,.77),(.691,-.221,.739),
                                   (.723,-.275,.703),(.785,-.277,.686)],
                       [.044,.042,.038,.029],'mao_E')
    return unir(partes,'Mao_E_escultura',.0032,.55,6000)


def faixa(nome, pontos, largura, mat=COURO, osso='peito'):
    vs = []
    for i, p in enumerate(pontos):
        d = Vector(pontos[min(i+1,len(pontos)-1)])-Vector(pontos[max(0,i-1)])
        lateral = Vector((-d.z, 0, d.x)).normalized()*largura*.5
        vs.extend([Vector(p)-lateral, Vector(p)+lateral])
    return malha(nome, vs, [(i*2,i*2+1,i*2+3,i*2+2) for i in range(len(pontos)-1)],
                 mat, osso, .012, .003)


def cinta(nome, centro, rx, ry, altura, mat=COURO, osso='quadril', n=28):
    x,y,z = centro
    vs = [(x+rx*math.cos(i*math.tau/n),y+ry*math.sin(i*math.tau/n),z+dz)
          for dz in [-altura/2,altura/2] for i in range(n)]
    return malha(nome,vs,[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)],mat,osso,.012)


def aro(nome, centro, eixo, raio, grossura, mat, osso):
    bpy.ops.mesh.primitive_torus_add(major_segments=20, minor_segments=6,
                                   location=centro, major_radius=raio, minor_radius=grossura)
    obj = bpy.context.object
    obj.name = nome
    obj.rotation_mode = 'QUATERNION'
    obj.rotation_quaternion = Vector(eixo).to_track_quat('Z','Y')
    return registrar(obj,mat,osso)


def placa(nome, contorno, mat=FERRO, osso='peito', volume=.025):
    centro = sum((Vector(p) for p in contorno),Vector())/len(contorno)
    centro.y -= volume
    n = len(contorno)
    return malha(nome,[centro]+contorno,[(0,i+1,(i+1)%n+1) for i in range(n)],mat,osso,.025,.008)


# A anatomia é modelada do zero; as peças não são importadas do Goblin King.
OSSOS = {
    'raiz': ((0,0,0),(0,0,.18),None),
    'quadril': ((0,0,.65),(0,0,.92),'raiz'),
    'peito': ((0,0,.92),(0,0,1.46),'quadril'),
    'cabeca': ((0,0,1.46),(0,-.03,1.91),'peito'),
    'manto': ((.24,.12,1.47),(.39,.23,1.05),'peito'),
}
unir([esfera('Torax',(0,0,1.16),(.48,.285,.39)),
      esfera('Abdomen',(0,-.005,.94),(.405,.27,.28)),
      esfera('Trapezio',(0,.025,1.41),(.47,.22,.18)),
      esfera('Pescoco',(0,.015,1.49),(.21,.195,.21))], 'Tronco_escultura',.016)
esfera('Quadril',(0,.025,.69),(.41,.26,.22),PELE,'quadril')

for s, lado in [(-1,'D'),(1,'E')]:
    quadril=(s*.25,.025,.69); joelho=(s*.32,-.02,.39); tornozelo=(s*.35,.015,.145)
    OSSOS['coxa_'+lado]=(quadril,joelho,'quadril')
    OSSOS['canela_'+lado]=(joelho,tornozelo,'coxa_'+lado)
    OSSOS['pe_'+lado]=(tornozelo,(s*.35,-.25,.08),'canela_'+lado)
    cone('Coxa_'+lado,quadril,joelho,.22,.18,PELE,'coxa_'+lado,16)
    esfera('Joelho_'+lado,joelho,(.18,.17,.15),PELE,'canela_'+lado)
    cone('Canela_'+lado,joelho,tornozelo,.16,.115,PELE,'canela_'+lado,16)
    partes_pe=[esfera('Pe_'+lado,(s*.35,-.12,.084),(.19,.245,.084),PELE,'pe_'+lado)]
    for j,(dx,y,rx,ry,rz) in enumerate([(-.115,-.327,.060,.10,.060),(-.04,-.33,.051,.095,.055),
                                       (.035,-.31,.043,.085,.050),(.10,-.29,.036,.078,.045)]):
        x=s*(.35+dx)
        partes_pe.append(esfera('Dedo_pe_'+lado,(x,y,.058),(rx,ry,rz),PELE,'pe_'+lado,16))
        z_base=.058+rz*.55;z_meio=.058+rz*.25
        malha('Unha_pe_'+lado,[(x-rx*.32,y-ry*.78,z_base),(x+rx*.32,y-ry*.78,z_base),
                              (x-rx*.24,y-ry*.99,z_meio),(x+rx*.24,y-ry*.99,z_meio),
                              (x,y-ry-.024,.043),(x-rx*.32,y-ry*.78,z_base-.016),
                              (x+rx*.32,y-ry*.78,z_base-.016),(x,y-ry*.99,.054)],
              [(0,1,3,2),(2,3,4),(0,2,4,7,5),(1,6,7,4,3),(5,7,6),(0,5,6,1)],UNHA,'pe_'+lado)
    unir(partes_pe,'Pe_escultura_'+lado,.005,.5,4000)
    for z in [.16,.21,.27]:
        cinta('Atadura_tornozelo_'+lado,(s*.35,.01,z),.127,.125,.041,COURO,'canela_'+lado,20)
    placa('Caneleira_'+lado,[(s*.35-.13,-.125,.31),(s*.35+.13,-.125,.31),
                           (s*.35+.105,-.148,.16),(s*.35-.105,-.148,.16)],osso='canela_'+lado)

    ombro=(s*.53,.01,1.36)
    cotovelo=(-.70,0,.99) if s<0 else (.755,-.02,1.025)
    pulso=(-.845,-.115,1.095) if s<0 else (.83,-.105,.80)
    mao=(-.93,-.20,1.095) if s<0 else (.84,-.14,.69)
    OSSOS['braco_'+lado]=(ombro,cotovelo,'peito')
    OSSOS['antebraco_'+lado]=(cotovelo,pulso,'braco_'+lado)
    OSSOS['mao_'+lado]=(pulso,(mao[0],mao[1],mao[2]-.09),'antebraco_'+lado)
    esfera('Deltoide_'+lado,ombro,(.235,.20,.215),PELE,'braco_'+lado)
    cone('Biceps_'+lado,ombro,cotovelo,.205,.16,PELE,'braco_'+lado,16)
    esfera('Cotovelo_'+lado,cotovelo,(.166,.158,.157),PELE,'antebraco_'+lado)
    cone('Antebraco_'+lado,cotovelo,pulso,.17,.115,PELE,'antebraco_'+lado,16)
    eixo=Vector(pulso)-Vector(cotovelo)
    for f in [.30,.55,.83]:
        p=Vector(cotovelo).lerp(Vector(pulso),f)
        aro('Cinta_bracal_'+lado,p,eixo,.173-f*.055,.024,COURO,'antebraco_'+lado)
    if s>0:
        placa('Bracal_ferro',[(.675,-.16,1.01),(.855,-.16,1.015),(.94,-.22,.80),
                              (.775,-.24,.76)],osso='antebraco_E')
        modelar_mao_esquerda()
    else:
        modelar_mao_direita()

# Cabeça achatada e mandíbula larga, com olhos pequenos sob o supercílio.
rosto=[esfera('Cranio',(0,-.015,1.785),(.32,.235,.265),PELE,'cabeca',24),
       esfera('Mandibula',(0,-.12,1.585),(.32,.25,.185),PELE,'cabeca',24),
       esfera('Queixo',(0,-.255,1.505),(.235,.145,.115),PELE,'cabeca'),
       esfera('Focinho',(0,-.265,1.655),(.25,.13,.09),PELE,'cabeca')]
for s in [-1,1]:
    rosto.append(esfera('Maca',(s*.24,-.16,1.67),(.115,.13,.15),PELE,'cabeca'))
    brow=esfera('Supercilio',(s*.145,-.23,1.855),(.165,.085,.064),PELE,'cabeca')
    brow.rotation_euler.y=-s*.24
    rosto.append(brow)
unir(rosto,'Cabeca_escultura',.009)
esfera('Nariz_ponte',(0,-.25,1.79),(.09,.10,.12),PELE,'cabeca')
esfera('Nariz_largo',(0,-.355,1.745),(.12,.085,.065),NARIZ,'cabeca')
for s in [-1,1]:
    cont=[(s*.265,.005,1.94),(s*.51,.015,1.965),(s*.94,.08,1.99),
          (s*.69,.015,1.825),(s*.40,-.045,1.70),(s*.275,-.08,1.72)]
    centro=(s*.475,-.055,1.835)
    malha('Orelha_'+str(s),[centro]+cont,[(0,i+1,(i+1)%6+1) for i in range(6)],PELE,'cabeca',.028)
    dentro=[(s*.34,-.062,1.914),(s*.82,.027,1.961),(s*.615,-.033,1.825),
            (s*.40,-.087,1.765)]
    malha('Concha_'+str(s),[(s*.47,-.075,1.846)]+dentro,
          [(0,i+1,(i+1)%4+1) for i in range(4)],ORELHA,'cabeca',.006)
    tubo('Borda_orelha',cont+[cont[0]],.012,PELE,'cabeca')
    x=s*.147
    esfera('Orbita',(x,-.265,1.81),(.104,.04,.058),SOMBRA,'cabeca')
    esfera('Olho',(x,-.299,1.807),(.077,.020,.033),OLHO,'cabeca')
    esfera('Pupila',(x,-.319,1.808),(.012,.006,.026),PUPILA,'cabeca',12)
    tubo('Palpebra_superior',[(s*.065,-.304,1.82),(s*.14,-.318,1.835),
                            (s*.225,-.274,1.852)],.022,PELE,'cabeca')
    esfera('Narina',(s*.061,-.428,1.72),(.025,.010,.014),SOMBRA,'cabeca',12)
    # Presas curvas e grossas, distintas dos dentes centrais.
    cone('Presa_base',(s*.226,-.334,1.555),(s*.259,-.365,1.675),.054,.034,MARFIM,'cabeca')
    cone('Presa_ponta',(s*.259,-.365,1.675),(s*.247,-.359,1.795),.034,.001,MARFIM,'cabeca')
tubo('Boca',[(-.26,-.30,1.535),(-.16,-.375,1.563),(0,-.39,1.578),
             (.16,-.375,1.563),(.26,-.30,1.535)],.015,SOMBRA,'cabeca')
tubo('Labio',[(-.19,-.375,1.518),(0,-.403,1.546),(.19,-.375,1.518)],.022,PELE,'cabeca')
# Uma cicatriz discreta quebra a simetria do rosto.
tubo('Cicatriz',[(.265,-.226,1.875),(.242,-.283,1.80),(.26,-.274,1.715)],.009,MARFIM,'cabeca')

# Cinto, saia de couro e tassets independentes para a articulação do quadril.
cinta('Cinto',(0,.005,.81),.455,.295,.115)
for i in range(12):
    a=i*math.tau/12
    b=(i+1)*math.tau/12
    z=.49+.035*math.sin(i*2.4)
    vs=[(.425*math.cos(a),.27*math.sin(a),.77),(.425*math.cos(b),.27*math.sin(b),.77),
        (.46*math.cos(b-.03),.30*math.sin(b-.03),z+.025),
        (.47*math.cos((a+b)/2),.31*math.sin((a+b)/2),z-.045),
        (.46*math.cos(a+.03),.30*math.sin(a+.03),z)]
    malha('Saia_couro',vs,[(0,1,2,3,4)],COURO,'quadril',.012)
for s,lado in [(-1,'D'),(1,'E')]:
    for j in range(2):
        z=.70-j*.12; x=s*.31
        placa('Tasset_'+lado,[(x-.15,-.258,z+.04),(x+.15,-.258,z+.04),
                             (x+.14,-.295,z-.075),(x-.13,-.30,z-.10)],osso='coxa_'+lado)
placa('Avental',[(-.125,-.305,.76),(.125,-.305,.76),(.10,-.33,.43),(0,-.35,.38),
                 (-.105,-.33,.45)],COURO,'quadril',.006)
tubo('Fivela',[(-.105,-.313,.755),(.105,-.313,.755),(.105,-.313,.866),
              (-.105,-.313,.866),(-.105,-.313,.755)],.018,BORDA,'quadril')
tubo('Lingueta_fivela',[(0,-.335,.813),(.092,-.335,.813)],.009,BORDA,'quadril')

# Placa peitoral assimétrica; suporte e alças continuam nas costas.
placa('Peitoral',[(-.19,-.293,1.31),(.25,-.28,1.345),(.455,-.22,1.12),
                  (.31,-.30,.965),(-.06,-.335,.93),(-.29,-.29,1.10)])
faixa('Tiracolo_frente',[(-.435,-.16,1.48),(-.28,-.31,1.33),(-.05,-.39,1.13),
                         (.23,-.345,.94),(.42,-.20,.855)],.105)
faixa('Tiracolo_costas',[(-.435,.14,1.48),(-.25,.285,1.34),(.04,.31,1.12),
                         (.30,.25,.94),(.42,.15,.855)],.105)
faixa('Cinta_torax',[(-.455,-.03,1.04),(-.35,-.265,1.00),(0,-.365,1.02),
                     (.37,-.25,1.09),(.48,-.05,1.12)],.09)
cinta('Cinta_torax_costas',(0,.01,1.025),.45,.295,.08,COURO,'peito')

# Três lâminas sobrepostas acompanham o ombro direito, sem pontas de coroa.
esfera('Apoio_ombreira',(-.565,.005,1.355),(.285,.25,.13),COURO,'braco_D')
for j in range(3):
    vs=[]; n=8
    for x,z in [(-.33-j*.15,1.46-j*.025),(-.535-j*.15,1.42-j*.04)]:
        for k in range(n+1):
            a=-math.pi/2+k*math.pi/n
            vs.append((x,.005+.255*math.sin(a),z+.17*math.cos(a)))
    malha('Ombreira_placa',vs,[(i,i+1,i+n+2,i+n+1) for i in range(n)],FERRO,'braco_D',.035,.012)
    for y in [-.22,.22]:
        esfera('Rebite_ombreira',(-.48-j*.15,y,1.465-j*.033),(.027,.018,.027),BORDA,'braco_D',12)
malha('Fecho_lateral_ombreira',[(-.825,-.20,1.35),(-.825,-.16,1.47),(-.825,0,1.53),
                               (-.825,.16,1.47),(-.825,.20,1.35),(-.835,0,1.27)],
      [(0,1,2,3,4,5)],FERRO,'braco_D',.025,.012)
for x,z in [(-.12,1.27),(.245,1.28),(.33,1.10),(-.17,1.08)]:
    esfera('Rebite_peitoral',(x,-.35,z),(.021,.015,.021),BORDA,'peito',12)

# Manto de um ombro com superfície volumétrica contínua e bainha rasgada.
vs=[]; fs=[]; n=14
for j in range(4):
    t=j/3
    for k in range(n+1):
        a=-1.95+k*4.80/n
        r=[.06,.22,.33,.38][j]
        x=.48+r*math.cos(a)
        y=.03+r*.86*math.sin(a)
        z=[1.66,1.59,1.40,1.19][j]+.012*math.sin(k*1.8+j)
        if j==3: z+= .045 if k%2 else -.035
        vs.append((x,y,z))
for j in range(3):
    for k in range(n):
        a=j*(n+1)+k;fs.append((a,a+1,a+n+2,a+n+1))
malha('Manto_ombro',vs,fs,MANTO,'manto',.022)
placa('Manto_costas',[(.22,.22,1.49),(.65,.12,1.35),(.69,.31,1.12),
                      (.62,.34,.88),(.54,.36,.93),(.44,.37,.83),(.35,.34,.90),(.22,.30,.96)],MANTO,'manto',-.01)
for j in range(6):
    z=1.60-j*.040;x=.38+j*.055;y=-.17-j*.012
    tubo('Costura_manto',[(x-.025,y,z+.014),(x+.023,y-.005,z-.013)],.009,COURO,'manto',6)

for i in range(3):
    x=.33+i*.061;y=-.29+i*.028;z=.59+(.04 if i==1 else 0)
    tubo('Cordao_trofeu',[(x,y,.80),(x+.01,y-.015,z+.06)],.009,COURO,'quadril',6)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1,location=(x+.01,y-.02,z))
    obj=bpy.context.object;obj.name='Fragmento_mineral';obj.scale=(.05,.045,.078)
    registrar(obj,PEDRA,'quadril')

# Martelo com cabeça facetada real e cruz de couro fechando nos quatro lados.
OSSOS['martelo']=((-.98,-.22,1.12),(-.98,-.22,1.55),'mao_D')
cone('Cabo_martelo',(-.98,-.22,.025),(-.98,-.22,2.09),.050,.065,MADEIRA,'martelo',12)
for z0,z1 in [(.11,.95),(1.32,1.87)]:
    pts=[]
    for k in range(int((z1-z0)*400)+1):
        z=z0+k/400
        a=(z-z0)*math.tau/.115
        pts.append((-.98+.057*math.cos(a),-.22+.057*math.sin(a),z))
    tubo('Atadura_cabo',pts,.014,CORDA,'martelo',5)
bpy.ops.mesh.primitive_cube_add(size=1,location=(-.98,-.22,2.105))
obj=bpy.context.object;obj.name='Cabeca_martelo';obj.scale=(.65,.48,.48)
registrar(obj,PEDRA,'martelo')
mod=obj.modifiers.new('Quinas_lascadas','BEVEL');mod.width=.10;mod.segments=1
aplicar(obj)
for v in obj.data.vertices:
    v.co+=Vector((random.uniform(-.017,.017),random.uniform(-.014,.014),random.uniform(-.014,.014)))
for s in [-1,1]:
    # A cinta segue as faces e os chanfros, sem projetar pontas para fora da pedra.
    contorno=[(-.486,1.965),(-.486,2.245),(-.36,2.371),(-.08,2.371),
              (.046,2.245),(.046,1.965),(-.08,1.839),(-.36,1.839)]
    vs=[]
    for y,z in contorno:
        x=-.98+s*max(-.185,min(.185,(z-2.105)*1.35))
        vs.extend([(x-.028,y,z),(x+.028,y,z)])
    malha('Correia_martelo',vs,[(i*2,i*2+1,(i*2+3)%16,(i*2+2)%16) for i in range(8)],COURO,'martelo',.009)

# UVs orientadas pelos planos da geometria; as texturas permanecem nítidas.
PECAS=[obj for obj in bpy.context.scene.objects if obj.type=='MESH']
for obj in PECAS:
    mw=obj.matrix_world.copy()
    for v in obj.data.vertices:
        v.co=(mw@v.co)*ESCALA_CHEFE
        if obj.name.startswith('Pe_escultura_'):
            v.co.z=max(0,v.co.z)
    obj.matrix_world.identity()
    obj.data.update()
    uv=obj.data.uv_layers.active or obj.data.uv_layers.new(name='Pintura_pixel')
    coords=[v.co for v in obj.data.vertices]
    lo=Vector(tuple(min(p[i] for p in coords) for i in range(3)))
    hi=Vector(tuple(max(p[i] for p in coords) for i in range(3)))
    for face in obj.data.polygons:
        e=max(range(3),key=lambda i:abs(face.normal[i]))
        eixos=[i for i in range(3) if i!=e]
        for loop in face.loop_indices:
            p=obj.data.vertices[obj.data.loops[loop].vertex_index].co
            uv.data[loop].uv=tuple(.03+.94*(p[i]-lo[i])/max(.025,hi[i]-lo[i]) for i in eixos)

# Esqueleto próprio: equipamentos e manto têm pivôs separados.
OSSOS={nome:(tuple(Vector(a)*ESCALA_CHEFE),tuple(Vector(b)*ESCALA_CHEFE),pai)
       for nome,(a,b,pai) in OSSOS.items()}
bpy.ops.object.select_all(action='DESELECT')
bpy.ops.object.armature_add()
rig=bpy.context.object;rig.name='LordeGoblin_Rig'
bpy.ops.object.mode_set(mode='EDIT')
rig.data.edit_bones.remove(rig.data.edit_bones[0])
for nome,(a,b,pai) in OSSOS.items():
    bone=rig.data.edit_bones.new(nome);bone.head=a;bone.tail=b
    if pai: bone.parent=rig.data.edit_bones[pai]
bpy.ops.object.mode_set(mode='OBJECT')
rig.show_in_front=True
for obj in PECAS:
    g=obj.vertex_groups.new(name=obj['osso'])
    g.add(list(range(len(obj.data.vertices))),1.0,'REPLACE')
    mod=obj.modifiers.new('Rig_lorde','ARMATURE');mod.object=rig
    obj.parent=rig

# Consolidar por material reduz os nós sem misturar os pesos dos ossos.
objetos=[]
grupos=[(mat,[obj for obj in PECAS if obj.data.materials[0]==mat]) for mat in list(bpy.data.materials)]
for mat,lista in grupos:
    if lista:
        objetos.append(unir(lista,'LordeGoblin_'+mat.name))
rig.animation_data_create()
acao=bpy.data.actions.new('parado');rig.animation_data.action=acao
for frame,valor in [(1,0),(25,1),(49,0),(73,-1),(97,0)]:
    for nome,angulo in [('peito',.003),('cabeca',-.012),('manto',.018),('antebraco_E',.012)]:
        bone=rig.pose.bones[nome];bone.rotation_mode='XYZ';bone.rotation_euler=(valor*angulo,0,0)
        bone.keyframe_insert(data_path='rotation_euler',frame=frame,group=nome)
rig.animation_data.action=None
track=rig.animation_data.nla_tracks.new();track.name='parado';track.strips.new('parado',1,acao)
sc=bpy.context.scene;sc.frame_start=1;sc.frame_end=97;sc.render.fps=30;sc.frame_set(1)
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True)
for obj in objetos: obj.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(DESTINO/'lorde_goblin.glb'),export_format='GLB',
                          use_selection=True,export_animations=True,export_animation_mode='NLA_TRACKS',
                          export_skins=True,export_materials='EXPORT',export_cameras=False,export_lights=False)
tris=sum(len(p.vertices)-2 for obj in objetos for p in obj.data.polygons)
manifesto={'arquivo':'res://assets/inimigos/lorde_goblin_3d/lorde_goblin.glb',
           'fonte':'arte/fontes/inimigos/lorde_goblin_3d/lorde_goblin.blend',
           'referencia':'referencia.png','atlas_materiais':'atlas_materiais.png',
           'metodo':'geometria própria criada do zero; nenhum modelo Goblin King importado',
           'altura_corpo_m':2.05*ESCALA_CHEFE,'escala_chefe':ESCALA_CHEFE,
           'altura_com_martelo_m':round(max((o.matrix_world@v.co).z for o in objetos for v in o.data.vertices),4),
           'altura_jogador_referencia_m':1.35,
           'triangulos':tris,'ossos':len(OSSOS),'materiais':len(objetos),
           'pivo':'centro entre os pés no chão','frente_blender':'-Y','frente_godot':'+Z',
           'animacoes':{'parado':{'fps':30,'duracao_s':3.2,'ciclo':True}},
           'limites':['Modelo e rig; caminhada, golpes e morte não produzidos nesta etapa.',
                      'A cena jogável conserva os sprites animados até a produção dos movimentos 3D.',
                      'Custo em mobile não perfilado.']}
(DESTINO/'manifesto.json').write_text(json.dumps(manifesto,ensure_ascii=False,indent=2)+'\n')

# Palco de autoria; a revisão final usa o GLB importado no Godot.
sc.render.engine='CYCLES';sc.cycles.samples=24
sc.render.resolution_x=1000;sc.render.resolution_y=1000;sc.render.resolution_percentage=100
sc.render.film_transparent=True
sc.world.color=(.18,.18,.18)
for pos,potencia,cor in [((-3,-4,5),550,(1,.88,.72)),((3,-2,3),300,(.70,.83,1)),((1,3,4),420,(1,.85,.62))]:
    bpy.ops.object.light_add(type='AREA',location=pos)
    luz=bpy.context.object;luz.data.energy=potencia;luz.data.shape='DISK';luz.data.size=4;luz.data.color=cor
    luz.rotation_euler=(Vector((0,0,1.1))-luz.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(3.1,-6,3.15))
cam=bpy.context.object;cam.location*=ESCALA_CHEFE;cam.data.type='ORTHO';cam.data.ortho_scale=3.2*ESCALA_CHEFE
cam.rotation_euler=(Vector((-.18,0,1.14))*ESCALA_CHEFE-cam.location).to_track_quat('-Z','Y').to_euler();sc.camera=cam
bpy.ops.wm.save_as_mainfile(filepath=str(FONTES/'lorde_goblin.blend'))
print('LORDE_GOBLIN_EXPORTADO',json.dumps(manifesto,ensure_ascii=False),flush=True)
