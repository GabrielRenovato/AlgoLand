extends Node2D
## Apresentação 3D no mundo 2D. Emite impactos para o ator aplicar o dano.
## Não aplica dano automaticamente nem grava saves.
signal impacto(acao: String, tipo: String, indice: int, raio: float)
signal aviso_area(acao: String, raio: float)
signal acao_concluida(acao: String)
const MODELO := preload("res://cenas/inimigos/goblin_king_3d.tscn")
const FILTRO_PERSONAGEM := preload("res://codigo/jogador/contorno_pixel_base_3d.gdshader")
@export_range(32.0, 200.0) var altura_pixels := 100.0
@export var acabamento_pixel_art := true
@export_range(1, 4, 1) var amostras_pixel_art := 2
var modelo: Node3D
var animador: AnimationPlayer
var _viewport: SubViewport
var _sprite: Sprite2D
var _clipes: Dictionary = {}
var _dados: Dictionary = {}
var _acao := ""
var _proximo_evento := 0
var _aviso_ativo := false
var _fracao := 0.0
var _onda := 0.0
var _raio_onda := 0.0

func _ready() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1024, 1024)
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	modelo = MODELO.instantiate()
	_viewport.add_child(modelo)
	var ambiente := WorldEnvironment.new()
	ambiente.environment = Environment.new()
	ambiente.environment.background_mode = Environment.BG_CLEAR_COLOR
	ambiente.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambiente.environment.ambient_light_color = Color("acb6c8")
	ambiente.environment.ambient_light_energy = .28
	_viewport.add_child(ambiente)
	for dados in [[Vector3(-3, 5, 5), Color("ffe0b1"), .75],
		[Vector3(4, 2, 3), Color("a9c9ff"), .25], [Vector3(1, 4, -3), Color("ffb56e"), .6]]:
		var luz := DirectionalLight3D.new()
		_viewport.add_child(luz)
		luz.position = dados[0]
		luz.look_at(Vector3(0, 1.6, 0))
		luz.light_color = dados[1]
		luz.light_energy = dados[2]
	var camera := Camera3D.new()
	_viewport.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	# O enquadramento maior comporta espada erguida e giro sem reduzir o chefe.
	camera.size = 7.4
	camera.position = Vector3(0, 4.3, 7)
	camera.look_at(Vector3(0, 1.62, 0))
	if acabamento_pixel_art:
		# Mesma grade de duas amostras por pixel e mesmo shader do HeroiBase3D.
		var altura_quadro := ceili(altura_pixels * camera.size / 3.31)
		_viewport.size = Vector2i(altura_quadro, altura_quadro) * amostras_pixel_art
		_viewport.msaa_3d = Viewport.MSAA_DISABLED
	_sprite = Sprite2D.new()
	_sprite.texture = _viewport.get_texture()
	_sprite.centered = false
	_sprite.offset = -camera.unproject_position(Vector3.ZERO)
	_sprite.scale = Vector2.ONE * altura_pixels / (3.31 / camera.size * _viewport.size.y)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if acabamento_pixel_art else CanvasItem.TEXTURE_FILTER_LINEAR
	if acabamento_pixel_art:
		var filtro := ShaderMaterial.new()
		filtro.shader = FILTRO_PERSONAGEM
		_sprite.material = filtro
	add_child(_sprite)
	animador = _procurar_animador(modelo)
	if animador != null:
		_dados = JSON.parse_string(FileAccess.get_file_as_string("res://assets/inimigos/goblin_king/animacoes.json"))
		for clipe in animador.get_animation_list():
			var nome := String(clipe).get_slice("/", String(clipe).get_slice_count("/")-1)
			_clipes[nome] = clipe
			if nome == "parado":
				animador.get_animation(clipe).loop_mode = Animation.LOOP_LINEAR
			else:
				animador.get_animation(clipe).loop_mode = Animation.LOOP_NONE
		animador.animation_finished.connect(_ao_terminar)
		_tocar_parado()

func executar_ataque(nome: String) -> bool:
	if not _acao.is_empty() or not _dados.has(nome) or not _clipes.has(nome):
		return false
	_acao = nome
	_proximo_evento = 0
	_fracao = 0
	_aviso_ativo = bool(_dados[nome].get("aviso_area", false))
	animador.play(_clipes[nome], .10)
	if _aviso_ativo:
		aviso_area.emit(nome, float(_dados[nome].raio))
	queue_redraw()
	return true

func executar_combo() -> bool:
	return executar_ataque("combo_triplo")

func cancelar_ataque() -> void:
	_acao = ""
	_aviso_ativo = false
	_onda = 0
	_tocar_parado()
	queue_redraw()

func _tocar_parado() -> void:
	if animador != null and _clipes.has("parado"):
		animador.play(_clipes.parado, .14)

func _process(delta: float) -> void:
	if not _acao.is_empty():
		var duracao := animador.get_animation(_clipes[_acao]).length
		_fracao = clampf(animador.current_animation_position / maxf(duracao, .001), 0, 1)
		_emitir_impactos(_fracao)
	if _onda > 0:
		_onda = maxf(0, _onda-delta)
		queue_redraw()
	if _aviso_ativo or _onda > 0:
		queue_redraw()

func _emitir_impactos(ate: float) -> void:
	if _acao.is_empty(): return
	var eventos: Array = _dados[_acao].eventos
	var acao_original := _acao
	while _proximo_evento < eventos.size() and float(eventos[_proximo_evento].fracao) <= ate:
		var evento: Dictionary = eventos[_proximo_evento]
		_proximo_evento += 1
		if String(evento.tipo).begins_with("area_"):
			_aviso_ativo = false
			_onda = .38
			_raio_onda = float(evento.raio)
		impacto.emit(_acao, evento.tipo, int(evento.indice), float(evento.raio))
		# Um consumidor pode cancelar a ação ao receber o impacto.
		if _acao != acao_original: return

func _ao_terminar(clipe: StringName) -> void:
	if _acao.is_empty() or String(clipe) != String(_clipes[_acao]): return
	_emitir_impactos(1)
	if _acao.is_empty(): return
	var concluida := _acao
	_acao = ""
	_aviso_ativo = false
	_tocar_parado()
	queue_redraw()
	acao_concluida.emit(concluida)

func _draw() -> void:
	if _aviso_ativo and not _acao.is_empty():
		var raio := float(_dados[_acao].raio) * altura_pixels / 100.0
		draw_circle(Vector2.ZERO, raio, Color(1.0, .42, .12, .06))
		draw_arc(Vector2.ZERO, raio, 0, TAU, 96, Color(1.0, .52, .17, .65), 1.2)
		draw_arc(Vector2.ZERO, raio * clampf(_fracao / float(_dados[_acao].eventos[0].fracao), 0, 1),
			0, TAU, 96, Color(1.0, .72, .27, .5), 1)
	if _onda > 0:
		var progresso := 1.0-_onda/.38
		var raio := _raio_onda * altura_pixels / 100.0 * lerpf(.20, 1.0, progresso)
		draw_arc(Vector2.ZERO, raio, 0, TAU, 96, Color(1.0, .79, .38, 1-progresso), 2)

func definir_direcao(direcao: Vector2) -> void:
	if modelo != null and not direcao.is_zero_approx():
		modelo.rotation.y = atan2(direcao.x, direcao.y)

func _procurar_animador(no: Node) -> AnimationPlayer:
	if no is AnimationPlayer: return no
	for filho in no.get_children():
		var resultado := _procurar_animador(filho)
		if resultado != null: return resultado
	return null
