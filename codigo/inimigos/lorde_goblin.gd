extends "res://codigo/inimigos/inimigo_base.gd"
## Guardião da dungeon do moinho: martelada 2D e dano no contato com o chão.
signal apresentacao_concluida
const Chegada := preload("res://cenas/campanha/chegada_lorde_goblin.tscn")
const Escombros := preload("res://codigo/efeitos/impacto_marreta_lorde_2d.gd")
const CAMINHO_ESCOMBROS := "res://assets/inimigos/lorde_goblin_2d/impacto_escombros.png"
const Aviso := preload("res://codigo/efeitos/indicador_ataque.gd")
@export var raio_impacto := 56.0
@export var ia_habilitada := true
@export var chegada_habilitada := true
var aguardando_chegada := true
var em_apresentacao := false
var em_combate := false
var _recarga := .65
var _sequencia := 0
var _rumo := Vector2.DOWN
var _chegada: Node
var _sombra := 1.0
var _aviso: Node2D

func _ready() -> void:
	eh_chefe=true;nome_chefe="LORDE GOBLIN"
	super()
	add_to_group("boss_lorde_goblin")
	sprite.impacto.connect(_impacto)
	sprite.acao_concluida.connect(_fim_ataque)
	sprite.visible=not chegada_habilitada
	if not chegada_habilitada:liberar_combate()

func _iniciar_chefe() -> void:
	# A barra só entra depois da fala; o chefe ainda não pode receber dano.
	vida_maxima=vida

func _process(_delta: float) -> void:
	if not aguardando_chegada or em_apresentacao or esta_morto or not chegada_habilitada:return
	if get_tree().paused or get_tree().get_meta("cinema_ativo",false):return
	for interface in get_tree().get_nodes_in_group("interface"):
		if not interface._telas_abertas.is_empty():return
	for jogador in jogadores_vivos():
		if jogador.get_world_2d()==get_world_2d() and global_position.distance_to(jogador.global_position)<180 and not _parede(jogador.global_position):
			iniciar_apresentacao(jogador);break

func iniciar_apresentacao(jogador: Node2D) -> void:
	if em_apresentacao or not aguardando_chegada or esta_morto:return
	em_apresentacao=true;velocity=Vector2.ZERO
	_chegada=Chegada.instantiate();_chegada.chefe=self;_chegada.jogador=jogador
	add_child(_chegada)

func liberar_combate() -> void:
	aguardando_chegada=false;em_apresentacao=false;em_combate=true
	sprite.visible=true;set_meta("guardiao_aguardando",false);set_physics_process(true)
	get_tree().call_group("hud","mostrar_chefe",nome_chefe,vida,vida_maxima)
	apresentacao_concluida.emit();queue_redraw()

func aplicar_dano_contato() -> void:pass
func definir_animacao(_nome: String) -> void:pass
func definir_direcao_animacao(rumo: Vector2) -> void:
	if esta_atacando or rumo.is_zero_approx():return
	_rumo=rumo.normalized();sprite.orientar(_rumo)

func _physics_process(delta: float) -> void:
	_atualizar_ordem_desenho()
	if esta_morto or not em_combate or not ia_habilitada:return
	if esta_congelado():
		sprite.set_process(false);velocity=Vector2.ZERO;_atualizar_efeitos(delta);return
	sprite.set_process(true)
	_recarga=maxf(0.0,_recarga-delta)
	if esta_atacando:
		if is_instance_valid(_aviso):_aviso.atualizar_progresso(sprite._tempo_ms/float(sprite._dados(sprite.direcao).impacto_ms))
		velocity=Vector2.ZERO;_atualizar_efeitos(delta);return
	super(delta)
	if esta_morto:return
	sprite.definir_andando(velocity.length()>2.0 and not esta_recuando)
	var alvo:=obter_jogador()
	if is_instance_valid(alvo) and _recarga<=0 and not esta_recuando and not _parede(alvo.global_position):
		var tipo := "martelada"
		if _alvo_ao_alcance(tipo,alvo.global_position):iniciar_ataque(tipo,alvo.global_position)

func _alvo_ao_alcance(_tipo: String,ponto: Vector2) -> bool:
	var centro: Vector2=sprite.ponto_contato_para(ponto-global_position)
	return _na_area(to_local(ponto+Vector2(0,5)),centro)

func _na_area(ponto: Vector2,centro: Vector2) -> bool:
	# Mesma elipse no plano do chão para IA, aviso e dano.
	return ((ponto-centro)/Vector2(raio_impacto,raio_impacto*.5)).length_squared()<=1.0

func iniciar_ataque(tipo: String,destino: Vector2) -> bool:
	if not em_combate or esta_morto or esta_atacando or esta_congelado():return false
	if tipo not in ["martelada","golpe_duas_maos","impacto_area"]:return false
	_rumo=(destino-global_position).normalized();sprite.orientar(_rumo)
	if not sprite.iniciar_ataque(_rumo):return false
	esta_atacando=true;velocity=Vector2.ZERO;_sequencia+=1
	_aviso=Aviso.new();get_parent().add_child(_aviso)
	_aviso.configurar(to_global(sprite.ponto_contato_para(_rumo)),raio_impacto)
	_aviso.scale=Vector2(1,.5)
	return true

func _impacto(centro: Vector2) -> void:
	if esta_morto:return
	if is_instance_valid(_aviso):_aviso.queue_free()
	var efeito:=Escombros.new()
	efeito.textura_escombros=load(CAMINHO_ESCOMBROS)
	if em_apresentacao:efeito.process_mode=Node.PROCESS_MODE_ALWAYS
	get_parent().add_child(efeito)
	efeito.global_position=to_global(centro)
	efeito.scale=Vector2.ONE*.3
	efeito.z_index=Profundidade.z_de(efeito.global_position.y)+4
	efeito.iniciar()
	if em_apresentacao:
		Sons.tocar("chefe_aparece",0.0);return
	if not em_combate or esta_morto or not esta_atacando:return
	_tremer_camera(2.0,.16)
	for alvo in jogadores_vivos():
		if alvo.get_world_2d()!=get_world_2d():continue
		var ponto:Vector2=alvo.global_position+Vector2(0,5)
		if not _na_area(to_local(ponto),centro) or _parede(ponto):continue
		alvo.receber_dano(roundi(obter_dano()*1.25),(alvo.global_position-global_position).normalized()*180)
		atingiu_jogador.emit()

func _fim_ataque(_acao: StringName=&"martelada") -> void:
	if is_instance_valid(_aviso):_aviso.queue_free()
	esta_atacando=false;_recarga=.5 if vida>vida_maxima*.5 else .3

func _parede(ponto: Vector2) -> bool:
	return not get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(global_position,ponto,64)).is_empty()

func receber_dano(quantidade: int,forca: Vector2=Vector2.ZERO) -> void:
	if not em_combate:return
	super(quantidade,forca)
func receber_dano_efeito(quantidade: int,cor: Color) -> void:
	if em_combate:super(quantidade,cor)

func ponto_de_acerto_proximo(origem: Vector2) -> Vector2:
	return to_global(Vector2(clampf(to_local(origem).x,-22,22),clampf(to_local(origem).y,-66,4)))

func morrer() -> void:
	if esta_morto:return
	esta_morto=true;em_combate=false;esta_atacando=false;velocity=Vector2.ZERO
	if is_instance_valid(_aviso):_aviso.queue_free()
	sprite.cancelar_ataque();_limpar_gelo_morte();_tocar_som_morte();_ao_morrer_chefe()
	get_node("AlvoGolpes").set_deferred("monitorable",false)
	set_deferred("collision_layer",0)
	inimigo_morreu.emit()
	var tween:=create_tween();tween.tween_property(sprite,"modulate:a",0.0,.7)
	await tween.finished
	queue_free()

func _draw() -> void:
	if not is_instance_valid(sprite) or not sprite.visible:return
	draw_set_transform(Vector2(0,3),0,Vector2(1,.36))
	draw_circle(Vector2.ZERO,23,Color(0,0,0,.22*_sombra))

func ponto_marcador() -> Vector2:
	return to_global(sprite.ponto_cabeca())
