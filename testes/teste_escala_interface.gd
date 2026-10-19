extends SceneTree

## HUD, menus, clique e preferências com saves isolados. Com janela e --capturar, salva prévias reais.
const Opcoes := preload("res://codigo/globais/opcoes_jogo.gd")
const Escala := preload("res://codigo/ui/escala_interface.gd")
var falhas := 0
var opcoes: Dictionary

func _initialize() -> void: _rodar.call_deferred()
func _quadros(n := 16) -> void:
	for i in n: await process_frame
func _verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ", nome)
	if not ok: falhas += 1
func _cabe(no: Control) -> bool:
	var area: Rect2 = no.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, no.size)
	return no.get_viewport().get_visible_rect().grow(1).encloses(area)
func _clique(no: Control) -> void:
	var pos := no.get_global_transform_with_canvas() * (no.size / 2)
	for pressionado in [true,false]:
		var evento := InputEventMouseButton.new()
		evento.position = pos
		evento.button_index = MOUSE_BUTTON_LEFT
		evento.pressed = pressionado
		root.push_input(evento,true)
func _carregar(caminho: String) -> void:
	change_scene_to_file(caminho)
	await _quadros(24)
	await create_timer(0.25).timeout
func _aplicar(valor: float) -> void:
	opcoes.escala_interface = valor
	Opcoes.aplicar(opcoes)
	Opcoes.salvar(opcoes)
	await _quadros()
func _rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"):
		push_error("Use saves isolados.")
		quit(1)
		return
	root.mode = Window.MODE_WINDOWED
	root.get_node("Saves").trocar("solo")
	root.content_scale_size = Vector2i(576,324)
	root.size = Vector2i(1152,648)
	opcoes = Opcoes.carregar()
	opcoes.tela_cheia = false
	await _aplicar(1.0)
	root.get_node("Introducao").pular_prologo()
	root.get_node("InventarioJogador").criar_itens_iniciais()
	for mapa in ["cidade", "casa", "fazenda", "praia", "palafita", "cenario"]:
		await _carregar("res://cenas/%s.tscn" % mapa)
		var hud := get_first_node_in_group("hud")
		_verificar("barra de itens visivel em " + mapa, hud.barra_armas != null and hud.barra_armas.is_visible_in_tree() and _cabe(hud.barra_armas._painel))
		_verificar("modo de ferramentas somente na fazenda " + mapa, hud.barra_armas.modo_fazenda == (mapa == "fazenda"))
	await _carregar("res://cenas/cidade.tscn")
	var hud := get_first_node_in_group("hud")
	var ui := current_scene.get_node("Interface")
	var jogador := current_scene.get_node("Jogador")
	var zoom_original: Vector2 = jogador.camera.zoom
	var posicao_original: Vector2 = hud.barra_armas._painel.position
	for valor in [1.25,1.5,0.75,1.0]:
		await _aplicar(valor)
		_verificar("escala aplicada e persistida %s" % valor, hud.scale.is_equal_approx(Vector2.ONE * valor * Escala.BASE_DESKTOP) and is_equal_approx(Opcoes.carregar().escala_interface,valor))
		_verificar("zoom do mundo preservado %s" % valor, jogador.camera.zoom.is_equal_approx(zoom_original))
		_verificar("HUD e barra cabem %s" % valor, _cabe(hud.get_node("Status")) and _cabe(hud.get_node("CantoDireito")) and _cabe(hud.barra_armas._painel))
		ui._abrir_tela("pausa")
		var pausa: Control = ui._telas.pausa
		pausa._mostrar(pausa.Vista.OPCOES)
		await _quadros()
		await create_timer(0.2).timeout
		_verificar("opcoes cabem com interface %s" % valor, _cabe(ui._paineis.pausa))
		var linha: Dictionary = pausa._linhas.filter(func(l): return l.chave == "escala_interface")[0]
		pausa._rolagem_opcoes.ensure_control_visible(linha.menos)
		await _quadros()
		_clique(linha.menos)
		await _quadros()
		var esperado: float = Opcoes.ESCALAS_INTERFACE[maxi(Opcoes.ESCALAS_INTERFACE.find(valor)-1,0)]
		_verificar("clique acompanha escala %s" % valor, Opcoes.carregar().escala_interface == esperado)
		ui._fechar_tela("pausa")
	await _aplicar(1.0)
	_verificar("retornar a 100 nao acumula deslocamento", hud.barra_armas._painel.position.is_equal_approx(posicao_original))
	# A preferência do parceiro não deve alterar a do jogador 1.
	var p2 := Opcoes.carregar(2)
	p2.escala_interface = 0.75
	Opcoes.aplicar(p2,2)
	Opcoes.salvar(p2,2)
	_verificar("tamanho por jogador preservado", Opcoes.carregar(2).escala_interface == 0.75 and Opcoes.carregar(1).escala_interface == 1.0)
	root.get_node("Controle").usando_toque = true
	await _carregar("res://cenas/fazenda.tscn")
	hud = get_first_node_in_group("hud")
	for tamanho in [Vector2i(720,324),Vector2i(480,270)]:
		root.content_scale_size = tamanho
		root.size = tamanho * 2
		for valor in [0.75,1.25,1.5,1.0]:
			await _aplicar(valor)
			_verificar("barra mobile cabe %s / %s" % [tamanho,valor], _cabe(hud.barra_armas._painel))
			ui = current_scene.get_node("Interface")
			var controles: Node
			for filho in ui.get_children():
				if filho is CanvasLayer: controles = filho
			var ataque: Dictionary = controles._botao_da_acao(&"attack")
			var retangulo: Rect2 = hud.barra_armas._painel.get_global_transform_with_canvas() * Rect2(Vector2.ZERO,hud.barra_armas._painel.size)
			var livre := true
			for botao in controles._botoes:
				if not botao.visivel: continue
				var perto: Vector2 = botao.centro.clamp(retangulo.position,retangulo.end)
				livre = livre and perto.distance_to(botao.centro) >= float(botao.raio)
			_verificar("barra nao cobre comandos mobile %s / %s" % [tamanho,valor],livre)
			var vistos := {}
			var barra: Control = hud.barra_armas
			var fileira: int = barra._fileira
			for pagina in barra._paginas_por_fileira():
				for i in barra._casas_por_pagina:
					var coluna: int = barra._celula(i) - fileira * barra._casas.size()
					if coluna < barra._casas.size(): vistos[coluna] = true
				barra.proxima_linha()
			_verificar("paginacao permite acessar todos os itens da fileira",vistos.size() == barra._casas.size())
			barra._fileira = fileira
			barra._pagina_barra = 0
			barra._atualizar()
			await _quadros()
			var centro: Vector2 = controles.transform * ataque.centro
			var toque := InputEventScreenTouch.new()
			toque.index = 7
			toque.position = centro
			toque.pressed = true
			root.push_input(toque,true)
			_verificar("botao mobile recebe toque escalado %s / %s" % [tamanho,valor], controles._dedos.has(7))
			toque.pressed = false
			root.push_input(toque,true)
			_verificar("toque escalado solta sem prender", not controles._dedos.has(7))
			var casa: Control = hud.barra_armas._casas[0]
			toque.position = casa.get_global_transform_with_canvas() * (casa.size / 2)
			toque.pressed = true
			root.push_input(toque,true)
			_verificar("tocar item nao aciona joystick %s / %s" % [tamanho,valor], controles._dedo_joystick == -1)
			toque.pressed = false
			root.push_input(toque,true)
			if "--capturar" in OS.get_cmdline_user_args():
				DirAccess.make_dir_recursive_absolute("res://arte/previas/ui/escala")
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://arte/previas/ui/escala/mobile_%d_%s.png" % [tamanho.x,valor])
	# Cada metade aplica sua própria escala; viajar sozinho não pode esconder a barra.
	root.get_node("Controle").usando_toque = false
	root.content_scale_size = Vector2i(576,324)
	root.size = Vector2i(1152,648)
	root.get_node("Saves").trocar("coop")
	root.get_node("InventarioJogador2").criar_itens_iniciais()
	await _aplicar(1.25)
	await _carregar("res://cenas/cidade.tscn")
	var coop := root.get_node("Cooperativo")
	var camada := current_scene.get_node("TelaDividida")
	for lado in [1,2]:
		var vista: SubViewport = camada.get_node("Vista%d" % lado).get_child(0)
		var hud_coop := vista.get_child(1)
		_verificar("HUD e barra cabem com escalas proprias no coop %d" % lado, _cabe(hud_coop.get_node("Status")) and _cabe(hud_coop.get_node("CantoDireito")) and _cabe(hud_coop.barra_armas._painel))
		_verificar("escala propria aplicada na metade %d" % lado, hud_coop.scale.is_equal_approx(Vector2.ONE * Escala.fator(hud_coop)))
	for caminho in ["res://cenas/casa.tscn","res://cenas/fazenda.tscn","res://cenas/cidade.tscn"]:
		await coop.viajar_local(coop.jogador2(),caminho,"entrada")
		await _quadros()
		var hud_coop: Node = coop._vistas[2].get_child(1)
		_verificar("barra permanece na viagem individual " + caminho, hud_coop.barra_armas.is_visible_in_tree() and hud_coop.barra_armas.modo_fazenda == caminho.ends_with("fazenda.tscn"))
	await _aplicar(1.0)
	p2.escala_interface = 1.0
	Opcoes.aplicar(p2,2)
	Opcoes.salvar(p2,2)
	current_scene.queue_free()
	current_scene = null
	await _quadros()
	print("FALHAS: ",falhas)
	quit(1 if falhas else 0)
