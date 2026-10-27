extends RefCounted
## Somente o desenho; itens, raridade, bônus e saves continuam no cadastro comum.
const Conjuntos=preload("res://codigo/dados/conjuntos_armadura.gd")
const Aparencia=preload("res://codigo/dados/aparencia.gd")
const PECAS=["elmo","peitoral","luvas","botas"]
const RAIZES=["res://assets/personagens/conjuntos/cavalheiro/","res://assets/personagens/conjuntos/carrasco/","res://assets/personagens/conjuntos/cavaleiro_rubro/"]
const ELMOS_FECHADOS=[RAIZES[1],RAIZES[2]]
const ALTURAS_GREVAS={RAIZES[1]:.46,RAIZES[2]:.46}
var raizes_pecas: Array[String]=["","","",""]
var _recursos: Dictionary={}
var heroi: Node
var malhas: Array[MeshInstance3D]=[]
var mascara: int=-1
var _chave: int=-1
var _cabelos: Dictionary={}
var _corpo: MeshInstance3D

func _init(visual: Node):
 heroi=visual
 _corpo=heroi._modelo.find_child("CorpoBase",true,false)
 for i in 4:
  var m:=MeshInstance3D.new()
  m.name="Armadura"+PECAS[i].capitalize()
  m.skin=_corpo.skin
  m.skeleton=_corpo.skeleton
  m.transform=_corpo.transform
  _corpo.get_parent().add_child(m)
  malhas.append(m)
 ajustar_cabelo()
 atualizar()

func ajustar_cabelo():
 var origem: ArrayMesh=heroi._pecas[3].mesh
 if origem in _cabelos.values():return
 var id:=origem.get_instance_id()
 if not _cabelos.has(id):
  var t: Transform3D=_corpo.global_transform.affine_inverse()*heroi._esqueleto.global_transform*heroi._esqueleto.get_bone_global_rest(heroi._esqueleto.find_bone("DEF-head"))
  var nova:=ArrayMesh.new()
  for s in origem.get_surface_count():
   var a:=origem.surface_get_arrays(s)
   var uv2: PackedVector2Array=a[Mesh.ARRAY_TEX_UV2] if a[Mesh.ARRAY_TEX_UV2]!=null else PackedVector2Array()
   uv2.resize(a[Mesh.ARRAY_VERTEX].size())
   for i in uv2.size():
    uv2[i].y=(t.affine_inverse()*a[Mesh.ARRAY_VERTEX][i]).y
   a[Mesh.ARRAY_TEX_UV2]=uv2
   nova.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a)
  _cabelos[id]=nova
 heroi._pecas[3].mesh=_cabelos[id]

func atualizar():
 var j: Node=heroi._jogador
 var raizes: Dictionary={}
 var inventario=j.get("inventario")
 # O F3 pode mostrar peças sem conceder itens ou bônus.
 var roupa=j.get("roupa_atual")
 var bits: int=j.pecas_cavaleiro if roupa!=null else 0
 var tipos: Array=[]
 if inventario!=null:
  for slot in ["cabeca","corpo","luvas","botas"]:
   var item=inventario.equipados.get(slot)
   tipos.append([item.tipo,item.categoria] if item!=null else [])
 var chave:=hash([roupa,bits,tipos])
 if chave==_chave:return
 _chave=chave
 if inventario!=null:raizes=Conjuntos.raizes(inventario.equipados)
 if roupa!=null:
  var raiz_visual: String=Aparencia.raiz_armadura_visual(int(roupa))
  if not raiz_visual.is_empty():
   raizes.clear()
   for i in 4:
    if bits & (1<<i):raizes[PECAS[i]]=raiz_visual
 var nova:=0
 var novas: Array[String]=["","","",""]
 for i in 4:
  var raiz: String=String(raizes.get(PECAS[i],"")).trim_suffix("/")+"/"
  if raiz in RAIZES:
   nova|=1<<i;novas[i]=raiz
 if nova==mascara and novas==raizes_pecas:return
 mascara=nova
 raizes_pecas=novas
 heroi._atualizar_pecas()
 for i in 4:
  malhas[i].visible=(mascara & (1<<i))!=0
  if not malhas[i].visible:continue
  var caminho: String=raizes_pecas[i]+"base_3d/"+PECAS[i]+".res"
  if not _recursos.has(caminho):
   var malha=load(caminho) as ArrayMesh
   _recursos[caminho]={"malha":malha,"material":malha.surface_get_material(0).duplicate()}
  malhas[i].mesh=_recursos[caminho].malha
  malhas[i].material_override=_recursos[caminho].material
 if mascara & 2:
  heroi._pecas[0].visible=false
  heroi._pecas[1].visible=false
 if mascara & 8:heroi._pecas[2].visible=false
 var elmo_fechado: bool=raizes_pecas[0] in ELMOS_FECHADOS
 if elmo_fechado:heroi._pecas[3].visible=false
 var pele: ShaderMaterial=_corpo.material_override
 pele.set_shader_parameter("casaca_mordomo",(mascara & 2)!=0)
 pele.set_shader_parameter("elmo_fechado",elmo_fechado)
 var cartola: bool=raizes_pecas[0]==RAIZES[0]
 pele.set_shader_parameter("recortar_cartola",cartola)
 heroi._pecas[3].material_override.set_shader_parameter("recortar_cartola",cartola)
 var grevas: float=ALTURAS_GREVAS.get(raizes_pecas[3],0.)
 pele.set_shader_parameter("altura_botas",maxf(grevas,heroi.CATALOGO_ROUPAS.modelo("calcado",heroi.roupas_3d.calcado).altura))
 heroi._pecas[1].material_override.set_shader_parameter("altura_grevas",grevas)
 if mascara & 2:malhas[1].material_override.set_shader_parameter("altura_grevas",grevas)
 heroi._atualizar_materiais_pixel()

func invalidar():
 _chave=-1
 mascara=-1
