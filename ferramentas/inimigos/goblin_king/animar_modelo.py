"""Anima o rig próprio sem alterar a pintura ou a geometria canônica.

Executar após gerar_modelo.py, com Blender 4.5 em background. Braços e pernas
usam IK analítica; a espada tem osso independente para passar do apoio no
pomo à pegada de combate. O giro pivota sobre o pé direito, sem root motion
na cena consumidora. Os eventos são frações do clipe importado no Godot.
"""
import bpy
import math
import json
from pathlib import Path
from mathutils import Vector, Quaternion, Matrix, Euler

RAIZ=Path(__file__).resolve().parents[3]
FONTES=RAIZ/'arte/fontes/inimigos/goblin_king'
DESTINO=RAIZ/'assets/inimigos/goblin_king'
FPS=30
bpy.ops.wm.open_mainfile(filepath=str(FONTES/'goblin_king.blend'))
rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
assert 'espada' in rig.data.bones, 'Regenerar a base com o osso independente da espada.'
scene=bpy.context.scene
scene.render.fps=FPS
REST={b.name:b.matrix_local.copy() for b in rig.data.bones}
IDENTIDADE=Quaternion((1,0,0,0))
FRENTE=Vector((0,-1,0))
MAO_D=Vector((-.83,-.36,1.91))
MAO_E=Vector((.57,-.32,1.33))
PIVO=Vector((-.36,-.005,0))
ESPADA_REST=Vector((-.83,-.34,1.85))
PONTA_REST=Vector((-.83,-.34,.035))
ANTERIORES={}


def pose(t, mao=MAO_D, lamina=(0,0,-1), esquerda=MAO_E,
         giro=0, tronco=0, inclinar=0, abaixar=0, pegar=0,
         duas_maos=0, curva='suave', braco_livre=0):
    return dict(t=t,mao=Vector(mao),lamina=Vector(lamina).normalized(),
        esquerda=Vector(esquerda),giro=giro,tronco=tronco,inclinar=inclinar,
        abaixar=abaixar,pegar=pegar,duas_maos=duas_maos,curva=curva,
        braco_livre=braco_livre)


BASE=pose(0)
CORTE_PRE=pose(0,(-.79,-.20,2.26),(-.85,.12,.51),tronco=-.34,
               inclinar=-.04,abaixar=.035,pegar=1,curva='acelerar')
CORTE_HIT=pose(0,(-.39,-.63,1.99),(.75,-.64,-.16),tronco=.28,
               inclinar=.07,abaixar=.045,pegar=1,curva='frear')
CORTE_FIM=pose(0,(-.08,-.47,1.85),(.96,-.23,-.16),tronco=.53,
               inclinar=.06,abaixar=.035,pegar=1)
VOLTA_PRE=pose(0,(-.10,-.48,2.14),(.96,-.08,.27),tronco=.42,
               abaixar=.035,pegar=1,curva='acelerar')
VOLTA_HIT=pose(0,(-.55,-.55,1.96),(-.82,-.55,-.16),tronco=-.20,
               inclinar=.06,abaixar=.045,pegar=1,curva='frear')
VOLTA_FIM=pose(0,(-.81,-.24,1.80),(-.96,-.05,-.27),tronco=-.46,
               inclinar=.035,abaixar=.035,pegar=1)
ALTO=pose(0,(-.13,-.12,2.66),(-.20,.16,.97),tronco=-.12,
          inclinar=-.09,abaixar=.025,pegar=1,duas_maos=1,curva='acelerar')
CHAO=pose(0,(-.05,-.48,1.65),(0,-.40,-.9165),tronco=.13,
          inclinar=.20,abaixar=.12,pegar=1,duas_maos=1,curva='frear')
AMORTECER=pose(0,(-.03,-.48,1.65),(0,-.40,-.9165),tronco=.18,
              inclinar=.23,abaixar=.13,pegar=1,duas_maos=1)


def montar(*chaves):
    return [dict(p,t=t) for t,p in chaves]


CLIPES={
 'corte_direita':montar((0,BASE),(.25,CORTE_PRE),(.39,CORTE_HIT),(.52,CORTE_FIM),(.94,BASE)),
 'corte_esquerda':montar((0,BASE),(.25,VOLTA_PRE),(.39,VOLTA_HIT),(.52,VOLTA_FIM),(.94,BASE)),
 'golpe_pesado':montar((0,BASE),(.48,ALTO),(.70,CHAO),(.83,AMORTECER),(1.43,BASE)),
 'combo_triplo':montar((0,BASE),(.22,CORTE_PRE),(.35,CORTE_HIT),(.48,CORTE_FIM),
     (.64,VOLTA_PRE),(.77,VOLTA_HIT),(.90,VOLTA_FIM),(1.26,ALTO),
     (1.48,CHAO),(1.62,AMORTECER),(2.18,BASE)),
 'impacto_area':montar((0,BASE),(.62,ALTO),(.85,dict(ALTO,inclinar=-.13)),
     (1.04,CHAO),(1.22,AMORTECER),(1.95,BASE)),
 'giro_area':montar((0,BASE),(.40,pose(0,(-.86,-.08,1.96),(-.98,-.15,.05),
      esquerda=(.70,.05,1.81),tronco=-.35,pegar=1,abaixar=.06,curva='acelerar')),
     (.56,pose(0,(-.90,-.07,1.96),(-.99,-.12,.025),esquerda=(.70,.05,1.81),
      pegar=1,abaixar=.065,curva='linear')),
     (1.36,pose(0,(-.90,-.07,1.96),(-.99,-.12,.025),esquerda=(.70,.05,1.81),
      giro=math.tau,tronco=.16,pegar=1,abaixar=.065,curva='frear')),
     (1.59,pose(0,(-.73,-.17,1.84),(-.85,-.35,-.38),giro=math.tau,
      tronco=.28,pegar=1,abaixar=.04)),(2.03,dict(BASE,giro=math.tau)))
}
EVENTOS={
 'corte_direita':[dict(t=.39,tipo='corte',indice=1,raio=65)],
 'corte_esquerda':[dict(t=.39,tipo='corte',indice=1,raio=65)],
 'golpe_pesado':[dict(t=.70,tipo='pesado',indice=1,raio=75)],
 'combo_triplo':[dict(t=.35,tipo='corte',indice=1,raio=65),
                 dict(t=.77,tipo='corte',indice=2,raio=65),
                 dict(t=1.48,tipo='pesado',indice=3,raio=80)],
 'giro_area':[dict(t=.68,tipo='area_giro',indice=1,raio=90),
              dict(t=.94,tipo='area_giro',indice=2,raio=90),
              dict(t=1.21,tipo='area_giro',indice=3,raio=90)],
 'impacto_area':[dict(t=1.04,tipo='area_chao',indice=1,raio=110)]
}


def atualizar(): bpy.context.view_layer.update()


def pai_delta(nome):
    pai=rig.pose.bones[nome].parent
    return pai.matrix@REST[pai.name].inverted() if pai else Matrix.Identity(4)


def colocar(nome, rot, deslocamento=Vector()):
    m=pai_delta(nome)@REST[nome]
    p=m.translation.copy()+deslocamento
    m=Matrix.Translation(p)@rot.to_matrix().to_4x4()@m.to_3x3().to_4x4()
    rig.pose.bones[nome].matrix=m
    atualizar()


def apontar(nome, inicio, fim):
    direcao=(fim-inicio).normalized()
    q=(REST[nome].to_3x3()@Vector((0,1,0))).rotation_difference(direcao)
    rig.pose.bones[nome].matrix=Matrix.LocRotScale(inicio,
        q@REST[nome].to_quaternion(),Vector((1,1,1)))
    atualizar()


def ik(superior,inferior,destino,polo):
    origem=pai_delta(superior)@rig.data.bones[superior].head_local
    vetor=destino-origem
    u=rig.data.bones[superior].length
    v=rig.data.bones[inferior].length
    distancia=max(abs(u-v)+.001,min(vetor.length,u+v-.001))
    eixo=vetor.normalized()
    destino=origem+eixo*distancia
    x=(u*u-v*v+distancia*distancia)/(2*distancia)
    altura=math.sqrt(max(0,u*u-x*x))
    fora=polo-origem
    fora=(fora-eixo*fora.dot(eixo)).normalized()
    meio=origem+eixo*x+fora*altura
    apontar(superior,origem,meio)
    apontar(inferior,meio,destino)
    return destino


def interp(a,b,t):
    if a['curva']=='acelerar': t=t*t*t
    elif a['curva']=='frear': t=1-(1-t)**3
    elif a['curva']=='suave': t=t*t*(3-2*t)
    p={}
    for k in a:
        if k in ['curva','t']: continue
        if isinstance(a[k],Vector):
            p[k]=a[k].slerp(b[k],t) if k=='lamina' else a[k].lerp(b[k],t)
        else: p[k]=a[k]+(b[k]-a[k])*t
    return p


def amostrar(chaves,t):
    for a,b in zip(chaves,chaves[1:]):
        if t<=b['t']+1e-6:
            return interp(a,b,max(0,min(1,(t-a['t'])/(b['t']-a['t']))))
    return interp(chaves[-1],chaves[-1],0)


def aplicar_pose(p):
    for b in rig.pose.bones:
        b.rotation_mode='QUATERNION'
        b.matrix_basis=Matrix.Identity(4)
    atualizar()
    rz=Matrix.Rotation(p['giro'],4,'Z')
    raiz=Matrix.Translation(PIVO)@rz@Matrix.Translation(-PIVO)
    rig.pose.bones['raiz'].matrix=raiz@REST['raiz']
    atualizar()
    colocar('quadril',Euler((p['inclinar']*.25,0,p['tronco']*.28)).to_quaternion(),
            Vector((0,0,-p['abaixar'])))
    colocar('peito',Euler((p['inclinar'],0,p['tronco'])).to_quaternion())
    colocar('cabeca',Euler((-p['inclinar']*.40,0,-p['tronco']*.35)).to_quaternion())
    # Os tornozelos compensam o agachamento. No giro, o direito é o pivô fixo.
    for lado,sinal in [('D',-1),('E',1)]:
        tornozelo=raiz@rig.data.bones['pe_'+lado].head_local
        if lado=='E': tornozelo.z+=.11*max(0,math.sin(p['giro']/2))
        polo=rig.data.bones['canela_'+lado].head_local.lerp(
            Vector((sinal*.35,-1,.65)),min(1,p['abaixar']*18))
        ik('coxa_'+lado,'canela_'+lado,tornozelo,raiz@polo)
        m=raiz@REST['pe_'+lado]
        m.translation=tornozelo
        rig.pose.bones['pe_'+lado].matrix=m
        atualizar()
    alvo=raiz@p['mao']
    polo=rig.data.bones['antebraco_D'].head_local.lerp(Vector((-1.5,.18,1.8)),p['pegar'])
    direita=ik('braco_D','antebraco_D',alvo,raiz@polo)
    q=Vector((0,0,-1)).rotation_difference(p['lamina'])
    qtotal=rz.to_quaternion()@q
    rig.pose.bones['mao_D'].matrix=Matrix.LocRotScale(direita,
        qtotal@REST['mao_D'].to_quaternion(),Vector((1,1,1)))
    atualizar()
    deslocamento=qtotal@(ESPADA_REST-MAO_D+Vector((0,0,.12*p['pegar'])))
    rig.pose.bones['espada'].matrix=Matrix.LocRotScale(direita+deslocamento,
        qtotal@REST['espada'].to_quaternion(),Vector((1,1,1)))
    atualizar()
    # A segunda mão encontra o mesmo cabo no golpe pesado, sem trocar de arma.
    pegada=direita-qtotal@Vector((0,0,-.14))
    alvo=(raiz@p['esquerda']).lerp(pegada,p['duas_maos'])
    polo=rig.data.bones['antebraco_E'].head_local.lerp(Vector((1.35,.2,1.85)),p['pegar'])
    esquerda=ik('braco_E','antebraco_E',alvo,raiz@polo)
    qe=IDENTIDADE.slerp(q,p['duas_maos'])
    rig.pose.bones['mao_E'].matrix=Matrix.LocRotScale(esquerda,
        rz.to_quaternion()@qe@REST['mao_E'].to_quaternion(),Vector((1,1,1)))
    atualizar()
    delta=rig.pose.bones['espada'].matrix@REST['espada'].inverted()
    ponta=delta@PONTA_REST
    return dict(ponta=list(ponta),mao=list(direita),
        erro_segunda_mao=(esquerda-pegada).length if p['duas_maos']>.95 else 0,
        apoio_direito=list(rig.pose.bones['pe_D'].head),
        apoio_esquerdo=list(rig.pose.bones['pe_E'].head))


def gravar(quadro):
    for b in rig.pose.bones:
        if b.name in ANTERIORES and b.rotation_quaternion.dot(ANTERIORES[b.name])<0:
            b.rotation_quaternion.negate()
        ANTERIORES[b.name]=b.rotation_quaternion.copy()
        for caminho in ['location','rotation_quaternion','scale']:
            b.keyframe_insert(data_path=caminho,frame=quadro,group=b.name)


rig.animation_data_create()
# Preserva o ciclo original; remove só faixas de combate de execuções anteriores.
for trilha in list(rig.animation_data.nla_tracks):
    if trilha.name!='parado': rig.animation_data.nla_tracks.remove(trilha)
for trilha in rig.animation_data.nla_tracks: trilha.mute=True
relatorio={}
evidencia={}
for nome,chaves in CLIPES.items():
    acao=bpy.data.actions.new(nome)
    rig.animation_data.action=acao
    quadros=round(chaves[-1]['t']*FPS)
    ANTERIORES.clear()
    trajetoria=[]
    for quadro in range(quadros+1):
        scene.frame_set(quadro)
        registro=aplicar_pose(amostrar(chaves,quadro/FPS))
        registro['t']=quadro/FPS
        trajetoria.append(registro)
        gravar(quadro)
    # Baked por quadro: interpolação linear evita overshoot de mão/espada.
    for camada in acao.layers:
        for faixa in camada.strips:
            for bag in faixa.channelbags:
                for f in bag.fcurves:
                    for k in f.keyframe_points: k.interpolation='LINEAR'
    rig.animation_data.action=None
    trilha=rig.animation_data.nla_tracks.new()
    trilha.name=nome
    trilha.strips.new(nome,0,acao)
    trilha.mute=True
    duracao=quadros/FPS
    marcas=[dict(fracao=e['t']/duracao,tipo=e['tipo'],indice=e['indice'],raio=e['raio']) for e in EVENTOS[nome]]
    relatorio[nome]=dict(duracao_s=duracao,quadros=quadros+1,fps=FPS,loop=False,eventos=marcas,
        aviso_area=nome in ['giro_area','impacto_area'],
        raio=110 if nome=='impacto_area' else (90 if nome=='giro_area' else 65))
    evidencia[nome]=trajetoria
    print('CLIPE_ANIMADO',nome,duracao,'ponta_min_z',round(min(p['ponta'][2] for p in trajetoria),3),flush=True)

for trilha in rig.animation_data.nla_tracks: trilha.mute=False
scene.frame_set(0)
aplicar_pose(amostrar(CLIPES['corte_direita'],0))
rig.animation_data.action=None
bpy.ops.object.select_all(action='DESELECT')
for o in scene.objects:
    if o.type in ['MESH','ARMATURE']: o.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(DESTINO/'goblin_king.glb'),export_format='GLB',
    use_selection=True,export_yup=True,export_animations=True,export_animation_mode='NLA_TRACKS',
    export_skins=True,export_all_influences=False,export_def_bones=True,
    export_materials='EXPORT',export_image_format='AUTO',export_cameras=False,export_lights=False)
bpy.ops.wm.save_as_mainfile(filepath=str(FONTES/'goblin_king_animado.blend'))
manifesto=json.loads((DESTINO/'manifesto.json').read_text())
manifesto['fonte']='arte/fontes/inimigos/goblin_king/goblin_king_animado.blend'
manifesto['animacoes'].update(relatorio)
manifesto['acabamento_visual']={'tipo':'filtro do HeroiBase3D, aplicado ao render original',
    'shader':'res://codigo/jogador/contorno_pixel_base_3d.gdshader',
    'amostras_por_pixel':2,'texturas_originais':True}
manifesto['limites']=[s for s in manifesto['limites'] if 'caminhada' not in s]
manifesto['limites'].append('Ataques animados com marcadores; caminhada e IA não implementadas. Dano depende do ator consumidor.')
(DESTINO/'manifesto.json').write_text(json.dumps(manifesto,ensure_ascii=False,indent=2)+'\n')
(DESTINO/'animacoes.json').write_text(json.dumps(relatorio,ensure_ascii=False,indent=2)+'\n')
(FONTES/'trajetorias_combate.json').write_text(json.dumps(evidencia,separators=(',',':'))+'\n')
print('GOBLIN_KING_COMBATE_EXPORTADO',list(relatorio),flush=True)
