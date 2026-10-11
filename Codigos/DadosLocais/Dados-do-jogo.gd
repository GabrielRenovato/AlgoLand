extends Node

var moedas: int = 0

func _ready() -> void:
	# Atualiza a UI de moedas (caso já exista)
	atualizar_ui_moedas()

func adicionar_moedas(quantidade: int) -> void:
	moedas += quantidade
	atualizar_ui_moedas()

func gastar_moedas(quantidade: int) -> bool:
	# Retorna true/false se a compra foi possível
	if moedas >= quantidade:
		moedas -= quantidade
		atualizar_ui_moedas()
		return true
	return false

func resetar_moedas() -> void:
	moedas = 1000
	atualizar_ui_moedas()

func atualizar_ui_moedas() -> void:
	get_tree().call_group("hud", "atualizar_moedas", moedas)
