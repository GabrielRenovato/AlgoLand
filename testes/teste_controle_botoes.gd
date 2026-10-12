extends SceneTree

# Rodar: godot --headless --path . --script res://testes/teste_controle_botoes.gd
# Controle (Xbox, Nintendo, PlayStation): nome dos botoes nas dicas conforme o desenho do controle (Controle.rotulo_acao),
# dicas vivas (aviso de interacao, cinto de pocoes), ferreiro (L/R trocam de aba, dica sem "arrastar", detalhe ao focar),
# caixa de detalhe do item em foco no inventario e as linhas VIBRACAO e BOTOES das opcoes.
# Grava user://opcoes.cfg (opcoes): o teste guarda o conteudo antes e restaura no fim. Faca o backup do resto do user:// como nos outros.

var _falhas: int = 0
var _cfg_original: String = ""
var _cfg_existia: bool = false

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

func _botao(indice: int) -> void:
	for pressionado in [true, false]:
		var evento := InputEventJoypadButton.new()
		evento.button_index = indice
		evento.pressed = pressionado
		Input.parse_input_event(evento)
		await process_frame

func _acao(nome: String) -> void:
	for pressionado in [true, false]:
		var evento := InputEventAction.new()
		evento.action = nome
		evento.pressed = pressionado
		Input.parse_input_event(evento)
		await process_frame

func _guardar_opcoes() -> void:
	_cfg_existia = FileAccess.file_exists("user://opcoes.cfg")
	if _cfg_existia:
		_cfg_original = FileAccess.get_file_as_string("user://opcoes.cfg")

func _restaurar_opcoes() -> void:
	if _cfg_existia:
		var arquivo := FileAccess.open("user://opcoes.cfg", FileAccess.WRITE)
		arquivo.store_string(_cfg_original)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://opcoes.cfg"))

func _rodar() -> void:
	await process_frame
	_guardar_opcoes()
	var ctl: Node = root.get_node("Controle")
	var cenario: Node = load("res://cenas/cenario.tscn").instantiate()
	root.add_child(cenario)
	current_scene = cenario
	await _quadros(10)

	# --- nomes dos botoes por desenho de controle
	ctl.definir_preferencia_layout("xbox")
	ctl._definir(false)
	_verificar("teclado: F interage, R bebe, Q/E trocam", ctl.rotulo_acao("open_menu") == "F" and ctl.rotulo_acao("usar_pocao") == "R"
			and ctl.rotulo_acao("ferramenta_anterior") == "Q" and ctl.rotulo_acao("ferramenta_proxima") == "E",
			"%s %s %s %s" % [ctl.rotulo_acao("open_menu"), ctl.rotulo_acao("usar_pocao"), ctl.rotulo_acao("ferramenta_anterior"), ctl.rotulo_acao("ferramenta_proxima")])
	ctl._definir(true)
	_verificar("xbox: Y interage, X bebe, LB/RB trocam, A confirma, B volta",
			ctl.rotulo_acao("open_menu") == "Y" and ctl.rotulo_acao("usar_pocao") == "X" and ctl.rotulo_acao("ferramenta_anterior") == "LB"
			and ctl.rotulo_acao("ferramenta_proxima") == "RB" and ctl.rotulo_acao("ui_accept") == "A" and ctl.rotulo_acao("close_menu") == "B", "")
	ctl.definir_preferencia_layout("nintendo")
	_verificar("nintendo: X interage (botao de cima), Y bebe, L/R trocam, B confirma (embaixo), A volta, + abre o inventario",
			ctl.rotulo_acao("open_menu") == "X" and ctl.rotulo_acao("usar_pocao") == "Y" and ctl.rotulo_acao("ferramenta_anterior") == "L"
			and ctl.rotulo_acao("ferramenta_proxima") == "R" and ctl.rotulo_acao("ui_accept") == "B" and ctl.rotulo_acao("close_menu") == "A"
			and ctl.rotulo_acao("open_inventory") == "+", "")
	ctl.definir_preferencia_layout("playstation")
	_verificar("playstation: TRI interage, QUAD bebe, L1/R1 trocam, X confirma, O volta",
			ctl.rotulo_acao("open_menu") == "TRI" and ctl.rotulo_acao("usar_pocao") == "QUAD" and ctl.rotulo_acao("ferramenta_anterior") == "L1"
			and ctl.rotulo_acao("ferramenta_proxima") == "R1" and ctl.rotulo_acao("ui_accept") == "X" and ctl.rotulo_acao("close_menu") == "O", "")
	_verificar("gatilho do ataque: RT/ZR/R2 conforme o desenho (acao attack tem botao A primeiro, entao o gatilho vem do mapa)",
			ctl.ROTULOS_GATILHO["xbox"][JOY_AXIS_TRIGGER_RIGHT] == "RT" and ctl.ROTULOS_GATILHO["nintendo"][JOY_AXIS_TRIGGER_RIGHT] == "ZR"
			and ctl.ROTULOS_GATILHO["playstation"][JOY_AXIS_TRIGGER_RIGHT] == "R2", "")
	_verificar("direcional tem nome proprio", ctl.rotulo_botao(JOY_BUTTON_DPAD_UP) == "CIMA", ctl.rotulo_botao(JOY_BUTTON_DPAD_UP))
	ctl.definir_preferencia_layout("auto")
	_verificar("auto sem controle conectado cai no desenho Xbox", ctl.layout == "xbox", ctl.layout)
	_verificar("detectar pelo nome: 8BitDo (Xbox ou D-input) fica Xbox, pois o nome nao diz as letras impressas",
			ctl.layout_pelo_nome("8BitDo Ultimate Wireless Controller") == "xbox" and ctl.layout_pelo_nome("8BitDo Pro 2") == "xbox" and ctl.layout_pelo_nome("Xbox 360 Controller") == "xbox", "")
	_verificar("detectar pelo nome: Switch Pro e Joy-Con sao Nintendo, DualSense e DS4 sao PlayStation",
			ctl.layout_pelo_nome("Nintendo Switch Pro Controller") == "nintendo" and ctl.layout_pelo_nome("Joy-Con (L)") == "nintendo"
			and ctl.layout_pelo_nome("PS5 Controller") == "playstation" and ctl.layout_pelo_nome("DualSense Wireless Controller") == "playstation"
			and ctl.layout_pelo_nome("Controle desconhecido") == "xbox", "")
	var tema: Theme = load("res://recursos/ui/tema_sidebar.tres")
	var foco_botao := tema.get_stylebox("focus", "Button")
	var foco_slot := tema.get_stylebox("focus", "BotaoSlot")
	_verificar("tema do ferreiro: botao focado ganha borda dourada (sem isso nao da para ver onde o foco esta)",
			foco_botao is StyleBoxFlat and not foco_botao.draw_center and foco_botao.border_width_left > 0
			and foco_slot is StyleBoxFlat and not foco_slot.draw_center and foco_slot.border_width_left > 0, "")
	# --- dicas vivas
	var mercador: Node = cenario.get_node("Merchant")
	var aviso: Button = mercador.get_node("button/openMenu")
	ctl.definir_preferencia_layout("nintendo")
	await _quadros(2)
	_verificar("aviso do mercador: X no controle Nintendo", aviso.text == "X", aviso.text)
	ctl.definir_preferencia_layout("xbox")
	await _quadros(2)
	_verificar("aviso do mercador: Y no controle Xbox", aviso.text == "Y", aviso.text)
	ctl._definir(false)
	await _quadros(2)
	_verificar("aviso do mercador: F no teclado", aviso.text == "F", aviso.text)
	var cinto: Node = null
	for no in cenario.find_children("*", "", true, false):
		if no.get_script() != null and no.get_script().resource_path.ends_with("cinto_pocoes.gd"):
			cinto = no
	ctl._definir(true)
	ctl.definir_preferencia_layout("nintendo")
	await _quadros(2)
	_verificar("cinto de pocoes: L, R e Y BEBER no controle Nintendo", cinto != null and cinto._tecla_anterior.text == "L" and cinto._tecla_proxima.text == "R"
			and cinto._tecla_beber.text == "Y BEBER", "" if cinto == null else cinto._tecla_beber.text)

	# --- ferreiro
	root.get_node("DadosJogo").moedas = 5000
	root.get_node("EventosJogo").abrir_tela.emit("mercante")
	await _quadros(4)
	var interface: Node = cenario.get_node("Interface")
	var ferreiro: Node = interface._telas["mercante"]
	_verificar("ferreiro: no controle a dica nao manda arrastar e cita o botao de confirmar (B no Nintendo)",
			"ARRASTE" not in ferreiro._rotulo_arraste_encantar.text and " B " in ferreiro._rotulo_arraste_encantar.text and "ARRASTE" not in ferreiro._rotulo_arraste.text,
			ferreiro._rotulo_arraste_encantar.text)
	_verificar("ferreiro: dica das abas mostra L / R", ferreiro._dica_abas.visible and ferreiro._dica_abas.text.begins_with("L / R"), ferreiro._dica_abas.text)
	_verificar("ferreiro: abre na aba ENCANTAR", ferreiro.get_node("%AbaEncantar").button_pressed, "")
	await _botao(JOY_BUTTON_RIGHT_SHOULDER)
	await _quadros(2)
	_verificar("ferreiro: botao direito do ombro vai para a aba LOJA e o foco acompanha", ferreiro.get_node("%AbaLoja").button_pressed and ferreiro._painel_loja.visible
			and root.get_viewport().gui_get_focus_owner() == ferreiro.get_node("%AbaLoja"), "")
	await _botao(JOY_BUTTON_LEFT_SHOULDER)
	await _quadros(2)
	_verificar("ferreiro: botao esquerdo do ombro volta para ENCANTAR", ferreiro.get_node("%AbaEncantar").button_pressed, "")
	await _botao(JOY_BUTTON_LEFT_SHOULDER)
	await _quadros(2)
	_verificar("ferreiro: no primeiro item o ombro esquerdo nao passa da borda", ferreiro.get_node("%AbaEncantar").button_pressed, "")
	await _botao(JOY_BUTTON_RIGHT_SHOULDER)
	await _quadros(2)
	var item_loja: Button = null
	for botao in ferreiro._grade_itens.get_children():
		if botao.visible:
			item_loja = botao
			break
	ferreiro._detalhe.visible = false
	item_loja.grab_focus()
	await _quadros(2)
	_verificar("loja: focar um item (sem mouse) ja mostra o detalhe e o preco", ferreiro._detalhe.visible and ferreiro._nome_item.text != "", ferreiro._nome_item.text)
	ctl._definir(false)
	await _quadros(2)
	_verificar("ferreiro: no mouse a dica volta a dizer ARRASTE e a dica das abas some",
			"ARRASTE" in ferreiro._rotulo_arraste_encantar.text and not ferreiro._dica_abas.visible, ferreiro._rotulo_arraste_encantar.text)
	ctl._definir(true)
	await _quadros(2)

	# --- caixa de detalhe do item em foco
	var inventario: Node = interface._telas["inventario"]
	var slot_arma: Control = null
	for slot in inventario._slots_equipamento.values() + inventario._slots_mochila:
		if slot.item_atual != null and slot.item_atual.categoria == "arma":
			slot_arma = slot
			break
	ferreiro.get_node("%AbaEncantar").button_pressed = true
	ferreiro.get_node("%AbaEncantar").pressed.emit()
	ferreiro.get_node("%AbaEncantar").grab_focus()
	await _quadros(2)
	slot_arma.grab_focus()
	await _quadros(3)
	var ultima: Node = inventario._info_linhas.get_child(inventario._info_linhas.get_child_count() - 1)
	_verificar("inventario: item em foco mostra a caixa de detalhe no controle", inventario._info_item.visible and inventario._info_linhas.get_child_count() >= 2, "")
	_verificar("inventario: com ENCANTAR aberto, confirmar coloca a arma no encanto (B no Nintendo)", ultima is Label and ultima.text == "B COLOCAR NO ENCANTO", ultima.text if ultima is Label else "?")
	ctl._definir(false)
	await _quadros(2)
	_verificar("inventario: no mouse a caixa some (a dica fica no mouse)", not inventario._info_item.visible, "")
	root.get_node("EventosJogo").fechar_tela.emit("mercante")
	await _quadros(2)

	# --- ferreiro: slot vazio, validacao e loja pelo controle
	ctl._definir(true)
	ctl.definir_preferencia_layout("xbox")
	root.get_node("DadosJogo").moedas = 5000
	var modelo: Node = root.get_node("InventarioJogador")
	if modelo.esta_vazio():
		modelo.criar_itens_iniciais()
	var espada = modelo.buscar_por_tipo("espada_basica")
	if modelo.equipados["arma"] == null and espada != null:
		modelo.equipar(espada)
	root.get_node("EventosJogo").abrir_tela.emit("mercante")
	await _quadros(5)
	ferreiro.get_node("%AbaEncantar").button_pressed = true
	ferreiro.get_node("%AbaEncantar").pressed.emit()
	await _quadros(3)
	var slot_enc: Control = ferreiro._slot_encantar
	slot_enc.limpar()
	slot_enc.grab_focus()
	await _acao("ui_accept")
	await _quadros(2)
	_verificar("encantar: confirmar no slot vazio coloca a arma equipada", slot_enc.item_atual != null and slot_enc.item_atual.obter_tipo_item() == modelo.equipados["arma"].tipo,
			"vazio" if slot_enc.item_atual == null else slot_enc.item_atual.obter_tipo_item())
	await _acao("ui_accept")
	await _quadros(2)
	_verificar("encantar: confirmar no slot cheio tira a arma", slot_enc.item_atual == null, "")
	var clique := InputEventMouseButton.new()
	clique.button_index = MOUSE_BUTTON_LEFT
	clique.pressed = true
	slot_enc._ao_entrada(clique)
	await _quadros(2)
	_verificar("encantar: clicar no slot vazio (mouse) tambem coloca a arma equipada", slot_enc.item_atual != null, "")
	slot_enc.limpar()
	await _quadros(2)
	# arma so na mochila: o foco vai para ela e aparece o aviso
	modelo.desequipar("arma")
	await _quadros(3)
	slot_enc.grab_focus()
	await _acao("ui_accept")
	await _quadros(2)
	var foco_inv := root.get_viewport().gui_get_focus_owner()
	_verificar("encantar: sem arma equipada, confirmar no slot vazio leva o foco para a arma da mochila e avisa",
			foco_inv != null and inventario.is_ancestor_of(foco_inv) and ferreiro._mensagem.visible and "ESCOLHA A ARMA E APERTE A" in ferreiro._mensagem.text,
			"%s / %s" % [foco_inv, ferreiro._mensagem.text])
	var espada_ui: Control = null
	for s in inventario._slots_mochila:
		if s.item_atual != null and s.item_atual.tipo == "espada_basica":
			espada_ui = s.item_ui()
	var elmo_ui: Control = inventario._slots_equipamento["cabeca"].item_ui()
	_verificar("encantar: armadura confirmada e recusada com aviso (nao some em silencio)",
			not ferreiro.receber_item_do_controle(elmo_ui) and ferreiro._mensagem.visible and ferreiro._mensagem.text.begins_with("SO ARMAS"), ferreiro._mensagem.text)
	var escudo_ui: Control = null
	for s in inventario._slots_mochila + inventario._slots_equipamento.values():
		if s.item_atual != null and s.item_atual.tipo == "escudo_basico":
			escudo_ui = s.item_ui()
	if escudo_ui != null:
		_verificar("encantar: escudo recusado com o motivo", not ferreiro.receber_item_do_controle(escudo_ui) and ferreiro._mensagem.text == "ESCUDO NAO PODE SER ENCANTADO", ferreiro._mensagem.text)
	if espada_ui != null:
		_verificar("encantar: arma da mochila confirmada vai para o slot", ferreiro.receber_item_do_controle(espada_ui) and slot_enc.item_atual == espada_ui, "")
		slot_enc.limpar()
	modelo.equipar(modelo.buscar_por_tipo("espada_basica"))
	await _quadros(3)
	# loja de totens: A seleciona e o foco vai sozinho para COMPRAR; B volta para o item
	ferreiro.get_node("%AbaLoja").button_pressed = true
	ferreiro.get_node("%AbaLoja").pressed.emit()
	await _quadros(3)
	var botao_item: Button = null
	for b in ferreiro._grade_itens.get_children():
		if b.visible:
			botao_item = b
			break
	root.get_node("DadosJogo").moedas = 5000
	botao_item.grab_focus()
	await _quadros(2)
	await _acao("ui_accept")
	await _quadros(3)
	_verificar("loja: confirmar o item no controle leva o foco direto para COMPRAR", root.get_viewport().gui_get_focus_owner() == ferreiro._botao_comprar, str(root.get_viewport().gui_get_focus_owner()))
	await _acao("close_menu")
	await _quadros(2)
	_verificar("loja: voltar (B) sai do COMPRAR para o item, sem fechar o ferreiro", root.get_viewport().gui_get_focus_owner() == botao_item and ferreiro.visible, str(root.get_viewport().gui_get_focus_owner()))
	root.get_node("DadosJogo").moedas = 0
	ferreiro._atualizar_detalhe()
	await _acao("ui_accept")
	await _quadros(2)
	_verificar("loja: sem moedas, confirmar avisa MOEDAS INSUFICIENTES e nao entra no COMPRAR",
			ferreiro._mensagem.visible and ferreiro._mensagem.text == "MOEDAS INSUFICIENTES" and root.get_viewport().gui_get_focus_owner() == botao_item, ferreiro._mensagem.text)
	root.get_node("DadosJogo").moedas = 5000
	await _acao("close_menu")
	await _quadros(3)
	_verificar("loja: voltar (B) no item (sem COMPRAR) fecha o ferreiro", not ferreiro.visible, "")
	_verificar("rotulos de botao usam a fonte Planes_ValMore (o Y da CraftPixNet parece minusculo)",
			aviso.get_theme_font("font").resource_path.ends_with("Planes_ValMore.ttf") and cinto != null and cinto._tecla_beber.get_theme_font("font").resource_path.ends_with("Planes_ValMore.ttf"),
			aviso.get_theme_font("font").resource_path)
	# --- B fecha a tela e nao pode virar dash (B tambem e o botao de rolar)
	var jog: Node = cenario.get_node("Jogador")
	var dash_com_b := func() -> bool:
		jog.stamina = jog.stamina_maxima
		var evento := InputEventJoypadButton.new()
		evento.button_index = JOY_BUTTON_B
		evento.pressed = true
		Input.parse_input_event(evento)
		var deu := false
		for i in 12:
			await physics_frame
			deu = deu or jog.esta_em_dash
		evento = InputEventJoypadButton.new()
		evento.button_index = JOY_BUTTON_B
		evento.pressed = false
		Input.parse_input_event(evento)
		await _quadros(45)
		return deu
	# A janela sem acao (250 ms) e em tempo real: espera passar a do fechamento anterior
	await create_timer(0.35).timeout
	var deu_dash: bool = await dash_com_b.call()
	_verificar("B sem nenhuma tela aberta continua dando dash", deu_dash, "")
	for nome in ["inventario", "mercante", "acampamento"]:
		root.get_node("EventosJogo").abrir_tela.emit(nome)
		await _quadros(5)
		var aberta: bool = interface._telas[nome].visible
		deu_dash = await dash_com_b.call()
		_verificar("B fecha a tela %s e nao dispara o dash" % nome, aberta and not interface._telas[nome].visible and not deu_dash, "aberta=%s dash=%s" % [aberta, deu_dash])
	await create_timer(0.35).timeout
	deu_dash = await dash_com_b.call()
	_verificar("depois da janela curta o dash volta ao normal", deu_dash, "")
	# --- vibracao
	ctl._definir(true)
	ctl.vibracao_ligada = true
	ctl.vibrar(1.0, 1.0, 0.1)
	ctl.vibracao_ligada = false
	ctl.vibrar(1.0, 1.0, 0.1)
	_verificar("vibrar sem controle fisico ou com a opcao desligada nao da erro", true, "")
	var jogador: Node = cenario.get_node("Jogador")
	jogador.invulneravel = false
	var vida_antes: int = jogador.hp_atual
	jogador.receber_dano(5)
	_verificar("levar dano com vibracao no caminho continua tirando vida", jogador.hp_atual < vida_antes, "%d -> %d" % [vida_antes, jogador.hp_atual])
	ctl.vibracao_ligada = true

	# --- opcoes: VIBRACAO e BOTOES
	cenario.queue_free()
	await _quadros(3)
	var titulo: Node = load("res://cenas/inicio-do-jogo.tscn").instantiate()
	root.add_child(titulo)
	current_scene = titulo
	await _quadros(8)
	ctl._definir(true)
	titulo._abrir_painel(titulo.painel_opcoes, titulo.botao_opcoes, titulo.get_node("%BotaoVolumeMenos"))
	await _quadros(4)
	_verificar("opcoes: 5 linhas (volume, tela cheia, fps, vibracao, botoes)", titulo._linhas.size() == 5, str(titulo._linhas.size()))
	for i in 4:
		await _acao("ui_down")
	_verificar("opcoes: baixo 4 vezes chega na linha BOTOES", root.get_viewport().gui_get_focus_owner() == titulo.get_node("%BotaoBotoesMenos"), "")
	await _acao("ui_right")
	_verificar("opcoes: direita em BOTOES escolhe XBOX e o jogo passa a usar esse desenho", titulo.get_node("%ValorBotoes").text == "XBOX" and ctl.layout == "xbox", titulo.get_node("%ValorBotoes").text)
	await _acao("ui_right")
	_verificar("opcoes: de novo escolhe NINTENDO e a dica diz como ficaram os botoes", ctl.layout == "nintendo" and "NINTENDO" in titulo.get_node("%DicaBotoes").text and "CONFIRMA = B" in titulo.get_node("%DicaBotoes").text,
			titulo.get_node("%DicaBotoes").text)
	await _acao("ui_up")
	await _acao("ui_left")
	_verificar("opcoes: esquerda em VIBRACAO desliga", not ctl.vibracao_ligada and titulo.get_node("%ValorVibracao").text == "NAO", titulo.get_node("%ValorVibracao").text)
	var cfg := ConfigFile.new()
	cfg.load("user://opcoes.cfg")
	_verificar("opcoes: vibracao e botoes foram salvos", cfg.get_value("opcoes", "vibracao", true) == false and cfg.get_value("opcoes", "layout_controle", "") == "nintendo", "")
	var Opcoes = load("res://Codigos/Globais/opcoes_jogo.gd")
	var lidas: Dictionary = Opcoes.carregar()
	_verificar("opcoes: carregar devolve o que foi salvo", lidas["layout_controle"] == "nintendo" and lidas["vibracao"] == false, str(lidas))
	cfg.set_value("opcoes", "layout_controle", "invalido")
	cfg.save("user://opcoes.cfg")
	_verificar("opcoes: valor de botoes invalido vira auto", Opcoes.carregar()["layout_controle"] == "auto", "")
	await _acao("close_menu")
	await _quadros(2)
	_verificar("opcoes: B fecha o painel", titulo._painel_aberto == null, "")

	ctl.definir_preferencia_layout("auto")
	ctl.vibracao_ligada = true
	_restaurar_opcoes()
	print("FALHAS: ", _falhas)
	quit(1 if _falhas > 0 else 0)
