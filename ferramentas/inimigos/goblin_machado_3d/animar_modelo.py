"""Rig do machadeiro, movimentos locais e pegada rígida das duas mãos.

Blender em background. --estudo exporta apenas parado e ataque pesado.
"""
import bpy, math, json, hashlib, statistics, sys
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion, Euler

RAIZ=Path(__file__).resolve().parents[3]
FONTES=RAIZ/'arte/fontes/inimigos/goblin_machado_3d'
DESTINO=RAIZ/'assets/inimigos/goblin_machado_3d'
MIXAMO=RAIZ/'arte/fontes/personagens/base_3d/mixamo'
WALK=RAIZ/'arte/pacotes/quaternius_ual/Animation Library[Standard]/Godot/AnimationLibrary_Godot_Standard.glb'
FPS=60
bpy.ops.wm.open_mainfile(filepath=str(FONTES/'goblin_machado.blend'))
sc=bpy.context.scene
malhas=[o for o in sc.objects if o.type=='MESH']

def inclinar(p):
    x,y,z=p;z-=.749
    return Vector((math.cos(.178)*x+math.sin(.178)*z,y,.749-math.sin(.178)*x+math.cos(.178)*z))

ossos={
 'Hips':((0,.02,.60),(0,.02,.72),None),
 'Spine':((0,.02,.72),(0,.02,.86),'Hips'),
 'Spine1':((0,.02,.86),(0,.02,1.02),'Spine'),
 'Spine2':((0,.02,1.02),(0,.02,1.16),'Spine1'),
 'Neck':((0,.02,1.16),(0,0,1.25),'Spine2'),
 'Head':((0,0,1.25),(0,0,1.53),'Neck')}
for lado,s in [('Right',-1),('Left',1)]:
    ombro=(s*.335,0,1.135);cot=(s*.445,-.09,.908-s*.035)
    pulso=(s*.255,-.315,.765-s*.045)
    ossos.update({lado+'Shoulder':((s*.10,.01,1.13),ombro,'Spine2'),
      lado+'Arm':(ombro,cot,lado+'Shoulder'),lado+'ForeArm':(cot,pulso,lado+'Arm'),
      lado+'Hand':(pulso,tuple(inclinar((s*.254,-.36,.749))),'Machado'),
      lado+'UpLeg':((s*.161,.015,.59),(s*.248,-.025,.33),'Hips'),
      lado+'Leg':((s*.248,-.025,.33),(s*.277,.012,.12),lado+'UpLeg'),
      lado+'Foot':((s*.277,.012,.12),(s*.277,-.20,.075),lado+'Leg'),
      lado+'ToeBase':((s*.277,-.20,.075),(s*.277,-.27,.045),lado+'Foot')})
ossos['Machado']=((0,-.36,.749),tuple(inclinar((.30,-.36,.749))),'Spine2')
bpy.ops.object.select_all(action='DESELECT');bpy.ops.object.armature_add()
rig=bpy.context.object;rig.name='GoblinMachado_Rig';rig.show_in_front=True
bpy.ops.object.mode_set(mode='EDIT');rig.data.edit_bones.remove(rig.data.edit_bones[0])
for n,(a,b,pai) in ossos.items():
    eb=rig.data.edit_bones.new(n);eb.head=a;eb.tail=b
for n,(_,_,pai) in ossos.items():
    if pai:rig.data.edit_bones[n].parent=rig.data.edit_bones[pai]
bpy.ops.object.mode_set(mode='OBJECT')
REST={b.name:b.matrix_local.copy() for b in rig.data.bones}
QREST={n:m.to_quaternion() for n,m in REST.items()}
IDENT=Quaternion((1,0,0,0))

def dist(p,a,b):
    a=Vector(a);d=Vector(b)-a;t=max(0,min(1,(p-a).dot(d)/d.length_squared))
    return (p-a-d*t).length

def mistura_dist(p,nomes):
    w={n:1/max(.015,dist(p,*ossos[n][:2]))**4 for n in nomes}
    total=sum(w.values());return {n:v/total for n,v in w.items()}

def tronco(p):
    alturas={'Hips':.63,'Spine':.77,'Spine1':.92,'Spine2':1.105,'Neck':1.235}
    nomes=sorted(alturas,key=lambda n:abs(p.z-alturas[n]))[:2]
    w={n:1/(abs(p.z-alturas[n])+.035)**3 for n in nomes};t=sum(w.values())
    return {n:v/t for n,v in w.items()}

def componentes(o):
    pai=list(range(len(o.data.vertices)))
    def raiz(i):
        while pai[i]!=i:pai[i]=pai[pai[i]];i=pai[i]
        return i
    for e in o.data.edges:
        a,b=[raiz(i) for i in e.vertices]
        if a!=b:pai[b]=a
    grupos={}
    for v in o.data.vertices:grupos.setdefault(raiz(v.index),[]).append(v.index)
    centros={}
    for ids in grupos.values():
        c=sum((o.data.vertices[i].co for i in ids),Vector())/len(ids)
        for i in ids:centros[i]=c
    return centros

for o in malhas:
    mw=o.matrix_world.copy()
    for v in o.data.vertices:v.co=mw@v.co
    o.matrix_world=Matrix.Identity(4)
    centros=componentes(o)
    grupos={n:o.vertex_groups.new(name=n) for n in ossos}
    for v in o.data.vertices:
        p=v.co;c=centros[v.index];lado='Right' if p.x<0 else 'Left';n=o.name
        if n.startswith('Machado_'):w={'Machado':1}
        elif n.startswith('Mao_D_'):w={'RightHand':1}
        elif n.startswith('Mao_E_'):w={'LeftHand':1}
        elif any(x in n for x in ['Pele_rosto','Pele_relevo','Concha_orelha','Cavidades','Cabelo','Mechas','Marfim','Olho','Iris','Pupila']):w={'Head':1}
        elif 'Pele_oliva' in n:
            f=max(0,min(1,(abs(p.x)-.265)/.085))
            if p.y<-.17 and p.z<.99:f=max(f,min(1,(-p.y-.17)/.07))
            if f>.001:
                w={k:val*f for k,val in mistura_dist(p,[lado+'Arm',lado+'ForeArm']).items()}
                for k,val in tronco(p).items():w[k]=w.get(k,0)+val*(1-f)
            else:w=tronco(p)
        elif c.z<.285 and abs(c.x)>.15:w={lado+'Foot':1}
        elif 'Calca_' in n:
            if p.z>.51 and abs(p.x)<.23:w={'Hips':1}
            else:w=mistura_dist(p,[lado+'UpLeg',lado+'Leg'])
        elif c.z<.46 and abs(c.x)>.17:w={lado+'UpLeg':1}
        elif c.z<.71:w={'Hips':1}
        elif c.z>1.12 and c.x>.25 and ('Ferro' in n or 'Aco' in n or 'Fio' in n):w={'LeftArm':1}
        elif abs(c.x)>.28 and c.y<-.10 and .70<c.z<1.0:w={lado+'ForeArm':1}
        else:w=tronco(p)
        w=dict(sorted(w.items(),key=lambda a:a[1],reverse=True)[:4]);total=sum(w.values())
        for nome,peso in w.items():
            if peso>.00001:grupos[nome].add([v.index],peso/total,'REPLACE')
    mod=o.modifiers.new('Rig_goblin','ARMATURE');mod.object=rig
    o.parent=rig;o.hide_set(True)

def fonte_nome(r,n,walk=False):
    if not walk:return next(b.name for b in r.data.bones if b.name.split(':')[-1]==n)
    mapa={'Hips':'DEF-hips','Spine':'DEF-spine.001','Spine1':'DEF-spine.002','Spine2':'DEF-spine.003','Neck':'DEF-neck','Head':'DEF-head'}
    if n in mapa:return mapa[n]
    lado='L' if n.startswith('Left') else 'R'
    for fim,base in [('Shoulder','shoulder'),('ForeArm','forearm'),('Arm','upper_arm'),('Hand','hand'),('UpLeg','thigh'),('Leg','shin'),('Foot','foot'),('ToeBase','toe')]:
        if n.endswith(fim):return 'DEF-'+base+'.'+lado
    raise ValueError(n)

def carregar(arquivo,walk=False):
    sc.render.fps=30;antes=set(bpy.data.objects)
    if walk:bpy.ops.import_scene.gltf(filepath=str(arquivo))
    else:bpy.ops.import_scene.fbx(filepath=str(arquivo))
    novos=set(bpy.data.objects)-antes
    src=next(o for o in novos if o.type=='ARMATURE')
    if walk:
        ac=next(a for a in bpy.data.actions if a.name.split('|')[-1]=='Walk_Loop' or a.name=='Walk_Loop')
        for track in src.animation_data.nla_tracks:track.mute=True
        src.animation_data.action=ac
    ac=src.animation_data.action;ini,fim=ac.frame_range
    mapa={n:fonte_nome(src,n,walk) for n in ossos if n!='Machado'}
    rep={n:(src.matrix_world@src.data.bones[b].matrix_local).to_quaternion() for n,b in mapa.items()}
    amostras=[]
    for i in range(math.ceil(fim-ini)+1):
        f=ini+(fim-ini)*i/max(1,math.ceil(fim-ini))
        sc.frame_set(int(f),subframe=f-int(f))
        amostras.append({n:src.matrix_world@src.pose.bones[b].matrix for n,b in mapa.items()})
    for o in novos:bpy.data.objects.remove(o,do_unlink=True)
    return amostras,rep,(fim-ini)/30

def amostrar(lista,t):
    f=max(0,min(len(lista)-1,t*(len(lista)-1)));a=int(f);b=min(len(lista)-1,a+1);u=f-a
    return {n:lista[a][n].lerp(lista[b][n],u) for n in lista[a]}

def suave(x):return max(0,min(1,x))**2*(3-2*max(0,min(1,x)))
def curva(chaves,u):
    for i in range(len(chaves)-1):
        ta,a=chaves[i];tb,b=chaves[i+1]
        if u<=tb:return Vector(a).lerp(Vector(b),suave((u-ta)/(tb-ta)))
    return Vector(chaves[-1][1])

def matriz(q,p):
    m=q.to_matrix().to_4x4();m.translation=p;return m

def resolver_membro(lado,superior,inferior,alvo,polo):
    a=rig.pose.bones[lado+superior].head.copy()
    l1=rig.data.bones[lado+superior].length;l2=rig.data.bones[lado+inferior].length
    d=alvo-a;compr=d.length;direcao=d.normalized()
    alcance=max(0,compr-l1-l2)
    v=polo-a;v-=direcao*v.dot(direcao)
    if v.length<.001:v=Vector((0,-1,0))
    v.normalize();h=(l1*l1-l2*l2+compr*compr)/(2*max(.001,compr));h=max(-l1,min(l1,h))
    cot=a+direcao*h+v*math.sqrt(max(0,l1*l1-h*h))
    for nome,p0,p1 in [(lado+superior,a,cot),(lado+inferior,cot,alvo)]:
        rest=Vector(ossos[nome][1])-Vector(ossos[nome][0])
        q=rest.rotation_difference(p1-p0)@QREST[nome]
        rig.pose.bones[nome].matrix=matriz(q,p0)
        bpy.context.view_layer.update()
    return alcance

clips={
 'parado':(MIXAMO/'Idle.fbx',4.0,True),
 'andar':(WALK,4/3,True),
 'correr':(MIXAMO/'Standard Run.fbx',22/30,True),
 'ataque_1':(MIXAMO/'Great Sword Slash.fbx',1.27,False),
 'ataque_2':(MIXAMO/'Great Sword Slash.fbx',1.4,False),
 'ferido':(MIXAMO/'Hit Reaction.fbx',1.2,False),
 'morrer':(MIXAMO/'Dying.fbx',3.0,False)}
if '--estudo' in sys.argv:clips={k:clips[k] for k in ['parado','ataque_2']}
rig.animation_data_create();rel=[]
weapon_rest=REST['Machado'];weapon_inv=weapon_rest.inverted()
PEGADAS={}
for lado,sinal in [('Right',-1),('Left',1)]:
    ajustada=REST[lado+'Hand'].copy()
    ajustada.translation+=inclinar((sinal*.115,-.36,.749))-inclinar((sinal*.254,-.36,.749))
    PEGADAS[lado]=ajustada
vertices_arma=[v.co.copy() for o in malhas if o.name.startswith('Machado_') for v in o.data.vertices]
for nome,(arquivo,duracao,loop) in clips.items():
    dados,rep,duracao_fonte=carregar(arquivo,nome=='andar')
    primeiro={n:m.to_quaternion() for n,m in dados[0].items()}
    root0=dados[0]['Hips'].translation
    hipmedio=statistics.median(m['Hips'].translation.z for m in dados)
    escala=.49/max(.1,(dados[0]['Hips'].translation-dados[0]['LeftFoot'].translation).length)
    base_y={l:statistics.mean(m[l+'Foot'].translation.y-(m['Hips'].translation.y-root0.y) for m in dados) for l in ['Right','Left']}
    piso_src={l:min(m[l+'Foot'].translation.z for m in dados) for l in ['Right','Left']}
    ac=bpy.data.actions.new(nome);rig.animation_data.action=ac
    for tr in rig.animation_data.nla_tracks:tr.mute=True
    N=round(duracao*FPS);maior_erro=0;maior_alcance=0;passadas=[];anteriores={}
    for q in range(N+1):
        u=q/N
        if loop and q==N:u=0
        t=u
        impacto=.49 if nome=='ataque_1' else .54
        if nome.startswith('ataque'):
            contato=.49
            t=(u/impacto*contato) if u<impacto else contato+(u-impacto)/(1-impacto)*(1-contato)
        src=amostrar(dados,t)
        for pb in rig.pose.bones:
            pb.rotation_mode='QUATERNION';pb.location=(0,0,0);pb.rotation_quaternion=IDENT;pb.scale=(1,1,1)
        loc=nome in ['andar','correr']
        rotacoes={}
        for n in ossos:
            if n=='Machado' or any(n.endswith(x) for x in ['Arm','ForeArm','Hand','Shoulder']):continue
            d=src[n].to_quaternion()@(rep[n] if loc else primeiro[n]).inverted()
            fator=1.0
            if not loc and nome!='morrer':fator=.65 if n not in ['Head','Neck'] else .25
            if nome.startswith('ataque'):fator=1.0*(1-suave((u-.88)/.12))
            if nome=='ferido':fator*=1-suave((u-.85)/.15)
            rotacoes[n]=IDENT.slerp(d,fator)@QREST[n]
        for n in ossos:
            if n not in rotacoes:continue
            pai=ossos[n][2];qp=rotacoes.get(pai,QREST.get(pai,IDENT))
            local=(QREST.get(pai,IDENT).inverted()@QREST[n]).inverted()@qp.inverted()@rotacoes[n]
            rig.pose.bones[n].rotation_quaternion=local
        dz=(src['Hips'].translation.z-(hipmedio if loc else root0.z))*escala
        if loc:dz-=.055 if nome=='andar' else .085
        if nome.startswith('ataque'):dz-=.045*math.sin(math.pi*u)**2
        desloc=Vector((0,0,dz))
        if nome.startswith('ataque'):
            desloc.x=(src['Hips'].translation.x-root0.x)*.35
            desloc.y=(src['Hips'].translation.y-root0.y)*.40
        if nome=='morrer':desloc=(src['Hips'].translation-root0)*escala
        rig.pose.bones['Hips'].location=QREST['Hips'].inverted()@desloc
        bpy.context.view_layer.update()
        # Pés plantados para apoio/combate; locomoção usa a trajetória real da fonte.
        if nome!='morrer':
            for lado,s in [('Right',-1),('Left',1)]:
                alvo=Vector(ossos[lado+'Foot'][0]);fq=QREST[lado+'Foot']
                lift=0
                if loc or nome.startswith('ataque'):
                    f=src[lado+'Foot'].translation
                    if loc:
                        alvo.y+=(f.y-(src['Hips'].translation.y-root0.y)-base_y[lado])*escala
                    else:
                        peso=suave(u/.10)*(1-suave((u-.88)/.12))
                        desloc_pe=(f-dados[0][lado+'Foot'].translation)*escala*peso
                        alvo.x+=desloc_pe.x;alvo.y+=desloc_pe.y
                    lift=max(0,(f.z-piso_src[lado])*escala)
                    base_pe=rep[lado+'Foot'] if loc else primeiro[lado+'Foot']
                    delta_pe=src[lado+'Foot'].to_quaternion()@base_pe.inverted()
                    if not loc:delta_pe=IDENT.slerp(delta_pe,peso)
                    fq=delta_pe@QREST[lado+'Foot']
                    rd=fq@QREST[lado+'Foot'].inverted()
                    cantos=[Vector((s*.277+x,y,0))-Vector(ossos[lado+'Foot'][0]) for x in [-.115,.115] for y in [-.27,.09]]
                    alvo.z=-min((rd@p).z for p in cantos)+lift
                    if loc:passadas.append((q,lado,alvo.y,lift))
                resolver_membro(lado,'UpLeg','Leg',alvo,Vector((s*.30,-.38,.30))+desloc)
                rig.pose.bones[lado+'Foot'].matrix=matriz(fq,alvo)
            bpy.context.view_layer.update()
        peito=rig.pose.bones['Spine2'].matrix@REST['Spine2'].inverted()
        centro=Vector((0,-.36,.749));rot=Vector((0,0,0))
        if loc:
            centro.z+=.025+.012*math.sin(u*math.tau*2)
            rot.z=.035*math.sin(u*math.tau)
        wm=peito@Matrix.Translation(centro)@Euler(rot,'XYZ').to_matrix().to_4x4()@weapon_rest.to_3x3().to_4x4()
        if nome.startswith('ataque'):
            # Translação e rotação vêm da mão real do clipe de arma de duas mãos.
            # A arma inteira determina as duas pegadas; o IK acomoda a anatomia.
            eixo=Vector((-math.cos(.178),0,math.sin(.178)))
            normal=Vector((0,1,0))
            base_arma=Matrix((eixo,normal,eixo.cross(normal))).transposed()
            base_mao=Matrix(((1,0,0),(0,0,1),(0,-1,0))).transposed()
            calibracao=(base_mao@base_arma.inverted()).to_quaternion()
            qfonte=src['RightHand'].to_quaternion()@calibracao
            inicio=(dados[0]['RightHand'].translation+dados[0]['LeftHand'].translation)*.5-root0
            atual=(src['RightHand'].translation+src['LeftHand'].translation)*.5-src['Hips'].translation
            desloc_mao=atual-inicio
            desloc_mao.x*=.68;desloc_mao.y*=.68;desloc_mao.z*=1.05
            entrada=suave(u/.10);saida=1-suave((u-.88)/.12);peso=entrada*saida
            pos=Vector((0,-.36,.749))+desloc_mao*peso
            pos.y-=.03*math.sin(math.pi*u)**2
            qr=IDENT.slerp(qfonte,peso)@QREST['Machado']
            wm=matriz(qr,pos)
        # Limitar centro da arma para que ambos os braços alcancem o cabo sem esticar.
        for tentativa in range(30):
            deform=wm@weapon_inv;erro=0
            for lado in ['Right','Left']:
                S=rig.pose.bones[lado+'Arm'].head.copy();W=deform@PEGADAS[lado].translation
                alcance=rig.data.bones[lado+'Arm'].length+rig.data.bones[lado+'ForeArm'].length-.003
                excesso=max(0,(W-S).length-alcance);erro=max(erro,excesso)
                if excesso>0:wm.translation+=(S-W).normalized()*excesso*.8
            deform=wm@weapon_inv
            piso=min((deform@p).z for p in vertices_arma[::8])
            if piso<.015:wm.translation.z+=.015-piso
            if erro<.0002 and piso>=.0149:break
        deform=wm@weapon_inv
        rig.pose.bones['Machado'].matrix=wm
        for lado,s in [('Right',-1),('Left',1)]:
            hm=deform@PEGADAS[lado];polo=peito@Vector((s*.58,-.025,.90))
            maior_alcance=max(maior_alcance,resolver_membro(lado,'Arm','ForeArm',hm.translation,polo))
            rig.pose.bones[lado+'Hand'].matrix=hm
        bpy.context.view_layer.update()
        for lado in ['Right','Left']:
            erro=(rig.pose.bones[lado+'Hand'].matrix.translation-(deform@PEGADAS[lado]).translation).length
            maior_erro=max(maior_erro,erro)
        for pb in rig.pose.bones:
            quat=pb.rotation_quaternion
            if pb.name in anteriores and anteriores[pb.name].dot(quat)<0:quat.negate()
            anteriores[pb.name]=quat.copy()
            pb.keyframe_insert('rotation_quaternion',frame=q+1);pb.keyframe_insert('location',frame=q+1)
    assert maior_alcance<.002,(nome,'braço sem alcance',maior_alcance)
    assert maior_erro<.001,(nome,'mão solta',maior_erro)
    for fc in ac.fcurves if hasattr(ac,'fcurves') else []:
        for k in fc.keyframe_points:k.interpolation='LINEAR'
    ac.use_fake_user=True;rig.animation_data.action=None
    tr=rig.animation_data.nla_tracks.new();tr.name=nome;strip=tr.strips.new(nome,1,ac);tr.mute=True
    velocidades=[]
    for lado in ['Right','Left']:
        pontos=[p for p in passadas if p[1]==lado]
        for a,b in zip(pontos,pontos[1:]):
            vel=(b[2]-a[2])*FPS
            if a[3]<.025 and b[3]<.025 and vel>.03:velocidades.append(vel)
    velocidade=statistics.median(velocidades) if velocidades else 0
    rel.append({'id':nome,'arquivo':str(arquivo.relative_to(RAIZ)),'sha256':hashlib.sha256(arquivo.read_bytes()).hexdigest(),
      'duracao':duracao,'fps':FPS,'quadros':N+1,'loop':loop,'pegada_erro_m':maior_erro,'alcance_excedido_m':maior_alcance,
      'velocidade_m_s':velocidade,'impacto_s':duracao*(.49 if nome=='ataque_1' else .54) if nome.startswith('ataque') else None})
    print('CLIPE_EXPORTAVEL',nome,N+1,'pegada',maior_erro,'alcance',maior_alcance,flush=True)

for pb in rig.pose.bones:pb.location=(0,0,0);pb.rotation_quaternion=IDENT
for tr in rig.animation_data.nla_tracks:tr.mute=False
sc.render.fps=FPS;sc.frame_set(1)
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
for o in malhas:o.hide_set(False);o.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(DESTINO/'goblin_machado_animado.glb'),export_format='GLB',use_selection=True,
  export_animations=True,export_animation_mode='NLA_TRACKS',export_skins=True,export_def_bones=True,export_cameras=False,export_lights=False)
for tr in rig.animation_data.nla_tracks:tr.mute=True
bpy.ops.wm.save_as_mainfile(filepath=str(FONTES/'goblin_machado_animado.blend'))
(FONTES/'animacoes.json').write_text(json.dumps({'rig':len(ossos),'clipes':rel,'pegada':'Mãos filhas do osso Machado para manter pegada também na interpolação; braços com cinemática inversa assada a 60 fps','integracao':'cena visual; sem IA ou danos'},ensure_ascii=False,indent=2)+'\n')
print('GOBLIN_MACHADO_ANIMADO_OK',flush=True)
