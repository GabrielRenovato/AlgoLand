extends BoneAttachment3D
## Oito direções e três inclinações da pintura, presas à pose final do rig.
## A malha do corpo, suas poses e os dados salvos permanecem intactos.
const CENTROS := [Vector2(273,190),Vector2(704,190),Vector2(1095,190),Vector2(1532,190),Vector2(253,613),Vector2(680,613),Vector2(1093,613),Vector2(1523,613)]
const JAW := [320.0,316.0,307.0,303.0,717.0,714.0,727.0,737.0]
# Limites do pescoço após o queixo; excluem os ombros pintados na folha.
const PESCOCOS := [Vector2(230,307),Vector2(674,751),Vector2(1030,1110),Vector2(1460,1553),Vector2(207,289),Vector2(631,720),Vector2(1060,1142),Vector2(1465,1581)]
const OLHOS_AREA := [
	[Vector4(199,223,248,267),Vector4(297,224,342,268)],
	[Vector4(714,220,755,270),Vector4(779,200,807,248)],
	[Vector4(1164,204,1194,250)],[],[],[],
	[Vector4(991,616,1018,664)],
	[Vector4(1414,618,1447,668),Vector4(1483,635,1528,683)]
]
const QUEIXOS_BAIXO := [344.0,333.0,337.0,320.0,717.0,736.0,750.0,758.0]
const QUEIXOS_CIMA := [281.0,283.0,290.0,303.0,714.0,715.0,707.0,708.0]
# Marcos medidos para alinhar os olhos entre inclinações durante a mescla.
const OLHAR_BASE := [Vector2(267.6,247.9),Vector2(754.9,242.1),Vector2(1177.7,228),Vector2(1532,240),Vector2(253,663),Vector2(680,663),Vector2(1005.7,641.3),Vector2(1476.4,656.8)]
const OLHAR_BAIXO := [Vector2(263.6,293.4),Vector2(729,285.6),Vector2(1147.4,285.6),Vector2(1532,257),Vector2(253,663),Vector2(680,685),Vector2(1016.9,685.2),Vector2(1497.3,699.1)]
const OLHAR_CIMA := [Vector2(271.3,200.3),Vector2(747.5,196.9),Vector2(1172.2,188.3),Vector2(1532,240),Vector2(253,660),Vector2(680,664),Vector2(1002.4,601.8),Vector2(1482,606)]
const ESCALA := .0018
var material: ShaderMaterial
var malha: MeshInstance3D
var _corpo: MeshInstance3D
var _camera: Camera3D
var _esqueleto: Skeleton3D
var _base_osso: Basis
var _base_tronco: Basis
var _heroi: Node
var _direcao:=0
var _vista_aplicada:=-1
var _angulo:=0.0
var flexao:=0.0
var giro_rosto:=0.0

func montar(heroi: Node) -> void:
	name="CabecaReferencia"
	_heroi=heroi
	bone_name="DEF-head"
	_camera=heroi._camera
	_esqueleto=heroi._esqueleto
	_corpo=heroi._modelo.find_child("CorpoBase",true,false)
	_esqueleto.add_child(self)
	var quad:=QuadMesh.new()
	quad.size=Vector2(370,370)*ESCALA
	malha=MeshInstance3D.new()
	malha.mesh=quad
	material=ShaderMaterial.new()
	material.shader=preload("res://codigo/jogador/cabeca_referencia_3d.gdshader")
	material.set_shader_parameter("pintura",load("res://assets/personagens/base_3d/pintura_corpo/referencia_oito_direcoes.png"))
	material.set_shader_parameter("pintura_baixo",load("res://assets/personagens/base_3d/pintura_corpo/cabeca_baixa.png"))
	material.set_shader_parameter("pintura_cima",load("res://assets/personagens/base_3d/pintura_corpo/cabeca_erguida.png"))
	malha.material_override=material
	add_child(malha)
	var osso:=_esqueleto.find_bone("DEF-head")
	var t: Transform3D=_esqueleto.global_transform*_esqueleto.get_bone_global_pose(osso)
	_base_osso=_esqueleto.get_bone_global_pose(osso).basis.orthonormalized()
	_base_tronco=_esqueleto.get_bone_global_pose(_esqueleto.find_bone("DEF-spine.003")).basis.orthonormalized()
	_esqueleto.skeleton_updated.connect(_atualizar_inclinacao)
	var centro:=t*Vector3(0,.14,0)
	var tela:=_camera.unproject_position(centro)
	var tamanho:=Vector2(heroi._vp.size)
	centro+=_camera.global_basis.x*((tamanho.x*.49375-tela.x)*heroi.TAMANHO_CAMERA/tamanho.y)
	centro+=_camera.global_basis.y*((tela.y-tamanho.y*.3625)*heroi.TAMANHO_CAMERA/tamanho.y)
	malha.position=t.affine_inverse()*centro
	orientar(0)

func aplicar_aparencia(dados: Dictionary,peles: Array,olhos: Array) -> void:
	material.set_shader_parameter("tom_pele",peles[clampi(int(dados.get("pele",0)),0,peles.size()-1)])
	var cor: Array=dados.get("cor",[1.0,1.0,1.0,1.0])
	var tinta:=Color(cor[0],cor[1],cor[2])
	material.set_shader_parameter("tingir_cabelo",not tinta.is_equal_approx(Color.WHITE))
	material.set_shader_parameter("tinta_cabelo",tinta)
	material.set_shader_parameter("tingir_olhos",dados.has("olhos"))
	material.set_shader_parameter("tinta_olhos",olhos[clampi(int(dados.get("olhos",0)),0,olhos.size()-1)])

func orientar(angulo: float) -> void:
	_angulo=angulo
	_atualizar_inclinacao()

func _definir_vista(d: int) -> void:
	if d==_vista_aplicada:return
	_vista_aplicada=d
	_direcao=d
	material.set_shader_parameter("centro",CENTROS[d])
	material.set_shader_parameter("queixo",JAW[d])
	material.set_shader_parameter("pescoco",PESCOCOS[d])
	material.set_shader_parameter("direcao",d)
	material.set_shader_parameter("centro_baixo",CENTROS[d]+Vector2(0,QUEIXOS_BAIXO[d]-JAW[d]))
	material.set_shader_parameter("centro_cima",CENTROS[d]+Vector2(0,QUEIXOS_CIMA[d]-JAW[d]))
	material.set_shader_parameter("olhar_base",OLHAR_BASE[d]-CENTROS[d])
	material.set_shader_parameter("olhar_baixo",OLHAR_BAIXO[d]-CENTROS[d]-Vector2(0,QUEIXOS_BAIXO[d]-JAW[d]))
	material.set_shader_parameter("olhar_cima",OLHAR_CIMA[d]-CENTROS[d]-Vector2(0,QUEIXOS_CIMA[d]-JAW[d]))
	var areas: Array=OLHOS_AREA[d]
	material.set_shader_parameter("olho_a",areas[0] if areas.size()>0 else Vector4.ZERO)
	material.set_shader_parameter("olho_b",areas[1] if areas.size()>1 else Vector4.ZERO)

func _atualizar_inclinacao() -> void:
	# Ler a pose final depois dos modificadores: seek/AnimationPlayer podem
	# deixar uma pose intermediária diferente daquela que será desenhada.
	var osso:=_esqueleto.find_bone("DEF-head")
	var atual:=_esqueleto.get_bone_global_pose(osso).basis.orthonormalized()
	# Os ossos deste GLB são Z-up; converter a rotação para o mundo antes
	# de medir pitch/yaw/roll evita inclinação falsa nas diagonais.
	var mundo:=_esqueleto.global_basis.orthonormalized()
	var delta:=mundo*(atual*_base_osso.inverse())*mundo.inverse()
	var frente:=Basis(Vector3.UP,_angulo)*Vector3.BACK
	var olhar:=delta*frente
	flexao=asin(clampf(-olhar.y,-1.0,1.0))
	if _heroi._acao=="correr":
		# O clipe estabiliza quase totalmente a cabeça. Incorporar parte da
		# inclinação real do peito conserva o olhar à frente sem congelar o rosto.
		var tronco:=_esqueleto.get_bone_global_pose(_esqueleto.find_bone("DEF-spine.003")).basis.orthonormalized()
		var delta_tronco:=mundo*(tronco*_base_tronco.inverse())*mundo.inverse()
		var olhar_tronco:=delta_tronco*frente
		flexao=lerpf(flexao,asin(clampf(-olhar_tronco.y,-1.0,1.0)),.4)
	giro_rosto=atan2(olhar.x,olhar.z)
	var d:=posmod(roundi(giro_rosto/(PI*.25)),8)
	_definir_vista(d)
	var dormindo:=bool(_corpo.material_override.get_shader_parameter("olhos_fechados"))
	material.set_shader_parameter("olhos_fechados",dormindo)
	# Neutralidade precisa do repouso; variações pequenas da animação não
	# fazem o desenho piscar entre poses. Peso contínuo para o aceno da cabeça.
	var peso:=clampf((absf(flexao)-deg_to_rad(2.0))/deg_to_rad(16.0 if flexao>0.0 else 10.0),0.0,1.0)
	material.set_shader_parameter("flexao",0.0 if dormindo else signf(flexao)*smoothstep(0.0,1.0,peso))
	var cima:=delta*_camera.global_basis.y
	var inclinacao:=atan2(-cima.dot(_camera.global_basis.x),cima.dot(_camera.global_basis.y))
	material.set_shader_parameter("inclinacao",clampf(inclinacao,-PI*.3,PI*.3))
