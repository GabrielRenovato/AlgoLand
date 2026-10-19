extends SceneTree

## Valida as metades e os painéis reais, com saves isolados e troca de mapas.
var falhas := 0
var cooperativo: Node

func _initialize() -> void:
	_rodar()

func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ", nome)
	if not ok:
		falhas += 1

func quadros(n := 8) -> void:
	for i in n:
		await process_frame

func cabe(controle: Control) -> bool:
	var area := Rect2(Vector2.ZERO, controle.get_viewport_rect().size).grow(1.0)
	var retangulo := controle.get_global_rect()
	return area.encloses(retangulo)

func separados(interface: Node, nome: String) -> bool:
	if not interface._telas[nome].visible or not interface._telas["inventario"].visible:
		return interface._troca_companheira.visible
	return not interface._paineis[nome].get_global_rect().intersects(interface._paineis["inventario"].get_global_rect())

func carregar(caminho: String) -> void:
	change_scene_to_file(caminho)
	await quadros(20)
	await create_timer(0.3).timeout

func conferir_metades() -> void:
	var tamanho := root.get_visible_rect().size
	var camada := current_scene.get_node("TelaDividida")
	for lado in [1, 2]:
		var moldura: SubViewportContainer = camada.get_node("Vista%d" % lado)
		var vista: SubViewport = moldura.get_child(0)
		verificar("metade %d preenche a janela" % lado, (moldura.size * moldura.scale - Vector2(tamanho.x / 2.0, tamanho.y)).length() < 1.0)
		verificar("textura apresentada em pixels fisicos 1:1 %d" % lado, (moldura.scale * root.get_final_transform().get_scale()).is_equal_approx(Vector2.ONE))
		verificar("resolucao fisica da metade %d" % lado, Vector2(vista.size) == moldura.size and absf(vista.size.x - root.size.x / 2.0) < 1.0 and vista.size.y == root.size.y)
		verificar("origem na grade de pixels %d" % lado, (moldura.position * root.get_final_transform().get_scale()).is_equal_approx((moldura.position * root.get_final_transform().get_scale()).round()))
		var camera: Camera2D = vista.get_node("Camera")
		verificar("escala do mundo preservada %d" % lado, camera.zoom.is_equal_approx(current_scene.get_node("Jogador").camera.zoom))
		var hud: Node = vista.get_child(1)
		verificar("HUD pertence ao jogador %d" % lado, hud.is_in_group("hud_p%d" % lado))
		verificar("lembrete somente para jogador 1", (hud.get_node_or_null("MiniTutorial") != null) == (lado == 1))
		verificar("vida cabe %d" % lado, cabe(hud.get_node("Status")))
		verificar("calendario cabe %d" % lado, cabe(hud.get_node("CantoDireito")))
		verificar("vida e calendario separados %d" % lado, not hud.get_node("Status").get_global_rect().intersects(hud.get_node("CantoDireito").get_global_rect()))
		if hud.barra_armas != null:
			verificar("barra de itens cabe %d" % lado, cabe(hud.barra_armas._painel))

func conferir_telas() -> void:
	var camada := current_scene.get_node("TelaDividida")
	for lado in [1, 2]:
		var interface: Node = camada.get_node("Vista%d" % lado).get_child(0).get_child(2)
		for nome in ["inventario", "mercante", "bau", "acampamento", "mistica", "caldeirao", "mural_cidade", "desafio_arena", "conversa_cidade", "dormir", "pausa"]:
			interface._abrir_tela(nome)
			await create_timer(0.25).timeout
			var painel: Control = interface._paineis[nome]
			verificar("painel %s cabe no jogador %d: %s" % [nome, lado, painel.get_global_rect()], cabe(painel))
			if nome in ["mercante", "bau"]:
				var mochila: Control = interface._paineis["inventario"]
				verificar("%s e mochila sem sobreposicao %d" % [nome, lado], separados(interface,nome))
			if nome in ["mercante", "bau"]:
				var inventario: Node = interface._telas["inventario"]
				if interface._troca_companheira.visible:
					interface._troca_companheira.pressed.emit()
					await quadros(4)
				inventario._rolagem.ensure_control_visible(inventario._atributos)
				await quadros(4)
				var area: Rect2 = inventario.get_node("Sidebar").get_global_rect().grow(-8)
				verificar("atributos cabem na mochila compacta %d" % lado, area.encloses(inventario._atributos.get_global_rect()))
				for rotulo in inventario._atributos.get_children():
					verificar("atributo legivel %s %d" % [rotulo.text, lado], area.encloses(rotulo.get_global_rect()))
			if nome == "mercante":
				var loja: Node = interface._telas[nome]
				for aba in [loja._painel_loja, loja._painel_bigorna, loja._painel_encantar, loja._painel_vender]:
					loja._mostrar_aba(aba)
					await quadros(3)
					verificar("aba %s cabe ao lado da mochila %d" % [aba.name, lado], cabe(painel) and separados(interface,nome))
			interface._fechar_tela(nome)
		interface._abrir_tela("inventario")
		var inventario_aberto: Node = interface._telas["inventario"]
		inventario_aberto.selecionar_aba(true)
		interface._abrir_tela("mercante")
		await create_timer(0.25).timeout
		verificar("loja volta da aba missoes para itens %d" % lado, not inventario_aberto._aba_missoes)
		verificar("loja ajusta mochila ja aberta %d" % lado, separados(interface,"mercante"))
		interface._fechar_tela("mercante")
		# O X da mochila do jogador 2 precisa fechar a mochila dele.
		interface._abrir_tela("inventario")
		interface._telas["inventario"].find_child("BotaoFechar",true,false).pressed.emit()
		verificar("X fecha a mochila do dono %d" % lado, interface._telas_abertas.is_empty())
		interface._abrir_tela("inventario")
		await create_timer(0.25).timeout
		verificar("reabrir durante animacao mantem mochila visivel %d" % lado, cabe(interface._paineis["inventario"]))
		if lado == 1:
			# O clique atravessa as coordenadas físicas da moldura e as lógicas da interface.
			var moldura: Control = camada.get_node("Vista1")
			var fechar: Control = interface._telas["inventario"].find_child("BotaoFechar",true,false)
			var posicao := (moldura.position + fechar.get_global_rect().get_center()) * root.get_final_transform().get_scale()
			var mover := InputEventMouseMotion.new()
			mover.position = posicao
			mover.global_position = posicao
			root.push_input(mover)
			for pressionado in [true, false]:
				var clique := InputEventMouseButton.new()
				clique.button_index = MOUSE_BUTTON_LEFT
				clique.position = posicao
				clique.global_position = posicao
				clique.pressed = pressionado
				root.push_input(clique)
			await quadros(3)
			verificar("mouse fecha mochila na posicao visual", interface._telas_abertas.is_empty())
		interface._fechar_tela("inventario")

func _rodar() -> void:
	if not ProjectSettings.get_setting("application/config/use_custom_user_dir", false) or not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"):
		push_error("Execute em copia com diretorio de saves isolado.")
		quit(1)
		return
	await process_frame
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1152, 648)
	root.content_scale_size = Vector2i(576, 324)
	root.get_node("Saves").trocar("coop")
	cooperativo = root.get_node("Cooperativo")
	root.get_node("InventarioJogador").criar_itens_iniciais()
	root.get_node("InventarioJogador2").criar_itens_iniciais()
	root.get_node("Cidade").interlocutor = "mercador"
	await carregar("res://cenas/cidade.tscn")
	conferir_metades()
	await conferir_telas()
	if "--capturar" in OS.get_cmdline_user_args():
		var interface: Node = cooperativo.interface_p2()
		interface._abrir_tela("inventario")
		await create_timer(0.3).timeout
		await capturar("cidade")
		var interface_p1: Node = root.get_node("EventosJogo").interface_p1()
		interface_p1._abrir_tela("mercante")
		await create_timer(0.3).timeout
		await capturar("loja")
		interface_p1._fechar_tela("mercante")
		interface._fechar_tela("inventario")
	root.size = Vector2i(1536, 648)
	await quadros()
	conferir_metades()
	root.size = Vector2i(1920, 1080)
	await quadros()
	conferir_metades()
	await carregar("res://cenas/fazenda.tscn")
	conferir_metades()
	await carregar("res://cenas/cenario.tscn")
	conferir_metades()
	var hud: Node = current_scene.get_node("TelaDividida/Vista1").get_child(0).get_child(1)
	hud.anunciar("CHEFE DERROTADO", "ONDA 10 CONCLUIDA", 2.0)
	await create_timer(0.5).timeout
	verificar("aviso de onda cabe na metade", cabe_banner(hud.faixa_banner))
	verificar("aviso sem escala fracionaria", hud.faixa_banner.scale == Vector2.ONE)
	if "--capturar" in OS.get_cmdline_user_args():
		await capturar("arena")
	cooperativo.set_process(false)
	current_scene.queue_free()
	current_scene = null
	await quadros()
	cooperativo.sair()
	root.get_node("Saves").trocar("solo")
	await carregar("res://cenas/cidade.tscn")
	verificar("solo sem tela dividida", current_scene.get_node_or_null("TelaDividida") == null)
	var hud_solo: Node = get_first_node_in_group("hud_p1")
	verificar("calendario solo mantem formato", not hud_solo.rotulo_data.text.contains("\n"))
	current_scene.queue_free()
	current_scene = null
	await quadros()
	print("FALHAS: ", falhas)
	quit(1 if falhas else 0)

func cabe_banner(banner: Control) -> bool:
	return cabe(banner) and banner.size.x <= banner.get_viewport_rect().size.x - 15.0

func capturar(nome: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/algoland-ui-coop-%s.png" % nome)
