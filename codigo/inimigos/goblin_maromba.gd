extends "inimigo_base.gd"

const AreaDanoChefe := preload("res://codigo/inimigos/area_dano_chefe.gd")
const Aviso := preload("res://codigo/efeitos/aviso_ataque.gd")
const TEXTURA_LUZ := preload("res://recursos/luz/luz_radial.tres")
const TIPOS := ["porretada", "varrida", "salto", "furia", "execucao"]
const AVISOS := {"porretada": 0.45, "varrida": 0.7, "salto": 0.8, "furia": 0.65, "execucao": 2.5}
const DURACOES := {"porretada": 0.4, "varrida": 0.5, "salto": 0.65, "furia": 1.8, "execucao": 0.65}
const RAIO_EXECUCAO := 180.0
const ALCANCE_PORRETADA := 65.0
const ALCANCE_VARRIDA := 95.0
enum Estado { LIVRE, AVISANDO, ATACANDO, RECUPERANDO }

var estado := Estado.LIVRE
var ataque_atual := "porretada"
var _tempo := 0.0
var _recarga := 0.8
var _direcao := Vector2.DOWN
var _linha := 0
var _passos := 0.0
var _normais := 0
var _recarga_furia := 8.0
var _golpes_furia := 0
var _acertou := false
var _origem_salto := Vector2.ZERO
var _distancia_salto := 240.0
var _folhas: Dictionary = {}
var _area_dano: Area2D
var _aviso: Node2D
var _efeito: Sprite2D
var _centro_execucao := Vector2.ZERO
var _limiares_execucao: Array[float] = [0.5, 0.1]
var _proxima_execucao := 0
var _execucao_pendente := false
var _escala_circulo := Vector2.ONE
var _rotulo_execucao: Label
var _luz_circulo: PointLight2D
var _luz_corpo: PointLight2D
var _destino_salto := Vector2.ZERO

func _ready() -> void:
	eh_chefe = true
	nome_chefe = "GOBLIN MAROMBA"
	super()
	for pagina in ["movimento", "porretada", "varrida", "salto", "furia", "execucao"]:
		_folhas[pagina] = load("res://assets/inimigos/goblin_maromba/" + pagina + ".png")
	_area_dano = AreaDanoChefe.new()
	add_child(_area_dano)
	_tocar("movimento", 0)

func aplicar_dano_contato() -> void:
	pass

func _physics_process(delta: float) -> void:
	if esta_morto:
		return
	if _proxima_execucao < _limiares_execucao.size() and vida <= vida_maxima * _limiares_execucao[_proxima_execucao]:
		_execucao_pendente = true
	if esta_congelado():
		_atualizar_efeitos(delta)
		velocity = Vector2.ZERO
		return
	_recarga_furia = maxf(0, _recarga_furia - delta)
	if estado == Estado.LIVRE:
		var inicio := global_position
		var parada := raio_parada
		var alvo := obter_jogador()
		if alvo != null and not _caminho_livre(alvo.global_position):
			raio_parada = 0
		super(delta)
		raio_parada = parada
		if esta_morto or alvo == null or alvo.get("estaMorto") == true:
			return
		_definir_linha(alvo.global_position - global_position)
		# Um ciclo contém dois passos completos; o ritmo acompanha o deslocamento real.
		_passos = fposmod(_passos + global_position.distance_to(inicio), 72.0)
		_tocar("movimento", int(_passos / 6.0) if global_position.distance_to(inicio) > 0.01 else 0)
		_recarga = maxf(0, _recarga - delta)
		if _execucao_pendente and _caminho_livre(alvo.global_position):
			if iniciar_ataque("execucao", alvo.global_position):
				_proxima_execucao += 1
				_execucao_pendente = false
		elif _recarga <= 0 and _caminho_livre(alvo.global_position):
			iniciar_ataque(_escolher_ataque(alvo.global_position), alvo.global_position)
		return
	_atualizar_efeitos(delta)
	if esta_morto:
		return
	_tempo += delta
	match estado:
		Estado.AVISANDO:
			_tocar("execucao" if ataque_atual == "execucao" else ataque_atual, mini(2, int(_tempo / float(AVISOS[ataque_atual]) * 3)))
			if is_instance_valid(_aviso):
				_aviso.animar(_tempo)
			if ataque_atual == "execucao":
				_animar_invocacao()
			if _tempo >= float(AVISOS[ataque_atual]):
				estado = Estado.ATACANDO
				_tempo = 0
				_aviso.hide()
		Estado.ATACANDO:
			var duracao: float = DURACOES[ataque_atual]
			_tocar(ataque_atual, (2 + int(_tempo / 0.5) % 3) if ataque_atual == "furia" else (3 if _tempo < duracao * 0.65 else 4))
			if ataque_atual in ["salto", "execucao"]:
				var destino := _centro_execucao - Vector2(0, 9) if ataque_atual == "execucao" else _destino_salto
				var progresso := clampf(_tempo / duracao, 0, 1)
				var posicao := _origem_salto.lerp(destino, progresso)
				velocity = (posicao - global_position) / maxf(delta, 0.001)
				move_and_slide()
				# O corpo sobe; a colisão permanece nos pés, sem atravessar cenário.
				sprite.position.y = -54 - sin(progresso * PI) * 65
				_area_dano.acompanhar(sprite)
				if progresso >= 0.85 and not _acertou:
					_atingir_area()

			elif ataque_atual == "furia":
				var golpe := mini(3, int(_tempo / 0.5))
				if golpe > _golpes_furia:
					_golpes_furia = golpe
					_acertou = false
					_atingir_area()
			elif not _acertou and _tempo >= duracao * 0.3:
				_atingir_area()
			if is_instance_valid(_efeito):
				_efeito.visible = _tempo >= duracao * (0.85 if ataque_atual in ["salto", "execucao"] else 0.3)
				_efeito.frame = clampi(int(fposmod(_tempo, 0.5) / 0.5 * 6), 0, 5) if ataque_atual == "furia" else clampi(int(_tempo / duracao * 6), 0, 5)
				if ataque_atual in ["salto", "execucao"]:
					_efeito.global_position = _centro_execucao if ataque_atual == "execucao" else _destino_salto
			if estado == Estado.ATACANDO and _tempo >= duracao:
				_recuperar()
		Estado.RECUPERANDO:
			if is_instance_valid(_efeito):
				_efeito.frame = clampi(int(_tempo / 0.4 * 6), 0, 5)
				_efeito.visible = _tempo < 0.4
			_tocar("execucao" if ataque_atual == "execucao" else ataque_atual, 5)
			if _tempo >= (1.0 if ataque_atual in ["furia", "execucao"] else 0.4):
				_limpar_efeitos()
				estado = Estado.LIVRE
				esta_atacando = false
				_recarga = 0.65 if vida <= vida_maxima * 0.5 else 0.9

func _escolher_ataque(destino: Vector2) -> String:
	var distancia := global_position.distance_to(destino)
	if _recarga_furia <= 0 and distancia <= ALCANCE_VARRIDA:
		return "furia"
	if distancia > ALCANCE_VARRIDA:
		return "salto"
	if distancia <= ALCANCE_PORRETADA:
		return "varrida" if _normais % 3 == 2 else "porretada"
	return "varrida"

func _caminho_livre(destino: Vector2) -> bool:
	return get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(global_position, destino, 64)).is_empty()

func iniciar_ataque(tipo: String, destino: Vector2) -> bool:
	if estado != Estado.LIVRE or esta_morto or esta_congelado() or not TIPOS.has(tipo):
		return false
	_limpar_efeitos()
	ataque_atual = tipo
	_direcao = (destino - global_position).normalized()
	if _direcao == Vector2.ZERO:
		_direcao = Vector2.DOWN
	_definir_linha(_direcao)
	_origem_salto = global_position
	_distancia_salto = minf(global_position.distance_to(destino), 300)
	_destino_salto = global_position + _direcao * _distancia_salto
	_acertou = false
	_golpes_furia = 0
	if tipo == "furia":
		_recarga_furia = 13.0
	_tempo = 0
	estado = Estado.AVISANDO
	esta_atacando = true
	velocity = Vector2.ZERO
	if tipo == "execucao":
		# A marca fica no local em que o jogador estava; não o persegue durante a fuga.
		_centro_execucao = destino + Vector2(0, 9)
		_rotulo_execucao = Label.new()
		_rotulo_execucao.text = "EXECUCAO: SAIA DO CIRCULO"
		_rotulo_execucao.position = Vector2(-52, -125)
		_rotulo_execucao.z_index = 6
		_rotulo_execucao.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rotulo_execucao.add_theme_font_override("font", load("res://assets/ui/Planes_ValMore.ttf"))
		_rotulo_execucao.add_theme_font_size_override("font_size", 8)
		_rotulo_execucao.add_theme_color_override("font_color", Color(1, 0.7, 0.3))
		_rotulo_execucao.add_theme_color_override("font_outline_color", Color(0.08, 0.12, 0.1))
		_rotulo_execucao.add_theme_constant_override("outline_size", 1)
		add_child(_rotulo_execucao)
	elif tipo == "furia":
		get_tree().call_group("hud", "anunciar", "FURIA DO GOBLIN", "TRES GOLPES EM SEQUENCIA", 1.0)
	else:
		_normais += 1
	_aviso = Aviso.new()
	_aviso.z_as_relative = false
	_aviso.z_index = Profundidade.Z_CHAO + 30
	get_parent().add_child(_aviso)
	_aviso.global_position = _centro_execucao if tipo == "execucao" else (_destino_salto if tipo == "salto" else global_position)
	_aviso.definir_area(_pontos_ataque())
	_efeito = Sprite2D.new()
	_efeito.texture = load("res://assets/efeitos/goblin_maromba/" + ("execucao" if tipo == "execucao" else tipo) + ".png")
	_efeito.hframes = 6
	_efeito.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_efeito.visible = false
	# Os efeitos ficam acima do aviso no chão, sem herdar a profundidade do corpo.
	_efeito.z_as_relative = false
	_efeito.z_index = Profundidade.Z_CHAO + 35
	if tipo == "execucao":
		_efeito.position = to_local(_centro_execucao)
		_efeito.scale = _escala_efeito_circular(RAIO_EXECUCAO)
		_escala_circulo = _efeito.scale
		_efeito.visible = true
		var sem_sombra := CanvasItemMaterial.new()
		sem_sombra.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		_efeito.material = sem_sombra
	elif tipo == "porretada":
		_efeito.position = _direcao * 38 + Vector2(0, -20)
		_efeito.rotation = _direcao.angle()
		_efeito.scale = Vector2.ONE * 0.65
	elif tipo in ["varrida", "furia"]:
		_efeito.position = Vector2(0, 2)
		_efeito.scale = _escala_efeito_circular(ALCANCE_VARRIDA)
	elif tipo == "salto":
		_efeito.position = to_local(_destino_salto)
		_efeito.scale = _escala_efeito_circular(65.0)
	else:
		_efeito.position = Vector2(0, -80)
		_efeito.scale = Vector2.ONE * 0.65
	add_child(_efeito)
	if tipo == "execucao":
		_luz_circulo = _criar_luz(to_local(_centro_execucao), RAIO_EXECUCAO * 2 / 128, 0.7)
		_luz_corpo = _criar_luz(Vector2(0, -90), 0.5, 1.0)
		_animar_invocacao()
	return true

func _escala_efeito_circular(raio: float) -> Vector2:
	var imagem := _efeito.texture.get_image()
	var lado := imagem.get_width() / 6
	var tamanho := Vector2i.ONE
	for quadro in 6:
		tamanho = tamanho.max(imagem.get_region(Rect2i(quadro * lado, 0, lado, lado)).get_used_rect().size)
	return Vector2(raio * 2 / tamanho.x, raio * 2 / tamanho.y)

func _criar_luz(posicao: Vector2, escala_luz: float, energia: float) -> PointLight2D:
	var luz := PointLight2D.new()
	luz.texture = TEXTURA_LUZ
	luz.texture_scale = escala_luz
	luz.color = Color(1.0, 0.45, 0.12)
	luz.energy = energia
	luz.shadow_enabled = false
	luz.position = posicao
	add_child(luz)
	return luz

func _animar_invocacao() -> void:
	if is_instance_valid(_efeito):
		_efeito.position = to_local(_centro_execucao)
		_efeito.scale = _escala_circulo
		_efeito.frame = int(_tempo * 5) % 2
		_efeito.modulate.a = 0.6 + 0.2 * sin(_tempo * 7)

func _pontos_ataque() -> PackedVector2Array:

	if ataque_atual in ["varrida", "furia", "execucao", "salto"]:
		var circulo := PackedVector2Array()
		for i in 48:
			circulo.append(Vector2.from_angle(TAU * i / 48) * (RAIO_EXECUCAO if ataque_atual == "execucao" else (65.0 if ataque_atual == "salto" else ALCANCE_VARRIDA)))
		return circulo
	var pontos := PackedVector2Array([Vector2.ZERO])
	var raio := ALCANCE_PORRETADA
	var abertura := PI / 3
	for i in 25:
		pontos.append(Vector2.from_angle(_direcao.angle() - abertura + abertura * 2 * i / 24) * raio)
	return pontos

func _atingir_area() -> void:
	if _acertou:
		return
	_acertou = true
	var alvo := obter_jogador()
	if alvo == null or alvo.get("estaMorto") == true:
		return
	var ponto := alvo.global_position + Vector2(0, 9)
	if ataque_atual == "execucao":
		if ponto.distance_to(_centro_execucao) <= RAIO_EXECUCAO and alvo.has_method("receber_hitkill_chefe"):
			alvo.receber_hitkill_chefe()
		return
	if ataque_atual == "salto" and global_position.distance_to(_destino_salto) > 65:
		return
	var centro := _destino_salto if ataque_atual == "salto" else global_position
	if not Geometry2D.is_point_in_polygon(ponto - centro, _pontos_ataque()) or not _caminho_livre(ponto):
		return
	alvo.receber_dano(roundi(dano * (1.2 if ataque_atual == "varrida" else 1.0)), (alvo.global_position - global_position).normalized() * 230)

func _recuperar() -> void:
	sprite.position.y = -54
	if is_instance_valid(_aviso):
		_aviso.queue_free()
	_aviso = null
	if is_instance_valid(_efeito):
		_efeito.frame = 0
		_efeito.visible = true
	velocity = Vector2.ZERO
	estado = Estado.RECUPERANDO
	_tempo = 0

func _definir_linha(rumo: Vector2) -> void:
	_linha = (2 if rumo.x > 0 else 3) if absf(rumo.x) > absf(rumo.y) else (0 if rumo.y >= 0 else 1)

func _tocar(pagina: String, quadro: int) -> void:
	sprite.texture = _folhas[pagina]
	var colunas := 12 if pagina == "movimento" else 6
	sprite.hframes = colunas
	sprite.vframes = 4
	sprite.frame = _linha * colunas + clampi(quadro, 0, colunas - 1)
	_area_dano.acompanhar(sprite)
	_atualizar_ordem_desenho()

func ponto_de_acerto_proximo(origem: Vector2) -> Vector2:
	return _area_dano.ponto_proximo(origem)

func forcar_ataque_debug(tipo: String) -> bool:
	if not OS.is_debug_build() or esta_morto:
		return false
	_recuperar()
	estado = Estado.LIVRE
	esta_atacando = false
	var alvo := obter_jogador()
	return iniciar_ataque(tipo, alvo.global_position) if alvo != null else false

func _limpar_efeitos() -> void:
	if is_instance_valid(_aviso):
		_aviso.queue_free()
	if is_instance_valid(_efeito):
		_efeito.queue_free()
	_aviso = null
	_efeito = null
	for efeito in [_luz_circulo, _luz_corpo, _rotulo_execucao]:
		if is_instance_valid(efeito):
			efeito.queue_free()
	_rotulo_execucao = null
	_luz_circulo = null
	_luz_corpo = null

func morrer() -> void:
	if esta_morto:
		return
	esta_morto = true
	_area_dano.set_deferred("monitorable", false)
	_limpar_efeitos()
	_limpar_gelo_morte()
	velocity = Vector2.ZERO
	_tocar_som_morte()
	_ao_morrer_chefe()
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.6)
	await tween.finished
	inimigo_morreu.emit()
	queue_free()

func _exit_tree() -> void:
	_limpar_efeitos()
