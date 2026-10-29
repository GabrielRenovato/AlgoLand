"""Modela o Goblin King em geometria real; executar com Blender 4.5 --background --python.

Fonte canônica: arte/fontes/inimigos/goblin_king/referencia.png.
Eixos de autoria: Z para cima, frente em -Y, sola em Z=0, unidade em metros.
Não modifica cenas, inventários nem saves. Coroa/armadura são partes do chefe,
não um conjunto de equipamento do jogador.
"""
import bpy
import math
import json
import random
from pathlib import Path
from mathutils import Vector
from mathutils.noise import noise_vector

RAIZ = Path(__file__).resolve().parents[3]
FONTES = RAIZ / 'arte/fontes/inimigos/goblin_king'
DESTINO = RAIZ / 'assets/inimigos/goblin_king'
PREVIAS = RAIZ / 'arte/previas/inimigos/goblin_king'
random.seed(431)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
PECAS = []
MATERIAIS = {}
OSSO = 'peito'


def material(nome, cor, metal=0, rugosidade=.6, variacao=.04):
    m = bpy.data.materials.new(nome)
    m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*cor, 1)
    p.inputs['Metallic'].default_value = metal
    p.inputs['Roughness'].default_value = rugosidade
    # Texturas portáteis reais, incorporadas no GLB, sem depender de shaders Blender.
    n = 128
    img = bpy.data.images.new(nome + '_albedo', width=n, height=n)
    pixels = []
    for y in range(n):
        for x in range(n):
            f = noise_vector(Vector((x / 13, y / 13, 1.7)))[0]
            f += .32 * noise_vector(Vector((x / 2.7, y / 2.7, 4.1)))[0]
            fator = 1 + f * variacao
            # As cores do shader são lineares; o PNG de albedo é sRGB.
            c = [max(0, min(1, v * fator)) for v in cor]
            pixels.extend([*(12.92*v if v <= .0031308 else 1.055*v**(1/2.4)-.055 for v in c), 1])
    img.pixels.foreach_set(pixels)
    img.pack()
    t = m.node_tree.nodes.new('ShaderNodeTexImage')
    t.image = img
    m.node_tree.links.new(t.outputs['Color'], p.inputs['Base Color'])
    MATERIAIS[nome] = m
    return m


PELE = material('Pele_oliva', (.155, .182, .045), rugosidade=.7, variacao=.1)
PELE_LUZ = material('Pele_relevo', (.18, .205, .058), rugosidade=.7)
ORELHA = material('Orelha_interna', (.135, .145, .042), rugosidade=.85)
SOMBRA = material('Cavidades_e_boca', (.018, .025, .008), rugosidade=.9)
METAL = material('Ferro_enegrecido', (.052, .057, .063), .78, .38, .25)
METAL_CLARO = material('Fio_aco', (.28, .30, .31), .85, .27, .1)
OURO = material('Ouro_antigo', (.55, .294, .066), .8, .31, .16)
OURO_ESCURO = material('Ouro_rebaixo', (.23, .096, .019), .75, .45)
VINHO = material('Veludo_vinho', (.16, .009, .018), .0, .92, .18)
VINHO_LUZ = material('Dobras_vinho', (.22, .014, .023), .0, .91, .08)
FORRO = material('Forro_manto', (.057, .008, .013), .0, .96)
PELO = material('Pelo_marfim', (.64, .54, .39), .0, .95, .1)
PELO_LUZ = material('Pelo_pontas', (.79, .71, .56), .0, .95)
COURO = material('Couro_castanho', (.054, .024, .014), .0, .83, .2)
MARFIM = material('Presas_marfim', (.84, .73, .49), .0, .36)
JOIA = material('Rubi', (.30, .004, .009), .3, .17)
OLHO = material('Olho_dourado', (.95, .34, .018), .05, .22)
PUPILA = material('Pupila', (.004, .003, .001), .0, .35)


def registrar(o, mat, osso=None, suave=True):
    o.data.materials.clear()
    o.data.materials.append(mat)
    if suave:
        for p in o.data.polygons:
            p.use_smooth = True
    o['osso'] = osso or OSSO
    PECAS.append(o)
    return o


def aplicar(o):
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    for mod in list(o.modifiers):
        bpy.ops.object.modifier_apply(modifier=mod.name)
    o.select_set(False)
    return o


def bola(nome, pos, escala, mat, osso=None, segmentos=24, aneis=16):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segmentos, ring_count=aneis, location=pos)
    o = bpy.context.object
    o.name = nome
    o.scale = escala
    registrar(o, mat, osso)
    return aplicar(o)


def malha(nome, verts, faces, mat, osso=None, suave=True, espessura=0, bevel=0):
    me = bpy.data.meshes.new(nome)
    me.from_pydata(verts, [], faces)
    me.update()
    o = bpy.data.objects.new(nome, me)
    bpy.context.collection.objects.link(o)
    registrar(o, mat, osso, suave)
    if espessura:
        m = o.modifiers.new('Espessura_real', 'SOLIDIFY')
        m.thickness = espessura
    if bevel:
        m = o.modifiers.new('Bordas_arredondadas', 'BEVEL')
        m.width = bevel
        m.segments = 2
    return aplicar(o)


def tubo(nome, pontos, raio, mat, osso=None, resolucao=2, reto=False):
    c = bpy.data.curves.new(nome, 'CURVE')
    c.dimensions = '3D'
    c.resolution_u = 8
    c.bevel_depth = raio
    c.bevel_resolution = resolucao
    if reto:
        s = c.splines.new('POLY')
        s.points.add(len(pontos)-1)
        for p, co in zip(s.points, pontos): p.co = (*co, 1)
    else:
        s = c.splines.new('BEZIER')
        s.bezier_points.add(len(pontos)-1)
        for p, co in zip(s.bezier_points, pontos):
            p.co = co
            p.handle_left_type = 'AUTO'
            p.handle_right_type = 'AUTO'
    o = bpy.data.objects.new(nome, c)
    bpy.context.collection.objects.link(o)
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.convert(target='MESH')
    o.select_set(False)
    return registrar(o, mat, osso)


def ponta(nome, a, b, r1, r2, mat, osso=None, vertices=12):
    d = Vector(b)-Vector(a)
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=r1, radius2=r2,
                                   depth=d.length, location=(Vector(a)+Vector(b))/2)
    o = bpy.context.object
    o.name = nome
    o.rotation_mode = 'QUATERNION'
    o.rotation_quaternion = d.to_track_quat('Z', 'Y')
    registrar(o, mat, osso)
    return aplicar(o)


def anel(nome, pos, raio, fio, mat, osso=None, rot=(math.pi/2, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_segments=32, minor_segments=8,
        location=pos, major_radius=raio, minor_radius=fio, rotation=rot)
    o = bpy.context.object
    o.name = nome
    registrar(o, mat, osso)
    return aplicar(o)


def lapidar(nome, pos, escala, mat, osso=None):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=1, location=pos)
    o = bpy.context.object
    o.name = nome
    o.scale = escala
    registrar(o, mat, osso, False)
    return aplicar(o)


def unir(pecas, nome, voxel=None):
    bpy.ops.object.select_all(action='DESELECT')
    for o in pecas:
        o.select_set(True)
    bpy.context.view_layer.objects.active = pecas[0]
    bpy.ops.object.join()
    o = bpy.context.object
    o.name = nome
    for p in pecas[1:]:
        PECAS.remove(p)
    if voxel:
        mod = o.modifiers.new('Escultura_volumetrica', 'REMESH')
        mod.mode = 'VOXEL'
        mod.voxel_size = voxel
        mod.use_smooth_shade = True
        aplicar(o)
        mod = o.modifiers.new('Suavizar_escultura', 'SMOOTH')
        mod.factor = .75
        mod.iterations = 4
        aplicar(o)
        mod = o.modifiers.new('Topologia_jogo', 'DECIMATE')
        mod.ratio = .55
        aplicar(o)
    bpy.ops.object.select_all(action='DESELECT')
    return o


def chapa(nome, contorno, mat=METAL, osso=None, centro=None, relevo=.035, borda=True):
    centro = Vector(centro) if centro else sum((Vector(p) for p in contorno), Vector())/len(contorno)
    centro.y -= relevo
    verts = [tuple(centro)] + list(contorno)
    faces = [(0, i+1, (i+1)%len(contorno)+1) for i in range(len(contorno))]
    if (Vector(contorno[0])-centro).cross(Vector(contorno[1])-centro).y > 0:
        faces = [tuple(reversed(f)) for f in faces]
    o = malha(nome, verts, faces, mat, osso, suave=True, espessura=.017, bevel=.008)
    if borda:
        tubo(nome+'_filete', list(contorno)+[contorno[0]], .008, OURO, osso, 2, reto=True)
    return o


# Corpo e volumes sob a armadura; regiões inteiras presas ao esqueleto.
OSSO = 'quadril'
bola('Quadril', (0, .01, 1.28), (.43, .26, .27), COURO)
OSSO = 'peito'
bola('Torax', (0, 0, 1.86), (.51, .28, .49), METAL)
bola('Abdomen_pele', (0, -.015, 1.53), (.36, .27, .28), PELE)
bola('Pescoco', (0, .015, 2.27), (.22, .18, .24), PELE)

OSSOS = {
    'raiz': ((0, 0, 0), (0, 0, .22), None),
    'quadril': ((0, 0, 1.22), (0, 0, 1.52), 'raiz'),
    'peito': ((0, 0, 1.52), (0, 0, 2.24), 'quadril'),
    'cabeca': ((0, 0, 2.24), (0, 0, 2.83), 'peito'),
}
for s, sufixo in [(-1, 'D'), (1, 'E')]:
    ombro = (s*.51, 0, 2.13)
    cotovelo = (s*.78, -.055, 1.80)
    mao = (s*.83, -.36, 1.91) if s == -1 else (s*.57, -.32, 1.33)
    OSSOS['braco_'+sufixo] = (ombro, cotovelo, 'peito')
    OSSOS['antebraco_'+sufixo] = (cotovelo, mao, 'braco_'+sufixo)
    OSSOS['mao_'+sufixo] = (mao, (mao[0], mao[1]-.11, mao[2]-.06), 'antebraco_'+sufixo)
    OSSO = 'braco_'+sufixo
    ponta('Braco_'+sufixo, ombro, cotovelo, .205, .17, METAL)
    OSSO = 'antebraco_'+sufixo
    ponta('Antebraco_'+sufixo, cotovelo, mao, .17, .125, METAL)
    for f in [.18, .45, .72]:
        p = Vector(cotovelo).lerp(Vector(mao), f)
        a = bola('Placa_manopla', p, (.177, .146, .095), METAL)
        # Arcos de reforço acompanham cada pulso.
        eixo = (Vector(mao)-Vector(cotovelo)).normalized()
        a.rotation_mode = 'QUATERNION'
        a.rotation_quaternion = eixo.to_track_quat('Z', 'Y')
        aro = anel('Aro_manopla', p, .152, .012, OURO)
        aro.rotation_mode = 'QUATERNION'
        aro.rotation_quaternion = eixo.to_track_quat('Z', 'Y')
    OSSO = 'mao_'+sufixo
    bola('Palma_'+sufixo, mao, (.132, .115, .098), PELE)
    for i in range(4):
        x = mao[0]+(i-1.5)*.052
        y = mao[1]-.067
        z = mao[2]-.017 + math.sin(i)*.005
        tubo('Dedo_'+sufixo, [(x, y+.06, z+.035), (x, y-.035, z), (x, y-.03, z-.075)], .026, PELE)
        bola('Unha', (x, y-.043, z-.058), (.018, .009, .024), MARFIM, segmentos=12, aneis=8)
    tubo('Polegar_'+sufixo, [(mao[0]-s*.10, mao[1]+.025, mao[2]),
        (mao[0]-s*.13, mao[1]-.05, mao[2]-.035),
        (mao[0]-s*.075, mao[1]-.10, mao[2]-.07)], .037, PELE)
    # Pernas robustas e placas sobrepostas, com pés realmente apoiados.
    x = s*.275
    quadril = (x, 0, 1.26)
    joelho = (x+s*.065, -.015, .72)
    tornozelo = (x+s*.085, -.005, .20)
    OSSOS['coxa_'+sufixo] = (quadril, joelho, 'quadril')
    OSSOS['canela_'+sufixo] = (joelho, tornozelo, 'coxa_'+sufixo)
    OSSOS['pe_'+sufixo] = (tornozelo, (tornozelo[0], -.30, .12), 'canela_'+sufixo)
    OSSO = 'coxa_'+sufixo
    ponta('Coxa', joelho, quadril, .19, .235, COURO)
    OSSO = 'canela_'+sufixo
    ponta('Greva_base', tornozelo, joelho, .135, .19, METAL)
    for i in range(4):
        z = .33+i*.115
        xc = x+s*.075
        cont = [(xc-.15, -.15, z+.11), (xc+.15, -.15, z+.11),
                (xc+.13, -.21, z-.015), (xc, -.26, z-.07), (xc-.13, -.21, z-.015)]
        chapa('Greva_laminada', cont)
    bola('Joelho', joelho, (.205, .19, .16), METAL)
    lapidar('Crista_joelho', (joelho[0], -.23, .73), (.14, .08, .18), OURO)
    OSSO = 'pe_'+sufixo
    bola('Bota', (tornozelo[0], -.145, .125), (.16, .33, .12), METAL)
    for i in range(3):
        y = -.20-i*.085
        chapa('Escama_bota', [(tornozelo[0]-.155, y+.055, .175),
            (tornozelo[0]+.155, y+.055, .175), (tornozelo[0]+.145, y-.05, .115),
            (tornozelo[0]-.145, y-.05, .115)], relevo=0)

# Escultura do rosto: focinho integrado, maçãs largas, queixo e nariz goblin.
OSSO = 'cabeca'
partes = [bola('Cranio', (0, .015, 2.60), (.325, .245, .305), PELE, segmentos=40, aneis=28),
    bola('Mandibula', (0, -.075, 2.43), (.28, .21, .19), PELE),
    bola('Queixo', (0, -.195, 2.365), (.205, .14, .105), PELE),
    bola('Focinho', (0, -.24, 2.48), (.24, .135, .095), PELE),
    bola('Nariz_ponte', (0, -.245, 2.65), (.084, .09, .145), PELE),
    bola('Nariz_ponta', (0, -.37, 2.565), (.12, .12, .076), PELE),
    bola('Nariz_asa_D', (-.094, -.323, 2.56), (.06, .075, .051), PELE),
    bola('Nariz_asa_E', (.094, -.323, 2.56), (.06, .075, .051), PELE)]
for s in [-1, 1]:
    partes.append(bola('Maca_rosto', (s*.23, -.16, 2.55), (.09, .115, .10), PELE))
    a = bola('Sobrancelha_volume', (s*.145, -.22, 2.715), (.143, .06, .046), PELE)
    a.rotation_euler.y = s*-.19
    partes.append(a)
unir(partes, 'Rosto_esculpido', .008)
for s in [-1, 1]:
    # Orelhas com casca côncava, rebordo e relevo interno, sem planos transparentes.
    cont = [(s*.265, .0, 2.73), (s*.44, .025, 2.805), (s*.80, .06, 2.88),
            (s*.65, -.015, 2.67), (s*.43, -.075, 2.54), (s*.29, -.065, 2.55)]
    centro = (s*.435, .02, 2.685)
    malha('Orelha_concha', [centro]+cont,
          [(0, i+1, (i+1)%len(cont)+1) for i in range(len(cont))], PELE, espessura=.035)
    dentro = [(s*.32, -.027, 2.707), (s*.44, .002, 2.75), (s*.68, .035, 2.825),
              (s*.55, -.03, 2.675), (s*.39, -.07, 2.59)]
    malha('Orelha_interior', [(s*.43, -.003, 2.69)]+dentro,
          [(0, i+1, (i+1)%5+1) for i in range(5)], ORELHA)
    tubo('Orelha_rebordo', cont+[cont[0]], .012, PELE_LUZ, reto=True)
    tubo('Orelha_cartilagem', [(s*.32, -.074, 2.58), (s*.35, -.079, 2.68),
          (s*.56, -.029, 2.76)], .014, PELE)
    anel('Brinco_real', (s*.425, -.06, 2.535), .048, .011, OURO)
    lapidar('Brinco_pingente', (s*.425, -.06, 2.47), (.024, .017, .039), OURO)
    # Olhos estreitos em órbitas escuras; pálpebras oblíquas cobrem a esfera.
    x = s*.151
    bola('Orbita', (x, -.248, 2.661), (.095, .032, .033), SOMBRA)
    bola('Esclera_ambar', (x, -.279, 2.662), (.071, .023, .022), MARFIM)
    bola('Iris', (x-s*.008, -.301, 2.662), (.026, .008, .026), OLHO, segmentos=20)
    bola('Pupila_vertical', (x-s*.008, -.309, 2.662), (.007, .004, .019), PUPILA, segmentos=12)
    bola('Brilho_olho', (x-.008, -.313, 2.673), (.005, .003, .005), MARFIM, segmentos=8, aneis=6)
    tubo('Palpebra_superior', [(s*.066, -.276, 2.656), (s*.145, -.294, 2.687),
          (s*.242, -.233, 2.695)], .021, PELE)
    tubo('Palpebra_inferior', [(s*.069, -.274, 2.65), (s*.149, -.289, 2.637),
          (s*.239, -.236, 2.679)], .012, PELE_LUZ)
    tubo('Vinco_sobrancelha', [(s*.055, -.265, 2.732), (s*.143, -.25, 2.76),
          (s*.25, -.19, 2.762)], .009, ORELHA)
    bola('Narina', (s*.078, -.419, 2.544), (.029, .012, .017), SOMBRA, segmentos=16)
    tubo('Sulco_bochecha', [(s*.117, -.333, 2.534), (s*.185, -.29, 2.50),
          (s*.231, -.238, 2.496)], .006, ORELHA)
    ponta('Presa', (s*.165, -.332, 2.431), (s*.173, -.365, 2.505), .027, .002, MARFIM, vertices=16)
    tubo('Vinco_temporal', [(s*.253, -.205, 2.638), (s*.282, -.166, 2.622),
          (s*.282, -.15, 2.59)], .006, ORELHA)
tubo('Sorriso_assimetrico', [(-.232, -.247, 2.468), (-.16, -.346, 2.444),
    (0, -.37, 2.435), (.15, -.343, 2.447), (.24, -.235, 2.492)], .010, SOMBRA)
tubo('Labio_inferior', [(-.16, -.34, 2.423), (0, -.357, 2.416), (.16, -.333, 2.431)], .014, PELE_LUZ)
for z, largura in [(2.80, .12), (2.827, .15)]:
    tubo('Vinco_testa', [(-largura, -.174, z), (0, -.206, z+.014), (largura, -.174, z)], .005, ORELHA)

# Coroa: aro elíptico, treze pontas com alturas alternadas, rubis e rebites.
OSSO = 'cabeca'
N = 96
verts = []
for z in [2.825, 2.924]:
    for i in range(N):
        a = i*math.tau/N
        verts.append((.303*math.sin(a), .01-.235*math.cos(a), z))
malha('Coroa_aro', verts, [(i, (i+1)%N, (i+1)%N+N, i+N) for i in range(N)], OURO, espessura=.025)
for z in [2.826, 2.917]:
    tubo('Coroa_borda', [(.309*math.sin(i*math.tau/64), .01-.241*math.cos(i*math.tau/64), z)
        for i in range(65)], .012, OURO)
for i in range(13):
    a = i*math.tau/13
    h = .30 if i%2 == 0 else .19
    if i == 0: h = .34
    def c(t, z, raio=1):
        return (.315*math.sin(t)*raio, .01-.245*math.cos(t)*raio, z)
    cont = [c(a-.20, 2.89), c(a-.105, 2.982), c(a, 2.92+h, 1.10),
            c(a+.105, 2.982), c(a+.20, 2.89)]
    chapa('Coroa_ponta', cont, OURO, centro=c(a, 2.99, 1.04), relevo=0, borda=False)
    p = c(a, 2.96+h*.22, 1.09)
    lapidar('Rubi_coroa', p, (.029, .025, .041), JOIA)
    ponta('Coroa_lanceta', c(a, 2.92+h-.04, 1.1), c(a, 2.92+h+.05, 1.12), .023, 0, OURO, vertices=6)
for i in range(26):
    a = i*math.tau/26
    bola('Rebite_coroa', (.317*math.sin(a), .01-.249*math.cos(a), 2.85), (.009,)*3, OURO, segmentos=8, aneis=6)

# Manto volumétrico com dobras geométricas, forro e orla bordada.
OSSO = 'peito'
linhas, colunas = 30, 64
verts = []
for j in range(linhas+1):
    t = j/linhas
    for i in range(colunas+1):
        a = .94+(math.tau-1.88)*i/colunas
        ond = (.018+.026*t)*math.sin(a*11+.4*t)
        rx = .53+.34*t+ond
        ry = .27+.18*t+ond*.5
        z = 2.28-2.20*t+.028*math.sin(a*9)*t**5
        verts.append((rx*math.sin(a), -.015-ry*math.cos(a)+.065*t*t, z))
faces = []
for j in range(linhas):
    for i in range(colunas):
        k = j*(colunas+1)+i
        faces.append((k, k+1, k+colunas+2, k+colunas+1))
manto = malha('Manto_real', verts, faces, VINHO, espessura=.025)
manto.data.materials.append(FORRO)
for p in manto.data.polygons:
    if p.center.y > .2 and p.normal.y < 0: p.material_index = 1
for lado in [0, colunas]:
    pts = [verts[j*(colunas+1)+lado] for j in range(linhas+1)]
    tubo('Orla_vertical', pts, .014, OURO_ESCURO)
pts = [verts[linhas*(colunas+1)+i] for i in range(colunas+1)]
tubo('Orla_inferior', pts, .018, OURO_ESCURO)
for lado in [0, colunas]:
    s = -1 if lado == colunas else 1
    for j in range(5, 29, 2):
        base = Vector(verts[j*(colunas+1)+lado])
        tubo('Bordado_folha', [base+Vector((s*.015, -.02, -.025)),
            base+Vector((s*.065, -.028, .015)), base+Vector((s*.024, -.025, .053))], .0055, OURO)

# Gola de pelos: tufos modelados, sem cartões ou transparência.
for i in range(35):
    a = .70+i*(math.tau-1.4)/34
    x = .56*math.sin(a)
    y = .02-.30*math.cos(a)
    z = 2.29+.04*math.cos(a)
    for j in range(3):
        p = (x+random.uniform(-.025,.025), y-.12+j*.10, z+random.uniform(-.025,.035))
        bola('Gola_tufo', p, (.085, .075, .060), PELO, segmentos=12, aneis=8)
        for k in range(7):
            inicio = (p[0]+random.uniform(-.035,.035), p[1]+random.uniform(-.045,.035), p[2]+random.uniform(-.015,.04))
            fim = (inicio[0]+math.sin(a)*random.uniform(.05,.12), inicio[1]+random.uniform(-.07,.05), inicio[2]+random.uniform(-.045,.07))
            ponta('Pelo_ponta', inicio, fim, .022, .001, PELO_LUZ if k%3 == 0 else PELO, vertices=7)

# Ombreiras, peitoral e tassets: placas independentes com recobrimento físico.
OSSO = 'peito'
for s in [-1, 1]:
    for i in range(3):
        x0, x1 = s*(.30+i*.06), s*(.68+i*.045)
        z = 2.18-i*.087
        chapa('Ombreira', [(x0, -.21, z+.065), (s*.52, -.28, z+.11),
            (x1, -.18, z), (s*(.65+i*.04), -.28, z-.09), (s*.40, -.32, z-.04)])
    # Frontal simétrico dividido por crista central.
    chapa('Peitoral', [(s*.035, -.292, 2.15), (s*.34, -.25, 2.13),
        (s*.45, -.20, 1.97), (s*.34, -.298, 1.85), (s*.025, -.325, 1.89)],
        centro=(s*.21, -.35, 2.02), relevo=.02)
    for i in range(3):
        z = 1.84-i*.11
        chapa('Abdomen_lamina', [(s*.025, -.30, z+.035), (s*.33, -.275, z+.08),
              (s*.36, -.26, z-.035), (s*.11, -.33, z-.09), (s*.025, -.33, z-.065)])
    for i in range(4):
        z = 1.25-i*.125
        x = s*(.32+i*.025)
        chapa('Saia_placas', [(x-s*.19, -.205, z+.14), (x+s*.19, -.17, z+.10),
             (x+s*.23, -.23, z-.04), (x+s*.025, -.32, z-.11), (x-s*.17, -.285, z-.045)])
    for i in range(8):
        x = s*(.12+random.random()*.24)
        z = 1.70+random.random()*.40
        tubo('Risco_armadura', [(x, -.342, z), (x+s*.026, -.343, z+.035)], .0022, METAL_CLARO, resolucao=1)

# Tecido frontal em três dobras contínuas abaixo do cinto.
OSSO = 'quadril'
v = []
for j in range(17):
    t = j/16
    for i in range(17):
        u = i/16
        x = (u-.5)*(.39+.09*t)
        y = -.295-.045*math.sin(u*math.tau*2)-.035*t
        z = 1.35-t*.91+.075*math.sin(u*math.pi)*t**5
        v.append((x, y, z))
malha('Tabardo_frontal', v, [(j*17+i,j*17+i+1,(j+1)*17+i+1,(j+1)*17+i) for j in range(16) for i in range(16)], VINHO, espessura=.015)
for lado in [0,16]:
    tubo('Tabardo_bordado', [v[j*17+lado] for j in range(17)], .008, OURO_ESCURO)
OSSO = 'peito'
# Faixa de tecido diagonal no colo.
for j in range(4):
    tubo('Drapeado_colo', [(-.43, -.22, 2.20-j*.025), (-.19, -.35, 2.13-j*.03),
        (.13, -.34, 2.07-j*.025), (.41, -.22, 2.09-j*.018)], .045, VINHO_LUZ)


def caveira(nome, pos, escala=1, osso=None):
    x,y,z = pos
    bola(nome+'_cranio', (x,y,z), (.092*escala,.045*escala,.10*escala), OURO, osso)
    bola(nome+'_face', (x,y-.018*escala,z-.054*escala), (.071*escala,.04*escala,.059*escala), OURO, osso)
    for s in [-1,1]:
        bola(nome+'_orbita', (x+s*.039*escala,y-.047*escala,z+.005*escala),
            (.027*escala,.013*escala,.029*escala), SOMBRA, osso, segmentos=12, aneis=8)
        ponta(nome+'_chifre', (x+s*.074*escala,y,z+.035*escala),
            (x+s*.15*escala,y+.01*escala,z+.13*escala), .033*escala, 0, OURO, osso)
    lapidar(nome+'_nariz', (x,y-.063*escala,z-.035*escala), (.015*escala,.009*escala,.022*escala), SOMBRA, osso)
    for i in range(5):
        ponta(nome+'_dente', (x+(i-2)*.020*escala,y-.026*escala,z-.08*escala),
              (x+(i-2)*.020*escala,y-.03*escala,z-.12*escala), .009*escala,.005*escala,OURO,osso)


for s in [-1,1]:
    anel('Broche_aro', (s*.40, -.29, 2.155), .10, .014, OURO)
    caveira('Broche_real', (s*.40, -.30, 2.155), .72)
    for j in range(11):
        t = j/10
        x = -.40+.8*t
        z = 2.10-.14*math.sin(math.pi*t)
        anel('Corrente_peitoral', (x,-.36,z), .031,.007, OURO,
             rot=(math.pi/2,0,.4 if j%2 else -.4))
OSSO = 'quadril'
N=64
v=[]
for z in [1.31,1.43]:
    for i in range(N):
        a=i*math.tau/N
        v.append((.445*math.sin(a),-.025-.292*math.cos(a),z))
malha('Cinto',v,[(i,(i+1)%N,(i+1)%N+N,i+N) for i in range(N)],COURO,espessura=.024)
caveira('Fivela_caveira', (.15,-.355,1.375),1.35)
for i in range(12):
    t=i/11
    anel('Corrente_cinto',(-.23+.18*t,-.34,1.32-.25*math.sin(math.pi*t)),.022,.0055,OURO)
lapidar('Pingente_cinto',(-.20,-.36,1.10),(.047,.024,.072),OURO)

# Espada da referência: lâmina longa, sulco, guarda ornamental, rubi e punho.
OSSOS['espada'] = ((-.83, -.34, 1.85), (-.83, -.34, .85), 'mao_D')
OSSO = 'espada'
SX, SY = -.83, -.34
def espada_ponto(x,y,z): return (SX+x,SY+y,z)
cont=[espada_ponto(-.105,0,1.55),espada_ponto(.105,0,1.55),espada_ponto(.125,0,.35),
      espada_ponto(.045,0,.11),espada_ponto(0,0,.035),espada_ponto(-.10,0,.19)]
chapa('Espada_lamina',cont,METAL_CLARO,centro=espada_ponto(0,-.045,.89),relevo=0,borda=False)
cont2=[espada_ponto(-.061,-.029,1.54),espada_ponto(.061,-.029,1.54),
       espada_ponto(.073,-.033,.36),espada_ponto(0,-.036,.14),espada_ponto(-.063,-.032,.27)]
chapa('Espada_canal',cont2,METAL,centro=espada_ponto(0,-.055,.88),relevo=0,borda=False)
ponta('Espada_punho',(SX,SY,1.54),(SX,SY,1.92),.045,.045,COURO)
for i in range(11):
    z=1.565+i*.030
    tubo('Espada_tranca',[(SX-.04,SY,z),(SX,SY-.047,z+.018),(SX+.04,SY,z+.03)],.006,OURO_ESCURO)
for z in [1.565,1.89]:
    anel('Espada_aro_punho',(SX,SY,z),.045,.009,OURO,rot=(0,0,0))
lapidar('Espada_pomo',(SX,SY,1.925),(.068,.056,.058),OURO)
for s in [-1,1]:
    cont=[espada_ponto(s*.035,-.005,1.61),espada_ponto(s*.13,-.005,1.63),
        espada_ponto(s*.225,-.005,1.71),espada_ponto(s*.20,-.005,1.595),
        espada_ponto(s*.31,-.005,1.55),espada_ponto(s*.17,-.005,1.52),
        espada_ponto(s*.11,-.005,1.45),espada_ponto(s*.10,-.005,1.56)]
    chapa('Espada_guarda',cont,OURO,centro=espada_ponto(s*.14,-.045,1.59),relevo=0,borda=False)
    ponta('Espada_espora',espada_ponto(s*.12,0,1.51),espada_ponto(s*.10,0,1.30),.033,.001,OURO)
lapidar('Espada_engaste',espada_ponto(0,-.052,1.57),(.092,.037,.12),OURO)
lapidar('Espada_rubi',espada_ponto(0,-.088,1.59),(.048,.021,.073),JOIA)

# Rig próprio: pesos rígidos nas placas e deformação distribuída no manto.
bpy.ops.object.select_all(action='DESELECT')
bpy.ops.object.armature_add()
rig=bpy.context.object
rig.name='GoblinKing_Rig'
bpy.ops.object.mode_set(mode='EDIT')
rig.data.edit_bones.remove(rig.data.edit_bones[0])
for nome,(inicio,fim,pai) in OSSOS.items():
    b=rig.data.edit_bones.new(nome)
    b.head=inicio
    b.tail=fim
    if pai: b.parent=rig.data.edit_bones[pai]
bpy.ops.object.mode_set(mode='OBJECT')
rig.show_in_front=True

for o in PECAS:
    if o.type != 'MESH': continue
    # UVs garantidas também nas placas/curvas modeladas.
    if not o.data.uv_layers:
        uv=o.data.uv_layers.new(name='UVMap')
        for poly in o.data.polygons:
            for loop in poly.loop_indices:
                co=o.data.vertices[o.data.loops[loop].vertex_index].co
                uv.data[loop].uv=(co.x*.85+co.y*.25,co.z*.7+co.y*.15)
    osso=o['osso']
    if o == manto:
        g1=o.vertex_groups.new(name='peito')
        g2=o.vertex_groups.new(name='quadril')
        for vert in o.data.vertices:
            z=(o.matrix_world@vert.co).z
            w=max(.0,min(1,(z-1.25)/.7))
            if w>0: g1.add([vert.index],w,'REPLACE')
            if w<1: g2.add([vert.index],1-w,'REPLACE')
    else:
        g=o.vertex_groups.new(name=osso)
        g.add(list(range(len(o.data.vertices))),1,'REPLACE')
    mod=o.modifiers.new('Esqueleto','ARMATURE')
    mod.object=rig
    o.parent=rig
    o.matrix_parent_inverse=rig.matrix_world.inverted()

# Agrupamento por material reduz draw calls, mantendo grupos e modificador.
for nome,mat in MATERIAIS.items():
    pecas=[o for o in PECAS if o.type=='MESH' and o.data.materials[0]==mat]
    if pecas:
        o = unir(pecas,'GoblinKing_'+nome)
        triangulos = sum(len(p.vertices)-2 for p in o.data.polygons)
        if triangulos > 6000:
            mod = o.modifiers.new('Reducao_para_jogo', 'DECIMATE')
            mod.ratio = .5
            bpy.context.view_layer.objects.active = o
            bpy.ops.object.modifier_apply(modifier=mod.name)

# Um ciclo de respiração sutil. Não se apresenta caminhada/combate como prontos.
rig.animation_data_create()
acao=bpy.data.actions.new('parado')
rig.animation_data.action=acao
for quadro, fator in [(1,0),(21,1),(41,0),(61,-.65),(81,0)]:
    for nome in ['peito','cabeca']:
        p=rig.pose.bones[nome]
        p.rotation_mode='XYZ'
        p.rotation_euler=(fator*(.008 if nome=='peito' else -.006),0,0)
        p.keyframe_insert(data_path='rotation_euler',frame=quadro,group=nome)
rig.animation_data.action=None
trilha=rig.animation_data.nla_tracks.new()
trilha.name='parado'
strip=trilha.strips.new('parado',1,acao)
bpy.context.scene.frame_start=1
bpy.context.scene.frame_end=81
bpy.context.scene.render.fps=30
bpy.context.scene.frame_set(1)

DESTINO.mkdir(parents=True,exist_ok=True)
FONTES.mkdir(parents=True,exist_ok=True)
PREVIAS.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True)
for o in PECAS: o.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(DESTINO/'goblin_king.glb'),export_format='GLB',
    use_selection=True,export_yup=True,export_animations=True,export_animation_mode='NLA_TRACKS',
    export_skins=True,export_all_influences=False,export_def_bones=True,
    export_materials='EXPORT',export_image_format='AUTO',export_cameras=False,export_lights=False)

# Fonte editável: iluminação e câmera de revisão ficam somente no .blend.
scene=bpy.context.scene
scene.render.engine='CYCLES'
scene.cycles.samples=24
scene.render.resolution_x=900
scene.render.resolution_y=1100
scene.render.resolution_percentage=100
scene.world.color=(.16,.16,.16)
scene.view_settings.view_transform='AgX'
def luz(nome,pos,potencia,cor,tamanho):
    d=bpy.data.lights.new(nome,'AREA')
    d.energy=potencia
    d.color=cor
    d.shape='DISK'
    d.size=tamanho
    o=bpy.data.objects.new(nome,d)
    bpy.context.collection.objects.link(o)
    o.location=pos
    o.rotation_euler=(Vector((0,0,1.65))-o.location).to_track_quat('-Z','Y').to_euler()
luz('Principal',(-3,-4,5),550,(1,.84,.65),4)
luz('Preenchimento',(3,-2,3),300,(.66,.78,1),3)
luz('Recorte',(1,3,4),650,(1,.66,.34),2)
bpy.ops.object.camera_add(location=(4,-7,3.2))
camera=bpy.context.object
camera.name='Camera_revisao'
camera.rotation_euler=(Vector((-.05,0,1.62))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.type='ORTHO'
camera.data.ortho_scale=3.8
scene.camera=camera
scene.render.film_transparent=True
bpy.ops.wm.save_as_mainfile(filepath=str(FONTES/'goblin_king.blend'))
triangulos=sum(len(p.vertices)-2 for o in PECAS for p in o.data.polygons)
relatorio={'arquivo':'res://assets/inimigos/goblin_king/goblin_king.glb',
 'fonte':'arte/fontes/inimigos/goblin_king/goblin_king.blend',
 'referencia':'referencia.png','metodo':'modelagem procedural esculpida em Blender; aproximação da referência',
 'altura_m':3.31,'chao_z_blender':0,'frente_blender':'-Y','frente_godot':'+Z',
 'triangulos':triangulos,'ossos':len(OSSOS),'materiais':len(MATERIAIS),
 'animacoes':{'parado':{'duracao_s':80/30,'quadros':81,'fps':30}},
 'limites':['Fidelidade à referência depende de revisão visual; não é reprodução exata.',
 'Rig articulado fornecido; caminhada, ataques e IA não implementados.',
 'Cenário de jogo e inimigos existentes preservados.']}
(DESTINO/'manifesto.json').write_text(json.dumps(relatorio,ensure_ascii=False,indent=2)+'\n')
print('GOBLIN_KING_EXPORTADO',json.dumps(relatorio,ensure_ascii=False))
if '--renderizar' in __import__('sys').argv:
    scene.render.filepath=str(PREVIAS/'blender_tres_quartos.png')
    bpy.ops.render.render(write_still=True)
