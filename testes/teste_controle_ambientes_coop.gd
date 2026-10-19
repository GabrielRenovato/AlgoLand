extends SceneTree

var falhas := 0
var coop: Node
var controle: Node

func _initialize() -> void:
	_rodar()

func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ", nome)
	if not ok:
		falhas += 1

func quadros(n := 8) -> void:
	for i in n:
		await process_frame

func botao(device: int, indice: int) -> void:
	for pressionado in [true, false]:
		var evento := InputEventJoypadButton.new()
		evento.device = device
		evento.button_index = indice
		evento.pressed = pressionado
		root.push_input(evento)
		await process_frame

func entrada_real(device: int, indice: int, pressionado: bool) -> void:
	var evento := InputEventJoypadButton.new()
	evento.device = device
	evento.button_index = indice
	evento.pressed = pressionado
	Input.parse_input_event(evento)

func _rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"):
		push_error("Use saves isolados.")
		quit(1)
		return
	await process_frame
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1152, 648)
	root.get_node("Saves").trocar("coop")
	coop = root.get_node("Cooperativo")
	controle = root.get_node("Controle")
	for nome in ["InventarioJogador", "InventarioJogador2"]:
		root.get_node(nome).limpar()
		root.get_node(nome).criar_itens_iniciais()
	change_scene_to_file("res://cenas/cidade.tscn")
	await quadros(20)
	verificar("cercas decorativas foram montadas", get_nodes_in_group("cercas_vila").size() >= 12)
	for id in ["venda", "sede", "enfermaria", "pousada", "mistica", "casa_bento"]:
		var chegada: Node2D = current_scene.get_node("Chegada_" + id)
		verificar("cercas deixam acesso a " + id, not current_scene.caminho_entre(Vector2(336, 284), chegada.position).is_empty())
	var estacoes: Node = current_scene.get_node("Terrains/Estacoes")
	var terreno: TileMapLayer = current_scene.get_node("Terrains/Terreno")
	var nomes := ["spring", "summer", "autumn", "winter"]
	var contagem := terreno.get_used_cells().size()
	for indice in 4:
		estacoes.definir_estacao(indice, true)
		await quadros()
		var imagem: Image = terreno.tile_set.get_source(0).texture.get_image()
		var original: Image = load("res://assets/cenario/Seasonal Forest/seasonal sample (%s).png" % nomes[indice]).get_image()
		var igual := true
		for y in 16:
			for x in 16:
				igual = igual and imagem.get_pixel(x, y + 64) == original.get_pixel(x, y + 16)
		verificar("cidade usa grama Mana Seed original: " + nomes[indice], igual)
		verificar("estacao preserva celulas do mapa: " + nomes[indice], terreno.get_used_cells().size() == contagem)
		if "--capturar" in OS.get_cmdline_user_args():
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/algoland-grama-%s.png" % nomes[indice])
	estacoes.definir_estacao(0, true)
	coop.dispositivo_p1 = coop.SEM_CONTROLE
	coop.dispositivo_p2 = 40
	coop._reconfigurar_entrada()
	controle._definir(false)
	await botao(40, JOY_BUTTON_BACK)
	await quadros()
	var interface: Node = coop.interface_p2()
	verificar("controle abre mochila do jogador 2", interface._telas_abertas.has("inventario"))
	var vista: SubViewport = coop._vistas[2]
	var foco := vista.gui_get_focus_owner()
	verificar("mochila inicia com item selecionado no controle", foco != null and "item_atual" in foco)
	verificar("jogador 2 nao troca modo do teclado do jogador 1", not controle.usando_controle)
	var mochila: Node = interface._telas["inventario"]
	verificar("dica do item aparece no jogador 2", mochila._info_item.visible)
	verificar("dica usa botao do controle", controle.rotulo_acao("ui_accept", mochila) == "A")
	await botao(40, JOY_BUTTON_DPAD_RIGHT)
	verificar("direcional navega entre slots", vista.gui_get_focus_owner() != null and vista.gui_get_focus_owner() != foco)
	var slot: Control = mochila._slots_mochila[0]
	slot.grab_focus()
	await quadros()
	var item = slot.item_atual
	await botao(40, JOY_BUTTON_A)
	await quadros()
	verificar("confirmar equipa item no inventario do jogador 2", root.get_node("InventarioJogador2").equipados.get("arma") == item)
	verificar("inventario do jogador 1 nao recebe item do parceiro", root.get_node("InventarioJogador").equipados.get("arma") != item)
	await botao(40, JOY_BUTTON_B)
	verificar("B fecha mochila do jogador 2", interface._telas_abertas.is_empty())
	coop.dispositivo_p1 = 41
	coop._reconfigurar_entrada()
	await botao(41, JOY_BUTTON_BACK)
	var interface_p1: Node = root.get_node("EventosJogo").interface_p1()
	var vista_p1: SubViewport = coop._vistas[1]
	verificar("jogador 1 seleciona item com seu controle", vista_p1.gui_get_focus_owner() != null)
	await botao(40, JOY_BUTTON_BACK)
	var foco_p1 := vista_p1.gui_get_focus_owner()
	await botao(40, JOY_BUTTON_DPAD_RIGHT)
	verificar("controle do jogador 2 nao move selecao do jogador 1", vista_p1.gui_get_focus_owner() == foco_p1)
	var foco_p2 := vista.gui_get_focus_owner()
	await botao(41, JOY_BUTTON_DPAD_LEFT)
	verificar("controle do jogador 1 nao move selecao do jogador 2", vista.gui_get_focus_owner() == foco_p2)
	controle._definir(false)
	verificar("mouse do jogador 1 nao esconde dica do jogador 2", mochila._info_item.visible)
	var cidade_estado: Node = root.get_node("Cidade")
	cidade_estado.missoes.clear()
	mochila.selecionar_aba(true)
	await quadros()
	verificar("aba mostra estado sem missoes", mochila._missoes._lista.get_child_count() == 1 and mochila._missoes._lista.get_child(0) is Label)
	cidade_estado.aceitar("cancao")
	cidade_estado.missoes["boas_vindas"] = {"estado": "concluida"}
	cidade_estado.alterado.emit()
	await quadros()
	verificar("lista mostra somente missoes ativas", mochila._missoes._lista.get_child_count() == 1 and mochila._missoes._lista.get_child(0).get_meta("missao") == "cancao")
	for i in 3:
		cidade_estado.registrar_onda(i)
	await quadros()
	var textos := ""
	for rotulo in mochila._missoes.find_children("*", "Label", true, false):
		textos += rotulo.text + " "
	verificar("missao mostra progresso recompensa e entrega", textos.contains("3 / 3") and textos.contains("20 BRASAS") and textos.contains("PRONTA PARA ENTREGAR"))
	verificar("aba de missoes independente por jogador", not interface_p1._telas["inventario"]._aba_missoes)
	await botao(40, JOY_BUTTON_LEFT_SHOULDER)
	verificar("LB volta aos itens no jogador 2", not mochila._aba_missoes and mochila._rolagem.visible)
	await botao(40, JOY_BUTTON_RIGHT_SHOULDER)
	verificar("RB abre missoes no jogador 2", mochila._aba_missoes and mochila._missoes.is_visible_in_tree())
	await botao(40, JOY_BUTTON_DPAD_DOWN)
	var foco_missao := vista.gui_get_focus_owner()
	verificar("direcional seleciona missao para rolagem", foco_missao != null and foco_missao.has_meta("missao"))
	await botao(41, JOY_BUTTON_RIGHT_SHOULDER)
	verificar("jogador 1 tambem troca aba pelo controle", interface_p1._telas["inventario"]._aba_missoes)
	for ator in [coop._jogador1(), coop.jogador2()]:
		ator.definir_sprites_visiveis(false)
		verificar("arma nas costas restaurada jogador " + str(ator.name), ator._armas_nas_costas() and (ator.sprite_espada.visible == ator.usando_espada) and (ator.sprite_lanca.visible == ator.usando_lanca))
	if "--capturar" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/algoland-missoes-coop.png")
	await botao(40, JOY_BUTTON_B)
	await botao(41, JOY_BUTTON_B)
	verificar("cada controle fecha apenas a propria mochila", interface._telas_abertas.is_empty() and interface_p1._telas_abertas.is_empty())
	mochila.selecionar_aba(false)
	interface_p1._telas["inventario"].selecionar_aba(false)
	current_scene.get_node("Iluminacao").definir_hora(6.0)
	current_scene.get_node("Porta_venda").abrir_tela_p2()
	await create_timer(0.25).timeout
	var aviso: Node = interface._telas["introducao"]
	verificar("aviso de loja fechada aparece no jogador 2", interface._telas_abertas.has("introducao") and aviso._texto.text.contains("Fechado"))
	verificar("aviso tem texto e botao visiveis", aviso._texto.is_visible_in_tree() and not aviso._avancar.text.is_empty())
	verificar("aviso nao abre na metade do jogador 1", interface_p1._telas_abertas.is_empty())
	await botao(40, JOY_BUTTON_B)
	verificar("B fecha aviso sem travar jogador 2", interface._telas_abertas.is_empty() and coop.jogador2().movimento_habilitado)
	var porta_loja: Node2D = current_scene.get_node("Porta_venda")
	var posicao_antes: Vector2 = coop.jogador2().global_position
	coop.jogador2().global_position = porta_loja.global_position
	await quadros()
	entrada_real(40, JOY_BUTTON_A, true)
	await quadros(4)
	verificar("A abre o aviso de loja fechada pela porta", interface._telas_abertas.has("introducao"))
	entrada_real(40, JOY_BUTTON_A, false)
	await create_timer(0.25).timeout
	entrada_real(40, JOY_BUTTON_A, true)
	await quadros(8)
	verificar("A em ENTENDI fecha sem reabrir enquanto segurado", interface._telas_abertas.is_empty())
	entrada_real(40, JOY_BUTTON_A, false)
	await quadros(4)
	entrada_real(40, JOY_BUTTON_A, true)
	await quadros(4)
	verificar("uma nova pressao pode interagir novamente", interface._telas_abertas.has("introducao"))
	entrada_real(40, JOY_BUTTON_A, false)
	await create_timer(0.25).timeout
	await botao(40, JOY_BUTTON_B)
	coop.jogador2().global_position = posicao_antes
	await quadros()
	var dados := load("res://codigo/cidade/dados_cidade.gd")
	for hora in [18.0, 23.0, 0.0, 1.99]:
		verificar("taverna aberta a noite: " + str(hora), dados.taverna_aberta(hora))
		verificar("Caio atende a noite: " + str(hora), not dados.agenda("bardo", hora, 0, -1, 0).get("dormindo", false))
	for hora in [2.0, 8.0, 12.0, 17.99]:
		verificar("taverna fechada de dia: " + str(hora), not dados.taverna_aberta(hora))
	verificar("enfermaria abre as 8", dados.servico_fechado("curandeira", 7.99, 0) != "" and dados.servico_fechado("curandeira", 8.0, 0) == "")
	verificar("enfermaria fecha as 18", dados.servico_fechado("curandeira", 17.99, 0) == "" and dados.servico_fechado("curandeira", 18.0, 0) != "")
	var luz: Node = current_scene.get_node("Iluminacao")
	for caso in [["pousada", 12.0, false], ["pousada", 18.0, true], ["pousada", 0.0, true], ["enfermaria", 18.0, false], ["enfermaria", 8.0, true]]:
		luz.definir_hora(caso[1])
		current_scene.get_node("Porta_" + caso[0])._atravessar(coop.jogador2())
		await quadros()
		if caso[2]:
			verificar("porta abre no horario: %s %s" % [caso[0], caso[1]], coop.cena_de(coop.jogador2()).scene_file_path.ends_with(caso[0] + ".tscn"))
			await coop.viajar_local(coop.jogador2(), "res://cenas/cidade.tscn", caso[0])
		else:
			verificar("porta fechada informa horario: %s %s" % [caso[0], caso[1]], interface._telas_abertas.has("introducao") and not aviso._texto.text.is_empty())
			await create_timer(0.25).timeout
			await botao(40, JOY_BUTTON_B)
	luz.definir_hora(6.0)
	var p1: Node2D = coop._jogador1()
	var p2: Node2D = coop.jogador2()
	var posicao_p2 := p2.global_position
	var cidade := current_scene
	var casa := "res://cenas/cidade/casa_bento.tscn"
	p1.hp_atual = 37
	await coop.viajar_local(p1, casa, "entrada")
	await quadros()
	verificar("jogador 1 entra na casa sem trocar a cena do parceiro", current_scene == cidade and coop.cena_de(p1).scene_file_path == casa)
	verificar("jogador 2 permanece no lugar da cidade", p2.global_position.distance_to(posicao_p2) < 8.0 and coop.cena_de(p2) == cidade)
	verificar("jogadores em ambientes fisicos distintos", p1.get_world_2d() != p2.get_world_2d())
	verificar("porta preserva personagem e vida", coop._jogador1() == p1 and p1.hp_atual == 37)
	if "--capturar" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/algoland-casas-independentes.png")
	await coop.viajar_local(p2, casa, "entrada")
	await quadros()
	verificar("parceiro pode entrar na mesma casa", p1.get_world_2d() == p2.get_world_2d() and coop.cena_de(p1) == coop.cena_de(p2))
	var posicao_na_casa := p2.global_position
	await coop.viajar_local(p1, "res://cenas/cidade.tscn", "casa_bento")
	await quadros()
	verificar("jogador 1 volta para cidade sem puxar o parceiro", coop.cena_de(p1) == cidade and coop.cena_de(p2).scene_file_path == casa and p2.global_position == posicao_na_casa)
	var interior: Node = coop.cena_de(p2)
	p2.global_position = interior.get_node("Saida").global_position
	for i in 12:
		await physics_frame
	verificar("saida automatica da casa funciona para jogador 2", coop.cena_de(p2) == cidade)
	await coop.viajar_local(p2, "res://cenas/cidade/pousada.tscn", "entrada")
	await quadros()
	verificar("jogador 2 pode visitar outra casa sozinho", coop.cena_de(p2).scene_file_path.ends_with("pousada.tscn") and coop.cena_de(p1) == cidade)
	await coop.viajar_local(p2, "res://cenas/cidade.tscn", "pousada")
	await quadros()
	verificar("reencontro na cidade compartilha o mundo", p1.get_world_2d() == p2.get_world_2d())
	var posicao_cidade := p2.global_position
	await coop.viajar_local(p1, "res://cenas/fazenda.tscn", "porta")
	await quadros()
	verificar("fazenda independente preserva parceiro na cidade", coop.cena_de(p1).scene_file_path.ends_with("fazenda.tscn") and coop.cena_de(p2) == cidade and p2.global_position.distance_to(posicao_cidade) < 8.0)
	var fazenda: Node = coop.cena_de(p1)
	await coop.viajar_local(p1, "res://cenas/casa.tscn", "entrada")
	await quadros()
	verificar("casa da fazenda so move quem entrou", coop.cena_de(p1).scene_file_path.ends_with("/casa.tscn") and coop.cena_de(p2) == cidade)
	p1.global_position = coop.cena_de(p1).get_node("SaidaCasa").global_position
	for i in 12:
		await physics_frame
	verificar("saida da casa retorna a fazenda preservada", coop.cena_de(p1) == fazenda)
	await coop.viajar_local(p1, "res://cenas/cidade.tscn", "fazenda")
	await quadros()
	verificar("retorno da fazenda mantem identidade e vida", coop._jogador1() == p1 and p1.hp_atual == 37)
	for id in ["venda", "sede", "enfermaria", "pousada", "mistica", "casa_bento"]:
		await coop.viajar_local(p1, "res://cenas/cidade/%s.tscn" % id, "entrada")
		await quadros()
		var sala: Node = coop.cena_de(p1)
		var porta: Node2D = sala.get_node("Saida")
		p1.global_position = porta.global_position + Vector2(0, -12)
		for i in 4:
			await physics_frame
		verificar("nao sai antes de pisar no bloco: " + id, coop.cena_de(p1) == sala)
		p1.global_position = porta.global_position + Vector2(0, -10)
		for i in 8:
			await physics_frame
		verificar("sai depois de cruzar o bloco: " + id, coop.cena_de(p1) == cidade)
	await coop.viajar_local(p1, "res://cenas/casa.tscn", "entrada")
	await quadros()
	var casa_fazenda: Node = coop.cena_de(p1)
	var porta_fazenda: Node2D = casa_fazenda.get_node("SaidaCasa")
	p1.global_position = porta_fazenda.global_position + Vector2(0, -12)
	for i in 4:
		await physics_frame
	verificar("casa da fazenda nao sai antes de pisar no bloco", coop.cena_de(p1) == casa_fazenda)
	p1.global_position = porta_fazenda.global_position + Vector2(0, -10)
	for i in 8:
		await physics_frame
	verificar("casa da fazenda sai depois de cruzar o bloco", coop.cena_de(p1).scene_file_path.ends_with("fazenda.tscn"))
	# Conferência da mesa de cristal com a moradora em seu ponto real de trabalho.
	current_scene.get_node("Iluminacao").definir_hora(12.0)
	root.get_node("Calendario").dia = 1
	await coop.viajar_local(p1, "res://cenas/cidade/mistica.tscn", "entrada")
	await quadros()
	var casa_mistica: Node = coop.cena_de(p1)
	var estela: Node2D = casa_mistica.moradores["mistica"]
	var ponto_trabalho: Vector2 = dados.InteriorCasa.ponto("mistica", "trabalho")
	verificar("Estela fica ao lado da bola de cristal", ponto_trabalho.x < 299.0 and estela.global_position.distance_to(ponto_trabalho) < 3.0)
	if "--capturar" in OS.get_cmdline_user_args():
		p1.global_position = Vector2(280, 128)
		await quadros()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/algoland-estela-corrigida.png")
	# Verifica as camadas em repouso, durante o golpe e ao trocar a família da arma.
	for ator in [p1, p2]:
		ator.troca_sem_pose = true
		if ator.usando_espada:
			ator.desequipar_espada()
		ator.equipar_espada()
		ator.definir_sprites_visiveis(false)
		verificar("espada aparece nas costas: " + str(ator.name), ator.sprite_espada.visible)
		ator.definir_sprites_visiveis(true)
		verificar("golpe usa camada de ataque: " + str(ator.name), not ator.sprite_espada.visible and ator.braco_espada_ataque.visible)
		ator.equipar_lanca()
		ator.definir_sprites_visiveis(false)
		verificar("troca para lanca nas costas: " + str(ator.name), ator.sprite_lanca.visible and not ator.sprite_espada.visible)
		ator.desequipar_lanca()
		ator.definir_sprites_visiveis(false)
		verificar("desequipar remove arma das costas: " + str(ator.name), not ator.sprite_lanca.visible and not ator.sprite_espada.visible)
	coop.set_process(false)
	current_scene.queue_free()
	current_scene = null
	await quadros()
	coop.sair()
	print("FALHAS: ", falhas)
	quit(1 if falhas else 0)
