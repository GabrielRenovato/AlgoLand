extends Node

## Abertura das Clareiras da Chegada: invocação em cada nova tentativa (cerca de 10 s).
## Pode ser pulada com Esc, Enter ou toque. A entrada curta serve à restauração interna de checkpoints.
signal concluida

## Luz da invocação: brilho no chão e luz correndo pelas raízes. Serve ao jogador local e aos avatares dos outros jogadores.
class Luz extends Node2D:
	var pulso := 0.0
	func _process(_delta: float) -> void: queue_redraw()
	func _draw() -> void:
		var p := pulso
		if p <= 0.01: return
		for i in 4:
			draw_circle(Vector2(0, 6), 10.0 + i * 12.0 * p + 18.0 * maxf(p - 0.55, 0.0) * 4.0, Color(0.62, 0.95, 0.70, 0.10 * p / (1 + i * 0.5)))
		draw_arc(Vector2(0, 6), 24.0 + 70.0 * maxf(p - 0.55, 0.0) * 2.2, 0.0, TAU, 40, Color(0.8, 1.0, 0.8, 0.5 * p), 1.5)
		for k in 6:
			var a := k * TAU / 6.0 + 0.4
			var fim := Vector2(cos(a), sin(a) * 0.6) * (28.0 + 46.0 * p)
			draw_line(Vector2(0, 6), fim, Color(0.7, 1.0, 0.75, 0.55 * p), 1.0)

var cena: Node2D
var ativa := false
var _camada: CanvasLayer
var _cortina: ColorRect
var _barras: Array[ColorRect] = []
var _dica: Label
var _brilho: Luz
var _tween: Tween
var _pulso := 0.0
var _folhas: CPUParticles2D
var _poeira: CPUParticles2D
var _som: AudioStreamPlayer
var _chao := Vector2.ZERO
var _travou := false
var _heroi_3d := false

func iniciar(primeira: bool) -> void:
	if ativa: return
	ativa = true
	var jogador: CharacterBody2D = cena.jogador
	_heroi_3d = _detectar_heroi_3d(jogador)
	_montar_interface(primeira)
	if primeira:
		get_tree().set_meta("cinema_ativo", true)
		_travar(jogador)
		if _online():
			# Convidado: com a vigília em andamento a cena longa deixaria o jogador parado no meio do combate.
			if not cena.sessao.sou_host():
				for i in 12:
					if cena.vigilia_remota != -1: break
					await get_tree().create_timer(0.1).timeout
					if not ativa: return
			if cena.vigilia_remota == 1 or (is_instance_valid(cena.encontro) and cena.encontro.ativa):
				primeira = false
				_destravar(jogador)
			else:
				cena.sessao.enviar({"t": "invocacao", "andar": 1})
	_dica.visible = primeira
	if primeira:
		await _invocacao(jogador)
	else:
		await _entrada_curta()
	_encerrar()

## Há herói 3D no jogador? Ele tem os clipes de joelhos do Mixamo; o herói 2D não.
func _detectar_heroi_3d(jogador: Node) -> bool:
	for no in jogador.find_children("*", "", true, false):
		var roteiro: Script = no.get_script()
		while roteiro != null:
			if roteiro.resource_path.ends_with("heroi_base_3d.gd"): return true
			roteiro = roteiro.get_base_script()
	return false

func _online() -> bool:
	return cena.sessao != null and cena.sessao.ativo

func _travar(jogador: CharacterBody2D) -> void:
	_travou = true
	jogador.invulneravel = true
	jogador.temporizador_invul = 30.0
	jogador.desabilitar_todas_acoes(true)
	jogador.velocity = Vector2.ZERO

func _destravar(jogador: CharacterBody2D) -> void:
	if not _travou: return
	_travou = false
	jogador.desabilitar_todas_acoes(false)
	jogador.invulneravel = false
	jogador.temporizador_invul = 0.0

## A vigília começou para o grupo: quem ainda está na cena longa volta ao jogo.
func pular() -> void:
	if not ativa: return
	if _tween != null and _tween.is_valid(): _tween.kill()
	var jogador: CharacterBody2D = cena.jogador
	jogador.modulate.a = 1.0
	_pulso = 0.0
	_encerrar()

## Os outros jogadores veem só luz e poeira sobre o avatar de quem chegou; ninguém fica travado.
static func efeito_remoto(avatar: Node2D) -> void:
	var luz := Luz.new()
	luz.z_index = -1
	avatar.add_child(luz)
	var folhas := _fazer_particulas(luz, Vector2(0, 10), Color("8fbf5a"), Vector2(0, -34), 24, 2.4, 90.0, 1.0, false)
	avatar.modulate.a = 0.0
	var t := luz.create_tween()
	t.tween_property(luz, "pulso", 0.55, 1.6)
	t.tween_callback(func():
		avatar.create_tween().tween_property(avatar, "modulate:a", 1.0, 0.8)
		_fazer_particulas(luz, Vector2(0, 8), Color("c9b58a"), Vector2(0, -6), 20, 1.0, 70.0, 0.5, true))
	t.tween_property(luz, "pulso", 1.0, 0.8)
	t.tween_property(luz, "pulso", 0.0, 1.2)
	t.tween_callback(func():
		avatar.modulate.a = 1.0
		folhas.emitting = false)
	t.tween_interval(1.5)
	t.tween_callback(luz.queue_free)

func _montar_interface(primeira: bool) -> void:
	_camada = CanvasLayer.new()
	_camada.layer = 90
	add_child(_camada)
	_cortina = ColorRect.new()
	_cortina.color = Color(0.02, 0.03, 0.02, 1.0)
	_cortina.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cortina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_camada.add_child(_cortina)
	if primeira:
		for topo in [true, false]:
			var barra := ColorRect.new()
			barra.color = Color.BLACK
			barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
			barra.set_anchors_preset(Control.PRESET_TOP_WIDE if topo else Control.PRESET_BOTTOM_WIDE)
			if not topo: barra.grow_vertical = Control.GROW_DIRECTION_BEGIN
			_camada.add_child(barra)
			_barras.append(barra)
	_dica = Label.new()
	_dica.text = "Pular (Esc ou toque)"
	_dica.add_theme_font_override("font",preload("res://codigo/ui/estilo_campanha.gd").FONTE)
	_dica.add_theme_font_size_override("font_size", 8)
	_dica.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	_dica.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_dica.position = Vector2(-110, -18)
	_dica.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_camada.add_child(_dica)
	_som = AudioStreamPlayer.new()
	_som.stream = load("res://assets/audio/chefe_aparece.wav")
	_som.pitch_scale = 0.55
	_som.volume_db = -12
	add_child(_som)

func _entrada_curta() -> void:
	_tween = create_tween()
	_tween.tween_property(_cortina, "color:a", 0.0, 1.6)
	await _tween.finished

func _invocacao(jogador: CharacterBody2D) -> void:
	var chao := jogador.position
	_chao = chao
	cena.hud.anunciar("A floresta sente a chegada…", "", 3.0)
	jogador.modulate.a = 0.0
	_brilho = Luz.new()
	_brilho.position = chao
	cena.add_child(_brilho)
	_folhas = _fazer_particulas(cena, chao + Vector2(0, 10), Color("8fbf5a"), Vector2(0, -34), 38, 3.4, 90.0, 1.0, false)
	var camera: Camera2D = jogador.get_node("Camera2D")
	# 1. Cortina abre, barras de cinema entram, folhas começam a subir.
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_cortina, "color:a", 0.0, 1.8)
	for barra in _barras:
		_tween.tween_property(barra, "custom_minimum_size:y", 26.0, 1.2)
	_tween.tween_property(self, "_pulso", 0.55, 3.0)
	await _tween.finished
	if not ativa: return
	# 2. O personagem se materializa pouco acima do chão e cai de joelhos.
	if _heroi_3d: jogador.set_meta("invocacao", "ajoelhar")
	jogador.position = chao + Vector2(0, -22)
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(jogador, "modulate:a", 1.0, 1.1)
	_tween.tween_property(jogador, "position:y", chao.y, 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN).set_delay(0.5)
	await _tween.finished
	if not ativa: return
	# De joelhos: o herói 3D usa a animação própria; o 2D, sem quadro de joelhos, se encolhe um pouco.
	if not _heroi_3d:
		create_tween().tween_property(jogador, "scale:y", 0.84, 0.25)
	await get_tree().create_timer(0.8).timeout
	if not ativa: return
	# 3. A mão toca a terra: pulso, poeira e marca rasa no solo.
	_pulso = 1.0
	if _heroi_3d: jogador.set_meta("invocacao", "ajoelhado")
	_som.play()
	_marca_no_chao(chao)
	_poeira = _fazer_particulas(cena, chao + Vector2(0, 8), Color("c9b58a"), Vector2(0, -6), 26, 1.0, 70.0, 0.5, true)
	_tween = create_tween()
	_tween.tween_property(camera, "offset", Vector2(0, 3), 0.06)
	_tween.tween_property(camera, "offset", Vector2(0, -2), 0.06)
	_tween.tween_property(camera, "offset", Vector2.ZERO, 0.12)
	await get_tree().create_timer(1.1).timeout
	if not ativa: return
	# 4. A luz se apaga, ele se levanta e o controle volta ao jogador.
	_tween = create_tween().set_parallel(true)
	if not _heroi_3d: _tween.tween_property(jogador, "scale:y", 1.0, 0.6)
	_tween.tween_property(self, "_pulso", 0.0, 1.4)
	for barra in _barras:
		_tween.tween_property(barra, "custom_minimum_size:y", 0.0, 0.9)
	if _heroi_3d: jogador.set_meta("invocacao", "levantar_ajoelhado")
	await _tween.finished
	if _heroi_3d and ativa:
		# Termina de se levantar antes de devolver o controle.
		await get_tree().create_timer(1.5).timeout

func _process(_delta: float) -> void:
	if is_instance_valid(_brilho): _brilho.pulso = _pulso
	# Luz, folhas e poeira ficam sempre logo atrás do personagem, nunca por cima dele.
	if is_instance_valid(cena.jogador):
		var atras: int = cena.jogador.z_index - 1
		for no in [_brilho, _folhas, _poeira]:
			if is_instance_valid(no): no.z_index = atras

static func _fazer_particulas(pai: Node, onde: Vector2, cor: Color, gravidade: Vector2, quantidade: int, vida: float, velocidade: float, tamanho: float, unica: bool) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.position = onde
	p.amount = quantidade
	p.lifetime = vida
	p.one_shot = unica
	p.explosiveness = 0.9 if unica else 0.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 6.0 if unica else 40.0
	p.direction = Vector2(0, -1)
	p.spread = 180.0 if unica else 25.0
	p.initial_velocity_min = velocidade * 0.4
	p.initial_velocity_max = velocidade if unica else velocidade * 0.4
	p.gravity = gravidade
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0 + tamanho
	p.color = cor
	pai.add_child(p)
	p.emitting = true
	return p

func _marca_no_chao(onde: Vector2) -> void:
	var marca := Polygon2D.new()
	var pontos := PackedVector2Array()
	for i in 20:
		var a := i * TAU / 20.0
		pontos.append(Vector2(cos(a) * 17.0, sin(a) * 8.0))
	marca.polygon = pontos
	marca.color = Color(0.12, 0.09, 0.06, 0.38)
	marca.position = onde + Vector2(0, 8)
	marca.z_index = 1
	cena.add_child(marca)
	marca.name = "MarcaDaInvocacao"

func _unhandled_input(evento: InputEvent) -> void:
	if not ativa: return
	var quer_pular: bool = evento.is_action_pressed("ui_cancel") or evento.is_action_pressed("ui_accept")
	if evento is InputEventScreenTouch and evento.pressed: quer_pular = true
	if quer_pular:
		get_viewport().set_input_as_handled()
		self.pular()

func _encerrar() -> void:
	if not ativa: return
	ativa = false
	get_tree().set_meta("cinema_ativo", false)
	var jogador: CharacterBody2D = cena.jogador
	if is_instance_valid(jogador):
		jogador.remove_meta("invocacao")
		jogador.modulate.a = 1.0
		jogador.scale.y = 1.0
		if _chao != Vector2.ZERO: jogador.position = _chao
		jogador.get_node("Camera2D").offset = Vector2.ZERO
		_destravar(jogador)
		cena.salvar_retorno()
	for no in [_brilho, _folhas, _poeira]:
		if is_instance_valid(no): no.queue_free()
	if is_instance_valid(_camada): _camada.queue_free()
	cena.hud.anunciar("Água, vento… e madeira batendo ao longe.", "", 3.5)
	concluida.emit()
