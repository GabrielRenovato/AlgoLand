extends "res://codigo/inimigos/inimigo_base.gd"
## Goblin de adaga 2D: direção, quadros e impactos usam os mesmos recursos revisados.
const QUADROS := preload("res://assets/inimigos/goblin_adaga/animacoes.tres")
const REGISTRO := preload("res://assets/inimigos/goblin_adaga/registro_animacoes.json")
const DIRECOES := ["baixo", "direita", "cima", "esquerda"]
@export_enum("adaga","machado") var arma_goblin := "adaga"
@export var armadura_goblin := false
var _quadros: SpriteFrames = QUADROS
var _registro: Dictionary = REGISTRO.data
@export var raio_percepcao := 132.0
@export var ia_habilitada := true
@export var fator_velocidade_animacao := 1.0
@export var fator_velocidade_ataque := 1.0
@export var antecipacao_ataque := 0.22
@export var limite_postura := 0.30
@export var chance_combo := 0.5
@export var avanco_golpe := 100.0
var animacao := "parado"
var tempo_animacao := 0.0
var direcao := 0
var _perseguindo := false
var _recarga := .5
var _impactou := false
var _rumo := Vector2.DOWN
var _aviso: Line2D
var _vida_cheia := 1
var _postura := 0.0
var _postura_quebrada := false
var _combo_pendente := false
var _lado_giro := 1.0
var _tempo_giro := 0.0
var _tranco := 0.0
var _lado_tranco := 1.0
var _clip := "parado_baixo"
var _impactos_resolvidos := {}
var _avanco_restante := 0.0
var _reacao_dano_restante := 0.0
var _direcao_ferido := 0

func _ready() -> void:
	if arma_goblin == "machado":
		_quadros = load("res://assets/inimigos/goblin_machado_2d/animacoes.tres")
		_registro = JSON.parse_string(FileAccess.get_file_as_string("res://assets/inimigos/goblin_machado_2d/registro_animacoes.json"))
	if armadura_goblin:
		var caminho := "res://assets/inimigos/goblins_moinho/guarda_novato/"+arma_goblin+"/animacoes.tres"
		if ResourceLoader.exists(caminho):
			var armadura := load(caminho) as SpriteFrames
			if armadura!=null:_quadros=armadura
	super()
	_atualizar_ordem_desenho()
	_vida_cheia = maxi(vida,1)
	_lado_giro = 1.0 if randf()<.5 else -1.0
	if _agente != null: _agente.navigation_layers = 1
	sprite.centered = false
	sprite.offset = -Vector2(_registro.pivo[0],_registro.pivo[1])
	sprite.scale = Vector2.ONE * float(_registro.escala)
	sprite.hframes = 1
	sprite.vframes = 1
	_aviso = Line2D.new()
	_aviso.width = 2.0
	_aviso.default_color = Color("ffb46a")
	_aviso.add_point(Vector2.ZERO)
	_aviso.add_point(Vector2.RIGHT*alcance_ataque)
	_aviso.visible = false
	add_child(_aviso)
	_tocar("parado",true)

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
	var horizontal := absf(dir.x)>absf(dir.y)
	# Evita alternar atlas a cada quadro quando o rumo oscila perto da diagonal.
	if direcao in [1,3] and absf(dir.y)<absf(dir.x)*1.2: horizontal=true
	elif direcao in [0,2] and absf(dir.x)<absf(dir.y)*1.2: horizontal=false
	direcao = (1 if dir.x>0 else 3) if horizontal else (0 if dir.y>0 else 2)

func _centro_do_alvo(alvo: Node2D) -> Vector2:
	var centro := super(alvo)
	var para_alvo := centro-_centro_de_navegacao()
	var indice := (1 if para_alvo.x>0 else 3) if absf(para_alvo.x)>absf(para_alvo.y) else (0 if para_alvo.y>0 else 2)
	if para_alvo.length()>raio_percepcao or _quadros.has_animation(("ataque_" if arma_goblin=="machado" else "combo_")+DIRECOES[indice]): return centro
	# Sem arte de ataque neste ângulo, contorna até uma direção disponível.
	# O destino passa pela navegação normal e não teletransporta nem muda o dano de lado.
	var afastamento := -para_alvo
	if afastamento.is_zero_approx(): afastamento = Vector2.RIGHT
	var diferenca := wrapf(-3.0*PI/4.0-afastamento.angle(),-PI,PI)
	return centro+afastamento.normalized().rotated(signf(diferenca)*1.2)*24.0

func _physics_process(delta: float) -> void:
	_atualizar_ordem_desenho()
	if esta_morto:
		_animar(delta)
		if tempo_animacao >= _duracao_clip()+1.25: queue_free()
		return
	if not ia_habilitada:
		_reacao_dano_restante = maxf(0.0,_reacao_dano_restante-delta)
		if animacao == "ferido" and _reacao_dano_restante == 0.0: _tocar("parado")
		velocity = Vector2.ZERO
		_animar(delta)
		return
	_recarga = maxf(0.0,_recarga-delta)
	if esta_atacando:
		_atualizar_efeitos(delta)
		if esta_morto: return
		if esta_atordoado() or esta_congelado() or (esta_recuando and _postura_quebrada):
			_cancelar_golpe()
			return
		velocity = Vector2.ZERO
		_animar(delta)
		# Avanço curto, limitado pela distância ao alvo; nunca atravessa paredes.
		if not _impactou and tempo_animacao >= antecipacao_ataque+.055:
			var alvo_golpe := obter_jogador()
			if alvo_golpe != null:
				var passo := minf(_avanco_restante, minf(avanco_golpe*delta,maxf(0.0,global_position.distance_to(alvo_golpe.global_position)-12.0)))
				move_and_collide(_rumo*passo)
				_avanco_restante -= passo
		_resolver_impactos()
		if tempo_animacao >= antecipacao_ataque+_duracao_clip(): _terminar_golpe()
		return
	_postura = maxf(0.0,_postura-delta*float(_vida_cheia)*.25)
	super(delta)
	if esta_morto: return
	if esta_congelado():
		_aplicar_quadro()
		return
	if _reacao_dano_restante > 0.0 or esta_recuando or esta_atordoado():
		direcao = _direcao_ferido if _reacao_dano_restante > 0.0 else direcao
		_tocar("ferido")
	else: _tocar("correr" if velocity.length()>2.0 else "parado")
	_animar(delta)
	_reacao_dano_restante = maxf(0.0,_reacao_dano_restante-delta)
	var alvo := obter_jogador()
	if alvo != null and _recarga == 0.0 and not esta_recuando and not esta_atordoado() and _reacao_dano_restante == 0.0:
		if global_position.distance_to(alvo.global_position)<=alcance_ataque and not _parede(alvo.global_position):
			iniciar_ataque(alvo.global_position-global_position)

## O contorno escolhe o rumo antes da aceleração, sem girar a velocidade já integrada.
func _direcao_ate(alvo: Node2D, para_alvo: Vector2, delta: float) -> Vector2:
	var rumo := super(alvo,para_alvo,delta)
	if rumo.is_zero_approx(): return rumo
	var distancia := global_position.distance_to(alvo.global_position)
	if distancia<=alcance_ataque*1.3 or distancia>raio_percepcao*.8: return rumo
	_tempo_giro -= delta
	if _tempo_giro<=0.0:
		_tempo_giro = randf_range(.8,1.8)
		_lado_giro = -_lado_giro if randf()<.4 else _lado_giro
	var contorno := (rumo*.9+para_alvo.normalized().orthogonal()*_lado_giro*.25).normalized()
	return rumo if test_move(global_transform,contorno*12.0) else contorno

func receber_dano(quantidade_dano: int,forca_knockback := Vector2.ZERO) -> void:
	if esta_morto:return
	if armadura_goblin: quantidade_dano = maxi(1,roundi(quantidade_dano*.8))
	_postura+=float(quantidade_dano)
	if esta_atacando and _postura<float(_vida_cheia)*limite_postura:
		# Guarda firme: o golpe do jogador machuca, mas o goblin não se desfaz do corte nem é empurrado.
		_tranco=maxf(_tranco,0.4);_lado_tranco=1.0 if randf()<.5 else -1.0
		super(quantidade_dano,forca_knockback*0.2)
		return
	if _postura>=float(_vida_cheia)*limite_postura:
		_postura=0.0;_postura_quebrada=true
	_tranco=1.0;_lado_tranco=1.0 if randf()<.5 else -1.0
	super(quantidade_dano,forca_knockback)
	if esta_morto: return
	if esta_atacando: _cancelar_golpe()
	_direcao_ferido = direcao
	_reacao_dano_restante = .3
	_tocar("ferido",true)

func _terminar_golpe() -> void:
	_cancelar_golpe()

func iniciar_ataque(rumo: Vector2) -> void:
	if esta_morto or esta_atacando or rumo.is_zero_approx(): return
	direcao = (1 if rumo.x>0 else 3) if absf(rumo.x)>absf(rumo.y) else (0 if rumo.y>0 else 2)
	var orientacao: String = DIRECOES[direcao]
	# Só iniciar ações que têm arte direcional, mantendo dano e desenho no mesmo rumo.
	if not _quadros.has_animation(("ataque_" if arma_goblin=="machado" else "combo_")+orientacao): return
	_rumo = [Vector2.DOWN,Vector2.RIGHT,Vector2.UP,Vector2.LEFT][direcao]
	esta_atacando = true
	_impactou = false
	_postura_quebrada = false
	_impactos_resolvidos.clear()
	_avanco_restante = 6.0
	_combo_pendente = arma_goblin=="adaga" and randf()<chance_combo
	velocity = Vector2.ZERO
	_tocar("ataque_1",true)
	_aviso.rotation = _rumo.angle()
	_aviso.show()

func _resolver_impactos() -> void:
	var t := 0.0
	for q in _quadros.get_frame_count(_clip):
		if q in ([4] if arma_goblin=="machado" else [1,5,9]) and tempo_animacao >= antecipacao_ataque+t and not _impactos_resolvidos.has(q):
			_impactos_resolvidos[q] = true
			_impactou = true
			_aviso.hide()
			_atingir()
		t += _quadros.get_frame_duration(_clip,q)/_quadros.get_animation_speed(_clip)

func _atingir() -> void:
	for alvo in jogadores_vivos():
		var diff := alvo.global_position-global_position
		if diff.length()>alcance_ataque+6.0 or diff.normalized().dot(_rumo)<.2 or _parede(alvo.global_position):continue
		if not bool(alvo.get("invulneravel")):atingiu_jogador.emit()
		alvo.receber_dano(obter_dano(),_rumo*110.0)

func _parede(ponto: Vector2) -> bool:
	return not get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(global_position,ponto,64)).is_empty()

func _cancelar_golpe() -> void:
	_combo_pendente = false
	_postura_quebrada = false
	esta_atacando = false
	_recarga = tempo_recarga_ataque
	_aviso.hide()
	_tocar("parado",true)

func _tocar(nome: String, reiniciar := false) -> void:
	var orientacao: String = DIRECOES[direcao]
	var desejado := "correr_"+orientacao if nome == "correr" else "parado_"+orientacao
	if nome == "ferido": desejado = "ferido_"+orientacao
	if nome == "morrer": desejado = "morte_"+orientacao
	if nome == "ataque_1": desejado = ("ataque_" if arma_goblin=="machado" else ("combo_" if _combo_pendente else "ataque_1_"))+orientacao
	if not _quadros.has_animation(desejado): desejado = "correr_"+orientacao
	if nome == animacao and desejado == _clip and not reiniciar: return
	animacao = nome
	_clip = desejado
	tempo_animacao = 0.0
	_aplicar_quadro()

func _duracao_clip() -> float:
	var total := 0.0
	for q in _quadros.get_frame_count(_clip):
		total += _quadros.get_frame_duration(_clip,q)/_quadros.get_animation_speed(_clip)
	return total

func _animar(delta: float) -> void:
	var fator := fator_velocidade_animacao*(fator_velocidade_ataque if esta_atacando else 1.0)
	if esta_morto: fator = 1.0
	if animacao == "correr": fator *= velocity.length()/float(_registro.velocidade_corrida_px_s)
	tempo_animacao += delta*maxf(fator,0.0)
	# O balanço da corrida está desenhado nos quadros; não deformar nem inclinar o atlas.
	sprite.scale = Vector2.ONE*float(_registro.escala)
	sprite.position = Vector2.ZERO
	sprite.rotation = 0.0
	if esta_morto:
		# A queda está desenhada; segurar o corpo antes de limpar a instância.
		sprite.modulate.a = 1.0-smoothstep(_duracao_clip()+.9,_duracao_clip()+1.25,tempo_animacao)
	_aplicar_quadro()

func _aplicar_quadro() -> void:
	var t := maxf(0.0,tempo_animacao-antecipacao_ataque) if esta_atacando else tempo_animacao
	if animacao == "parado": t = 0.0
	elif _quadros.get_animation_loop(_clip): t = fmod(t,_duracao_clip())
	var quadro := _quadros.get_frame_count(_clip)-1
	for q in _quadros.get_frame_count(_clip):
		var duracao := _quadros.get_frame_duration(_clip,q)/_quadros.get_animation_speed(_clip)
		if t < duracao:
			quadro = q
			break
		t -= duracao
	sprite.texture = _quadros.get_frame_texture(_clip,quadro)

func morrer() -> void:
	if esta_morto: return
	esta_morto = true
	esta_atacando = false
	velocity = Vector2.ZERO
	_limpar_gelo_morte()
	_aviso.hide()
	_tocar_som_morte()
	_ao_morrer_chefe()
	_tocar("morrer",true)
	set_deferred("collision_layer",0)
	set_deferred("collision_mask",0)
	if has_node("HPBar"): get_node("HPBar").hide()
	inimigo_morreu.emit()
