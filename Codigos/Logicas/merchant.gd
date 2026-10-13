extends CharacterBody2D

const Interagivel := preload("res://Codigos/Logicas/interagivel.gd")
const FONTE_TECLA := preload("res://UI/Planes_ValMore.ttf")

@onready var icon: Sprite2D = $button
@onready var _rotulo_tecla: Button = $button/openMenu

var player_in_range: bool = false

func _ready() -> void:
	add_to_group("merchant")
	# Dispute o F com a fogueira (zonas sobrepostas): só o mais próximo do jogador responde
	add_to_group("interagiveis")
	icon.visible = false
	Controle.dicas_alteradas.connect(_atualizar_tecla)
	_atualizar_tecla()

func _atualizar_tecla() -> void:
	# Planes_ValMore: o Y da fonte do aviso parece um "y" minúsculo
	_rotulo_tecla.add_theme_font_override("font", FONTE_TECLA)
	_rotulo_tecla.text = Controle.rotulo_acao("open_menu")
	# Texto de toque ("AGIR") é mais comprido que uma tecla: fonte menor para caber no botão
	if _rotulo_tecla.text.length() > 2:
		_rotulo_tecla.add_theme_font_size_override("font_size", 7)
	else:
		_rotulo_tecla.remove_theme_font_size_override("font_size")

func _process(_delta: float) -> void:
	icon.visible = player_in_range and visible and Interagivel.eh_o_mais_proximo(self)
	if icon.visible and Input.is_action_just_pressed("open_menu"):
		open_menu()

func disponivel_isolada() -> bool:
	return player_in_range and visible

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("character"):
		player_in_range = true
		icon.visible = true

func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.is_in_group("character"):
		player_in_range = false
		icon.visible = false
		close_menu()

func open_menu() -> void:
	EventosJogo.abrir_tela.emit("mercante")

func close_menu() -> void:
	EventosJogo.fechar_tela.emit("mercante")
