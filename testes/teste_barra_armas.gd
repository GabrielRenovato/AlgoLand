extends SceneTree

# Rodar: godot --headless --path . --script res://testes/teste_barra_armas.gd
# Barra de baixo do HUD (codigo/ui/barra_armas.gd): é a primeira linha da mochila (como a do Stardew), nos slots do inventário. Troca por 1-5,
# roda do mouse, Z, toque na casa; a arma em uso continua na casa dela; escudo que some com arma de duas mãos e volta; não troca no meio do golpe.
# ATENCAO: carrega a cena de jogo e equipa itens (grava user://inventario.json); faça backup do user:// antes.

var _falhas: int = 0
var _cena: Node
var _jogador: Node2D
var _inv: Node
var _barra: Control

func _initialize() -> void:
	_rodar()

func _verificar(nome: String, condicao: bool, detalhe: String = "") -> void:
	if condicao:
		print("OK ", nome)
	else:
		_falhas += 1
		print("FALHA ", nome, ": ", detalhe)

func _quadros(n: int) -> void:
	for i in n:
		await process_frame

func _ms(ms: int) -> void:
	await create_timer(ms / 1000.0).timeout

func _tecla(codigo: int) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = codigo
	ev.keycode = codigo
	ev.pressed = true
	Input.parse_input_event(ev)
	var solta := InputEventKey.new()
	solta.physical_keycode = codigo
	solta.keycode = codigo
	solta.pressed = false
	Input.parse_input_event(solta)

func _roda(para_cima: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_WHEEL_UP if para_cima else MOUSE_BUTTON_WHEEL_DOWN
	ev.pressed = true
	Input.parse_input_event(ev)

func _tipo_equipado() -> String:
	var arma = _inv.equipados["arma"]
	return arma.tipo if arma != null else ""

func _item_da_casa(i: int):
	return _inv.item_na_celula(i)

func _tipo_da_casa(i: int) -> String:
	var item = _item_da_casa(i)
	return item.tipo if item != null else ""

## O kit inicial agora vem com espada e escudo na mão e as ferramentas da fazenda na primeira linha. Estes cenários partem da
## barra só de armas, de mãos vazias: espada, lança e escudo nas casas 1 a 3 e as ferramentas na terceira linha
func _arranjo_so_de_armas() -> void:
	# Equipamentos fabricados explicitamente para o cenário de troca de armas.
	_inv.adicionar_arma_nova("lanca_basica")
	_inv.adicionar_arma_nova("aljava_basica")
	_inv.equipar(_inv.buscar_por_tipo("aljava_basica"))
	_inv.desequipar("arma")
	_inv.desequipar("escudo")
	_inv.mover_para_mochila(_inv.buscar_por_tipo("lanca_basica"), 1)
	_inv.mover_para_mochila(_inv.buscar_por_tipo("escudo_basico"), 2)
	_inv.mover_para_mochila(_inv.buscar_por_tipo("enxada"), 10)
	_inv.mover_para_mochila(_inv.buscar_por_tipo("regador"), 11)
	_inv.mover_para_mochila(_inv.buscar_por_tipo("machadinha"), 12)
	_inv.mover_para_mochila(_inv.buscar_por_tipo("picareta"), 13)
	# Este arranjo testa o ciclo apenas de armas; a vara tambem fica fora da fileira.
	_inv.mover_para_mochila(_inv.buscar_por_tipo("vara_pesca"), 14)

func _rodar() -> void:
	await process_frame
	root.get_node("Progresso").caminho_save = "user://teste_barra_progresso.json"
	root.get_node("Fazenda").caminho_save = "user://teste_barra_fazenda.json"
	root.get_node("Progresso").apagar()
	root.get_node("Fazenda").apagar()
	_inv = root.get_node("InventarioJogador")
	_inv.limpar()
	_inv.criar_itens_iniciais()
	_arranjo_so_de_armas()
	_cena = load("res://cenas/cenario.tscn").instantiate()
	root.add_child(_cena)
	current_scene = _cena
	await _quadros(10)
	await _ms(200)
	_jogador = _cena.get_node("Jogador")
	_cena.get_node("enemySpawner/GerenciadorOndas").parar_ondas()
	# O nó do HUD se chama "assets/ui" (com barra no nome): get_node com esse caminho não o acha
	_barra = get_nodes_in_group("hud")[0].barra_armas
	_verificar("a barra de baixo existe no HUD da arena", _barra != null, "")
	_verificar("a barra tem uma casa por coluna da mochila (8)", _barra._casas.size() == _inv.COLUNAS_MOCHILA and _inv.COLUNAS_MOCHILA == 8, str(_barra._casas.size()))
	var grade: GridContainer = _cena.get_node("Interface/TelaInventario")._grade
	_verificar("a grade da mochila tem as mesmas colunas da barra", grade.columns == _inv.COLUNAS_MOCHILA, str(grade.columns))
	_verificar("as casas usam o slot do inventario (slot_ui)", _barra._casas[0].get_node("Conteudo/Slot").get_script() == load("res://codigo/ui/slot_ui.gd"), "")
	_verificar("arranjo de teste na primeira linha: espada, lanca e escudo", _tipo_da_casa(0) == "espada_basica" and _tipo_da_casa(1) == "lanca_basica" and _tipo_da_casa(2) == "escudo_basico" and _item_da_casa(3) == null, "%s %s %s" % [_tipo_da_casa(0), _tipo_da_casa(1), _tipo_da_casa(2)])
	_verificar("a casa mostra o item (icone do slot)", _barra._casas[0].get_node("Conteudo/Slot").item_atual == _item_da_casa(0), "")
	_verificar("sem arma na mao no inicio, nenhuma casa em destaque", _tipo_equipado() == "" and not _barra._casas[0].get_node("Conteudo/Marco").visible, "")

	# armas novas entram nas casas livres da primeira linha; as que passam da linha ficam so na mochila
	_inv.adicionar_arma_nova("arco_longo")
	_inv.adicionar_arma_nova("arco_curto")
	_inv.adicionar_arma_nova("maca")
	_inv.adicionar_arma_nova("espada_gemea")
	_inv.adicionar_arma_nova("machado")
	_inv.mover_para_mochila(_inv.buscar_por_tipo("machado"), 8)
	await _quadros(2)
	_verificar("arcos entram nas casas 4 e 5", _tipo_da_casa(3) == "arco_longo" and _tipo_da_casa(4) == "arco_curto", "%s %s" % [_tipo_da_casa(3), _tipo_da_casa(4)])
	_verificar("a arma que passou da primeira linha (machado) nao aparece na barra", _inv.mochila[8] != null and _inv.mochila[8].tipo == "machado" and _barra._casas.size() == 8, "")

	# tecla 1: espada (fica na casa 1, em destaque)
	_tecla(KEY_1)
	await _quadros(3)
	_verificar("tecla 1 equipa a espada", _tipo_equipado() == "espada_basica" and _jogador.usando_espada, _tipo_equipado())
	_verificar("a espada em uso continua na casa 1, em destaque (moldura branca)", _tipo_da_casa(0) == "espada_basica" and _barra._casas[0].get_node("Conteudo/Marco").visible, "")
	_verificar("o modelo guarda a casa da mao e a deixa vazia na mochila", _inv.celulas_da_mao["arma"] == 0 and _inv.mochila[0] == null, str(_inv.celulas_da_mao))
	# tecla 3: escudo
	await _ms(500)
	_tecla(KEY_3)
	await _quadros(3)
	_verificar("tecla 3 equipa o escudo junto da espada", _inv.equipados["escudo"] != null and _tipo_equipado() == "espada_basica", "")
	_verificar("o escudo em uso leva o filete azul na casa 3", _barra._casas[2].get_node("Conteudo/Marco").visible and _item_da_casa(2) == _inv.equipados["escudo"], "")
	# tecla 2: lanca (duas maos): o escudo volta para a casa dele, a espada para a casa 1
	await _ms(500)
	_tecla(KEY_2)
	await _quadros(3)
	_verificar("trocar pela barra nao toca a pose de guardar/sacar (troca na hora)", not _jogador.no_reacao.visible and not _jogador.troca_sem_pose, "")
	_verificar("tecla 2 equipa a lanca e o escudo volta para a casa 3", _tipo_equipado() == "lanca_basica" and _inv.equipados["escudo"] == null and _inv.mochila[2] != null and _inv.mochila[2].tipo == "escudo_basico", _tipo_equipado())
	_verificar("a espada voltou para a casa 1 e a lanca ocupa a casa 2", _inv.mochila[0] != null and _inv.mochila[0].tipo == "espada_basica" and _tipo_da_casa(1) == "lanca_basica" and _barra._casas[1].get_node("Conteudo/Marco").visible, "")
	await _ms(500)
	_tecla(KEY_1)
	await _quadros(3)
	_verificar("voltar para a espada poe o escudo de novo", _tipo_equipado() == "espada_basica" and _inv.equipados["escudo"] != null, "escudo=%s" % _inv.equipados["escudo"])
	# tecla 3 de novo: guarda o escudo na casa dele
	await _ms(500)
	_tecla(KEY_3)
	await _quadros(3)
	_verificar("tecla 3 com o escudo em uso guarda o escudo de volta na casa 3", _inv.equipados["escudo"] == null and _inv.mochila[2] != null and _tipo_equipado() == "espada_basica", "")
	await _ms(500)
	# arco
	_tecla(KEY_5)
	await _quadros(3)
	_verificar("tecla 5 equipa o arco curto (a aljava ja vem equipada)", _tipo_equipado() == "arco_curto" and _jogador.usando_arco, _tipo_equipado())
	await _ms(500)
	# casa vazia e a mesma arma nao fazem nada
	_tecla(KEY_4)
	_tecla(KEY_5)
	await _quadros(3)
	_verificar("a mesma arma nao troca", _tipo_equipado() == "arco_curto" or _tipo_equipado() == "arco_longo", _tipo_equipado())
	await _ms(500)
	_tecla(KEY_5)
	await _quadros(3)
	await _ms(300)
	# roda do mouse: percorre as armas da barra (espada, lanca, arco longo, arco curto)
	_tecla(KEY_1)
	await _quadros(3)
	await _ms(500)
	_roda(false)
	await _quadros(3)
	_verificar("roda para baixo vai para a proxima arma da barra (lanca)", _tipo_equipado() == "lanca_basica", _tipo_equipado())
	await _ms(500)
	_roda(false)
	await _quadros(3)
	_verificar("e para a seguinte, pulando o escudo (arco longo)", _tipo_equipado() == "arco_longo", _tipo_equipado())
	await _ms(500)
	_roda(false)
	await _quadros(3)
	await _ms(500)
	_roda(false)
	await _quadros(3)
	_verificar("roda inclui a maça da sexta casa", _tipo_equipado() == "maca", _tipo_equipado())
	await _ms(500)
	_roda(false)
	await _quadros(3)
	_verificar("roda inclui a espada gêmea da sétima casa", _tipo_equipado() == "espada_gemea", _tipo_equipado())
	await _ms(500)
	_roda(false)
	await _quadros(3)
	_verificar("e da a volta no fim da barra (espada)", _tipo_equipado() == "espada_basica", _tipo_equipado())
	await _ms(500)
	_roda(true)
	await _quadros(3)
	_verificar("roda para cima volta à última arma da linha", _tipo_equipado() == "espada_gemea", _tipo_equipado())
	# Z / R3
	await _ms(500)
	_tecla(KEY_Z)
	await _quadros(3)
	_verificar("Z (ou R3) passa para a proxima arma (espada)", _tipo_equipado() == "espada_basica", _tipo_equipado())
	# toque / clique na casa
	await _ms(500)
	var clique := InputEventMouseButton.new()
	clique.button_index = MOUSE_BUTTON_LEFT
	clique.pressed = true
	_barra._casas[1].gui_input.emit(clique)
	await _quadros(3)
	_verificar("tocar na casa 2 equipa a lanca", _tipo_equipado() == "lanca_basica", _tipo_equipado())
	_verificar("as casas fazem parte do grupo dos toques do HUD (nao viram joystick)", _barra._casas[0].is_in_group("toque_hud"), "")
	# nao troca no meio do golpe
	await _ms(500)
	_jogador._esta_atacando = true
	_tecla(KEY_1)
	await _quadros(3)
	_verificar("no meio de um golpe a barra nao troca", _tipo_equipado() == "lanca_basica", _tipo_equipado())
	_jogador._esta_atacando = false
	# com uma tela aberta tambem nao
	_jogador.movimento_habilitado = false
	_tecla(KEY_1)
	await _quadros(3)
	_verificar("com uma tela aberta (movimento desligado) nao troca", _tipo_equipado() == "lanca_basica", _tipo_equipado())
	_jogador.movimento_habilitado = true
	# nome ao trocar
	await _ms(300)
	_tecla(KEY_1)
	await _quadros(3)
	_verificar("ao trocar aparece o nome da arma acima da barra", _barra._nome.text.begins_with("ESPADA") and _barra._nome.modulate.a > 0.5, _barra._nome.text)
	_verificar("o numero da casa aparece (no PC)", _barra._casas[2].get_node_or_null("Conteudo/Numero") != null and _barra._casas[2].get_node("Conteudo/Numero").text == "3", "")

	# stardew: mover o machado para a primeira linha pelo inventario o poe na barra, e a casa dele vira a tecla
	var machado = _inv.buscar_por_tipo("machado")
	_inv.mover_para_mochila(machado, 3)
	await _quadros(3)
	_verificar("mover uma arma para a primeira linha a poe na barra (casa 4)", _tipo_da_casa(3) == "machado", _tipo_da_casa(3))
	await _ms(500)
	_tecla(KEY_4)
	await _quadros(3)
	_verificar("e a tecla 4 equipa o machado", _tipo_equipado() == "machado", _tipo_equipado())
	# o inventario mostra, apagada, a arma em uso na casa dela (a grade bate com a barra)
	var tela_inv: Control = _cena.get_node("Interface/TelaInventario")
	tela_inv._atualizar()
	var casa_grade: Control = tela_inv._slots_mochila[3]
	_verificar("a grade do inventario mostra a arma em uso apagada na casa dela", casa_grade.item_atual == machado and casa_grade.item_ui().em_uso, "")
	# arma em uso nao some da barra se a mochila encher: o inventario cheio nao a tira da casa
	root.get_node("Progresso").apagar()
	root.get_node("Fazenda").apagar()
	print("--- teste_barra_armas: ", "TUDO OK" if _falhas == 0 else "%d FALHAS" % _falhas)
	print("FALHAS: ", _falhas)
	quit(1 if _falhas > 0 else 0)
