extends "res://codigo/inimigos/inimigo_base.gd"
## Goblin do estágio 4: perseguição local e corte Mixamo com impacto único anunciado.
const FICHA := preload("res://assets/inimigos/goblin_capuz_3d/atlas/animacoes.json")
const ATLAS := {
	"parado":preload("res://assets/inimigos/goblin_capuz_3d/atlas/parado.png"),
	"correr":preload("res://assets/inimigos/goblin_capuz_3d/atlas/correr.png"),
	"ataque_1":preload("res://assets/inimigos/goblin_capuz_3d/atlas/ataque_1.png"),
	"ferido":preload("res://assets/inimigos/goblin_capuz_3d/atlas/ferido.png"),
	"morrer":preload("res://assets/inimigos/goblin_capuz_3d/atlas/morrer.png")}
@export var raio_percepcao := 132.0
@export var ia_habilitada := true
var animacao := "parado"
var tempo_animacao := 0.0
var direcao := 0
var _perseguindo := false
var _recarga := .5
var _impactou := false
var _rumo := Vector2.DOWN
var _aviso: Line2D

func _ready() -> void:
	super()
	# O terreno regional tem uma malha com folga de 7 px, na camada 1.
	if _agente!=null:_agente.navigation_layers=1
	sprite.hframes=12;sprite.vframes=4
	sprite.centered=false
	sprite.offset=-Vector2(FICHA.data.pivo[0],FICHA.data.pivo[1])
	_aviso=Line2D.new();_aviso.width=2.0;_aviso.default_color=Color("ffb46a")
	_aviso.add_point(Vector2.ZERO);_aviso.add_point(Vector2.RIGHT*alcance_ataque)
	_aviso.visible=false;add_child(_aviso)
	_tocar("parado")

func obter_jogador() -> Node2D:
	var alvo := super()
	if not is_instance_valid(alvo):return null
	var alcance := raio_percepcao*(1.5 if _perseguindo else 1.0)
	_perseguindo=global_position.distance_to(alvo.global_position)<alcance
	return alvo if _perseguindo else null

func aplicar_dano_contato() -> void: pass
func definir_animacao(_nome: String) -> void: pass
func definir_direcao_animacao(dir: Vector2) -> void:
	if dir.length_squared()<.01:return
	if absf(dir.x)>absf(dir.y):direcao=1 if dir.x>0 else 3
	else:direcao=0 if dir.y>0 else 2

func _physics_process(delta: float) -> void:
	if esta_morto:
		_animar(delta)
		if tempo_animacao>=float(FICHA.data.animacoes.morrer.duracao):queue_free()
		return
	if not ia_habilitada:
		velocity=Vector2.ZERO;_animar(delta);return
	_recarga=maxf(0.0,_recarga-delta)
	if esta_atacando:
		_atualizar_efeitos(delta)
		if esta_morto:return
		if esta_atordoado() or esta_recuando or esta_congelado():
			_cancelar_golpe();return
		velocity=Vector2.ZERO
		_animar(delta)
		var dados:Dictionary=FICHA.data.animacoes.ataque_1
		if not _impactou and tempo_animacao>=float(dados.duracao)*float(dados.impacto):
			_impactou=true;_aviso.hide();_atingir()
		if tempo_animacao>=float(dados.duracao):_cancelar_golpe()
		return
	super(delta)
	if esta_morto:return
	if esta_recuando or esta_atordoado():_tocar("ferido")
	else:_tocar("correr" if velocity.length()>2.0 else "parado")
	_animar(delta)
	var alvo := obter_jogador()
	if alvo!=null and _recarga==0.0 and not esta_recuando and not esta_atordoado() and not esta_congelado():
		if global_position.distance_to(alvo.global_position)<=alcance_ataque and not _parede(alvo.global_position):
			iniciar_ataque(alvo.global_position-global_position)

func iniciar_ataque(rumo: Vector2) -> void:
	if esta_morto or esta_atacando or rumo.is_zero_approx():return
	_rumo=rumo.normalized();definir_direcao_animacao(_rumo)
	esta_atacando=true;_impactou=false;velocity=Vector2.ZERO
	_tocar("ataque_1",true)
	_aviso.rotation=_rumo.angle();_aviso.show()

func _atingir() -> void:
	for alvo in jogadores_vivos():
		var diff := alvo.global_position-global_position
		if diff.length()>alcance_ataque+6.0 or diff.normalized().dot(_rumo)<.2 or _parede(alvo.global_position):continue
		if not bool(alvo.get("invulneravel")):atingiu_jogador.emit()
		alvo.receber_dano(obter_dano(),_rumo*110.0)

func _parede(ponto: Vector2) -> bool:
	return not get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(global_position,ponto,64)).is_empty()

func _cancelar_golpe() -> void:
	esta_atacando=false;_recarga=tempo_recarga_ataque;_aviso.hide();_tocar("parado",true)

func _tocar(nome: String,reiniciar := false) -> void:
	if nome==animacao and not reiniciar:return
	animacao=nome;tempo_animacao=0.0;sprite.texture=ATLAS[nome]
	_aplicar_quadro()
func _animar(delta: float) -> void:
	tempo_animacao+=delta;_aplicar_quadro()
func _aplicar_quadro() -> void:
	sprite.texture=ATLAS[animacao]
	var dados:Dictionary=FICHA.data.animacoes[animacao]
	var t:=fmod(tempo_animacao,float(dados.duracao)) if dados.loop else minf(tempo_animacao,float(dados.duracao))
	var q:=mini(11,int(t/float(dados.duracao)*12.0))
	sprite.frame=direcao*12+q
func morrer() -> void:
	if esta_morto:return
	esta_morto=true;esta_atacando=false;velocity=Vector2.ZERO
	_limpar_gelo_morte();_aviso.hide();_tocar_som_morte()
	_tocar("morrer",true)
	set_deferred("collision_layer",0);set_deferred("collision_mask",0)
	if has_node("HPBar"):get_node("HPBar").hide()
	inimigo_morreu.emit()
