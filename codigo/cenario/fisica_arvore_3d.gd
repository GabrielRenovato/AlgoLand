extends Node2D
## Uma simulação física isolada apenas durante golpes/queda; árvores paradas compartilham maquetes.
const CORTE := .68
const CENTRO := 2.05
var gerenciador: Node
var original: Sprite2D
var viewport_3d: SubViewport
var camera: Camera3D
class TroncoRigido extends RigidBody3D:
	var impulso_pendente := Vector3.ZERO
	func _integrate_forces(estado: PhysicsDirectBodyState3D) -> void:
		if not impulso_pendente.is_zero_approx():
			estado.apply_torque_impulse(impulso_pendente)
			impulso_pendente=Vector3.ZERO

var corpo: TroncoRigido
var modelo: Node3D
var dobradica: HingeJoint3D
var imagem: Sprite2D
var direcao := Vector3.RIGHT
var eixo := Vector3.FORWARD
var cortada := false
var tocou_chao := false
var idade := 0.0
var desde_golpe := 0.0
var apos_impacto := 0.0
var desde_corte := 0.0
var impacto_callback := Callable()
var _copas: Array[Dictionary] = []
var _balanco := 0.0
var _velocidade_folhas := 0.0
var _rng := RandomNumberGenerator.new()
var economico := OS.has_feature("mobile") or "--fisica-mobile" in OS.get_cmdline_user_args()

func configurar(dono: Node,sprite: Sprite2D,fonte: Dictionary,escala: Vector2,ponto: Vector2) -> void:
	gerenciador=dono;original=sprite
	position=get_parent().to_local(sprite.global_position)
	z_as_relative=false;z_index=sprite.z_index+1
	var afastamento := sprite.global_position-ponto
	if afastamento.length_squared()<1:afastamento=Vector2.RIGHT
	direcao=Vector3(afastamento.x,0,afastamento.y).normalized()
	eixo=Vector3(direcao.z,0,-direcao.x)
	_rng.seed=absi(int(position.x*913+position.y*173))
	viewport_3d=SubViewport.new()
	var resolucao := 512 if economico else 768
	viewport_3d.size=Vector2i(resolucao,resolucao);viewport_3d.transparent_bg=true;viewport_3d.own_world_3d=true
	viewport_3d.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(viewport_3d)
	for no in fonte.viewport.get_children():
		if no is Camera3D or no is DirectionalLight3D or no is WorldEnvironment:
			var copia=no.duplicate()
			viewport_3d.add_child(copia)
			if copia is Camera3D:camera=copia;camera.size=12.4
	var chao := StaticBody3D.new();chao.name="SoloFisico"
	var forma := CollisionShape3D.new();var caixa := BoxShape3D.new()
	caixa.size=Vector3(18,.2,18);forma.shape=caixa;forma.position.y=-.10
	chao.add_child(forma);viewport_3d.add_child(chao)
	var apoio := StaticBody3D.new();apoio.name="ApoioCorte";viewport_3d.add_child(apoio)
	corpo=TroncoRigido.new();corpo.name="TroncoRigido";corpo.mass=18.
	corpo.position=Vector3(0,CENTRO,0)
	corpo.center_of_mass_mode=RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	corpo.center_of_mass=Vector3.ZERO
	corpo.linear_damp=.25;corpo.angular_damp=.45
	corpo.contact_monitor=true;corpo.max_contacts_reported=8
	var material := PhysicsMaterial.new();material.friction=.85;material.bounce=.12
	corpo.physics_material_override=material
	viewport_3d.add_child(corpo)
	modelo=fonte.modelo.duplicate();modelo.position.y=-CENTRO;corpo.add_child(modelo)
	for m in modelo.get_children():
		if m is MeshInstance3D and (str(m.name).begins_with("FolhasRecortadas") or str(m.name).begins_with("RamoAgulhas")):
			_copas.append({"no":m,"rotacao":m.rotation})
	var tronco := CollisionShape3D.new();var capsula := CapsuleShape3D.new()
	capsula.radius=.19;capsula.height=3.05
	tronco.shape=capsula;tronco.position.y=CORTE+capsula.height*.5-CENTRO;corpo.add_child(tronco)
	for lado in [-1,1]:
		var copa := CollisionShape3D.new();var esfera := SphereShape3D.new()
		esfera.radius=.75;copa.shape=esfera;copa.position=Vector3(lado*.62,2.95-CENTRO,0)
		corpo.add_child(copa)
	dobradica=HingeJoint3D.new();dobradica.name="FibraDoCorte"
	dobradica.position=Vector3(0,CORTE,0)
	dobradica.quaternion=Quaternion(Vector3.BACK,eixo)
	viewport_3d.add_child(dobradica)
	dobradica.node_a=apoio.get_path();dobradica.node_b=corpo.get_path()
	dobradica.set_flag(HingeJoint3D.FLAG_USE_LIMIT,true)
	dobradica.set_param(HingeJoint3D.PARAM_LIMIT_LOWER,-1.8)
	dobradica.set_param(HingeJoint3D.PARAM_LIMIT_UPPER,.18)
	corpo.body_entered.connect(_contato)
	imagem=Sprite2D.new();imagem.centered=false;imagem.texture=viewport_3d.get_texture()
	imagem.scale=escala*(256.0/float(viewport_3d.size.x));imagem.offset=-camera.unproject_position(Vector3.ZERO)
	imagem.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;imagem.material=fonte.acabamento
	add_child(imagem)
	original.visible=false

func receber_golpe() -> void:
	desde_golpe=0
	corpo.sleeping=false
	corpo.impulso_pendente+=eixo*9.
	_velocidade_folhas+=.55
	_lascas(Vector3(0,CORTE,0),false)

func derrubar(retorno: Callable) -> void:
	if cortada:return
	cortada=true;impacto_callback=retorno
	# Remove raízes e encurta a parte do tronco que ficará no toco.
	for m in modelo.get_children():
		if not m.has_meta("inicio_ramo"):continue
		var a: Vector3=m.get_meta("inicio_ramo")
		var b: Vector3=m.get_meta("fim_ramo")
		if b.y<=CORTE and a.y<=CORTE:
			m.visible=false;continue
		if a.y<CORTE and b.y>CORTE:
			a=a.lerp(b,(CORTE-a.y)/(b.y-a.y))
			var cilindro := CylinderMesh.new()
			cilindro.radial_segments=7;cilindro.bottom_radius=float(m.get_meta("raio_ramo"))*.95
			cilindro.top_radius=float(m.get_meta("raio_ramo"))*.45;cilindro.height=a.distance_to(b)
			m.mesh=cilindro;m.position=(a+b)*.5;m.quaternion=Quaternion(Vector3.UP,(b-a).normalized())
	corpo.sleeping=false;corpo.impulso_pendente+=eixo*18.
	_velocidade_folhas+=.7
	_lascas(Vector3(0,CORTE,0),false)

func _physics_process(delta: float) -> void:
	if corpo==null:return
	idade+=delta;desde_golpe+=delta
	if cortada:desde_corte+=delta
	var angulo := atan2(corpo.global_basis.y.dot(direcao),corpo.global_basis.y.y)
	if not cortada:
		var velocidade := corpo.angular_velocity.dot(eixo)
		# Mola angular das fibras restantes: retorna à posição de repouso entre golpes.
		corpo.apply_torque(eixo*(-angulo*1500.-velocidade*150.))
		if desde_golpe>1.4 and absf(angulo)<.012 and absf(velocidade)<.035:
			_finalizar();return
	_velocidade_folhas+=(-_balanco*65.-_velocidade_folhas*7.5)*delta
	_balanco+=_velocidade_folhas*delta
	for i in _copas.size():
		var dados: Dictionary=_copas[i]
		dados.no.rotation=dados.rotacao+Vector3(_balanco*(.7+(i%3)*.15),0,_balanco*.45)
	if tocou_chao:
		apos_impacto+=delta
		imagem.modulate.a=1.0-clampf((apos_impacto-1.6)/.7,0,1)
		if apos_impacto>2.3:_finalizar()
	elif cortada and desde_corte>8.:
		# Limite de vida da apresentação; não deixa uma simulação órfã em caso de colisão ausente.
		_finalizar()

func _contato(outro: Node) -> void:
	if not cortada or tocou_chao or outro.name!="SoloFisico":return
	tocou_chao=true
	if is_instance_valid(dobradica):dobradica.queue_free()
	_velocidade_folhas+=1.4
	var ponto := corpo.position+direcao*1.2;ponto.y=.12
	_lascas(ponto,true)
	if impacto_callback.is_valid():
		var tela := (camera.unproject_position(ponto)-camera.unproject_position(Vector3.ZERO))*imagem.scale
		impacto_callback.call(to_global(tela))

func _lascas(ponto: Vector3,folhas: bool) -> void:
	var quantidade := (6 if folhas else 3) if economico else (18 if folhas else 7)
	for i in quantidade:
		var particula := RigidBody3D.new();particula.mass=.025
		particula.continuous_cd=true;particula.linear_damp=.8
		particula.position=ponto+Vector3(_rng.randf_range(-.20,.20),.13,_rng.randf_range(-.20,.20))
		var material := PhysicsMaterial.new();material.bounce=.12;material.friction=.9
		particula.physics_material_override=material
		var malha := MeshInstance3D.new();var caixa := BoxMesh.new()
		caixa.size=Vector3(.10,.025,.055) if folhas else Vector3(.045,.035,.12)
		malha.mesh=caixa
		malha.material_override=gerenciador._material((["8b9b45","75923e","bf8735","e7efed"][clampi(gerenciador.estacao,0,3)]) if folhas else "b0824c")
		particula.add_child(malha)
		var colisao := CollisionShape3D.new();var esfera := SphereShape3D.new();esfera.radius=.035
		colisao.shape=esfera;particula.add_child(colisao)
		particula.collision_layer=2;particula.collision_mask=1
		viewport_3d.add_child(particula)
		particula.linear_velocity=Vector3(_rng.randf_range(-1.5,1.5),_rng.randf_range(1.0,2.5),_rng.randf_range(-1.0,1.0))
		particula.angular_velocity=Vector3(2,4,3)*_rng.randf_range(-1,1)

func _finalizar() -> void:
	gerenciador.finalizar_fisica(original,cortada)
	queue_free()
