extends Area2D

## Círculo mágico no chão da arena (montado em cenario.gd, ao lado do portal): entre as ondas ele brilha e, se o jogador
## ficar TEMPO_PARA_COMECAR segundos em cima, a próxima onda começa. É o jeito de seguir sem abrir a janela do portal.
## Durante a onda (ou com alguma tela aberta) fica apagado e não conta.

const Profundidade := preload("res://codigo/globais/profundidade.gd")
const FONTE := preload("res://assets/ui/Planes_ValMore.ttf")
const RAIO := 18.0
const TEMPO_PARA_COMECAR := 2.0
const COR := Color(0.55, 0.75, 1.0)
const COR_CARGA := Color(1.0, 0.9, 0.55)

var _gerenciador: Node
var _jogador_em_cima := false
var _carga := 0.0
var _tempo := 0.0
var _ativo := false
var _rotulo: Label

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	z_as_relative = false
	# No chão: abaixo de tudo que tem altura
	z_index = Profundidade.z_de(global_position.y - 40.0)
	var forma := CollisionShape2D.new()
	var circulo := CircleShape2D.new()
	circulo.radius = RAIO - 4.0
	forma.shape = circulo
	add_child(forma)
	body_entered.connect(func(corpo: Node2D) -> void: if corpo.is_in_group("character"): _jogador_em_cima = true)
	body_exited.connect(func(corpo: Node2D) -> void: if corpo.is_in_group("character"): _jogador_em_cima = false)
	_rotulo = Label.new()
	_rotulo.add_theme_font_override("font", FONTE)
	_rotulo.add_theme_font_size_override("font_size", 8)
	_rotulo.add_theme_color_override("font_color", Color("fff3d6"))
	_rotulo.add_theme_color_override("font_outline_color", Color("2a2230"))
	_rotulo.add_theme_constant_override("outline_size", 3)
	_rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rotulo.size = Vector2(120, 12)
	_rotulo.position = Vector2(-60, RAIO + 3)
	_rotulo.z_as_relative = false
	_rotulo.z_index = 899
	add_child(_rotulo)
	_gerenciador = get_tree().get_first_node_in_group("gerenciador_ondas")

func _process(delta: float) -> void:
	_tempo += delta
	if _gerenciador == null:
		_gerenciador = get_tree().get_first_node_in_group("gerenciador_ondas")
	var jogador: Node = get_tree().get_first_node_in_group("character")
	_ativo = _gerenciador != null and not _gerenciador.onda_em_andamento and not _gerenciador.ondas_paradas \
		and not Introducao.ativa() and not Transicao.ocupada and jogador != null and not jogador.estaMorto
	var pode_contar: bool = _ativo and _jogador_em_cima and jogador.movimento_habilitado
	_carga = clampf(_carga + (delta if pode_contar else -delta * 2.0), 0.0, TEMPO_PARA_COMECAR)
	_rotulo.visible = _ativo
	if _ativo:
		_rotulo.text = "PROXIMO ANDAR (%d)" % int(_gerenciador.onda_atual)
	if pode_contar and _carga >= TEMPO_PARA_COMECAR:
		_carga = 0.0
		Sons.tocar("menu_confirmar", 0.0)
		_gerenciador.iniciar_onda()
	queue_redraw()

func _draw() -> void:
	var pulso := 0.5 + 0.5 * sin(_tempo * 3.0)
	var alfa := (0.55 + 0.35 * pulso) if _ativo else 0.12
	var cor := Color(COR, alfa)
	draw_circle(Vector2.ZERO, RAIO, Color(COR, alfa * 0.18))
	draw_arc(Vector2.ZERO, RAIO, 0.0, TAU, 40, cor, 1.5)
	draw_arc(Vector2.ZERO, RAIO - 5.0, 0.0, TAU, 32, Color(COR, alfa * 0.6), 1.0)
	# Quatro runas girando devagar
	for i in 4:
		var angulo := _tempo * 0.6 + i * TAU / 4.0
		draw_circle(Vector2(cos(angulo), sin(angulo) * 0.6) * (RAIO - 2.5), 1.5, cor)
	if _carga > 0.0:
		draw_arc(Vector2.ZERO, RAIO + 2.5, -PI / 2.0, -PI / 2.0 + TAU * _carga / TEMPO_PARA_COMECAR, 40, COR_CARGA, 2.0)
