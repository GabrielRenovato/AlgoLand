extends SceneTree

const Habilidade := preload("res://codigo/pesca/progressao_pesca.gd")
const Peixes := preload("res://codigo/pesca/peixes.gd")
var falhas := 0

func _initialize() -> void:
	_rodar.call_deferred()

func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ", nome)
	if not ok: falhas += 1

func quadros(n := 8) -> void:
	for i in n: await process_frame

func foto(nome: String) -> void:
	await quadros()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://arte/previas/pesca/progressao_99/" + nome + ".png")

func conferir(coluna: Control, nome: String) -> void:
	var anterior: Control
	for filho in coluna.get_children():
		if not filho is Control: continue
		var caixa: Rect2 = filho.get_global_rect()
		verificar(nome + " encaixa " + filho.name, caixa.position.x >= coluna.global_position.x - 1 and caixa.end.x <= coluna.global_position.x + coluna.size.x + 1)
		if anterior != null:
			verificar(nome + " separa " + filho.name, anterior.get_global_rect().end.y + 4 <= caixa.position.y)
		if filho is Label:
			verificar(nome + " não corta texto " + filho.name, filho.get_line_count() * filho.get_line_height() <= filho.size.y + 1)
		anterior = filho

func _rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes") or DisplayServer.get_name() == "headless":
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://arte/previas/pesca/progressao_99"))
	root.get_node("Saves").trocar("solo")
	root.get_node("Introducao").pular_prologo()
	var fazenda: Node = root.get_node("Fazenda")
	fazenda._zerar()
	root.get_node("Transicao").hora_salva = 12
	change_scene_to_file("res://cenas/palafita.tscn")
	await quadros(40)
	current_scene.get_node("Iluminacao").definir_hora(12)
	current_scene.get_node("Iluminacao").set_process(false)
	var interface: Node = current_scene.get_node("Interface")
	for tamanho in [Vector2i(576, 324), Vector2i(288, 512), Vector2i(288, 324), Vector2i(288, 216)]:
		root.get_node("Controle").usando_toque = tamanho.x == 288
		root.mode = Window.MODE_WINDOWED
		root.content_scale_size = tamanho
		root.size = tamanho * 2
		await quadros(15)
		fazenda.pesca_xp["p1"] = Habilidade.xp_para_nivel(49) + Habilidade.custo_nivel(49) / 2
		interface._abrir_tela("inventario")
		var inv: Node = interface._telas["inventario"]
		inv.selecionar_pagina(3)
		await quadros()
		conferir(inv._pesca._lista.get_node("ProgressaoPesca"), str(tamanho))
		await foto("catalogo_%dx%d" % [tamanho.x, tamanho.y])
		# Tooltip de nome longo e requisito de nível usa a renderização real do catálogo.
		inv._pesca._pagina = 999
		inv._pesca._aplicar_pagina()
		await quadros()
		var slot: Control = inv._pesca._grade_peixes.get_node("imperador_abissal")
		inv._pesca._mostrar_dica("imperador_abissal", slot)
		await quadros()
		var ficha: Control = inv._pesca._dica
		verificar("ficha compacta " + str(tamanho), ficha.size.y <= 145)
		verificar("ficha preserva margens " + str(tamanho), inv._pesca._area_dica.get_global_rect().grow(-8).encloses(ficha.get_global_rect()))
		var fechar: Button = ficha.find_child("FecharFicha", true, false)
		verificar("fechar fica dentro da ficha " + str(tamanho), fechar != null and ficha.get_global_rect().grow(-8).encloses(fechar.get_global_rect()))
		for rotulo in ficha.find_children("*", "Label", true, false):
			verificar("texto encaixa na ficha " + rotulo.text, ficha.get_global_rect().grow(-8).encloses(rotulo.get_global_rect()))
		await foto("desbloqueio_%dx%d" % [tamanho.x, tamanho.y])
		fechar.pressed.emit()
		verificar("toque fecha somente a ficha " + str(tamanho), not ficha.visible and inv.visible)
		inv._pesca._pagina = 0
		inv._pesca._aplicar_pagina()
		await quadros()
		inv._pesca._mostrar_dica("sardinha", inv._pesca._grade_peixes.get_node("sardinha"))
		await quadros()
		verificar("peixe liberado mostra requisito correto " + str(tamanho), ficha.find_children("*", "Label", true, false).any(func(rotulo): return rotulo.text.contains("LIBERADO")))
		verificar("ficha curta mantém botão acessível " + str(tamanho), ficha.get_global_rect().grow(-8).encloses(ficha.find_child("FecharFicha", true, false).get_global_rect()))
		await foto("ficha_liberada_%dx%d" % [tamanho.x, tamanho.y])
		inv._pesca._fechar_dica()
		interface._fechar_tela("inventario")
		interface._abrir_tela("guia_pesca")
		await quadros()
		var guia: Node = interface._telas["guia_pesca"]
		verificar("caderno atualiza habilidade ao abrir", guia._habilidade.get_child(0).text.contains("NV 49"))
		conferir(guia._habilidade, "caderno " + str(tamanho))
		await foto("caderno_%dx%d" % [tamanho.x, tamanho.y])
		interface._fechar_tela("guia_pesca")
	if "--so-tooltips" in OS.get_cmdline_user_args():
		await conferir_fichas_cooperativo()
		print("FALHAS: ", falhas)
		quit(1 if falhas else 0)
		return
	# Resultado real de uma captura: recompensa, subida de nível e texto acima da cabeça.
	root.get_node("Controle").usando_toque = false
	root.content_scale_size = Vector2i(576, 324)
	root.size = Vector2i(1152, 648)
	await quadros()
	change_scene_to_file("res://cenas/praia.tscn")
	await quadros(40)
	current_scene.get_node("Iluminacao").definir_hora(12)
	current_scene.get_node("Iluminacao").set_process(false)
	var jogador: CharacterBody2D = current_scene.get_node("Jogador")
	jogador.global_position = current_scene.get_node("PescaPierLeste").global_position
	fazenda.pesca_xp["p1"] = Habilidade.xp_para_nivel(50) - 10
	var sessao: Node = load("res://codigo/pesca/sessao_pesca.gd").new()
	sessao.iniciar(jogador, Vector2.RIGHT, "mar")
	sessao.peixe = "sardinha"
	sessao._pegar(true)
	await create_timer(0.4).timeout
	verificar("captura real sobe de nível", Habilidade.nivel(jogador) == 50)
	await foto("captura_subiu_nivel")
	sessao._terminar()
	await quadros()
	fazenda.pesca_xp["p1"] = Habilidade.xp_para_nivel(99)
	sessao = load("res://codigo/pesca/sessao_pesca.gd").new()
	sessao.iniciar(jogador, Vector2.RIGHT, "mar")
	sessao.peixe = "imperador_abissal"
	sessao._pegar(true)
	await create_timer(0.4).timeout
	await foto("captura_nivel_99")
	sessao._terminar()
	await quadros()
	# Os seis peixes, ampliados por vizinho mais próximo, junto dos dois ícones de referência.
	root.content_scale_size = Vector2i(576, 324)
	root.size = Vector2i(1152, 648)
	await quadros()
	var camada := CanvasLayer.new()
	root.add_child(camada)
	var painel := PanelContainer.new()
	painel.position = Vector2(20, 20)
	painel.size = Vector2(536, 284)
	camada.add_child(painel)
	var grade := GridContainer.new()
	grade.columns = 4
	grade.add_theme_constant_override("h_separation", 12)
	grade.add_theme_constant_override("v_separation", 12)
	painel.add_child(grade)
	for id in ["dourado", "salmao", "peixe_leao", "acara_disco", "peixe_mandarim", "aruana_prateada", "imperador_abissal", "carpa_celestial"]:
		var coluna := VBoxContainer.new()
		coluna.custom_minimum_size.x = 116
		grade.add_child(coluna)
		var icone := TextureRect.new()
		icone.texture = Peixes.icone(id)
		icone.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icone.custom_minimum_size = Vector2(64, 64)
		coluna.add_child(icone)
		var nome := Label.new()
		nome.text = Peixes.nome(id)
		nome.add_theme_font_size_override("font_size", 8)
		nome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		coluna.add_child(nome)
	await foto("icones_no_motor")
	camada.queue_free()
	print("FALHAS: ", falhas)
	quit(1 if falhas else 0)

func conferir_fichas_cooperativo() -> void:
	root.get_node("Controle").usando_toque = false
	root.content_scale_size = Vector2i(576, 324)
	root.size = Vector2i(1152, 648)
	await quadros()
	root.get_node("Saves").trocar("coop")
	var coop: Node = root.get_node("Cooperativo")
	coop.entrar(40)
	change_scene_to_file("res://cenas/palafita.tscn")
	await quadros(40)
	var paginas: Array = []
	for interface in [root.get_node("EventosJogo").interface_p1(), coop.interface_p2()]:
		interface._abrir_tela("inventario")
		var inventario: Node = interface._telas["inventario"]
		inventario.selecionar_pagina(3)
		await quadros()
		var pagina: Node = inventario._pesca
		pagina._pagina = 999
		pagina._aplicar_pagina()
		await quadros()
		pagina._mostrar_dica("imperador_abissal", pagina._grade_peixes.get_node("imperador_abissal"))
		await quadros()
		verificar("ficha respeita a metade do dono", pagina._area_dica.get_global_rect().grow(-8).encloses(pagina._dica.get_global_rect()))
		verificar("ficha cooperativa continua compacta", pagina._dica.size.y <= 145)
		paginas.append(pagina)
	await foto("fichas_cooperativo")
	paginas[0]._dica.find_child("FecharFicha", true, false).pressed.emit()
	verificar("fechar ficha de P1 preserva a de P2", not paginas[0]._dica.visible and paginas[1]._dica.visible)
