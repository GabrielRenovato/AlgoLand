extends SceneTree
## Consulta do mapa no celular sem painel permanente cobrindo a partida.
var falhas := 0
func _initialize() -> void: rodar.call_deferred()
func quadros(n := 10) -> void:
	for i in n:
		await process_frame
		await physics_frame
func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ", nome)
	if not ok: falhas += 1
func foto(nome: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/algoland-minimapa-" + nome + ".png")
func conferir(hud: Node, nome: String) -> void:
	var mapa: Control = hud.get_node("MinimapaAndar")
	verificar("mapa recolhido deixa área do jogador livre: " + nome, mapa.recolhido_no_toque() and not mapa._painel.visible)
	var botao: Button = hud.find_child("BotaoMapaMundi", true, false)
	verificar("botão MAPA continua disponível: " + nome, botao != null and botao.is_visible_in_tree())
	var escala_topo := preload("res://codigo/ui/escala_interface.gd").fator(hud)
	var resumo: Label = hud.get_node("CantoDireito/ResumoToque")
	verificar("relógio abaixo dos acessos: " + nome, resumo.get_global_rect().position.y * escala_topo >= 48)
	await foto(nome + "-recolhido")
	if botao == null:
		return
	var escala := preload("res://codigo/ui/escala_interface.gd").fator(hud)
	var area_botao: Rect2 = botao.get_global_transform_with_canvas() * Rect2(Vector2.ZERO,botao.size)
	var controles: Node
	for candidato in current_scene.find_children("*", "CanvasLayer", true, false):
		if candidato.get_script() == load("res://codigo/ui/controles_toque.gd") and candidato.get_viewport() == hud.get_viewport():
			controles = candidato
	if controles != null:
		var painel_barra: Control = hud.barra_armas._painel
		var area_barra := Rect2(painel_barra.get_global_rect().position * escala, painel_barra.size * escala)
		var sem_sobreposicao := true
		for controle: Dictionary in controles._botoes:
			if not controle["visivel"]: continue
			var raio: float = float(controle["raio"]) + controles.FOLGA_TOQUE
			var area := Rect2(controle["centro"] - Vector2.ONE * raio, Vector2.ONE * raio * 2)
			if area.intersects(area_botao) or area.intersects(area_barra):
				print("SOBREPOSICAO ", nome, " ", controle["acao"], " controle=", area, " barra=", area_barra, " mapa=", area_botao)
			sem_sobreposicao = sem_sobreposicao and not area.intersects(area_botao) and not area.intersects(area_barra)
		verificar("mapa e barra separados dos controles: " + nome, sem_sobreposicao)
	var entrada := InputEventScreenTouch.new()
	entrada.index = 9
	entrada.position = area_botao.get_center()
	entrada.pressed = true
	hud.get_viewport().push_input(entrada, true)
	entrada = entrada.duplicate()
	entrada.pressed = false
	hud.get_viewport().push_input(entrada, true)
	await quadros()
	verificar("botão abre consulta do andar: " + nome, mapa._grande and mapa._painel.visible)
	if controles != null: verificar("consulta esconde controles de combate: " + nome, not controles._ativo and not controles._tela.visible)
	var tela := preload("res://codigo/ui/escala_interface.gd").tamanho_logico(hud)
	verificar("consulta cabe no viewport: " + nome, Rect2(Vector2.ZERO, tela).grow(-8).encloses(mapa._painel.get_global_rect()))
	var interior: Rect2 = mapa._painel.get_global_rect().grow(-9.5)
	verificar("título mapa legenda e dica respeitam moldura: " + nome, interior.encloses(mapa._titulo.get_global_rect()) and interior.encloses(mapa._mapa.get_global_rect()) and interior.encloses(mapa._legenda.get_global_rect()) and interior.encloses(mapa._dica.get_global_rect()))
	verificar("mapa preserva proporções: " + nome, absf(mapa._mapa.size.y / mapa._mapa.size.x - mapa._tamanho_mundo.y / mapa._tamanho_mundo.x) < 0.02)
	await foto(nome + "-aberto")
	var toque := InputEventScreenTouch.new()
	toque.pressed = true
	toque.position = mapa._painel.size * 0.5
	mapa._painel.gui_input.emit(toque)
	await quadros()
	verificar("toque fecha e libera o mundo: " + nome, not mapa._grande and not mapa._painel.visible)
	if controles != null: verificar("fechar restaura controles: " + nome, controles._ativo and controles._tela.visible)
	# Segundo caminho de fechamento: o próprio botão já existente no HUD.
	botao.pressed.emit()
	await quadros()
	botao.pressed.emit()
	await quadros()
	verificar("botão MAPA também fecha consulta: " + nome, not mapa._grande and not mapa._painel.visible)
func rodar() -> void:
	await process_frame
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"):
		quit(1)
		return
	root.mode = Window.MODE_WINDOWED
	root.get_node("Saves").trocar("solo")
	root.get_node("Controle").usando_toque = true
	root.get_node("Introducao").pular_prologo()
	load("res://codigo/ui/mini_tutorial.gd")._fechado = 1
	root.get_node("Transicao").retornando = true
	root.get_node("Transicao").estado = {"onda_atual": 3}
	root.get_node("Transicao").iniciar_onda_ao_chegar = false
	change_scene_to_file("res://cenas/fendas/andar_03.tscn")
	await quadros(30)
	root.get_node("Transicao").retornando = false
	current_scene.get_node("enemySpawner/GerenciadorOndas").set_physics_process(false)
	current_scene.get_node("Jogador").set_physics_process(false)
	var hud := get_first_node_in_group("hud_p1")
	var mapa: Control = hud.get_node("MinimapaAndar")
	for tamanho in [Vector2i(576,324), Vector2i(390,540), Vector2i(288,216)]:
		root.get_node("Controle").usando_toque = true
		root.content_scale_size = tamanho
		root.size = tamanho * 2
		await quadros()
		await conferir(hud, "toque_%dx%d" % [tamanho.x, tamanho.y])
	root.content_scale_size = Vector2i(576,324)
	root.size = Vector2i(1152,648)
	for valor in [0.75,1.25]:
		var opcoes: Dictionary = load("res://codigo/globais/opcoes_jogo.gd").carregar()
		opcoes.escala_interface = valor
		load("res://codigo/globais/opcoes_jogo.gd").aplicar(opcoes)
		await quadros()
		await conferir(hud,"escala_%d" % roundi(valor*100))
	var padrao: Dictionary = load("res://codigo/globais/opcoes_jogo.gd").carregar()
	padrao.escala_interface = 1.0
	load("res://codigo/globais/opcoes_jogo.gd").aplicar(padrao)
	root.get_node("Controle").usando_toque = false
	root.size = Vector2i(1152,648)
	root.content_scale_size = Vector2i(576,324)
	await quadros()
	verificar("PC mantém miniatura no canto", mapa._painel.visible and not mapa._grande)
	await foto("pc")
	root.get_node("Saves").trocar("coop")
	root.get_node("Introducao").pular_prologo()
	root.get_node("Controle").usando_toque = true
	root.content_scale_size = Vector2i(576,324)
	root.get_node("Transicao").retornando = true
	root.get_node("Transicao").estado = {"onda_atual": 3}
	change_scene_to_file("res://cenas/fendas/andar_03.tscn")
	await quadros(30)
	root.get_node("Transicao").retornando = false
	for lado in [1,2]:
		var hud_coop := get_first_node_in_group("hud_p%d" % lado)
		await conferir(hud_coop, "coop_p%d" % lado)
	current_scene.queue_free()
	current_scene = null
	await quadros()
	print("Minimapa mobile: %d falhas" % falhas)
	quit(1 if falhas else 0)
