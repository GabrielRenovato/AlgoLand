extends RefCounted
## Efeito por instância. Não altera malhas, colisões, dano, materiais do corpo ou ferramentas.
const Visual=preload("res://codigo/dados/visual_armas.gd")
const Metal=preload("res://codigo/jogador/metal_arma_3d.gdshader")
const Aura=preload("res://codigo/jogador/aura_arma_3d.gdshader")
var heroi: Node
var pecas: Array=[]
var _chave: int=-1

func _init(h: Node):
 heroi=h
 _registrar(h._espada_uma_mao,[0],[1,3])
 _registrar(h._montante,[0],[1,3])
 _registrar(h._lanca,[4],[2,3])
 _registrar(h._machado_arma,[2,3],[1])
 _registrar(h._maca,[2,3,4,5,6,7],[1])
 _registrar(h._arco_visual._madeira,range(12),[])
 atualizar()

func _registrar(raiz: Node,energizadas: Array,metais: Array):
 var filhos:=raiz.get_children()
 for i in energizadas+metais:
  var no:=filhos[i] as MeshInstance3D
  var antigo=no.material_override
  var cor: Color=antigo.get_shader_parameter("cor") if antigo is ShaderMaterial else antigo.albedo_color
  var mat:=ShaderMaterial.new();mat.shader=Metal;mat.set_shader_parameter("cor_base",cor)
  no.material_override=mat
  var auras: Array=[]
  if i in energizadas:
   for camada in [1.,2.]:
    var aura:=MeshInstance3D.new()
    aura.name="AuraMelhoria%d"%int(camada)
    aura.mesh=no.mesh
    aura.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var m:=ShaderMaterial.new();m.shader=Aura;m.set_shader_parameter("camada",camada)
    m.set_shader_parameter("centro",no.mesh.get_aabb().get_center())
    m.set_shader_parameter("extensao",no.mesh.get_aabb().size*.5)
    aura.material_override=m
    no.add_child(aura);auras.append(aura)
  pecas.append({"metal":mat,"auras":auras})

func atualizar():
 var inv=heroi._jogador.get("inventario")
 var item=inv.equipados.get("arma") if inv!=null else null
 var nivel: int=item.nivel if item!=null else 1
 var raridade: String=item.raridade if item!=null else "comum"
 var chave:=hash([nivel,raridade,heroi.acabamento_pixel_art])
 if chave==_chave:return
 _chave=chave
 var energia:=Visual.brilho(nivel)
 for peca in pecas:
  var mat: ShaderMaterial=peca.metal
  mat.set_shader_parameter("cor_raridade",Visual.cor_material(raridade))
  mat.set_shader_parameter("tingimento",0. if raridade=="comum" else .64)
  mat.set_shader_parameter("cor_brilho",energia.cor)
  mat.set_shader_parameter("intensidade",energia.intensidade if not peca.auras.is_empty() else 0.)
  mat.set_shader_parameter("luz_em_blocos",heroi.acabamento_pixel_art)
  for aura in peca.auras:
   aura.visible=energia.intensidade>0.
   aura.material_override.set_shader_parameter("cor_brilho",energia.cor)
   aura.material_override.set_shader_parameter("intensidade",energia.intensidade)
   aura.material_override.set_shader_parameter("largura",energia.largura)
