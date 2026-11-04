"""Transfere clipes CC0 KayKit ao rig original; IK apenas acomoda a pegada."""
import bpy, bmesh, json, math
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion
ROOT=Path(__file__).resolve().parents[3]
FONTES=ROOT/'arte/fontes/inimigos/lorde_goblin_3d'
DEST=ROOT/'assets/inimigos/lorde_goblin_3d'
S=1.5
FPS=60
bpy.ops.wm.open_mainfile(filepath=str(FONTES/'lorde_goblin.blend'))
bpy.context.preferences.filepaths.save_version=0
rig=bpy.data.objects['LordeGoblin_Rig']
rig.animation_data_clear()
for p in rig.pose.bones:
    p.matrix_basis=Matrix.Identity(4)
    p.rotation_mode='QUATERNION'
# Ambas as mãos usam o cabo como referência durante a pegada dupla.
# A compensação animada permite soltar a esquerda; a fase presa não sofre
# desvio de interpolação entre cadeias independentes de ossos.
bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='EDIT')
rig.data.edit_bones['mao_E'].parent=rig.data.edit_bones['martelo']
bpy.ops.object.mode_set(mode='OBJECT')
REST={b.name:b.matrix_local.copy() for b in rig.data.bones}
V=lambda p:Vector(p)*S
T=lambda p:Matrix.Translation(p)
R=lambda angle,axis:Matrix.Rotation(angle,4,axis)
GD=V((-.98,-.22,1.12))
# A mão esquerda recebe a mesma anatomia curva e a mesma folga radial da direita.
pele=next(o for o in bpy.data.objects if o.type=='MESH' and o.vertex_groups.get('mao_D') and any(g.group==o.vertex_groups['mao_D'].index for v in o.data.vertices for g in v.groups))
clone=pele.copy();clone.data=pele.data.copy();bpy.context.collection.objects.link(clone)
def recortar(obj,grupo,manter):
    bm=bmesh.new();bm.from_mesh(obj.data);layer=bm.verts.layers.deform.active
    idx=obj.vertex_groups[grupo].index
    apagar=[v for v in bm.verts if (v[layer].get(idx,0)>.5)!=manter]
    bmesh.ops.delete(bm,geom=apagar,context='VERTS');bm.to_mesh(obj.data);bm.free()
recortar(clone,'mao_D',True)
recortar(pele,'mao_E',False)
M=T(V((.83,-.105,.8)))@R(math.pi/2,'Y')@Matrix.Diagonal(Vector((-1,1,1,1)))@T(-V((-.845,-.115,1.095)))
for v in clone.data.vertices:v.co=M@v.co
bm=bmesh.new();bm.from_mesh(clone.data);bmesh.ops.reverse_faces(bm,faces=list(bm.faces));bm.to_mesh(clone.data);bm.free()
clone.vertex_groups.clear();clone.vertex_groups.new(name='mao_E').add(list(range(len(clone.data.vertices))),1,'REPLACE')
bpy.ops.object.select_all(action='DESELECT');pele.select_set(True);clone.select_set(True);bpy.context.view_layer.objects.active=pele;bpy.ops.object.join()
GE=T(M@GD)@R(math.pi/2,'Y')@R(math.pi,'Z')
REL={'D':T(GD).inverted()@REST['mao_D'],'E':GE.inverted()@REST['mao_E']}
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.parent==rig]
# Cabeça e pés: os pontos reais da geometria determinam o contato com o chão.
def vertices_grupo(nome):
    out=[]
    for o in meshes:
        if nome not in o.vertex_groups:continue
        idx=o.vertex_groups[nome].index
        out.extend(v.co.copy() for v in o.data.vertices if any(g.group==idx and g.weight>.5 for g in v.groups))
    return out
pedra=[v for v in vertices_grupo('martelo') if v.z>1.84*S]
pes={s:vertices_grupo('pe_'+s) for s in ['D','E']}
# Pontos extremos do pé bastam para corrigir o apoio em qualquer inclinação X.
for s in pes:
    grupos={}
    for v in pes[s]:
        k=round(v.y,3)
        if k not in grupos or v.z<grupos[k].z:grupos[k]=v
    pes[s]=list(grupos.values())

def quadro(origem,direcao,rest):
    q=(rest.to_quaternion()@Vector((0,1,0))).rotation_difference(direcao.normalized())@rest.to_quaternion()
    return T(origem)@q.to_matrix().to_4x4()

def ik(n1,n2,base,target,pole,desired):
    l1=rig.data.bones[n1].length;l2=rig.data.bones[n2].length
    d=target-base;length=max(1e-6,min(d.length,(l1+l2)*.9999));axis=d.normalized()
    x=(length*length+l1*l1-l2*l2)/(2*length)
    h=math.sqrt(max(0,l1*l1-x*x));ortho=pole-base;ortho-=axis*ortho.dot(axis)
    if ortho.length<1e-6:ortho=axis.cross(Vector((0,1,0)))
    elbow=base+axis*x+ortho.normalized()*h
    desired[n1]=quadro(base,elbow-base,REST[n1]);desired[n2]=quadro(elbow,target-elbow,REST[n2])
    return max(0,d.length-l1-l2)

import hashlib,sys
SOURCE=ROOT/'arte/fontes/personagens/base_3d/kaykit/Rig_Medium_CombatMelee.glb'
SC=bpy.context.scene
NAMES=['root','hips','chest','head','upperarm.r','lowerarm.r','upperarm.l','lowerarm.l','hand.r','handslot.r','hand.l','foot.r','foot.l']
DADOS={};ARQUIVOS={}
for pacote,nomes in [(SOURCE,['Melee_2H_Attack_Slice','Melee_2H_Attack_Chop','Melee_2H_Attack_Spinning']),
    (SOURCE.with_name('Rig_Medium_MovementBasic.glb'),['Walking_A'])]:
    SC.render.fps=30
    antes=set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(pacote))
    novos=set(bpy.data.objects)-antes
    src=next(o for o in novos if o.type=='ARMATURE')
    for track in src.animation_data.nla_tracks:track.mute=True
    for nome in nomes:
        action=bpy.data.actions[nome];src.animation_data.action=action
        inicio,fim=action.frame_range;dur=(fim-inicio)/30
        frames=[]
        for f in range(round(dur*FPS)+1):
            time=min(f/FPS,dur);q=inicio+time*30
            SC.frame_set(int(q),subframe=q%1)
            frames.append({n:(src.matrix_world@src.pose.bones[n].matrix).copy() for n in NAMES})
        DADOS[nome]=(frames,dur);ARQUIVOS[nome]=pacote
        print('FONTE_KAYKIT',nome,dur,len(frames),flush=True)
    for o in novos:bpy.data.objects.remove(o,do_unlink=True)
for o in meshes:o.hide_set(True)
IDENT=Quaternion((1,0,0,0))
def suave(t):
    t=max(0,min(1,t));return t*t*(3-2*t)
def blend(a,b,u):
    return Matrix.LocRotScale(a.translation.lerp(b.translation,u),a.to_quaternion().slerp(b.to_quaternion(),u),Vector((1,1,1)))
def sample(name,t):
    frames,dur=DADOS[name];i=max(0,min(len(frames)-1,t*FPS));f=int(i);g=min(f+1,len(frames)-1)
    return {n:frames[f][n].lerp(frames[g][n],i-f) for n in NAMES}

def transferir(name,tempo,alpha,deslize=.80):
    source=sample(name,tempo);first=dict(DADOS[name][0][0])
    if name=='Walking_A':
        guarda=DADOS['Melee_2H_Attack_Slice'][0][0]['handslot.r']
        source['handslot.r']=source['chest']@first['chest'].inverted()@guarda
        first['handslot.r']=guarda

    rootdelta=source['root']@first['root'].inverted()
    # Somente yaw da raiz da fonte. Movimento da batalha fica com a física.
    root=R(rootdelta.to_euler().z*alpha,'Z')
    invroot=rootdelta.inverted()
    source={n:invroot@m for n,m in source.items()}
    desired={'raiz':root@REST['raiz']}
    desloc=(source['hips'].translation-first['hips'].translation)*S*.60*alpha
    desloc.x=max(-.12*S,min(.12*S,desloc.x));desloc.y=max(-.12*S,min(.12*S,desloc.y))
    def delta(n):return IDENT.slerp(source[n].to_quaternion()@first[n].to_quaternion().inverted(),alpha)
    pelvis=T(desloc)@T(REST['quadril'].translation)@delta('hips').to_matrix().to_4x4()@T(-REST['quadril'].translation)
    desired['quadril']=pelvis@REST['quadril']
    chpos=pelvis@REST['peito'].translation
    desired['peito']=T(chpos)@delta('chest').to_matrix().to_4x4()@REST['peito'].to_quaternion().to_matrix().to_4x4()
    chest=desired['peito']@REST['peito'].inverted()
    desired['cabeca']=T(chest@REST['cabeca'].translation)@delta('head').to_matrix().to_4x4()@REST['cabeca'].to_quaternion().to_matrix().to_4x4()
    # Eixo Y do slot da arma: a trajetória e a rotação vêm do clipe original.
    source_axis=source['handslot.r'].to_quaternion()@Vector((0,1,0))
    Q=Vector((0,0,1)).rotation_difference(source_axis).to_matrix().to_4x4()
    offset=source['handslot.r'].translation-first['handslot.r'].translation
    P=V((-.15,-.48,1.25))+Vector((offset.x*.80,offset.y*.65,offset.z*1.30))*S
    Q=IDENT.slerp(Q.to_quaternion(),alpha).to_matrix().to_4x4()
    P=GD.lerp(P,alpha)
    roll=R(math.pi*alpha,'Z')
    axis=Q@Vector((0,0,1))
    def maos(p):
        d=T(p)@Q@roll@REL['D']
        e=T(p+axis*.22*S)@Q@REL['E']
        return {'D':d,'E':blend(chest@REST['mao_E'],e,alpha)}
    inicial=P.copy()
    for _ in range(80):
        hands=maos(P)
        for s in ['D','E']:
            if s=='E' and alpha<.999:continue
            shoulder=chest@rig.data.bones['braco_'+s].head_local
            v=hands[s].translation-shoulder
            limite=(rig.data.bones['braco_'+s].length+rig.data.bones['antebraco_'+s].length)*.996
            if v.length>limite:P-=v.normalized()*(v.length-limite)
        wm=T(P)@Q@T(-GD+V((0,0,deslize*alpha)))
        floor=min((wm@v).z for v in pedra)
        if floor<.015:P.z+=.015-floor
    hands=maos(P)
    maxerr=0
    for s,sgn,suf in [('D',-1,'r'),('E',1,'l')]:
        shoulder=chest@rig.data.bones['braco_'+s].head_local
        pole=chest@rig.data.bones['antebraco_'+s].head_local
        # Polo da fonte preserva a intenção do cotovelo; anatomia usa comprimentos locais.
        vetor=source['lowerarm.'+suf].translation-source['upperarm.'+suf].translation
        pole=pole.lerp(shoulder+vetor.normalized()*.65*S,alpha)
        target=hands[s].translation
        limite=(rig.data.bones['braco_'+s].length+rig.data.bones['antebraco_'+s].length)*.999
        if (target-shoulder).length>limite and alpha<.999:
            target=shoulder+(target-shoulder).normalized()*limite;hands[s].translation=target
        maxerr=max(maxerr,ik('braco_'+s,'antebraco_'+s,shoulder,target,pole,desired))
        desired['mao_'+s]=hands[s]
    wm=T(P)@Q@T(-GD+V((0,0,deslize*alpha)))
    desired['martelo']=wm@REST['martelo']
    for s,suf in [('D','r'),('E','l')]:
        # A transferência segue os passos e giros dos pés da fonte; a correção
        # geométrica conserva a sola acima do chão, sem alongar pernas.
        fd=source['foot.'+suf]@first['foot.'+suf].inverted()
        fq=IDENT.slerp(fd.to_quaternion(),alpha)
        pos=REST['pe_'+s].translation+(source['foot.'+suf].translation-first['foot.'+suf].translation)*.70*S*alpha
        fm=T(pos)@fq.to_matrix().to_4x4()@REST['pe_'+s].to_quaternion().to_matrix().to_4x4()
        deform=fm@REST['pe_'+s].inverted()
        low=min((deform@v).z for v in pes[s]);fm.translation.z-=low
        lift=max(0,source['foot.'+suf].translation.z-first['foot.'+suf].translation.z)*.7*S*alpha
        fm.translation.z+=lift
        hip=pelvis@rig.data.bones['coxa_'+s].head_local
        reach=(rig.data.bones['coxa_'+s].length+rig.data.bones['canela_'+s].length)*.998
        if (fm.translation-hip).length>reach:
            # Conservar contato e reduzir apenas o passo que excede a perna do goblin.
            for _ in range(12):
                fm.translation.x=(fm.translation.x+hip.x)*.5;fm.translation.y=(fm.translation.y+hip.y)*.5
                if (fm.translation-hip).length<reach:break
        desired['pe_'+s]=fm
        pole=rig.data.bones['canela_'+s].head_local.lerp(V(((-.32 if s=='D' else .32),-.8,.4)),alpha)
        ik('coxa_'+s,'canela_'+s,hip,fm.translation,pole,desired)
    desired['manto']=chest@REST['manto']
    for n in list(desired):
        if n!='raiz':desired[n]=root@desired[n]
    return desired,{'projecao_m':(P-inicial).length,'erro_m':maxerr,'chao_m':min((wm@v).z for v in pedra),'cabeca':wm@V((-.98,-.22,2.105))}

# Intervalos de entrada e saída apenas conectam repouso e pose da biblioteca.
CONFIG={
 'andar':{'fonte':'Walking_A','entrada':0,'acao':1.20,'saida':0},
 'golpe_duas_maos':{'fonte':'Melee_2H_Attack_Slice','entrada':.30,'acao':1.40,'saida':.35},
 'impacto_area':{'fonte':'Melee_2H_Attack_Chop','entrada':.30,'acao':2.20,'saida':.35},
 'giro_area':{'fonte':'Melee_2H_Attack_Spinning','entrada':.55,'acao':2.70,'saida':.55,'voltas':3}}
if '--estudo' in sys.argv:CONFIG={n:CONFIG[n] for n in ['golpe_duas_maos']}
rig.animation_data_create();rel={};eventos={};metricas={}
for nome,config in CONFIG.items():
    ac=bpy.data.actions.new(nome);rig.animation_data.action=ac
    for tr in rig.animation_data.nla_tracks:tr.mute=True
    fonte=config['fonte'];dur=config['entrada']+config['acao']+config['saida'];N=round(dur*FPS);dur=N/FPS
    prev={};stats=[]
    for f in range(N+1):
        t=f/FPS;ini=config['entrada'];fim=ini+config['acao']
        alpha=suave(t/ini) if t<ini else (1-suave((t-fim)/config['saida']) if t>fim else 1)
        u=max(0,min(1,(t-ini)/config['acao']))
        if nome=='giro_area':
            # Repetição da animação giratória pronta, sem inventar poses de giro.
            u=(u*3)%1 if u<1 else 1
        source_t=u*DADOS[fonte][1]
        desired,st=transferir(fonte,source_t,alpha)
        if nome=='giro_area':
            # Ajuste pedido pelo usuário: ascensão e descida sobre o giro pronto.
            # Um arco suave, sem salto nas emendas nem mudança da pegada.
            fase=max(0,min(1,(t-ini)/config['acao']))
            elevacao=.50*math.sin(math.pi*fase)**2
            subir=T(Vector((0,0,elevacao)))
            desired={n:subir@m for n,m in desired.items()}
        # Fechamento da origem na saída: a raiz da fonte termina em uma volta inteira.
        for b in rig.data.bones:
            n=b.name;parent=desired[b.parent.name]@REST[b.parent.name].inverted() if b.parent else Matrix.Identity(4)
            basis=(parent@REST[n]).inverted()@desired[n]
            pb=rig.pose.bones[n];loc,q,scale=basis.decompose()
            if n in prev:q.make_compatible(prev[n])
            prev[n]=q.copy();pb.location=loc;pb.rotation_quaternion=q;pb.scale=scale
            for prop in ['location','rotation_quaternion','scale']:pb.keyframe_insert(prop,frame=f,group=n)
        stats.append(st)
    for layer in ac.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for fc in bag.fcurves:
                    for k in fc.keyframe_points:k.interpolation='LINEAR'
    ac.use_fake_user=True;rig.animation_data.action=None
    tr=rig.animation_data.nla_tracks.new();tr.name=nome;tr.strips.new(nome,0,ac)
    rel[nome]={'fonte':fonte,'arquivo':str(ARQUIVOS[fonte].relative_to(ROOT)),'sha256':hashlib.sha256(ARQUIVOS[fonte].read_bytes()).hexdigest(),'fps':FPS,'duracao_s':dur,'ciclo':False,'pegada_dupla':[ini,fim]}
    metricas[nome]={'projecao_max_m':max(s['projecao_m'] for s in stats),'erro_alcance_m':max(s['erro_m'] for s in stats)}
    if nome=='andar':
        rel[nome]['ciclo']=True
        continue
    # Menor altura da pedra na fase de descida determina o contato real.
    if nome=='impacto_area':
        hit=min(range(round((ini+.25*config['acao'])*FPS),round((ini+.72*config['acao'])*FPS)),key=lambda i:stats[i]['chao_m'])
        center=stats[hit]['cabeca'];center.z=0
        events=[{'tempo_s':max(ini,hit/FPS-.42),'tipo':'aviso','raio_m':2.4},{'tempo_s':hit/FPS,'tipo':'impacto','raio_m':2.4}]
    elif nome=='golpe_duas_maos':
        hit=round((ini+config['acao']*.43)*FPS);center=stats[hit]['cabeca'];events=[{'tempo_s':hit/FPS,'tipo':'impacto','raio_m':1.05}]
    else:
        center=Vector((0,0,0));events=[{'tempo_s':round(ini+.12+i*(config['acao']-.24)/6,3),'tipo':'impacto','raio_m':3.5} for i in range(7)]
    for e in events:e['centro_local_m']=[round(center.x,5),round(center.z,5),round(-center.y,5)]
    eventos[nome]={'duracao_s':dur,'pegada_dupla':[ini,fim],'eventos':events}
    if nome=='giro_area':
        eventos[nome]['voltas']=3
        eventos[nome]['elevacao_max_m']=.50
        rel[nome]['elevacao_max_m']=.50
    print('TRANSFERIDO',nome,json.dumps(metricas[nome]),flush=True)
# Respiração base preservada a3,2s.
idle=bpy.data.actions.get('parado')
for layer in idle.layers:
    for st in layer.strips:
        for bag in st.channelbags:
            for fc in bag.fcurves:
                for p in fc.keyframe_points:p.co.x-=1;p.handle_left.x-=1;p.handle_right.x-=1
tr=rig.animation_data.nla_tracks.new();tr.name='parado';tr.strips.new('parado',0,idle).scale=2
for tr in rig.animation_data.nla_tracks:tr.mute=False
for o in meshes:o.hide_set(False)
SC.render.fps=FPS;SC.frame_start=0;SC.frame_end=round(max(v['duracao_s'] for v in rel.values())*FPS);SC.frame_set(0)
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
for o in meshes:o.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(DEST/'lorde_goblin.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_skins=True,export_materials='EXPORT',export_cameras=False,export_lights=False)
bpy.ops.wm.save_as_mainfile(filepath=str(FONTES/'lorde_goblin_kaykit.blend'))
(DEST/'animacoes.json').write_text(json.dumps(eventos,ensure_ascii=False,indent=2)+'\n')
(FONTES/'animacoes_kaykit.json').write_text(json.dumps({'autor':'Kay Lousberg','fonte':'https://kaylousberg.itch.io/kaykit-character-animations','licenca':'CC0','clipes':rel,'metricas':metricas,'metodo':'Transferência de trajetória e eixo Y do slot da arma, rotações de tronco e pés da biblioteca. IK acomoda os membros do Lorde; entradas/saídas apenas ligam ao repouso.'},ensure_ascii=False,indent=2)+'\n')
manifesto=json.loads((DEST/'manifesto.json').read_text());manifesto['fonte']='arte/fontes/inimigos/lorde_goblin_3d/lorde_goblin_kaykit.blend';manifesto['animacoes']={'parado':{'duracao_s':3.2,'ciclo':True},**rel}
manifesto['integracao']={'ator':'cenas/inimigos/lorde_goblin.tscn','dungeon':'codigo/campanha/dungeon_comporta.gd','entrada':'cenas/campanha/chegada_lorde_goblin.tscn','combate':'Eventos 3D aplicam dano na projeção real das áreas; caminhada gratuita Walking_A.'}
manifesto['limites']=['Morte usa desaparecimento, sem clipe esquelético de morte.','Custo em mobile físico não perfilado.']
(DEST/'manifesto.json').write_text(json.dumps(manifesto,ensure_ascii=False,indent=2)+'\n')
