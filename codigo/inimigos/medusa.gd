extends "inimigo_base.gd"

const AreaDanoChefe := preload("res://codigo/inimigos/area_dano_chefe.gd")
const Aviso := preload("res://codigo/efeitos/aviso_ataque.gd")
const TEXTURA_LUZ := preload("res://recursos/luz/luz_radial.tres")
const AVISO_VERDE := preload("res://recursos/personagens/aviso_ruina_medusa.gdshader")
const RUINA_NITIDA := preload("res://recursos/personagens/ruina_medusa.gdshader")
const TELA_RUINA := preload("res://recursos/personagens/tela_ruina_medusa.tres")
const TIPOS := ["garras", "cauda", "bote", "olhar", "ruina"]
const AVISOS := {"garras": 0.45, "cauda": 0.7, "bote": 0.8, "olhar": 1.2, "ruina": 2.5}
const DURACOES := {"garras": 0.4, "cauda": 0.5, "bote": 0.65, "olhar": 0.45, "ruina": 0.65}
const RAIO_RUINA := 180.0
const ALCANCE_GARRAS := 65.0
const ALCANCE_CAUDA := 95.0
const ALCANCE_OLHAR := 260.0
const MEIA_ABERTURA_OLHAR := PI / 3.0
const DURACAO_PEDRA := 2.25
enum Estado { LIVRE, AVISANDO, ATACANDO, RECUPERANDO }

var estado := Estado.LIVRE
var ataque_atual := "garras"
var _tempo := 0.0
var _recarga := 0.8
var _direcao := Vector2.DOWN
var _linha := 0
var _passos := 0.0
var _normais := 0
var _acertou := false
var _origem_bote := Vector2.ZERO
var _distancia_bote := 240.0
var _folhas: Dictionary = {}
var _area_dano: Area2D
var _aviso: Node2D
var _efeito: Sprite2D
var _centro_ruina := Vector2.ZERO
var _limiares_ruina: Array[float] = [0.5, 0.1]
var _proxima_ruina := 0
var _ruina_pendente := false
var _escala_circulo := Vector2.ONE
var _rotulo_ruina: Label
var _luz_circulo: PointLight2D
var _luz_olhos: PointLight2D
var _cache_olhos: Dictionary = {}
var _imagem_olhar: Image

func _ready() -> void:
	eh_chefe = true
	nome_chefe = "MEDUSA"
	super()
	for pagina in ["movimento", "garras", "cauda", "bote", "olhar"]:
		_folhas[pagina] = load("res://assets/inimigos/medusa/" + pagina + ".png")
	_area_dano = AreaDanoChefe.new()
	add_child(_area_dano)
	_tocar("movimento", 0)

func aplicar_dano_contato() -> void:
	pass

func _physics_process(delta: float) -> void:
	if esta_morto:
		return
	if _proxima_ruina < _limiares_ruina.size() and vida <= vida_maxima * _limiares_ruina[_proxima_ruina]:
		_ruina_pendente = true
	if esta_congelado():
		_atualizar_efeitos(delta)
		velocity = Vector2.ZERO
		return
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
		_passos = fposmod(_passos + global_position.distance_to(inicio), 42.0)
		_tocar("movimento", int(_passos / 7.0) if global_position.distance_to(inicio) > 0.01 else int(Time.get_ticks_msec() / 400) % 2)
		_recarga = maxf(0, _recarga - delta)
		if _ruina_pendente:
			if iniciar_ataque("ruina", alvo.global_position):
				_proxima_ruina += 1
				_ruina_pendente = false
		elif _recarga <= 0 and _caminho_livre(alvo.global_position):
			iniciar_ataque(_escolher_ataque(alvo.global_position), alvo.global_position)
		return
	_atualizar_efeitos(delta)
	if esta_morto:
		return
	_tempo += delta
	match estado:
		Estado.AVISANDO:
			_tocar("olhar" if ataque_atual == "ruina" else ataque_atual, mini(2, int(_tempo / float(AVISOS[ataque_atual]) * 3)))
			if is_instance_valid(_aviso):
				_aviso.animar(_tempo)
			if ataque_atual == "ruina":
				_animar_invocacao()
			if _tempo >= float(AVISOS[ataque_atual]):
				estado = Estado.ATACANDO
				_tempo = 0
				_aviso.hide()
		Estado.ATACANDO:
			var duracao: float = DURACOES[ataque_atual]
			_tocar("olhar" if ataque_atual == "ruina" else ataque_atual, 3 if _tempo < duracao * 0.65 else 4)
			if ataque_atual == "bote":
				var inicio := global_position
				var restante := maxf(0, _distancia_bote - global_position.distance_to(_origem_bote))
				velocity = _direcao * minf(400, restante / maxf(delta, 0.001))
				move_and_slide()
				_atingir_bote(inicio, global_position)
				if get_slide_collision_count() > 0 or restante <= 1:
					_recuperar()
			elif not _acertou and _tempo >= duracao * 0.3:
				_atingir_area()
			if is_instance_valid(_efeito):
				_efeito.visible = ataque_atual == "bote" or _tempo >= duracao * 0.3
				if ataque_atual == "ruina":
					_efeito.material.set_shader_parameter("impacto",clampf(_tempo/duracao,0,1))
				else:
					_efeito.frame = clampi(int(_tempo / duracao * 6), 0, 5)
			if estado == Estado.ATACANDO and _tempo >= duracao:
				_recuperar()
		Estado.RECUPERANDO:
			_tocar("olhar" if ataque_atual == "ruina" else ataque_atual, 5)
			if _tempo >= (1.0 if ataque_atual in ["olhar", "ruina"] else 0.4):
				estado = Estado.LIVRE
				esta_atacando = false
				_recarga = 0.65 if vida <= vida_maxima * 0.5 else 0.9

func _escolher_ataque(destino: Vector2) -> String:
	var distancia := global_position.distance_to(destino)
	if distancia > ALCANCE_CAUDA:
		return "bote"
	if distancia <= ALCANCE_GARRAS:
		return "cauda" if _normais % 3 == 2 else "garras"
	return "cauda"

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
	_origem_bote = global_position
	_distancia_bote = clampf(global_position.distance_to(destino) + 40, 100, 260)
	_acertou = false
	_tempo = 0
	estado = Estado.AVISANDO
	esta_atacando = true
	velocity = Vector2.ZERO
	if tipo == "ruina":
		# A marca fica no local em que o jogador estava; não o persegue durante a fuga.
		_centro_ruina = destino + Vector2(0, 9)
		_rotulo_ruina = Label.new()
		_rotulo_ruina.text = "RUINA: SAIA DO CIRCULO"
		_rotulo_ruina.position = Vector2(-52, -125)
		_rotulo_ruina.z_index = 6
		_rotulo_ruina.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rotulo_ruina.add_theme_font_override("font", load("res://assets/ui/Planes_ValMore.ttf"))
		_rotulo_ruina.add_theme_font_size_override("font_size", 8)
		_rotulo_ruina.add_theme_color_override("font_color", Color(0.6, 1, 0.7))
		_rotulo_ruina.add_theme_color_override("font_outline_color", Color(0.08, 0.12, 0.1))
		_rotulo_ruina.add_theme_constant_override("outline_size", 1)
		add_child(_rotulo_ruina)
	elif tipo == "olhar":
		get_tree().call_group("hud", "anunciar", "OLHAR PETRIFICANTE", "SAIA DO CONE OU VIRE-SE", 1.2)
	else:
		_normais += 1
	_aviso = Aviso.new()
	_aviso.z_as_relative = false
	_aviso.z_index = Profundidade.Z_CHAO + 30
	get_parent().add_child(_aviso)
	_aviso.global_position = _centro_ruina if tipo == "ruina" else global_position
	_aviso.definir_area(_pontos_ataque())
	if tipo == "ruina":
		var material_verde := ShaderMaterial.new()
		material_verde.shader = AVISO_VERDE
		_aviso._superficie.material = material_verde
	_efeito = Sprite2D.new()
	_efeito.texture = load("res://assets/efeitos/medusa/" + ("ruina" if tipo == "ruina" else tipo) + ".png")
	_efeito.hframes = 6
	_efeito.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_efeito.visible = false
	_efeito.z_index = 2
	if tipo == "ruina":
		_efeito.texture = TELA_RUINA
		_efeito.hframes = 1
		_efeito.z_as_relative = false
		_efeito.z_index = Profundidade.Z_CHAO + 35
		_efeito.position = to_local(_centro_ruina)
		_efeito.scale = Vector2.ONE
		_efeito.visible = true
		var material_ruina := ShaderMaterial.new()
		material_ruina.shader = RUINA_NITIDA
		material_ruina.set_shader_parameter("raio",RAIO_RUINA)
		_efeito.material = material_ruina
	elif tipo == "garras":
		_efeito.position = _direcao * 38 + Vector2(0, -20)
		_efeito.rotation = _direcao.angle()
		_efeito.scale = Vector2.ONE * 0.65
	elif tipo == "cauda":
		_efeito.position = Vector2(0, 2)
		_efeito.scale = Vector2.ONE * ALCANCE_CAUDA * 2 / 128
	elif tipo == "bote":
		_efeito.position = -_direcao * 24
		_efeito.rotation = _direcao.angle()
		_efeito.scale = Vector2.ONE * 0.8
	else:
		_efeito.position = Vector2(0, -80)
		_efeito.scale = Vector2.ONE * 0.65
	add_child(_efeito)
	if tipo == "ruina":
		_luz_circulo = _criar_luz(to_local(_centro_ruina), RAIO_RUINA * 2 / 128, 0.7)
		_luz_olhos = _criar_luz(Vector2(0, -90), 0.5, 1.0)
		_animar_invocacao()
	return true

func _criar_luz(posicao: Vector2, escala_luz: float, energia: float) -> PointLight2D:
	var luz := PointLight2D.new()
	luz.texture = TEXTURA_LUZ
	luz.texture_scale = escala_luz
	luz.color = Color(0.15, 1.0, 0.4)
	luz.energy = energia
	luz.shadow_enabled = false
	luz.position = posicao
	add_child(luz)
	return luz

func _origem_olhos() -> Vector2:
	var quadro: int = sprite.frame
	if not _cache_olhos.has(quadro):
		if _imagem_olhar == null:
			_imagem_olhar = _folhas["olhar"].get_image()
		var lado := _imagem_olhar.get_width()/6
		var inicio := Vector2i(quadro % 6, quadro / 6) * lado
		var centro := Vector2.ZERO
		var quantidade := 0
		for y in range(int(lado*.09),int(lado*.45)):
			for x in range(int(lado*.09),int(lado*.91)):
				var pixel := _imagem_olhar.get_pixelv(inicio + Vector2i(x, y))
				if pixel.a > 0.5 and pixel.g > 0.7 and pixel.g > pixel.r * 1.25 and pixel.g > pixel.b * 1.15:
					centro += Vector2(x, y)
					quantidade += 1
		_cache_olhos[quadro] = centro / quantidade if quantidade > 0 else Vector2(lado*.5,lado*.27)
	var metade := Vector2(sprite.texture.get_width()/6.0,sprite.texture.get_height()/4.0)*.5
	return sprite.position + (Vector2(_cache_olhos[quadro]) - metade) * sprite.scale

func _animar_invocacao() -> void:
	if not is_instance_valid(_efeito) or not is_instance_valid(_luz_olhos):
		return
	var olhos := _origem_olhos()
	var destino := to_local(_centro_ruina)
	# Um anel nasce no rosto, cresce em todas as direções e assenta na área marcada.
	var progresso := clampf(_tempo / 0.8, 0, 1)
	_efeito.position = olhos.lerp(destino, progresso)
	_efeito.material.set_shader_parameter("invocacao",maxf(.04,progresso))
	_efeito.material.set_shader_parameter("relogio",_tempo)
	_efeito.z_as_relative = progresso < 1
	_efeito.z_index = 4 if progresso < 1 else Profundidade.Z_CHAO + 35
	_efeito.modulate.a = 1.0
	_luz_olhos.position = olhos
	_luz_olhos.energy = 1.0 + 0.3 * sin(_tempo * 12)
	_luz_circulo.energy = 0.6 + 0.35 * clampf(_tempo / float(AVISOS.ruina), 0, 1)

func _pontos_ataque() -> PackedVector2Array:
	if ataque_atual == "bote":
		var lateral := _direcao.orthogonal() * 20
		return PackedVector2Array([-lateral, lateral, lateral + _direcao * _distancia_bote, -lateral + _direcao * _distancia_bote])
	if ataque_atual in ["cauda", "ruina"]:
		var circulo := PackedVector2Array()
		for i in 48:
			circulo.append(Vector2.from_angle(TAU * i / 48) * (RAIO_RUINA if ataque_atual == "ruina" else ALCANCE_CAUDA))
		return circulo
	var pontos := PackedVector2Array([Vector2.ZERO])
	var raio := ALCANCE_OLHAR if ataque_atual == "olhar" else ALCANCE_GARRAS
	var abertura := MEIA_ABERTURA_OLHAR if ataque_atual == "olhar" else PI / 3
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
	if ataque_atual == "ruina":
		if ponto.distance_to(_centro_ruina) <= RAIO_RUINA and alvo.has_method("aplicar_petrificacao_fatal"):
			alvo.aplicar_petrificacao_fatal()
		return
	if not Geometry2D.is_point_in_polygon(ponto - global_position, _pontos_ataque()) or not _caminho_livre(ponto):
		return
	if ataque_atual == "olhar":
		if alvo.has_method("direcao_apontada") and alvo.has_method("aplicar_petrificacao"):
			var para_medusa := (global_position - alvo.global_position).normalized()
			if alvo.direcao_apontada().dot(para_medusa) > 0.25:
				alvo.aplicar_petrificacao(DURACAO_PEDRA)
	else:
		alvo.receber_dano(roundi(dano * (1.2 if ataque_atual == "cauda" else 1.0)), (alvo.global_position - global_position).normalized() * (230 if ataque_atual == "cauda" else 140))

func _atingir_bote(inicio: Vector2, fim: Vector2) -> void:
	if _acertou:
		return
	var alvo := obter_jogador()
	if alvo == null or alvo.get("estaMorto") == true:
		return
	var ponto := alvo.global_position + Vector2(0, 9)
	if Geometry2D.get_closest_point_to_segment(ponto, inicio, fim).distance_to(ponto) <= 25 and _caminho_livre(ponto):
		_acertou = true
		alvo.receber_dano(roundi(dano * 1.4), _direcao * 260)

func _recuperar() -> void:
	_limpar_efeitos()
	velocity = Vector2.ZERO
	estado = Estado.RECUPERANDO
	_tempo = 0

func _definir_linha(rumo: Vector2) -> void:
	_linha = (2 if rumo.x > 0 else 3) if absf(rumo.x) > absf(rumo.y) else (0 if rumo.y >= 0 else 1)

func _tocar(pagina: String, quadro: int) -> void:
	sprite.texture = _folhas[pagina]
	sprite.hframes = 6
	sprite.vframes = 4
	sprite.frame = _linha * 6 + clampi(quadro, 0, 5)
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
	for efeito in [_luz_circulo, _luz_olhos, _rotulo_ruina]:
		if is_instance_valid(efeito):
			efeito.queue_free()
	_rotulo_ruina = null
	_luz_circulo = null
	_luz_olhos = null

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
