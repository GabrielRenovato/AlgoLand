extends "inimigo_base.gd"

const AreaDanoChefe := preload("res://codigo/inimigos/area_dano_chefe.gd")
const Aviso := preload("res://codigo/efeitos/aviso_ataque.gd")
const TEXTURA_LUZ := preload("res://recursos/luz/luz_radial.tres")
const AVISO_VERDE := preload("res://recursos/personagens/aviso_ruina_medusa.gdshader")
const RUINA_NITIDA := preload("res://recursos/personagens/ruina_medusa.gdshader")
const TELA_RUINA := preload("res://recursos/personagens/tela_ruina_medusa.tres")
const CanalMedusa := preload("res://codigo/efeitos/canal_medusa.gd")
const TIPOS := ["garras", "cauda", "bote", "olhar", "ruina"]
const AVISOS := {"garras": 0.38, "cauda": 0.56, "bote": 0.66, "olhar": 0.95, "ruina": 2.2}
const DURACOES := {"garras": 0.4, "cauda": 0.5, "bote": 0.65, "olhar": 0.45, "ruina": 0.65}
const RAIO_RUINA := 180.0
const ALCANCE_GARRAS := 65.0
const ALCANCE_CAUDA := 95.0
const ALCANCE_OLHAR := 260.0
const MEIA_ABERTURA_OLHAR := PI / 3.0
const DURACAO_PEDRA := 0.85
const RECUPERACOES := {"garras": 0.55, "cauda": 0.72, "bote": 0.65, "olhar": 0.75, "ruina": 1.0}
const MULT_DANO_EXPOSTA := 1.25
const MULT_DANO_RUINA := 2.25
enum Estado { LIVRE, AVISANDO, ATACANDO, RECUPERANDO, ENTRE_GOLPES }

var estado := Estado.LIVRE
var ataque_atual := "garras"
var _tempo := 0.0
var _recarga := 0.4
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
var _limiares_ruina: Array[float] = [0.6, 0.25]
var _proxima_ruina := 0
var _ruina_pendente := false
var fase := 1
var _sequencia: Array[String] = []
var _padroes := 0
var _aviso_atual := 0.45
var _acompanhar_preparo := false
var _alvo_ataque: Node2D
var _atingidos: Dictionary = {}
var _rotulo_exposta: Label
var _rotulo_ruina: Label
var _luz_circulo: PointLight2D
var _luz_olhos: PointLight2D
var _canal: Node2D
var _animacao_fluida := preload("res://codigo/inimigos/animacao_fluida_medusa.gd").new()
var _fracao_animacao := 0.0
var _poses_redesenhadas := preload("res://codigo/inimigos/poses_medusa.gd").new()

func _ready() -> void:
	eh_chefe = true
	nome_chefe = "MEDUSA"
	super()
	for pagina in ["movimento", "garras", "cauda", "bote", "olhar"]:
		_folhas[pagina] = load("res://assets/inimigos/medusa/" + pagina + ".png")
	_area_dano = AreaDanoChefe.new()
	add_child(_area_dano)
	_tocar("movimento", 0)
	_rotulo_exposta = Label.new()
	_rotulo_exposta.text = "EXPOSTA"
	_rotulo_exposta.position = Vector2(-100, -130)
	_rotulo_exposta.size = Vector2(200, 16)
	_rotulo_exposta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rotulo_exposta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rotulo_exposta.z_index = 6
	_rotulo_exposta.add_theme_font_override("font", load("res://assets/ui/Planes_ValMore.ttf"))
	_rotulo_exposta.add_theme_font_size_override("font_size", 8)
	_rotulo_exposta.add_theme_color_override("font_color", Color("f0d28c"))
	_rotulo_exposta.add_theme_color_override("font_outline_color", Color("241b22"))
	_rotulo_exposta.add_theme_constant_override("outline_size", 1)
	_rotulo_exposta.hide()
	add_child(_rotulo_exposta)

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
		var repouso := (1.0 - cos(Time.get_ticks_msec() / 700.0 * PI)) * 0.5
		_tocar("movimento", _passos / 7.0 if global_position.distance_to(inicio) > 0.01 else repouso)
		_recarga = maxf(0, _recarga - delta)
		if _ruina_pendente:
			_sequencia.clear()
			fase = mini(3, _proxima_ruina + 2)
			if iniciar_ataque("ruina", alvo.global_position):
				_proxima_ruina += 1
				_ruina_pendente = false
		elif _recarga <= 0 and _caminho_livre(alvo.global_position):
			_iniciar_padrao(alvo)
		return
	_atualizar_efeitos(delta)
	if esta_morto:
		return
	_tempo += delta
	match estado:
		Estado.AVISANDO:
			_atualizar_mira_preparo()
			_tocar("olhar" if ataque_atual == "ruina" else ataque_atual, quadro_preparo(_tempo / _aviso_atual))
			if is_instance_valid(_aviso):
				_aviso.animar(_tempo)
			if ataque_atual == "ruina":
				_animar_invocacao()
			if _tempo >= _aviso_atual:
				estado = Estado.ATACANDO
				_tempo = 0
				_aviso.hide()
		Estado.ATACANDO:
			var duracao: float = DURACOES[ataque_atual]
			_tocar("olhar" if ataque_atual == "ruina" else ataque_atual, quadro_golpe(_tempo / duracao))
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
					_canal.atualizar(_origem_olhos(), to_local(_centro_ruina), float(AVISOS.ruina), _tempo / duracao)
				else:
					_efeito.frame = clampi(int(_tempo / duracao * 6), 0, 5)
			if estado == Estado.ATACANDO and _tempo >= duracao:
				_recuperar()
		Estado.ENTRE_GOLPES:
			_tocar(ataque_atual, quadro_recuperacao(_tempo / intervalo_combo()))
			if _tempo >= intervalo_combo():
				_continuar_combo()
		Estado.RECUPERANDO:
			_tocar("olhar" if ataque_atual == "ruina" else ataque_atual, quadro_recuperacao(_tempo / float(RECUPERACOES[ataque_atual])))
			if _tempo >= float(RECUPERACOES[ataque_atual]):
				estado = Estado.LIVRE
				esta_atacando = false
				_rotulo_exposta.hide()
				_recarga = 0.08 if fase == 1 else 0.04

func _escolher_ataque(destino: Vector2) -> String:
	var para_alvo := destino - global_position
	var distancia := para_alvo.length()
	# Cada quarto padrão oferece o olhar: distância sozinha não determina a luta.
	if _padroes % 4 == 3 and distancia <= ALCANCE_OLHAR:
		return "olhar"
	if distancia > ALCANCE_CAUDA:
		return "bote"
	if distancia <= ALCANCE_GARRAS:
		if para_alvo.normalized().dot(_direcao) < -0.25:
			return "cauda"
		return "garras"
	return "cauda"

func _iniciar_padrao(alvo: Node2D) -> void:
	var tipo := _escolher_ataque(alvo.global_position)
	_sequencia.clear()
	if tipo == "garras":
		if fase >= 2 or _padroes % 2 == 1:
			_sequencia.append("garras" if fase == 3 or _padroes % 2 == 1 else "cauda")
		if fase == 3:
			_sequencia.append("cauda")
	elif tipo == "bote" and fase >= 2:
		_sequencia.append("garras")
		if fase == 3:
			_sequencia.append("cauda")
	_padroes += 1
	iniciar_ataque(tipo, alvo.global_position, true)
	_alvo_ataque = alvo

func intervalo_combo() -> float:
	return 0.24 if fase == 1 else (0.22 if fase == 2 else 0.20)

func _continuar_combo() -> void:
	var alvo := _alvo_ataque
	if _ruina_pendente or not _jogador_valido(alvo) or _sequencia.is_empty():
		_sequencia.clear()
		_recuperar()
		return
	var tipo: String = _sequencia.pop_front()
	var alcance := ALCANCE_GARRAS if tipo == "garras" else ALCANCE_CAUDA
	# Sair do alcance quebra a pressão e garante a janela de contra-ataque.
	if global_position.distance_to(alvo.global_position) > alcance + 12:
		_sequencia.clear()
		_recuperar()
		return
	estado = Estado.LIVRE
	if not iniciar_ataque(tipo, alvo.global_position, true):
		_sequencia.clear()
		_recuperar()
	else:
		_alvo_ataque = alvo

func _atualizar_mira_preparo() -> void:
	# Segue apenas a posição observada no começo do gesto. Nunca lê inputs/esquiva.
	if not _acompanhar_preparo or _tempo >= _aviso_atual * 0.55 or ataque_atual in ["cauda", "ruina"]:
		return
	if not _jogador_valido(_alvo_ataque):
		return
	var para_alvo := _alvo_ataque.global_position - global_position
	if para_alvo.length_squared() < 0.01:
		return
	_direcao = para_alvo.normalized()
	_definir_linha(_direcao)
	if ataque_atual == "bote":
		_distancia_bote = clampf(para_alvo.length() + 32, 100, 260)
	_aviso.definir_area(_pontos_ataque())

static func quadro_preparo(progresso: float) -> float:
	return clampf(progresso * 3.0, 0.0, 2.5)

static func quadro_golpe(progresso: float) -> float:
	return 3.0 + clampf(progresso, 0.0, 1.0) * 2.0

static func quadro_recuperacao(progresso: float) -> float:
	return 5.0 + smoothstep(0.65, 1.0, progresso)

func receber_dano(quantidade_dano: int, forca_knockback: Vector2 = Vector2.ZERO) -> void:
	var quantidade := roundi(quantidade_dano * MULT_DANO_EXPOSTA) if estado == Estado.RECUPERANDO else quantidade_dano
	super(quantidade, forca_knockback)

func _caminho_livre(destino: Vector2) -> bool:
	return get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(global_position, destino, 64)).is_empty()

func iniciar_ataque(tipo: String, destino: Vector2, acompanhar_preparo := false) -> bool:
	if estado != Estado.LIVRE or esta_morto or esta_congelado() or not TIPOS.has(tipo):
		return false
	_limpar_efeitos()
	_rotulo_exposta.hide()
	if not acompanhar_preparo:
		_sequencia.clear()
	_acompanhar_preparo = acompanhar_preparo
	_alvo_ataque = obter_jogador()
	_aviso_atual = float(AVISOS[tipo])
	# Finalizador retardado: a antecipação permanece visível por mais tempo.
	if tipo == "cauda" and fase >= 2 and _sequencia.is_empty() and _padroes % 2 == 1:
		_aviso_atual = 0.95
	_atingidos.clear()
	ataque_atual = tipo
	_direcao = (destino - global_position).normalized()
	if _direcao == Vector2.ZERO:
		_direcao = Vector2.DOWN
	_definir_linha(_direcao)
	_origem_bote = global_position
	_tocar("olhar" if tipo == "ruina" else tipo, 0)
	_distancia_bote = clampf(global_position.distance_to(destino) + 40, 100, 260)
	_acertou = false
	_tempo = 0
	estado = Estado.AVISANDO
	esta_atacando = true
	velocity = Vector2.ZERO
	if tipo == "ruina":
		# A marca fica no local em que o jogador estava; não o persegue durante a fuga.
		_centro_ruina = destino + Vector2(0, 9)
	if tipo in ["ruina", "olhar"]:
		_rotulo_ruina = Label.new()
		_rotulo_ruina.text = "RUINA: SAIA OU ESQUIVE" if tipo == "ruina" else "OLHAR: VIRE-SE OU SAIA"
		if tipo == "ruina" and _ruina_pendente:
			_rotulo_ruina.text = "FASE %d: SAIA OU ESQUIVE" % fase
		_rotulo_ruina.position = Vector2(-100, -130)
		_rotulo_ruina.size = Vector2(200, 16)
		_rotulo_ruina.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_rotulo_ruina.z_index = 6
		_rotulo_ruina.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rotulo_ruina.add_theme_font_override("font", load("res://assets/ui/Planes_ValMore.ttf"))
		_rotulo_ruina.add_theme_font_size_override("font_size", 8)
		_rotulo_ruina.add_theme_color_override("font_color", Color(0.6, 1, 0.7))
		_rotulo_ruina.add_theme_color_override("font_outline_color", Color(0.08, 0.12, 0.1))
		_rotulo_ruina.add_theme_constant_override("outline_size", 1)
		add_child(_rotulo_ruina)
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
	_efeito.texture = TELA_RUINA if tipo == "ruina" else load("res://assets/efeitos/medusa/" + tipo + ".png")
	_efeito.hframes = 6
	_efeito.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_efeito.visible = false
	# Os efeitos passam atrás da silhueta, inclusive durante a canalização.
	_efeito.z_index = -1
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
		# O rastro acompanha o contato sem encobrir as mãos e o tronco.
		_efeito.scale = Vector2.ONE * (0.4 if _poses_redesenhadas.possui("garras") else 0.65)
		_efeito.modulate.a = 0.65 if _poses_redesenhadas.possui("garras") else 1.0
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
		_canal = CanalMedusa.new()
		_canal.z_index = -1
		add_child(_canal)
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
	# Âncoras anatômicas da folha de invocação; brilhos das cobras não são olhos do rosto.
	const OLHOS := [
		Vector2(84, 59), Vector2(80, 59), Vector2(80, 60), Vector2(82, 58), Vector2(81, 59), Vector2(80, 59),
		Vector2(80, 52), Vector2(80, 52), Vector2(80, 52), Vector2(80, 52), Vector2(80, 52), Vector2(80, 52),
		Vector2(109, 50), Vector2(107, 51), Vector2(107, 51), Vector2(109, 50), Vector2(112, 50), Vector2(106, 50),
		Vector2(58, 48), Vector2(60, 48), Vector2(58, 48), Vector2(55, 48), Vector2(62, 48), Vector2(62, 48),
	]
	var metade := Vector2(sprite.texture.get_width() / float(sprite.hframes), sprite.texture.get_height() / 4.0) * 0.5
	var coluna: float = float(sprite.frame % sprite.hframes) * 6.0 / sprite.hframes + _fracao_animacao
	var indice := _linha * 6 + int(coluna)
	var proximo := _linha * 6 + (int(coluna) + 1) % 6
	var olhos: Vector2 = OLHOS[indice].lerp(OLHOS[proximo], fposmod(coluna, 1.0))
	return sprite.position + (olhos - metade) * sprite.scale

func _animar_invocacao() -> void:
	if not is_instance_valid(_efeito) or not is_instance_valid(_luz_olhos):
		return
	var olhos := _origem_olhos()
	var destino := to_local(_centro_ruina)
	# A semente sai dos olhos; a marca cresce no chão depois de chegar ao destino.
	var viagem := clampf(_tempo / 0.45, 0, 1)
	var progresso := clampf((_tempo - 0.45) / 0.65, 0, 1)
	_efeito.position = olhos.lerp(destino, viagem).round()
	_efeito.material.set_shader_parameter("invocacao",maxf(.04,progresso))
	_efeito.material.set_shader_parameter("relogio",_tempo)
	_efeito.z_as_relative = viagem < 1
	_efeito.z_index = -1 if viagem < 1 else Profundidade.Z_CHAO + 35
	_canal.atualizar(olhos, destino, _tempo)
	_efeito.modulate.a = 1.0
	_luz_olhos.position = olhos
	_luz_olhos.energy = 0.4 + 0.12 * sin(_tempo * 12)
	_luz_circulo.energy = 0.6 + 0.35 * clampf(_tempo / float(AVISOS.ruina), 0, 1)

func _pontos_ataque() -> PackedVector2Array:
	if ataque_atual == "bote":
		var lateral := _direcao.orthogonal() * 25
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

func _jogador_valido(alvo: Variant) -> bool:
	return is_instance_valid(alvo) and alvo is Node2D and alvo.get_world_2d() == get_world_2d() and alvo.get("estaMorto") != true and alvo.get("caido") != true

func _alvos_validos() -> Array[Node2D]:
	var alvos: Array[Node2D] = []
	for alvo in get_tree().get_nodes_in_group("jogadores"):
		if alvo is Node2D and _jogador_valido(alvo):
			alvos.append(alvo)
	if alvos.is_empty() and get_tree().current_scene != null:
		var alvo := get_tree().current_scene.get_node_or_null("Jogador") as Node2D
		if _jogador_valido(alvo):
			alvos.append(alvo)
	return alvos

func obter_jogador() -> Node2D:
	var agora := Time.get_ticks_msec()
	if agora >= _proxima_escolha_alvo or not _jogador_valido(_jogador_cache):
		_proxima_escolha_alvo = agora + 500
		_jogador_cache = null
		var menor := INF
		for alvo in _alvos_validos():
			var distancia := global_position.distance_squared_to(alvo.global_position)
			if distancia < menor:
				menor = distancia
				_jogador_cache = alvo
	return _jogador_cache

func _atingir_area() -> void:
	if _acertou:
		return
	_acertou = true
	for alvo in _alvos_validos():
		var ponto := alvo.global_position + Vector2(0, 9)
		if ataque_atual == "ruina":
			if alvo.get("esta_em_dash") == true:
				continue
			if ponto.distance_to(_centro_ruina) <= RAIO_RUINA:
				# Dano normal respeita esquiva, guarda e invulnerabilidade do jogador.
				alvo.receber_dano(roundi(dano * MULT_DANO_RUINA), (ponto - _centro_ruina).normalized() * 230)
			continue
		if not Geometry2D.is_point_in_polygon(ponto - global_position, _pontos_ataque()) or not _caminho_livre(ponto):
			continue
		if ataque_atual == "olhar":
			if alvo.has_method("direcao_apontada") and alvo.has_method("aplicar_petrificacao"):
				var para_medusa := (global_position - alvo.global_position).normalized()
				if alvo.direcao_apontada().dot(para_medusa) > 0.25:
					alvo.aplicar_petrificacao(DURACAO_PEDRA)
		else:
			alvo.receber_dano(roundi(dano * (1.2 if ataque_atual == "cauda" else 1.0)), (alvo.global_position - global_position).normalized() * (230 if ataque_atual == "cauda" else 140))

func _atingir_bote(inicio: Vector2, fim: Vector2) -> void:
	for alvo in _alvos_validos():
		if _atingidos.has(alvo.get_instance_id()):
			continue
		var ponto := alvo.global_position + Vector2(0, 9)
		if Geometry2D.get_closest_point_to_segment(ponto, inicio, fim).distance_to(ponto) <= 25 and _caminho_livre(ponto):
			_acertou = true
			_atingidos[alvo.get_instance_id()] = true
			alvo.receber_dano(roundi(dano * 1.4), _direcao * 260)

func _recuperar() -> void:
	_limpar_efeitos()
	velocity = Vector2.ZERO
	_tempo = 0
	if not _sequencia.is_empty() and not _ruina_pendente:
		estado = Estado.ENTRE_GOLPES
	else:
		_sequencia.clear()
		estado = Estado.RECUPERANDO
		_rotulo_exposta.show()

func _definir_linha(rumo: Vector2) -> void:
	_linha = (2 if rumo.x > 0 else 3) if absf(rumo.x) > absf(rumo.y) else (0 if rumo.y >= 0 else 1)

func _tocar(pagina: String, quadro: float) -> void:
	if _poses_redesenhadas.possui(pagina):
		var pose := quadro
		if estado == Estado.AVISANDO:
			pose = _poses_redesenhadas.preparo(_tempo / _aviso_atual)
		elif estado == Estado.ATACANDO:
			pose = _poses_redesenhadas.golpe(_tempo / float(DURACOES[ataque_atual]))
		elif estado == Estado.RECUPERANDO:
			pose = _poses_redesenhadas.recuperacao(_tempo / float(RECUPERACOES[ataque_atual]))
		elif estado == Estado.ENTRE_GOLPES:
			pose = _poses_redesenhadas.recuperacao(_tempo / intervalo_combo())
		_poses_redesenhadas.aplicar(sprite, pagina, _linha, pose)
		_fracao_animacao = 0
		_area_dano.acompanhar(sprite)
		_atualizar_ordem_desenho()
		return
	sprite.texture = _folhas[pagina]
	sprite.hframes = 6
	sprite.vframes = 4
	var posicao := fposmod(quadro, 6.0)
	_fracao_animacao = fposmod(posicao, 1.0)
	sprite.frame = _linha * 6 + int(posicao)
	_animacao_fluida.aplicar(sprite, pagina, _fracao_animacao)
	var quadro_visual: int = sprite.frame
	if _fracao_animacao >= 0.5:
		sprite.frame = _linha * 6 + (int(posicao) + 1) % 6
	_area_dano.acompanhar(sprite)
	sprite.frame = quadro_visual
	_atualizar_ordem_desenho()

func ponto_de_acerto_proximo(origem: Vector2) -> Vector2:
	return _area_dano.ponto_proximo(origem)

func forcar_ataque_debug(tipo: String) -> bool:
	if not OS.is_debug_build() or esta_morto:
		return false
	_sequencia.clear()
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
	for efeito in [_luz_circulo, _luz_olhos, _rotulo_ruina, _canal]:
		if is_instance_valid(efeito):
			efeito.hide()
			efeito.queue_free()
	_rotulo_ruina = null
	_luz_circulo = null
	_luz_olhos = null
	_canal = null

func morrer() -> void:
	if esta_morto:
		return
	esta_morto = true
	_sequencia.clear()
	_rotulo_exposta.hide()
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
