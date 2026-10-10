extends CanvasLayer

@onready var _imagem: TextureRect = $Imagem

@export_range(0.0, 1.0) var intensidade: float = 0.35:
	set(valor):
		intensidade = valor
		if is_node_ready():
			_imagem.modulate.a = valor

func _ready() -> void:
	_imagem.modulate.a = intensidade
