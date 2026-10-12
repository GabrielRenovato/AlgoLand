extends SceneTree

# Rodar: godot --headless --path . --script res://testes/teste_creditos.gd
# Tela de CREDITOS do menu inicial (Etapa C): botao no menu, painel que abre/fecha (VOLTAR e B/Esc), foco de controle,
# rolagem por cima/baixo no controle e o conteudo (textos em ASCII maiusculo; Mana Seed, EmanuelleDev com o link
# emanuelledev.itch.io exigido pela licenca do Farm RPG, craftpix, PixyMoon e "SONS GERADOS POR CODIGO").
# Nao grava nada em user:// (so le saves existentes para montar o personagem); faca o backup do user:// do mesmo jeito.

var _falhas: int = 0

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

func _tecla(acao: String) -> InputEventAction:
	var evento := InputEventAction.new()
	evento.action = acao
	evento.pressed = true
	return evento

func _rodar() -> void:
	await process_frame
	var titulo: Node = load("res://cenas/inicio-do-jogo.tscn").instantiate()
	root.add_child(titulo)
	current_scene = titulo
	await _quadros(8)

	# --- conteudo
	var creditos: Array = titulo.CREDITOS
	var textos: Array[String] = []
	var ascii_ok := true
	var detalhe := ""
	for bloco in creditos:
		var todos: Array = [bloco["titulo"]]
		if bloco.has("link"):
			todos.append(bloco["link"])
		todos.append_array(bloco["linhas"])
		for t in todos:
			textos.append(String(t))
			if not _ascii_maiusculo(String(t)):
				ascii_ok = false
				detalhe = String(t)
	_verificar("creditos: todo texto em ASCII maiusculo (a fonte nao tem acentos)", ascii_ok, detalhe)
	_verificar("creditos: Seliel the Shaper (Mana Seed)", _tem(textos, "SELIEL THE SHAPER") and _tem(textos, "MANA SEED"), "")
	_verificar("creditos: EmanuelleDev com o link emanuelledev.itch.io (licenca do Farm RPG)", _tem(textos, "EMANUELLEDEV") and "EMANUELLEDEV.ITCH.IO" in textos and _tem(textos, "FARM RPG"), "")
	_verificar("creditos: craftpix e PixyMoon", _tem(textos, "CRAFTPIX.NET") and _tem(textos, "PIXYMOON"), "")
	_verificar("creditos: linha SONS GERADOS POR CODIGO", "SONS GERADOS POR CODIGO" in textos, "")
	var rotulos: Array = titulo.lista_creditos.get_children().filter(func(n): return n is Label)
	_verificar("creditos: a lista da tela tem um rotulo por texto", rotulos.size() == textos.size(), "%d x %d" % [rotulos.size(), textos.size()])

	# --- menu e foco
	var menu: Control = titulo.menu
	var ordem: Array = menu.get_children().filter(func(n): return n.visible).map(func(n): return n.name)
	_verificar("menu: CREDITOS fica entre OPCOES e SAIR", ordem.find(&"BotaoCreditos") == ordem.find(&"BotaoOpcoes") + 1 and ordem.find(&"BotaoSair") == ordem.find(&"BotaoCreditos") + 1, str(ordem))
	_verificar("menu: o botao CREDITOS tem o texto certo e o painel comeca fechado", titulo.botao_creditos.get_meta("texto_base") == "CREDITOS" and not titulo.painel_creditos.visible, "")
	var vizinho: Control = titulo.botao_opcoes.find_valid_focus_neighbor(SIDE_BOTTOM)
	_verificar("menu: no controle, baixo em OPCOES vai para CREDITOS", vizinho == titulo.botao_creditos, str(vizinho))
	vizinho = titulo.botao_creditos.find_valid_focus_neighbor(SIDE_BOTTOM)
	_verificar("menu: baixo em CREDITOS vai para SAIR", vizinho == titulo.botao_sair, str(vizinho))

	# --- abrir: o foco vai para VOLTAR
	titulo.botao_creditos.grab_focus()
	titulo.botao_creditos.pressed.emit()
	await _quadros(3)
	_verificar("abrir: painel visivel, menu escondido, fundo escurecido", titulo.painel_creditos.visible and not titulo.menu.visible and titulo.escurecer.visible, "")
	_verificar("abrir: o foco vai para VOLTAR", root.gui_get_focus_owner() == titulo.botao_voltar_creditos, str(root.gui_get_focus_owner()))
	var tela: Rect2 = titulo.painel_creditos.get_global_rect()
	var area := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	_verificar("abrir: o painel cabe inteiro na tela de 576x324", area.encloses(tela), "painel=%s tela=%s" % [tela, area])
	for lado in [SIDE_TOP, SIDE_BOTTOM, SIDE_LEFT, SIDE_RIGHT]:
		var outro: Control = titulo.botao_voltar_creditos.find_valid_focus_neighbor(lado)
		_verificar("foco: VOLTAR e o unico foco do painel (lado %d)" % lado, not is_instance_valid(outro) or outro == titulo.botao_voltar_creditos, str(outro))

	# --- rolagem no controle
	var rolagem: ScrollContainer = titulo.rolagem_creditos
	var maximo := int(rolagem.get_v_scroll_bar().max_value - rolagem.get_v_scroll_bar().page)
	_verificar("rolagem: a lista e maior que a janela (precisa rolar)", maximo > 0, "maximo=%d" % maximo)
	titulo.botao_voltar_creditos.gui_input.emit(_tecla("ui_down"))
	await _quadros(2)
	_verificar("rolagem: baixo desce a lista", rolagem.scroll_vertical > 0, "scroll=%d" % rolagem.scroll_vertical)
	titulo.botao_voltar_creditos.gui_input.emit(_tecla("ui_up"))
	await _quadros(2)
	_verificar("rolagem: cima sobe de volta ao topo", rolagem.scroll_vertical == 0, "scroll=%d" % rolagem.scroll_vertical)
	for i in 20:
		titulo.botao_voltar_creditos.gui_input.emit(_tecla("ui_down"))
	await _quadros(2)
	_verificar("rolagem: chega ao fim da lista", rolagem.scroll_vertical >= maximo - 1, "scroll=%d maximo=%d" % [rolagem.scroll_vertical, maximo])
	_verificar("rolagem: o foco continua em VOLTAR", root.gui_get_focus_owner() == titulo.botao_voltar_creditos, "")

	# --- fechar com B/Esc (close_menu): volta ao menu com o foco em CREDITOS
	titulo._unhandled_input(_tecla("close_menu"))
	await _quadros(2)
	_verificar("B/Esc: fecha o painel e volta ao menu", not titulo.painel_creditos.visible and titulo.menu.visible and not titulo.escurecer.visible, "")
	_verificar("B/Esc: o foco volta para CREDITOS", root.gui_get_focus_owner() == titulo.botao_creditos, str(root.gui_get_focus_owner()))

	# --- reabrir comeca no topo; VOLTAR tambem fecha
	titulo.botao_creditos.pressed.emit()
	await _quadros(2)
	_verificar("reabrir: a rolagem volta ao topo", rolagem.scroll_vertical == 0, "scroll=%d" % rolagem.scroll_vertical)
	titulo.botao_voltar_creditos.pressed.emit()
	await _quadros(2)
	_verificar("VOLTAR: fecha o painel e devolve o foco a CREDITOS", not titulo.painel_creditos.visible and root.gui_get_focus_owner() == titulo.botao_creditos, "")

	# --- opcoes continuam funcionando (mesmo mecanismo de painel)
	titulo.botao_opcoes.pressed.emit()
	await _quadros(2)
	_verificar("opcoes: abrir e fechar com B/Esc ainda funcionam", titulo.painel_opcoes.visible and not titulo.painel_creditos.visible, "")
	titulo._unhandled_input(_tecla("close_menu"))
	await _quadros(2)
	_verificar("opcoes: B/Esc volta ao menu", not titulo.painel_opcoes.visible and root.gui_get_focus_owner() == titulo.botao_opcoes, "")

	titulo.queue_free()
	await _quadros(2)
	print("FALHAS: ", _falhas)
	quit(_falhas)

func _tem(textos: Array, trecho: String) -> bool:
	for t in textos:
		if trecho in String(t):
			return true
	return false

# So A-Z, 0-9, espaco e pontuacao simples
func _ascii_maiusculo(texto: String) -> bool:
	for i in texto.length():
		var c := texto.unicode_at(i)
		if c < 32 or c > 126:
			return false
		if c >= 97 and c <= 122:
			return false
	return true
