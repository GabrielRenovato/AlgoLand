"""Confere interseção geométrica da lâmina com corpo/roupa em cada quadro exportado."""
import bpy,json,hashlib
from pathlib import Path
from mathutils.bvhtree import BVHTree
RAIZ=Path(__file__).resolve().parents[3]
bpy.ops.wm.open_mainfile(filepath=str(RAIZ/'arte/fontes/inimigos/goblin_capuz_3d/goblin_capuz_animado.blend'))
rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
lamina=next(o for o in bpy.context.scene.objects if o.name=='Lamina_curva')
nomes=['Tronco','Quadril','Rosto_escultura','Capuz','Manto_rasgado','Prega_gola','Cone','Braco','Cotovelo','Antebraco','Mao','Pe']
corpo=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.name.split('.')[0] in nomes]
for t in rig.animation_data.nla_tracks:t.mute=True
clips=[(t.name,t.strips[0].action) for t in rig.animation_data.nla_tracks]
resultado=[]
for nome,acao in clips:
    rig.animation_data.action=acao
    colisoes=[]
    for f in range(int(acao.frame_range[0]),int(acao.frame_range[1])+1):
        bpy.context.scene.frame_set(f)
        deps=bpy.context.evaluated_depsgraph_get()
        arvore=BVHTree.FromObject(lamina,deps)
        for o in corpo:
            pares=arvore.overlap(BVHTree.FromObject(o,deps))
            if pares:colisoes.append({'quadro':f,'objeto':o.name,'faces':len(pares)})
    resultado.append({'clipe':nome,'quadros':int(acao.frame_range[1]-acao.frame_range[0]+1),'intersecoes':colisoes})
    print('INTERSECOES_FACA',nome,len(colisoes),colisoes[:8],flush=True)
saida=RAIZ/'arte/previas/inimigos/goblin_capuz_3d/mixamo/intersecoes_faca.json'
saida.write_text(json.dumps({'modelo_sha256':hashlib.sha256((RAIZ/'assets/inimigos/goblin_capuz_3d/goblin_capuz_animado.glb').read_bytes()).hexdigest(),'clipes':resultado},ensure_ascii=False,indent=2))
(RAIZ/'ferramentas/inimigos/goblin_capuz_3d/validacao_faca.json').write_text(saida.read_text())
assert not any(c['intersecoes'] for c in resultado), 'Lâmina atravessa o corpo'
print('QUADROS',sum(c['quadros'] for c in resultado),'INTERSECOES',sum(len(c['intersecoes']) for c in resultado),flush=True)
