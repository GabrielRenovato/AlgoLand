extends "inimigo_base.gd"

## Chefe grande com três golpes distintos e preparação visível antes do dano.
const AreaGolpe := preload("res://codigo/efeitos/area_ataque_dragao.gd")
const GeometriaGolpe := preload("res://codigo/efeitos/geometria_ataque_dragao.gd")
const ChuvaFogo := preload("res://codigo/efeitos/chuva_fogo_dragao.gd")
const ATAQUES := ["sopro", "cauda", "asas"]
const TIPOS_ATAQUE := ["sopro", "cauda", "asas", "patada"]
const ALCANCES := {"sopro": 150.0, "cauda": 82.0, "asas": 112.0, "patada": 65.0}
const AVISOS := {"sopro": 0.9, "cauda": 0.75, "asas": 1.0, "patada": 0.32}
const DURACOES := GeometriaGolpe.DURACOES
const MULT_DANO := {"sopro": 1.6, "cauda": 1.8, "asas": 0.8, "patada": 0.6}
const EMPURRAO := {"sopro": 100.0, "cauda": 240.0, "asas": 380.0, "patada": 480.0}
enum Estado { LIVRE, PREPARANDO, ATACANDO, RECUPERANDO, SUBINDO, CHUVA, DESCENDO }

var estado := Estado.LIVRE
var ataque_atual := "sopro"
var _proximo_ataque := 0
var _recarga := 1.5
var _recarga_patada := 0.0
var _combo_sopro := false
var _tempo_estado := 0.0
var _tempo_animacao := 0.0
var _direcao_golpe := Vector2.DOWN
var _linha := 0
var _causou_dano := false
var _area_golpe: Node2D
var _folhas := {}
var _marcas_especial := [false, false]
var _especiais_pendentes := 0
var _chuva: Node2D
var _posicao_sprite := Vector2(0, -46)
var _tempo_especial := 0.0
var _mapa_especial := PackedVector2Array()
var _area_dano: Area2D
var _contorno_dano: Polygon2D
var _poligonos_dano := {}
var _formas_dano := {}
var _colisores_dano: Array[CollisionShape2D] = []
var _ultimo_contorno_dano := ""
## Base das patas por vista; a ponta da cauda não define a profundidade.
const BASE_PATAS := [10.0, 0.0, 1.0, -4.0]

func _ready() -> void:
	eh_chefe = true
	nome_chefe = "DRAGAO VERMELHO"
	super()
	for pagina in ["movimento", "sopro", "cauda", "asas", "voo", "patada"]:
		_folhas[pagina] = load("res://assets/inimigos/dragao_vermelho/" + pagina + ".png")
	_area_dano = Area2D.new()
	_area_dano.name = "AreaDanoDragao"
	_area_dano.collision_layer = 4
	_area_dano.collision_mask = 0
	_area_dano.monitoring = false
	_area_dano.add_to_group("hurtbox_inimigo")
	_contorno_dano = Polygon2D.new()
	_contorno_dano.visible = false
	_area_dano.add_child(_contorno_dano)
	add_child(_area_dano)
	_tocar_quadro("movimento", 0)
	_atualizar_ordem_desenho()

func aplicar_dano_contato() -> void:
	# O dragão só causa dano pelos impactos das três habilidades.
	pass

func _atualizar_ordem_desenho() -> void:
	altura_pes = BASE_PATAS[_linha]
	var pes := to_global(Vector2(0, altura_pes)).y
	z_index = Profundidade.z_de(pes)
	var alvo := obter_jogador()
	if alvo == null:
		return
	var pes_alvo := alvo.global_position.y + Profundidade.PES_JOGADOR
	var z_alvo := Profundidade.z_de(pes_alvo)
	# A quantização e os limites do z podem pôr os dois na mesma faixa.
	# Desempatar pelos pés reais mantém as patas atrás do jogador que está na frente.
	if z_index == z_alvo:
		z_index = alvo.z_index - Profundidade.NIVEIS if pes <= pes_alvo else alvo.z_index + Profundidade.NIVEIS

func _physics_process(delta: float) -> void:
	if esta_morto:
		return
	_atualizar_ordem_desenho()
	_registrar_especiais()
	if estado in [Estado.SUBINDO, Estado.CHUVA, Estado.DESCENDO]:
		_atualizar_especial(delta)
		return
	if _especiais_pendentes > 0 and not esta_congelado() and _recarga <= 1.5:
		if _iniciar_especial():
			return
	if esta_congelado():
		_atualizar_efeitos(delta)
		velocity = Vector2.ZERO
		return
	_tempo_animacao += delta
	_recarga_patada = maxf(0, _recarga_patada - delta)
	if estado == Estado.LIVRE:
		# Perto do jogador, um obstáculo não pode desligar a perseguição e os ataques ao mesmo tempo.
		var raio_original := raio_parada
		var alvo_rota := obter_jogador()
		if alvo_rota != null and not _caminho_livre(alvo_rota.global_position):
			raio_parada = 0.0
		super(delta)
		raio_parada = raio_original
		if esta_morto or esta_congelado():
			return
		var alvo := obter_jogador()
		if alvo:
			_definir_linha(alvo.global_position - global_position)
		var quadro := 2 + int(_tempo_animacao * 6) % 4 if velocity.length() > 2 else int(_tempo_animacao * 3) % 2
		_tocar_quadro("movimento", quadro)
		_recarga = maxf(0, _recarga - delta)
		if alvo == null or alvo.get("estaMorto") == true or not _caminho_livre(alvo.global_position):
			return
		if _recarga_patada <= 0 and to_local(alvo.global_position).length() <= ALCANCES["patada"]:
			iniciar_ataque("patada", alvo.global_position)
			return
		if _recarga <= 0:
			var tipo := _escolher_ataque(alvo.global_position)
			if not tipo.is_empty() and iniciar_ataque(tipo, alvo.global_position):
				_proximo_ataque = (ATAQUES.find(tipo) + 1) % ATAQUES.size()
		return
	_atualizar_efeitos(delta)
	if esta_morto:
		return
	_atualizar_ordem_desenho()
	velocity = Vector2.ZERO
	var tempo_anterior := _tempo_estado
	_tempo_estado += delta
	match estado:
		Estado.PREPARANDO:
			var progresso := clampf(_tempo_estado / float(AVISOS[ataque_atual]), 0, 1)
			_tocar_quadro(ataque_atual, mini(2, int(progresso * 3)))
			_area_golpe.atualizar(progresso, false, _tempo_estado)
			if progresso >= 1:
				estado = Estado.ATACANDO
				_tempo_estado = 0
		Estado.ATACANDO:
			_tocar_quadro(ataque_atual, 3 if _tempo_estado < float(DURACOES[ataque_atual]) * 0.6 else 4)
			_area_golpe.atualizar(1, true, _tempo_estado)
			if ataque_atual == "sopro":
				_aplicar_impacto()
			else:
				var instante := float(DURACOES[ataque_atual]) / 3.0
				if tempo_anterior < instante and _tempo_estado >= instante:
					_aplicar_impacto(instante + 0.0001)
			if _tempo_estado >= float(DURACOES[ataque_atual]):
				_cancelar_area()
				estado = Estado.RECUPERANDO
				_tempo_estado = 0
		Estado.RECUPERANDO:
			_tocar_quadro(ataque_atual, 5)
			if _combo_sopro and _tempo_estado >= 0.15:
				_combo_sopro = false
				estado = Estado.LIVRE
				esta_atacando = false
				var alvo := obter_jogador()
				if alvo != null and alvo.get("estaMorto") != true:
					iniciar_ataque("sopro", alvo.global_position)
				else:
					_recarga = 2.0
				return
			if _tempo_estado >= 0.6:
				estado = Estado.LIVRE
				esta_atacando = false
				_recarga = 2.0

func _escolher_ataque(destino: Vector2) -> String:
	var local := to_local(destino)
	for passo in ATAQUES.size():
		var tipo: String = ATAQUES[(_proximo_ataque + passo) % ATAQUES.size()]
		var origem := GeometriaGolpe.boca(_linha) if tipo == "sopro" else Vector2.ZERO
		if local.distance_to(origem) <= float(ALCANCES[tipo]):
			return tipo
	return ""

func _caminho_livre(destino: Vector2) -> bool:
	var consulta := PhysicsRayQueryParameters2D.create(global_position, destino, 64)
	return get_world_2d().direct_space_state.intersect_ray(consulta).is_empty()

func iniciar_ataque(tipo: String, destino: Vector2) -> bool:
	if esta_morto or esta_congelado() or estado != Estado.LIVRE or not TIPOS_ATAQUE.has(tipo):
		return false
	ataque_atual = tipo
	if tipo == "patada":
		_combo_sopro = true
		_recarga_patada = 4.5
	var destino_local := to_local(destino)
	_definir_linha(destino_local)
	var origem := GeometriaGolpe.boca(_linha) if tipo == "sopro" else Vector2.ZERO
	_direcao_golpe = (destino_local - origem).normalized()
	if _direcao_golpe == Vector2.ZERO:
		_direcao_golpe = Vector2.DOWN
	_tempo_estado = 0
	_causou_dano = false
	estado = Estado.PREPARANDO
	esta_atacando = true
	velocity = Vector2.ZERO
	_area_golpe = AreaGolpe.new()
	_area_golpe.tipo = tipo
	_area_golpe.direcao = _direcao_golpe
	_area_golpe.alcance = ALCANCES[tipo]
	_area_golpe.origem = origem
	if tipo == "sopro":
		var consulta := PhysicsRayQueryParameters2D.create(to_global(origem), to_global(origem + _direcao_golpe * ALCANCES[tipo]), 64)
		var parede := get_world_2d().direct_space_state.intersect_ray(consulta)
		if not parede.is_empty():
			_area_golpe.alcance = maxf(0, origem.distance_to(to_local(parede.position)) - 2.0)
	_area_golpe.chefe = self
	add_child(_area_golpe)
	return true

func _registrar_especiais() -> void:
	if esta_morto or vida_maxima <= 0:
		return
	for i in 2:
		var limite := 0.5 if i == 0 else 0.1
		var cruzou := vida < vida_maxima * limite if i == 0 else vida <= vida_maxima * limite
		if cruzou and not _marcas_especial[i]:
			_marcas_especial[i] = true
			_especiais_pendentes += 1

func _iniciar_especial() -> bool:
	var contorno := get_tree().current_scene.get_node_or_null("Terrains/LimiteArena/Contorno") as CollisionPolygon2D
	if contorno == null or contorno.polygon.size() < 3:
		return false
	var mapa := PackedVector2Array()
	for ponto in contorno.polygon:
		mapa.append(contorno.to_global(ponto))
	_mapa_especial = mapa
	_especiais_pendentes = maxi(0, _especiais_pendentes - 1)
	_cancelar_area()
	_combo_sopro = false
	_limpar_gelo_morte()
	estado = Estado.SUBINDO
	esta_atacando = true
	velocity = Vector2.ZERO
	_tempo_especial = 0
	_posicao_sprite = sprite.position
	_area_dano.set_deferred("monitorable", false)
	_chuva = ChuvaFogo.new()
	_chuva.chefe = self
	_chuva.centro_aviso = _centro_aviso_especial()
	_chuva.zona = ChuvaFogo.zona_centrada(mapa, _centro_aviso_especial())
	get_parent().add_child(_chuva)
	_chuva.hide()
	return true

func _centro_aviso_especial() -> Vector2:
	var alvo := obter_jogador()
	if alvo == null:
		return global_position
	var pes := alvo.get_node_or_null("CollisionShape2D") as CollisionShape2D
	return pes.global_position if pes != null else alvo.global_position

func _atualizar_especial(delta: float) -> void:
	_tempo_especial += delta
	velocity = Vector2.ZERO
	match estado:
		Estado.SUBINDO:
			_tocar_quadro("voo", mini(5, int(_tempo_especial * 5)))
			sprite.position = _posicao_sprite - Vector2(0, 220 * clampf(_tempo_especial / 1.2, 0, 1))
			_chuva.atualizar(_tempo_especial, false)
			if _tempo_especial >= 1.2:
				sprite.hide()
				_chuva.centro_aviso = _centro_aviso_especial()
				_chuva.definir_zona(ChuvaFogo.zona_centrada(_mapa_especial, _chuva.centro_aviso))
				_chuva.show()
				get_tree().call_group("hud", "anunciar", "CHUVA DE FOGO", "FUJA DA AREA VERMELHA", 1.2)
				estado = Estado.CHUVA
				_tempo_especial = 0
		Estado.CHUVA:
			_chuva.atualizar(maxf(0, _tempo_especial - ChuvaFogo.AVISO), _tempo_especial >= ChuvaFogo.AVISO)
			if _tempo_especial >= ChuvaFogo.AVISO + ChuvaFogo.DURACAO:
				_cancelar_chuva()
				sprite.show()
				estado = Estado.DESCENDO
				_tempo_especial = 0
		Estado.DESCENDO:
			_tocar_quadro("voo", maxi(0, 5 - int(_tempo_especial * 5)))
			sprite.position = _posicao_sprite - Vector2(0, 220 * (1.0 - clampf(_tempo_especial / 1.2, 0, 1)))
			if _tempo_especial >= 1.2:
				sprite.position = _posicao_sprite
				_area_dano.set_deferred("monitorable", true)
				estado = Estado.LIVRE
				esta_atacando = false
				_recarga = 2.0
				_tocar_quadro("movimento", 0)

func _cancelar_chuva() -> void:
	if is_instance_valid(_chuva):
		_chuva.queue_free()
	_chuva = null

func receber_dano(quantidade: int, empurrao: Vector2 = Vector2.ZERO) -> void:
	if estado in [Estado.SUBINDO, Estado.CHUVA, Estado.DESCENDO]:
		return
	super(quantidade, empurrao)

func receber_dano_efeito(quantidade: int, cor: Color) -> void:
	if estado in [Estado.SUBINDO, Estado.CHUVA, Estado.DESCENDO]:
		return
	super(quantidade, cor)

func forcar_ataque_debug(tipo: String) -> bool:
	if tipo == "chuva":
		if not OS.is_debug_build() or esta_morto or estado in [Estado.SUBINDO, Estado.CHUVA, Estado.DESCENDO]:
			return false
		return _iniciar_especial()
	if not OS.is_debug_build() or esta_morto or esta_congelado() or estado in [Estado.SUBINDO, Estado.CHUVA, Estado.DESCENDO] or not TIPOS_ATAQUE.has(tipo):
		return false
	var alvo := obter_jogador()
	if alvo == null:
		return false
	_cancelar_area()
	_combo_sopro = false
	estado = Estado.LIVRE
	return iniciar_ataque(tipo, alvo.global_position)

func _aplicar_impacto(instante: float = -1.0) -> void:
	if _causou_dano or esta_congelado() or esta_morto:
		return
	var alvo := obter_jogador()
	if alvo == null or ("invulneravel" in alvo and alvo.invulneravel) or not is_instance_valid(_area_golpe) or not _area_golpe.atinge_alvo(alvo, instante):
		return
	_causou_dano = true
	var rumo := (alvo.global_position - global_position).normalized()
	if rumo == Vector2.ZERO:
		rumo = _direcao_golpe
	alvo.receber_dano(maxi(1, roundi(obter_dano() * float(MULT_DANO[ataque_atual]))), rumo * float(EMPURRAO[ataque_atual]))
	_tremer_camera(2.0 if ataque_atual == "sopro" else 4.0, 0.2)

func _definir_linha(rumo: Vector2) -> void:
	_linha = (2 if rumo.x > 0 else 3) if absf(rumo.x) > absf(rumo.y) else (0 if rumo.y > 0 else 1)

func _tocar_quadro(pagina: String, quadro: int) -> void:
	sprite.texture = _folhas[pagina]
	sprite.hframes = 6
	sprite.vframes = 4
	sprite.frame = _linha * 6 + clampi(quadro, 0, 5)
	_atualizar_area_dano(pagina)
	_atualizar_ordem_desenho()

func _atualizar_area_dano(pagina: String) -> void:
	if _area_dano == null:
		return
	var chave := pagina + ":" + str(sprite.frame)
	_area_dano.transform = sprite.transform
	if chave == _ultimo_contorno_dano:
		return
	if not _poligonos_dano.has(chave):
		var imagem: Image = sprite.texture.get_image()
		var tamanho := Vector2i(imagem.get_width() / sprite.hframes, imagem.get_height() / sprite.vframes)
		var inicio := Vector2i(sprite.frame % sprite.hframes, sprite.frame / sprite.hframes) * tamanho
		var bitmap := BitMap.new()
		bitmap.create_from_image_alpha(imagem.get_region(Rect2i(inicio, tamanho)))
		var contornos := bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO, tamanho), 2.0)
		var maior := PackedVector2Array()
		for contorno in contornos:
			if contorno.size() > maior.size():
				maior = contorno
		# Pontas que se tocam por um único pixel podem produzir um contorno cruzado.
		# Nesse caso, um invólucro válido mantém a pose acertável sem perder a colisão.
		var vistos := {}
		var repetidos := false
		for ponto in maior:
			if vistos.has(ponto):
				repetidos = true
			vistos[ponto] = true
		if repetidos or Geometry2D.triangulate_polygon(maior).is_empty():
			maior = Geometry2D.convex_hull(maior)
		_poligonos_dano[chave] = maior
		var indices := Geometry2D.triangulate_polygon(maior)
		var formas: Array[Shape2D] = []
		for i in range(0, indices.size(), 3):
			var triangulo := ConvexPolygonShape2D.new()
			triangulo.points = PackedVector2Array([maior[indices[i]], maior[indices[i + 1]], maior[indices[i + 2]]])
			formas.append(triangulo)
		_formas_dano[chave] = formas
	_contorno_dano.position = sprite.get_rect().position
	_contorno_dano.polygon = _poligonos_dano[chave]
	var formas: Array = _formas_dano[chave]
	while _colisores_dano.size() < formas.size():
		var colisor := CollisionShape2D.new()
		_area_dano.add_child(colisor)
		_colisores_dano.append(colisor)
	for i in _colisores_dano.size():
		var colisor := _colisores_dano[i]
		colisor.disabled = i >= formas.size()
		if i < formas.size():
			colisor.position = _contorno_dano.position
			colisor.shape = formas[i]
	_ultimo_contorno_dano = chave

func _cancelar_area() -> void:
	if is_instance_valid(_area_golpe):
		_area_golpe.queue_free()
	_area_golpe = null

func ponto_de_acerto_proximo(origem_global: Vector2) -> Vector2:
	var poligono := _contorno_dano.polygon
	if poligono.size() < 3:
		return global_position
	if Geometry2D.is_point_in_polygon(_contorno_dano.to_local(origem_global), poligono):
		return origem_global
	var mais_perto := global_position
	var distancia := INF
	for i in poligono.size():
		var inicio := _contorno_dano.to_global(poligono[i])
		var fim := _contorno_dano.to_global(poligono[(i + 1) % poligono.size()])
		var ponto := Geometry2D.get_closest_point_to_segment(origem_global, inicio, fim)
		var atual := ponto.distance_squared_to(origem_global)
		if atual < distancia:
			distancia = atual
			mais_perto = ponto
	return mais_perto

func morrer() -> void:
	if esta_morto:
		return
	esta_morto = true
	_cancelar_chuva()
	if _area_dano != null:
		_area_dano.set_deferred("monitorable", false)
	_limpar_gelo_morte()
	_cancelar_area()
	velocity = Vector2.ZERO
	_tocar_som_morte()
	_ao_morrer_chefe()
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.8)
	await tween.finished
	inimigo_morreu.emit()
	queue_free()

func _exit_tree() -> void:
	_cancelar_area()
	_cancelar_chuva()
