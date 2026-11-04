"""Ajuste suave do giro do punho mantendo cabo, dedos e pulso unidos."""
import math
from mathutils import Quaternion,Vector
from mathutils.bvhtree import BVHTree
import bpy

def corrigir(rig,malhas,sc):
    lamina=next(o for o in malhas if o.name=='Lamina_curva')
    nomes={'Tronco','Quadril','Rosto_escultura','Capuz','Manto_rasgado','Prega_gola','Cone','Braco','Cotovelo','Antebraco','Pe'}
    corpo=[o for o in malhas if o.name.split('.')[0] in nomes]
    estados=[(math.radians(r),math.radians(p)) for r in range(-120,121,30) for p in range(-60,61,30)]
    for t in rig.animation_data.nla_tracks:t.mute=True
    for track in rig.animation_data.nla_tracks:
        act=track.strips[0].action;rig.animation_data.action=act
        frames=range(int(act.frame_range[0]),int(act.frame_range[1])+1)
        bases=[];permitidos=[]
        for f in frames:
            sc.frame_set(f)
            bpy.context.view_layer.update()
            pb=rig.pose.bones['RightHand'];base=pb.rotation_quaternion.copy();bases.append(base)
            deps=bpy.context.evaluated_depsgraph_get()
            arvores=[BVHTree.FromObject(o,deps,epsilon=.006) for o in corpo]
            livres=[]
            for i,(a,pitch) in enumerate(estados):
                pb.rotation_quaternion=base@Quaternion((1,0,0),pitch)@Quaternion((0,1,0),a)
                bpy.context.view_layer.update()
                faca=BVHTree.FromObject(lamina,bpy.context.evaluated_depsgraph_get(),epsilon=.006)
                if not any(faca.overlap(b) for b in arvores):livres.append(i)
            if not livres:raise RuntimeError(f'Sem giro de punho livre: {track.name} quadro {f}')
            permitidos.append(livres)
            pb.rotation_quaternion=base
        # Caminho de menor giro com penalidade à velocidade: antecipar e recuperar
        # a correção gradualmente, em vez de mudar a pegada só no quadro do contato.
        custos={i:sum(a*a for a in estados[i]) for i in permitidos[0]};anteriores=[]
        for livres in permitidos[1:]:
            prox={};pais={}
            for i in livres:
                candidatos=[(c+12*sum((a-b)**2 for a,b in zip(estados[i],estados[j]))+.03*sum(a*a for a in estados[i]),j) for j,c in custos.items() if max(abs(a-b) for a,b in zip(estados[i],estados[j]))<=math.radians(30.1)]
                if candidatos:prox[i],pais[i]=min(candidatos)
            if not prox:raise RuntimeError(f'Sem percurso suave: {track.name}')
            anteriores.append(pais);custos=prox
        ultimo=min(custos,key=lambda i:custos[i]+sum(a*a for a in estados[i]))
        caminho=[ultimo]
        for pais in reversed(anteriores):ultimo=pais[ultimo];caminho.append(ultimo)
        caminho.reverse()
        for f,base,i in zip(frames,bases,caminho):
            sc.frame_set(f)
            pb=rig.pose.bones['RightHand'];pb.rotation_quaternion=base@Quaternion((1,0,0),estados[i][1])@Quaternion((0,1,0),estados[i][0])
            pb.keyframe_insert('rotation_quaternion',frame=f)
        print('PUNHO_AJUSTADO',track.name,'graus',min(tuple(round(math.degrees(a)) for a in estados[i]) for i in caminho),max(tuple(round(math.degrees(a)) for a in estados[i]) for i in caminho),flush=True)
    rig.animation_data.action=None
