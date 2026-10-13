extends SceneTree

# Rodar: godot --headless --path . --script res://testes/teste_pausa.gd
# Tela de pausa (Codigos/UI/tela_pausa.gd): Esc abre e para o jogo, Esc fecha, CONTINUAR, OPCOES (valor muda e salva), confirmações de VOLTAR AO MENU
# e SAIR, e que Esc dentro das opções só volta ao menu da pausa.
# ATENCAO: carrega a cena de jogo; o teste grava user://opcoes.cfg (volume) e o devolve no fim; faça backup do user:// antes.

var _falhas := 0
var _cena: Node

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

func _esc() -> void:
	for pressionada in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_ESCAPE
		ev.keycode = KEY_ESCAPE
		ev.pressed = pressionada
		Input.parse_input_event(ev)
	await _quadros(3)

func _rodar() -> void:
	await process_frame
	root.get_node("Progresso").caminho_save = "user://teste_pausa_progresso.json"
	root.get_node("Fazenda").caminho_save = "user://teste_pausa_fazenda.json"
	root.get_node("Progresso").apagar()
	root.get_node("Fazenda").apagar()
	var Opcoes := load("res://Codigos/Globais/opcoes_jogo.gd")
	var opcoes_antes: Dictionary = Opcoes.carregar()
	_cena = load("res://cenas/cenario.tscn").instantiate()
	root.add_child(_cena)
	current_scene = _cena
	await _quadros(10)
	_cena.get_node("enemySpawner/GerenciadorOndas").parar_ondas()
	var tela: Control = _cena.get_node("UI/TelaPausa") if _cena.has_node("UI/TelaPausa") else _cena.get_node("Interface/TelaPausa")
	_verificar("a tela de pausa existe na Interface e comeca fechada", tela != null and not tela.visible and not paused, "")

	await _esc()
	_verificar("Esc sem tela aberta abre a pausa e para o jogo", tela.visible and paused, "visible=%s paused=%s" % [tela.visible, paused])
	await _esc()
	_verificar("Esc de novo fecha a pausa e o jogo volta a andar", not tela.visible and not paused, "")

	await _esc()
	tela._continuar()
	await _quadros(3)
	_verificar("CONTINUAR fecha a pausa", not tela.visible and not paused, "")

	# opcoes
	await _esc()
	tela._botao_opcoes.pressed.emit()
	await _quadros(2)
	_verificar("OPCOES mostra as linhas e esconde o menu", tela._vista_opcoes.visible and not tela._menu.visible and tela._titulo.text == "OPCOES", tela._titulo.text)
	var volume_antes: float = Opcoes.carregar()["volume"]
	var linha_volume: Dictionary = tela._linhas[0]
	tela._mudar_linha(0, -1)
	var depois: Dictionary = Opcoes.carregar()
	_verificar("mudar o volume grava em opcoes.cfg", is_equal_approx(depois["volume"], maxf(volume_antes - 0.1, 0.0)), "%s -> %s" % [volume_antes, depois["volume"]])
	_verificar("o rotulo da linha acompanha", linha_volume["rotulo"].text == "%d%%" % roundi(depois["volume"] * 100.0), linha_volume["rotulo"].text)
	await _esc()
	_verificar("Esc dentro das opcoes so volta ao menu da pausa", tela.visible and paused and tela._menu.visible and not tela._vista_opcoes.visible, "")
	await _esc()
	_verificar("Esc no menu da pausa fecha a tela", not tela.visible and not paused, "")

	# confirmacoes
	await _esc()
	tela._botao_menu.pressed.emit()
	await _quadros(2)
	_verificar("VOLTAR AO MENU pede confirmacao", tela._confirmar.visible and tela._titulo.text == "VOLTAR AO MENU?", tela._titulo.text)
	tela._botao_nao.pressed.emit()
	await _quadros(2)
	_verificar("NAO volta ao menu da pausa", tela._menu.visible and not tela._confirmar.visible, "")
	tela._botao_sair.pressed.emit()
	await _quadros(2)
	_verificar("SAIR DO JOGO pede confirmacao", tela._confirmar.visible and tela._titulo.text == "SAIR DO JOGO?", tela._titulo.text)
	await _esc()
	_verificar("Esc na confirmacao volta ao menu da pausa", tela._menu.visible and tela.visible, "")
	await _esc()

	# acoes do jogador ficam desligadas enquanto a pausa esta aberta e voltam depois
	var jogador: Node = _cena.get_node("Jogador")
	await _esc()
	_verificar("com a pausa aberta o jogador nao age", not jogador.movimento_habilitado, "")
	await _esc()
	_verificar("fechando a pausa o jogador volta a agir", jogador.movimento_habilitado, "")

	Opcoes.salvar(opcoes_antes)
	Opcoes.aplicar(opcoes_antes)
	print("--- teste_pausa: ", "TUDO OK" if _falhas == 0 else "%d FALHAS" % _falhas)
	print("FALHAS: ", _falhas)
	quit(_falhas)
