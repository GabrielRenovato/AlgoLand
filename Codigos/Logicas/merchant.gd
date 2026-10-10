extends CharacterBody2D

@onready var icon: Sprite2D = $button

var player_in_range: bool = false

func _ready() -> void:
	add_to_group("merchant")
	icon.visible = false

func _process(_delta: float) -> void:
	if player_in_range and Input.is_action_just_pressed("open_menu"):
		open_menu()

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
