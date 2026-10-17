extends Node2D

## Placa de madeira que indica o caminho (trilha da fazenda, praia, pier...). Em vez de um texto fixo no mapa, o nome
## do destino aparece num balão em cima da placa quando um jogador chega perto, igual ao balão dos moradores.

const FONTE := preload("res://assets/ui/Planes_ValMore.ttf")
const DISTANCIA := 56.0

@export var texto := ""

var _imagem: Sprite2D
var _estacao := -1
var _balao: Label
var _anim: Tween
var _visivel := false

func _ready() -> void:
	z_as_relative = false
	z_index = preload("res://codigo/globais/profundidade.gd").z_de(global_position.y)
	_imagem = Sprite2D.new()
	_imagem.centered = false
	_imagem.offset = Vector2(-16,-38)
	_imagem.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_imagem.flip_h = texto == "FAZENDA"
	add_child(_imagem)
	_atualizar_estacao()
	_balao = Label.new()
	_balao.name = "Balao"
	_balao.text = texto
	_balao.add_theme_font_override("font", FONTE)
	_balao.add_theme_font_size_override("font_size", 8)
	_balao.add_theme_color_override("font_color", Color("fff3d6"))
	_balao.add_theme_color_override("font_outline_color", Color("2a2230"))
	_balao.add_theme_constant_override("outline_size", 3)
	_balao.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = Color(0.10, 0.09, 0.14, 0.94)
	fundo.set_content_margin_all(3)
	fundo.set_corner_radius_all(4)
	_balao.add_theme_stylebox_override("normal", fundo)
	_balao.z_as_relative = false
	_balao.z_index = 899
	_balao.modulate.a = 0.0
	_balao.visible = false
	_balao.resized.connect(_centralizar)
	add_child(_balao)
	_centralizar()

func _centralizar() -> void:
	_balao.position = Vector2(-_balao.size.x / 2.0, -34.0 - _balao.size.y)

func _process(_delta: float) -> void:
	_atualizar_estacao()
	var perto := false
	for jogador in get_tree().get_nodes_in_group("jogadores"):
		if jogador is Node2D and jogador.get_world_2d() == get_world_2d() \
				and jogador.global_position.distance_to(global_position) < DISTANCIA:
			perto = true
			break
	if perto != _visivel:
		_visivel = perto
		if _anim != null:
			_anim.kill()
		_anim = create_tween()
		if perto:
			_balao.visible = true
		_anim.tween_property(_balao, "modulate:a", 1.0 if perto else 0.0, 0.15)
		if not perto:
			_anim.tween_callback(func(): _balao.visible = false)

func _atualizar_estacao() -> void:
	var cena := Cooperativo.cena_de(self)
	var atual: int = cena.estacao_visual() if cena.has_method("estacao_visual") else Calendario.estacao()
	if atual == _estacao:
		return
	_estacao = atual
	_imagem.texture = load("res://assets/cenario/cidade/placas/" + ["primavera","verao","outono","inverno"][atual] + ".png")
