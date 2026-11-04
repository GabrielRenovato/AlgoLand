"""Rig próprio e transferência das rotações globais dos FBXs Mixamo locais."""
import bpy, math, json, hashlib
from pathlib import Path
from mathutils import Vector, Matrix
RAIZ=Path(__file__).resolve().parents[3]
FONTES=RAIZ/'arte/fontes/inimigos/goblin_capuz_3d'
MIXAMO=RAIZ/'arte/fontes/personagens/base_3d/mixamo'
DESTINO=RAIZ/'assets/inimigos/goblin_capuz_3d'
bpy.ops.wm.open_mainfile(filepath=str(FONTES/'goblin_capuz.blend'))
malhas=[o for o in bpy.context.scene.objects if o.type=='MESH']
# Cabeça e acessórios mantêm sua forma; juntas recebem pesos contínuos.
ossos={
'Hips':((0,0,.55),(0,0,.66),None),
'Spine':((0,0,.66),(0,0,.78),'Hips'),
'Spine1':((0,0,.78),(0,0,.89),'Spine'),
'Spine2':((0,0,.89),(0,0,1.00),'Spine1'),
'Neck':((0,0,1.00),(0,-.018,1.10),'Spine2'),
'Head':((0,-.018,1.10),(0,-.018,1.38),'Neck')}
for lado,s in [('Right',-1),('Left',1)]:
    ossos.update({lado+'Shoulder':((s*.08,0,.96),(s*.25,0,.96),'Spine2'),lado+'Arm':((s*.25,0,.96),(s*.36,-.025,.76),lado+'Shoulder'),lado+'ForeArm':((s*.36,-.025,.76),(s*.40,-.085,.55),lado+'Arm'),lado+'Hand':((s*.40,-.085,.55),(s*.41,-.12,.46),lado+'ForeArm'),lado+'UpLeg':((s*.14,0,.55),(s*.18,.005,.30),'Hips'),lado+'Leg':((s*.18,.005,.30),(s*.20,-.005,.10),lado+'UpLeg'),lado+'Foot':((s*.20,-.005,.10),(s*.20,-.193,.044),lado+'Leg'),lado+'ToeBase':((s*.20,-.193,.044),(s*.20,-.25,.035),lado+'Foot')})
# Orientações de referência para preservar a torção do punho e dos pés.
bpy.ops.import_scene.fbx(filepath=str(MIXAMO/'Idle.fbx'))
fonte=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
def osso_fonte(r,n):return next((b for b in r.data.bones if b.name.split(':')[-1]==n),None)
orientacoes={n:(fonte.matrix_world@osso_fonte(fonte,n).matrix_local).to_3x3().normalized() for n in ossos}
for o in list(bpy.context.scene.objects):
    if o not in malhas and o.type not in ['CAMERA','LIGHT']:bpy.data.objects.remove(o,do_unlink=True)
bpy.ops.object.select_all(action='DESELECT')
bpy.ops.object.armature_add()
rig=bpy.context.object;rig.name='GoblinCapuz_Rig'
bpy.ops.object.mode_set(mode='EDIT');rig.data.edit_bones.remove(rig.data.edit_bones[0])
for n,(a,b,pai) in ossos.items():
    eb=rig.data.edit_bones.new(n);eb.head=a;eb.tail=b
    if pai:eb.parent=rig.data.edit_bones[pai]
    eb.align_roll(orientacoes[n].col[2])
bpy.ops.object.mode_set(mode='OBJECT')

def distancia_segmento(p,a,b):
    a=Vector(a);b=Vector(b);d=b-a;t=max(0,min(1,(p-a).dot(d)/d.length_squared))
    return (p-(a+d*t)).length

def pesos(o,p):
    n=o.name.split('.')[0]
    # As primitivas cônicas do utilitário antigo mantiveram o nome padrão Blender.
    if n=='Cone':
        centro=sum((o.matrix_world@v.co for v in o.data.vertices),Vector())/len(o.data.vertices)
        if centro.y<-.14 and centro.z>.35:n='Cabo_lamina'
        elif centro.z<.08:n='Unha_pe'
        elif centro.z<.31:n='Canela'
        elif centro.z<.57:n='Coxa'
        elif centro.z<.80:n='Antebraco'
        else:n='Braco'
    lado='Right' if p.x<0 else 'Left'
    if n in ['Cabo_lamina','Guarda','Lamina_curva','Fio_lamina']:return {'RightHand':1}
    if n in ['Pe','Dedo_pe','Unha_pe']:return {lado+'Foot':1}
    if n=='Faixa_tornozelo':return {lado+'Leg':1}
    if n in ['Mao','Dedos_mao','Polegar']:return {lado+'Hand':1}
    if n in ['Antebraco','Atadura_braco']:return {lado+'ForeArm':1}
    if n=='Ombro':return {lado+'Arm':.7,'Spine2':.3}
    if n in ['Braco','Cotovelo']:
        t=max(0,min(1,(.80-p.z)/.09));return {lado+'Arm':1-t,lado+'ForeArm':t}
    if n in ['Coxa','Joelho','Canela']:
        t=max(0,min(1,(.35-p.z)/.10));return {lado+'UpLeg':1-t,lado+'Leg':t}
    if n in ['Quadril','Bolsa','Costura_bolsa','Pano_frontal','Prega_avental','Cinto','Cinto_costas']:return {'Hips':1}
    if n in ['Tronco','Tiracolo','Rebite_tiracolo','Fivela','Lingueta']:
        centros={'Hips':.58,'Spine':.70,'Spine1':.83,'Spine2':.96}
        ds=sorted([(abs(p.z-z),b) for b,z in centros.items()])[:2]
        w=[1/(d+.015)**3 for d,b in ds];return {ds[i][1]:w[i]/sum(w) for i in range(2)}
    if n in ['Manto_rasgado','Prega_gola']:return {'Spine2':1}
    return {'Head':1}
for o in malhas:
    if o.name.startswith('Cone') and (o.matrix_world.translation-Vector((-.37,-.17,.47))).length<.13:
        o.name='Cabo_lamina' if o.dimensions.z>.07 else 'Guarda'
# Empunhadura canônica: eixo do cabo alinhado à mão; curva para fora do corpo.
# A transformação é rígida e idêntica para cabo, guarda, lâmina e fio.
def quadro_empunhadura(eixo, curva):
    y=Vector(eixo).normalized()
    x=Vector(curva);x=(x-y*x.dot(y)).normalized()
    return Matrix((x,y,x.cross(y))).transposed()
origem_cabo=Vector((-.37,-.17,.47))
centro_pegada=Vector((-.41,-.135,.492))
quadro_original=quadro_empunhadura((.12,-.02,-.14),(.64,-.05,-.18))
quadro_mao=quadro_empunhadura(Vector(ossos['RightHand'][1])-Vector(ossos['RightHand'][0]),(-1,-.3,0))
rotacao_faca=quadro_mao@quadro_original.transposed()
for o in malhas:
    if o.name.split('.')[0] in ['Lamina_curva','Fio_lamina','Cabo_lamina','Guarda']:
        for v in o.data.vertices:
            p=o.matrix_world@v.co
            v.co=o.matrix_world.inverted()@(centro_pegada+rotacao_faca@(p-origem_cabo))
for o in malhas:
    # Aplicar transforms antes de calcular pesos nas coordenadas canônicas.
    mw=o.matrix_world.copy()
    for v in o.data.vertices:v.co=mw@v.co
    o.matrix_world=Matrix.Identity(4)
    grupos={n:o.vertex_groups.new(name=n) for n in ossos}
    for v in o.data.vertices:
        for n,w in pesos(o,v.co).items():
            if w>0:grupos[n].add([v.index],w,'REPLACE')
    mod=o.modifiers.new('Deformacao_goblin','ARMATURE');mod.object=rig
    o.parent=rig

clips={'parado':('Idle.fbx',True),'correr':('Standard Run.fbx',True),'ataque_1':('Standing Melee Attack Horizontal.fbx',False),'ataque_2':('Standing Melee Attack Downward.fbx',False),'defesa':('Sword And Shield Block Idle.fbx',True),'ferido':('Hit Reaction.fbx',False),'morrer':('Dying.fbx',False)}
sc=bpy.context.scene;sc.render.fps=30
rel=[]
for nome,(arquivo,loop) in clips.items():
    antes=set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=str(MIXAMO/arquivo))
    src=next(o for o in set(bpy.data.objects)-antes if o.type=='ARMATURE')
    action=src.animation_data.action;inicio,fim=[int(x) for x in action.frame_range]
    srcmap={n:osso_fonte(src,n).name for n in ossos}
    rig.animation_data_create();rig.animation_data.action=bpy.data.actions.new(nome)
    act=rig.animation_data.action
    repouso_parado={}
    for f in range(inicio,fim+1):
        sc.frame_set(f)
        desejadas={n:(src.matrix_world@src.pose.bones[srcmap[n]].matrix).to_quaternion() for n in ossos}
        if nome=='parado':
            # A cabeça grande exige menos giro que o humano do clipe original.
            for n,fator in [('Neck',.35),('Head',.22)]:
                if n not in repouso_parado:repouso_parado[n]=desejadas[n].copy()
                desejadas[n]=repouso_parado[n].slerp(desejadas[n],fator)
        for n,(a,b,pai) in ossos.items():
            pb=rig.pose.bones[n];pb.rotation_mode='QUATERNION'
            rest=rig.data.bones[n].matrix_local.to_quaternion()
            restpai=rig.data.bones[pai].matrix_local.to_quaternion() if pai else Matrix.Identity(3).to_quaternion()
            localrep=restpai.inverted()@rest
            posepai=desejadas[pai] if pai else Matrix.Identity(3).to_quaternion()
            pb.rotation_quaternion=localrep.inverted()@posepai.inverted()@desejadas[n]
            pb.location=(0,0,0)
            if n=='Hips':
                pos=src.matrix_world@src.pose.bones[srcmap[n]].matrix.translation
                rep=src.matrix_world@src.data.bones[srcmap[n]].head_local
                desloc=(pos-rep)*(.55/max(.1,rep.z))
                if nome!='morrer':desloc.x=0;desloc.y=0
                pb.location=rest.inverted()@desloc
                pb.keyframe_insert('location',frame=f-inicio+1)
            pb.keyframe_insert('rotation_quaternion',frame=f-inicio+1)
    # Strip individual permite exportar cada clipe como animação GLB independente.
    act.use_fake_user=True;act['fonte']='Adobe Mixamo / '+arquivo;act['loop']=loop
    rig.animation_data.action=None
    track=rig.animation_data.nla_tracks.new();track.name=nome
    strip=track.strips.new(nome,1,act);strip.action_frame_start=1;strip.action_frame_end=fim-inicio+1
    track.mute=True
    for o in list(set(bpy.data.objects)-antes):bpy.data.objects.remove(o,do_unlink=True)
    rel.append({'id':nome,'arquivo':arquivo,'sha256':hashlib.sha256((MIXAMO/arquivo).read_bytes()).hexdigest(),'quadros':fim-inicio+1,'fps':30,'loop':loop})
    print('MIXAMO_TRANSFERIDO',nome,fim-inicio+1,flush=True)
# Correção geométrica por clipe, sem soltar a faca da mão.
import importlib.util
spec=importlib.util.spec_from_file_location('encaixe_faca',Path(__file__).with_name('encaixar_faca.py'))
encaixe=importlib.util.module_from_spec(spec);spec.loader.exec_module(encaixe)
encaixe.corrigir(rig,malhas,sc)
for pb in rig.pose.bones:pb.location=(0,0,0);pb.rotation_quaternion=(1,0,0,0)
for track in rig.animation_data.nla_tracks:track.mute=False
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
for o in malhas:o.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(DESTINO/'goblin_capuz_animado.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_skins=True,export_def_bones=True,export_cameras=False,export_lights=False)
for track in rig.animation_data.nla_tracks:track.mute=True
sc.frame_set(1)
bpy.ops.wm.save_as_mainfile(filepath=str(FONTES/'goblin_capuz_animado.blend'))
(FONTES/'animacoes_mixamo.json').write_text(json.dumps({'rig':len(ossos),'animacoes':rel,'retarget':'rotações globais; comprimentos do goblin; raiz X/Y removida exceto morte','arma':'mão direita','pendencia':'sem IA ou integração nos mapas'},ensure_ascii=False,indent=2))
print('GOBLIN_ANIMADO_EXPORTADO',flush=True)
