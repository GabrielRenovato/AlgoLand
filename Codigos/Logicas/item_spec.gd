extends Panel

var dados_item_atual: Dictionary
@onready var moedas = $"../Moedas"

func definir_dados_item(data: Dictionary) -> void:
	dados_item_atual = data
	$ItemName.text = data["nome"]
	$ItemPrice.text = str(data["preco"])
	$ItemSelected/itemImage.texture = load(data["icone"])
	$ItemDescription.text = data["descricao"]

func _on_button_pressed() -> void:
	var jogador = get_tree().get_root().get_node_or_null("cenario/Jogador")
	if not jogador:
		return

	var preco = dados_item_atual.get("preco", 0)
	if DadosJogo.moedas < preco:
		return

	jogador.gastar_moedas(preco)
	var rotulo_moedas = moedas.get_node("contador") as Label
	rotulo_moedas.text = str(DadosJogo.moedas)

	jogador.aplicar_efeitos_item(dados_item_atual)
	jogador.itens_comprados.append(dados_item_atual.duplicate())
	dados_item_atual["preco"] = int(round(preco * DadosDosItems.FATOR_PRECO_RECOMPRA))
	$ItemPrice.text = str(dados_item_atual["preco"])
