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
	# Se você tem um Label em /root/cenario/UI/Coins/count
	# e quer atualizar seu texto:
	var rotulo = get_tree().get_root().get_node_or_null("cenario/UI/Moedas/contador")
	if rotulo and rotulo is Label:
		rotulo.text = str(moedas)
