extends "Inimigo-base.gd"

const AreaDanoChefe := preload("res://Codigos/Inimigos/area_dano_chefe.gd")
const Aviso := preload("res://Codigos/Efeitos/aviso_ataque.gd")
const TIPOS := ["investida", "pisao", "machado", "pisao_furia"]
const TEMPOS_AVISO := {"investida": 0.9, "pisao": 0.7, "machado": 0.45, "pisao_furia": 0.75}
const TEMPOS_GOLPE := {"investida": 0.7, "pisao": 0.4, "machado": 0.35, "pisao_furia": 0.5}
const RAIOS := {"pisao": 90.0, "machado": 65.0, "pisao_furia": 125.0}
const MULTIPLICADORES := {"investida": 1.4, "pisao": 1.15, "machado": 1.0, "pisao_furia": 1.9}
const BASE_PATAS := [2.0, 0.0, -4.0, -6.0]
enum Estado { LIVRE, PREPARANDO, ATACANDO, RECUPERANDO, RUGINDO }
var estado := Estado.LIVRE
var ataque_atual := "investida"
var _tempo := 0.0
var _recarga := 0.75
var _direcao := Vector2.DOWN
var _linha := 0
var _origem_investida := Vector2.ZERO
var _distancia_investida := 280.0
var _causou_dano := false
var _furia_usada := false
var _furia_ativa := false
var _fila_furia: Array[String] = []
var _folhas := {}
var _area_dano: Area2D
var _aviso: Node2D
var _impacto: Sprite2D
var _golpes_normais := 0
var _distancia_passos := 0.0
var _pontas_machado := {}
var _bordas_arco: Array[Vector2] = []

func _ready() -> void:
	eh_chefe = true
	nome_chefe = "MINOTAURO"
	super()
	for pagina in ["movimento", "caminhada", "investida", "pisao", "machado", "furia"]:
		_folhas[pagina] = load("res://inimigos/minotauro/" + pagina + ".png")
	_preparar_encaixe_machado()
	_area_dano = AreaDanoChefe.new()
	add_child(_area_dano)
	_tocar("movimento", 0)

func aplicar_dano_contato() -> void:
	pass

func _atualizar_ordem_desenho() -> void:
	altura_pes = BASE_PATAS[_linha]
	var pes := to_global(Vector2(0, altura_pes)).y
	z_index = Profundidade.z_de(pes)
	var jogador := obter_jogador()
	if jogador != null:
		var pes_alvo := jogador.global_position.y + Profundidade.PES_JOGADOR
		if z_index == Profundidade.z_de(pes_alvo):
			z_index = jogador.z_index - Profundidade.NIVEIS if pes <= pes_alvo else jogador.z_index + Profundidade.NIVEIS

func _physics_process(delta: float) -> void:
	if esta_morto:
		return
	_atualizar_ordem_desenho()
	if esta_congelado():
		_atualizar_efeitos(delta)
		velocity = Vector2.ZERO
		return
	if not _furia_usada and vida <= vida_maxima * 0.4:
		_iniciar_furia()
	if estado == Estado.LIVRE:
		var inicio_passo := global_position
		# Perto do jogador, um obstáculo não pode desligar a perseguição e os ataques ao mesmo tempo.
		var raio_original := raio_parada
		var alvo_rota := obter_jogador()
		if alvo_rota != null and not _caminho_livre(alvo_rota.global_position):
			raio_parada = 0.0
		super(delta)
		raio_parada = raio_original
		if esta_morto:
			return
		_recarga = maxf(0, _recarga - delta)
		var alvo := obter_jogador()
		if alvo == null:
			return
		_definir_linha(to_local(alvo.global_position))
		_animar_deslocamento(global_position - inicio_passo)
		if _furia_ativa:
			_executar_furia()
			return
		if _recarga <= 0 and _caminho_livre(alvo.global_position):
			var tipo := _escolher_ataque(alvo.global_position)
			if not tipo.is_empty() and iniciar_ataque(tipo, alvo.global_position):
				_golpes_normais += 1
		return
	_atualizar_efeitos(delta)
	if esta_morto:
		return
	var anterior := _tempo
	_tempo += delta
	var pagina := "pisao" if ataque_atual == "pisao_furia" else ataque_atual
	match estado:
		Estado.RUGINDO:
			_tocar("furia", mini(5, int(_tempo * 6)))
			if _tempo >= 0.9:
				_executar_furia()
		Estado.PREPARANDO:
			var duracao: float = 0.55 if _furia_ativa and ataque_atual == "investida" else TEMPOS_AVISO[ataque_atual]
			_tocar(pagina, mini(2, int(_tempo / duracao * 3)))
			_aviso.animar(_tempo)
			if _tempo >= duracao:
				estado = Estado.ATACANDO
				_tempo = 0
				_aviso.hide()
		Estado.ATACANDO:
			_tocar(pagina, 3 if _tempo < float(TEMPOS_GOLPE[ataque_atual]) * 0.6 else 4)
			if ataque_atual == "investida":
				var inicio := global_position
				var restante := maxf(0, _distancia_investida - global_position.distance_to(_origem_investida))
				velocity = _direcao * minf(480 if _furia_ativa else 420, restante / maxf(delta, 0.001))
				move_and_slide()
				_atingir_investida(inicio, global_position)
				if is_instance_valid(_impacto):
					_impacto.visible = true
					_impacto.frame = int(_tempo * 18) % 6
				if get_slide_collision_count() > 0 or global_position.distance_to(_origem_investida) >= _distancia_investida:
					_tremer_camera(3, 0.15)
					_recuperar()
			else:
				var instante := float(TEMPOS_GOLPE[ataque_atual]) / 3.0
				if anterior < instante and _tempo >= instante:
					_atingir_area()
				if is_instance_valid(_impacto):
					_impacto.visible = _tempo >= instante
					_impacto.frame = clampi(int((_tempo - instante) / (float(TEMPOS_GOLPE[ataque_atual]) - instante) * 6), 0, 5)
					if ataque_atual == "machado":
						_alinhar_arco_machado()
			if estado == Estado.ATACANDO and _tempo >= float(TEMPOS_GOLPE[ataque_atual]):
				_recuperar()
		Estado.RECUPERANDO:
			_tocar(pagina, 5)
			if _tempo >= (0.2 if _furia_ativa else 0.4):
				if _furia_ativa:
					_executar_furia()
				else:
					estado = Estado.LIVRE
					esta_atacando = false
					_recarga = 0.75

func _escolher_ataque(destino: Vector2) -> String:
	var distancia := to_local(destino).length()
	if distancia <= RAIOS["machado"]:
		return "pisao" if _golpes_normais % 3 == 2 else "machado"
	if distancia <= RAIOS["pisao"]:
		return "pisao"
	# Mesmo sem alcançar de uma vez, a investida fecha a distância até o jogador.
	return "investida"

func _caminho_livre(destino: Vector2) -> bool:
	var consulta := PhysicsRayQueryParameters2D.create(global_position, destino, 64)
	return get_world_2d().direct_space_state.intersect_ray(consulta).is_empty()

func iniciar_ataque(tipo: String, destino: Vector2) -> bool:
	if estado != Estado.LIVRE or esta_morto or esta_congelado() or not TIPOS.has(tipo):
		return false
	ataque_atual = tipo
	_direcao = (destino - global_position).normalized()
	if _direcao == Vector2.ZERO:
		_direcao = Vector2.DOWN
	_definir_linha(_direcao)
	_origem_investida = global_position
	_causou_dano = false
	_tempo = 0
	estado = Estado.PREPARANDO
	esta_atacando = true
	velocity = Vector2.ZERO
	_aviso = Aviso.new()
	_aviso.z_as_relative = false
	_aviso.z_index = Profundidade.Z_CHAO + 30
	get_parent().add_child(_aviso)
	_aviso.global_position = global_position
	var pontos := PackedVector2Array()
	if tipo == "investida":
		var lateral := _direcao.orthogonal() * 22
		pontos = PackedVector2Array([-lateral, lateral, lateral + _direcao * _distancia_investida, -lateral + _direcao * _distancia_investida])
	elif tipo == "machado":
		pontos = _cone(65, PI / 3)
	else:
		for i in 64:
			pontos.append(Vector2.from_angle(TAU * i / 64) * float(RAIOS[tipo]))
	_aviso.definir_area(pontos)
	_impacto = Sprite2D.new()
	var arquivo := "furia" if tipo == "pisao_furia" else tipo
	_impacto.texture = load("res://Efeitos/minotauro/" + arquivo + ".png")
	_impacto.hframes = 6
	_impacto.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_impacto.visible = false
	_impacto.z_as_relative = false
	_impacto.z_index = Profundidade.Z_CHAO + 25
	if tipo == "investida":
		_impacto.position = -_direcao * 22
		_impacto.rotation = _direcao.angle()
	else:
		_impacto.scale = Vector2.ONE * float(RAIOS[tipo]) * 2 / (128 * 0.875)
		if tipo == "machado":
			_impacto.z_as_relative = true
			_impacto.z_index = 2
	add_child(_impacto)
	return true

func _preparar_encaixe_machado() -> void:
	# Mede o aço da lâmina nas poses do golpe, sem confundir pele, tecido e cascos.
	var imagem: Image = _folhas["machado"].get_image()
	var lado := imagem.get_width() / 6
	var aco := [Color("3d4148"), Color("64656a"), Color("909394"), Color("c3c4b6"), Color("45515d"), Color("697580"), Color("9ba8af"), Color("e0ddd0")]
	for linha in 4:
		var sentido := -1 if linha == 3 else 1
		for quadro in [3, 4]:
			var extremo := -INF
			var ponta := Vector2(40 * sentido, -36)
			for y in lado:
				for x in lado:
					var local: Vector2 = Vector2(x - lado * 0.5, y - lado * 0.5) + sprite.position
					if local.x * sentido < 20 or local.y > -15:
						continue
					var cor := imagem.get_pixel(quadro * lado + x, linha * lado + y)
					if cor.a > 0.5 and aco.has(cor) and local.x * sentido > extremo:
						extremo = local.x * sentido
						ponta = local
			_pontas_machado[linha * 6 + quadro] = ponta
	var arco: Image = load("res://Efeitos/minotauro/machado.png").get_image()
	var largura := arco.get_width() / 6
	for quadro in 6:
		var borda := Vector2.ZERO
		var extremo := -1
		var alturas: Array[int] = []
		for x in largura:
			for y in arco.get_height():
				if arco.get_pixel(quadro * largura + x, y).a > 0.5:
					if x > extremo:
						extremo = x
						alturas.clear()
					if x == extremo:
						alturas.append(y)
		if not alturas.is_empty():
			var soma := 0.0
			for y in alturas:
				soma += y
			borda = Vector2(extremo - largura * 0.5, soma / alturas.size() - arco.get_height() * 0.5)
		_bordas_arco.append(borda)

func _alinhar_arco_machado() -> void:
	var sentido := Vector2.LEFT if _linha == 3 else Vector2.RIGHT
	_impacto.rotation = sentido.angle()
	var ponta: Vector2 = _pontas_machado.get(sprite.frame, Vector2(40 * sentido.x, -36))
	var borda := (_bordas_arco[_impacto.frame] * _impacto.scale).rotated(_impacto.rotation)
	_impacto.position = ponta + sentido * 8 - borda

func _atingir_investida(inicio: Vector2, fim: Vector2) -> void:
	var alvo := obter_jogador()
	if alvo != null:
		var forma := CircleShape2D.new()
		forma.radius = 22
		var perto := Geometry2D.get_closest_point_to_segment(alvo.global_position, inicio, fim)
		_aplicar_dano(alvo, forma, Transform2D(0, perto), 280)
	for inimigo in get_tree().get_nodes_in_group("enemy"):
		if inimigo == self or not is_instance_valid(inimigo) or inimigo.get("eh_chefe") == true or inimigo.get("esta_morto") == true:
			continue
		if Geometry2D.get_closest_point_to_segment(inimigo.global_position, inicio, fim).distance_to(inimigo.global_position) <= 28:
			inimigo.receber_dano_efeito(maxi(1, inimigo.vida), Color("eeb552"))

func _atingir_area() -> void:
	var alvo := obter_jogador()
	if alvo == null:
		return
	var forma: Shape2D
	if ataque_atual == "machado":
		var poligono := ConvexPolygonShape2D.new()
		poligono.points = _cone(65, PI / 3)
		forma = poligono
	else:
		var circulo := CircleShape2D.new()
		circulo.radius = RAIOS[ataque_atual]
		forma = circulo
	_aplicar_dano(alvo, forma, global_transform, 220)
	_tremer_camera(4, 0.2)

func _aplicar_dano(alvo: Node2D, forma: Shape2D, transformacao: Transform2D, empurrao: float) -> void:
	if _causou_dano or alvo.get("invulneravel") == true or alvo.get("estaMorto") == true:
		return
	var caminho := "CollisionShape2D" if ataque_atual in ["pisao", "pisao_furia"] else "AreaDano/CollisionShape2D"
	var colisor := alvo.get_node_or_null(caminho) as CollisionShape2D
	var forma_alvo: Shape2D
	var transformacao_alvo := alvo.global_transform
	if colisor != null and not colisor.disabled:
		forma_alvo = colisor.shape
		transformacao_alvo = colisor.global_transform
	else:
		var circulo := CircleShape2D.new()
		circulo.radius = 5
		forma_alvo = circulo
	if not forma.collide(transformacao, forma_alvo, transformacao_alvo):
		return
	var consulta := PhysicsRayQueryParameters2D.create(global_position, transformacao_alvo.origin, 64)
	if not get_world_2d().direct_space_state.intersect_ray(consulta).is_empty():
		return
	_causou_dano = true
	var rumo := (alvo.global_position - global_position).normalized()
	if rumo == Vector2.ZERO:
		rumo = _direcao
	alvo.receber_dano(roundi(obter_dano() * float(MULTIPLICADORES[ataque_atual])), rumo * empurrao)

func _cone(raio: float, abertura: float) -> PackedVector2Array:
	var pontos := PackedVector2Array([Vector2.ZERO])
	for i in 17:
		pontos.append(Vector2.from_angle(_direcao.angle() - abertura + abertura * 2 * i / 16) * raio)
	return pontos

func _recuperar() -> void:
	_limpar_efeitos()
	velocity = Vector2.ZERO
	estado = Estado.RECUPERANDO
	_tempo = 0

func _iniciar_furia() -> void:
	_limpar_efeitos()
	_furia_usada = true
	_furia_ativa = true
	_fila_furia.assign(["investida", "investida", "investida", "pisao_furia"])
	estado = Estado.RUGINDO
	esta_atacando = true
	_tempo = 0
	velocity = Vector2.ZERO
	get_tree().call_group("hud", "anunciar", "FURIA DO LABIRINTO", "DESVIE DAS INVESTIDAS", 1.3)

func _executar_furia() -> void:
	estado = Estado.LIVRE
	esta_atacando = false
	if _fila_furia.is_empty():
		_furia_ativa = false
		esta_atacando = false
		_recarga = 1.0
		return
	var alvo := obter_jogador()
	if alvo == null or alvo.get("estaMorto") == true:
		_fila_furia.clear()
		_furia_ativa = false
		return
	var tipo: String = _fila_furia[0]
	if not _caminho_livre(alvo.global_position):
		return
	if tipo != "investida" and to_local(alvo.global_position).length() > float(RAIOS[tipo]):
		return
	_fila_furia.pop_front()
	iniciar_ataque(tipo, alvo.global_position)

func forcar_ataque_debug(tipo: String) -> bool:
	if not OS.is_debug_build() or esta_morto or esta_congelado():
		return false
	_limpar_efeitos()
	_furia_ativa = false
	_fila_furia.clear()
	estado = Estado.LIVRE
	if tipo == "furia":
		_iniciar_furia()
		return true
	var alvo := obter_jogador()
	return iniciar_ataque(tipo, alvo.global_position) if alvo != null else false

func _definir_linha(rumo: Vector2) -> void:
	_linha = (2 if rumo.x > 0 else 3) if absf(rumo.x) > absf(rumo.y) else (0 if rumo.y >= 0 else 1)

func _animar_deslocamento(deslocamento: Vector2) -> void:
	if deslocamento.length() > 0.05:
		_distancia_passos = fposmod(_distancia_passos + deslocamento.length(), 48.0)
		_tocar("caminhada", int(_distancia_passos / 8.0))
	else:
		_tocar("movimento", int(Time.get_ticks_msec() / 400) % 2)

func _tocar(pagina: String, quadro: int) -> void:
	var colunas := 6
	sprite.texture = _folhas[pagina]
	sprite.hframes = colunas
	sprite.vframes = 4
	sprite.frame = _linha * colunas + clampi(quadro, 0, colunas - 1)
	_area_dano.acompanhar(sprite)
	_atualizar_ordem_desenho()

func ponto_de_acerto_proximo(origem: Vector2) -> Vector2:
	return _area_dano.ponto_proximo(origem)

func _limpar_efeitos() -> void:
	if is_instance_valid(_aviso):
		_aviso.queue_free()
	if is_instance_valid(_impacto):
		_impacto.queue_free()
	_aviso = null
	_impacto = null

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
