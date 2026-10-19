extends SceneTree

## Botão direito no item da mochila equipa; no slot de equipamento desequipa. Saves somente na cópia isolada.
var _falhas := 0

func _initialize() -> void:
	_rodar()

func _verificar(nome: String, passou: bool) -> void:
	print("OK " if passou else "FALHA ", nome)
	if not passou:
		_falhas += 1

func _clique(controle: Control, botao: MouseButton) -> void:
	var evento := InputEventMouseButton.new()
	evento.button_index = botao
	evento.pressed = true
	controle.gui_input.emit(evento)

func _rodar() -> void:
	await process_frame
	if not OS.get_user_data_dir().ends_with("AlgoLand testes Carrasco"):
		push_error("Use a cópia isolada AlgoLand testes Carrasco.")
		quit(1)
		return
	var inv := root.get_node("InventarioJogador")
	inv.limpar()
	inv.criar_itens_iniciais()
	inv.adicionar_arma_nova("lanca_basica")
	var lanca = inv.buscar_por_tipo("lanca_basica")
	var slot: Control = load("res://cenas/ui/componentes/slot_ui.tscn").instantiate()
	slot.tipo_slot = "mochila"
	root.add_child(slot)
	await process_frame
	slot.exibir(lanca)
	_verificar("lança começa na mochila", inv.indice_de(lanca) != -1 and inv.equipados["arma"].tipo != "lanca_basica")
	_clique(slot.item_ui(), MOUSE_BUTTON_LEFT)
	_verificar("botão esquerdo não equipa", inv.indice_de(lanca) != -1)
	_clique(slot.item_ui(), MOUSE_BUTTON_RIGHT)
	_verificar("botão direito seleciona lança e suspende escudo sem retirá-lo", inv.equipados["arma"] == lanca and inv.equipados["escudo"] != null and not inv.escudo_ativo())
	_clique(slot.item_ui(), MOUSE_BUTTON_RIGHT)
	_verificar("selecionar novamente mantém a arma na barra", inv.equipados["arma"] == lanca and inv.item_na_celula(inv.casa_da_mao(lanca)) == lanca)
	inv.limpar()
	inv.criar_itens_iniciais()
	inv.salvar()
	print("Falhas: ", _falhas)
	quit(_falhas)
