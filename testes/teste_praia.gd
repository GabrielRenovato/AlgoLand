extends SceneTree

var falhas := 0
var verificacoes := 0

func _initialize() -> void:
	_rodar()

func verificar(nome: String, ok: bool) -> void:
	verificacoes += 1
	print("OK " if ok else "FALHA ", nome)
	if not ok:
		falhas += 1

func quadros(n := 8) -> void:
	for i in n:
		await process_frame
	await physics_frame
	await physics_frame

func carregar(caminho: String) -> Node2D:
	if current_scene != null:
		current_scene.queue_free()
		current_scene = null
		await quadros()
	root.get_node("Transicao").hora_salva = 12.0
	var cena: Node2D = load(caminho).instantiate()
	root.add_child(cena)
	current_scene = cena
	await quadros()
	cena.get_node("Iluminacao").set_process(false)
	return cena

func bloqueado(cena: Node2D, ponto: Vector2) -> bool:
	var consulta := PhysicsPointQueryParameters2D.new()
	consulta.position = ponto
	consulta.collision_mask = 64
	return not cena.get_world_2d().direct_space_state.intersect_point(consulta).is_empty()

## Consulta o corpo inteiro dos pés, não apenas um ponto no centro da passagem.
func corpo_bloqueado(jogador: CharacterBody2D, ponto: Vector2) -> bool:
	var pes: CollisionShape2D = jogador.get_node("CollisionShape2D")
	var consulta := PhysicsShapeQueryParameters2D.new()
	consulta.shape = pes.shape
	consulta.transform = Transform2D(0, ponto + pes.position)
	consulta.collision_mask = 64
	return not jogador.get_world_2d().direct_space_state.intersect_shape(consulta).is_empty()

func capturar_colisoes(praia: Node2D, nome: String, centro: Vector2, zoom := 2.0) -> void:
	if not "--capturar-colisoes" in OS.get_cmdline_user_args():
		return
	var camera: Camera2D = praia.get_node("Jogador").camera
	root.size = Vector2i(1408, 1152)
	root.content_scale_size = Vector2i(704, 576)
	camera.position_smoothing_enabled = false
	camera.zoom = Vector2.ONE * zoom
	camera.set_as_top_level(true)
	camera.global_position = centro
	await quadros(8)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/algoland-colisoes-%s.png" % nome)

func apertar_interacao(dispositivo := -1) -> void:
	for pressionado in [true, false]:
		await physics_frame
		if dispositivo < 0:
			var evento := InputEventKey.new()
			evento.physical_keycode = KEY_F
			evento.pressed = pressionado
			Input.parse_input_event(evento)
		else:
			var evento := InputEventJoypadButton.new()
			evento.device = dispositivo
			evento.button_index = JOY_BUTTON_A
			evento.pressed = pressionado
			Input.parse_input_event(evento)
		for i in 2:
			await physics_frame
			await process_frame

func verificar_bancos(praia: Node2D) -> void:
	var jogador: CharacterBody2D = praia.get_node("Jogador")
	for x in [208, 432]:
		var banco: Sprite2D = praia.get_node("MobiliarioCais/banco_%d_176" % x)
		var assento: Area2D = banco.get_node_or_null("Assento")
		verificar("banco %d tem interação" % x, assento != null)
		if assento == null:
			continue
		jogador.position = banco.position + Vector2(0, 8)
		await quadros()
		await create_timer(0.3).timeout
		verificar("banco %d acessível sem atravessar colisão" % x, not corpo_bloqueado(jogador, jogador.position) and assento.disponivel_para_interacao())
		await apertar_interacao()
		verificar("F senta no banco %d de frente" % x, jogador.esta_sentado and assento.ocupada and jogador.assento_atual == assento and jogador.sprite_corpo_forja.frame == 35)
		verificar("jogador fica à frente do encosto %d" % x, jogador.z_index > banco.z_index)
		if x == 208:
			await capturar_colisoes(praia, "banco", Vector2(208, 166), 4.0)
		await create_timer(0.65).timeout
		await apertar_interacao()
		verificar("F levanta do banco %d em espaço livre" % x, not jogador.esta_sentado and not assento.ocupada and jogador.movimento_habilitado and not corpo_bloqueado(jogador, jogador.position))
		verificar("banco %d pode ser reutilizado" % x, assento.pode_interagir_para(jogador))

func _rodar() -> void:
	if not ProjectSettings.get_setting("application/config/use_custom_user_dir", false) or not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"):
		push_error("Use a cópia isolada da praia.")
		quit(1)
		return
	await process_frame
	root.get_node("Calendario").dia = 1
	root.get_node("Fazenda").definir_clima_hoje(0)
	var cidade := await carregar("res://cenas/cidade.tscn")
	verificar("cidade leva à praia", cidade.get_node("TrilhaPraia").cena_destino == "res://cenas/praia.tscn")
	verificar("chegada de volta fora da passagem", cidade.get_node("Chegada_praia").position.distance_to(cidade.get_node("TrilhaPraia").position) > 28)
	var caminho_livre := true
	for y in range(464, 576, 8):
		if bloqueado(cidade, Vector2(336, y)):
			var consulta := PhysicsPointQueryParameters2D.new()
			consulta.position = Vector2(336, y)
			consulta.collision_mask = 64
			print("Obstáculo na saída sul y=", y, ": ", cidade.get_world_2d().direct_space_state.intersect_point(consulta))
		caminho_livre = caminho_livre and not bloqueado(cidade, Vector2(336, y))
	verificar("saída sul inteira livre de obstáculos", caminho_livre)
	verificar("borda sul continua fechada fora da rua", bloqueado(cidade, Vector2(280, 570)) and bloqueado(cidade, Vector2(400, 570)))
	var praia := await carregar("res://cenas/praia.tscn")
	verificar("volta para a cidade", praia.get_node("VoltaCidade").cena_destino == "res://cenas/cidade.tscn" and praia.get_node("VoltaCidade").ponto_chegada == "praia")
	verificar("areia caminhável", not bloqueado(praia, Vector2(256, 240)))
	verificar("entrada livre", not bloqueado(praia, Vector2(336, 0)))
	verificar("mar bloqueado nos dois lados", bloqueado(praia, Vector2(300, 380)) and bloqueado(praia, Vector2(400, 380)))
	verificar("píer caminhável até a ponta", not bloqueado(praia, Vector2(360, 450)))
	verificar("fim do píer impede cair no mar", bloqueado(praia, Vector2(352, 520)))
	verificar("cais lateral e plataforma da casa caminháveis", not bloqueado(praia, Vector2(136, 400)) and not bloqueado(praia, Vector2(400, 352)) and not bloqueado(praia, Vector2(560, 400)))
	verificar("vão entre os píeres continua sendo mar", bloqueado(praia, Vector2(240, 410)))
	var anterior: float = praia.material_mar.get_shader_parameter("tempo")
	praia._process(1.3)
	verificar("mar e espuma avançam na animação", praia.material_mar.get_shader_parameter("tempo") > anterior)
	var adornos := praia.get_node("DecoracaoPraia").get_children()
	verificar("coqueiros e conchas presentes", adornos.filter(func(no): return no.name.begins_with("coqueiro")).size() == 6 and adornos.filter(func(no): return no.name.begins_with("conchas")).size() == 10)
	verificar("tronco tem colisão", bloqueado(praia, Vector2(74, 160)))
	var margem_correta := true
	for x in range(32, 672, 32):
		if (x >= 112 and x <= 160) or (x >= 320 and x <= 384) or (x >= 448 and x <= 640):
			continue
		var costa := 300 + 16 * sin(x * 0.011) + 8 * sin(x * 0.027)
		margem_correta = margem_correta and not bloqueado(praia, Vector2(x, costa - 6)) and bloqueado(praia, Vector2(x, costa + 10))
	verificar("colisão acompanha margem curva", margem_correta)
	var nilo := praia.get_node("Nilo")
	verificar("NPC próprio com quatro direções", nilo.sprite.hframes == 4 and nilo.sprite.texture.resource_path.ends_with("nilo.png"))
	var catalogo: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/pesca/catalogo.json"))
	verificar("12 peixes Tiny RPG catalogados", catalogo["peixes"].size() == 12)
	for id in catalogo["peixes"]:
		verificar("ícone original carregável: " + id, load(catalogo["peixes"][id]["icone"]) is Texture2D)
	var jogador: Node2D = praia.get_node("Jogador")
	verificar("base da fachada bloqueada", bloqueado(praia, Vector2(544, 350)))
	verificar("frente da porta cabe o corpo inteiro", not corpo_bloqueado(jogador, Vector2(544, 349)))
	verificar("passagem diante da casa livre", not corpo_bloqueado(jogador, Vector2(544, 360)) and not corpo_bloqueado(jogador, Vector2(568, 360)))
	jogador.position = Vector2(544, 349)
	await quadros()
	verificar("jogador diante da porta não fica atrás da casa", jogador.z_index >= praia.get_node("Palafita").z_index)
	verificar("porta permanece alcançável", praia.get_node("PortaPalafita").disponivel_para_interacao())
	for estacao in 4:
		root.get_node("Calendario").dia = 1 + estacao * 7
		root.get_node("Calendario").estacao_mudou.emit(estacao)
		await quadros()
		verificar("casa e corrimão preservam colisão na estação %d" % estacao, bloqueado(praia, Vector2(544, 350)) and bloqueado(praia, Vector2(636, 400)))
		await capturar_colisoes(praia, "casa-estacao-%d" % estacao, Vector2(544, 326), 3.0)
	root.get_node("Calendario").dia = 1
	root.get_node("Calendario").estacao_mudou.emit(0)
	verificar("corrimãos verticais bloqueiam suas bases", bloqueado(praia, Vector2(116, 410)) and bloqueado(praia, Vector2(156, 410)) and bloqueado(praia, Vector2(636, 400)))
	verificar("corredor do cais livre entre corrimãos", not corpo_bloqueado(jogador, Vector2(136, 410)) and not corpo_bloqueado(jogador, Vector2(416, 344)))
	verificar("tronco inclinado B bloqueia sua base real", bloqueado(praia, Vector2(132, 104)) and not bloqueado(praia, Vector2(150, 104)))
	verificar("tronco A bloqueia sua base real", bloqueado(praia, Vector2(80, 160)))
	await verificar_bancos(praia)
	await capturar_colisoes(praia, "geral", Vector2(352, 288), 1.0)
	jogador.position = Vector2(368, 406)
	await quadros()
	var zona := nilo.get_node("Interacao")
	zona.abrir_tela()
	await quadros()
	var interface := praia.get_node("Interface")
	verificar("Nilo abre guia com ícones", interface._telas["guia_pesca"].visible and interface._telas["guia_pesca"]._grade.get_child_count() == 12)
	verificar("conversa bloqueia ações do jogador", not jogador.movimento_habilitado)
	interface._telas["guia_pesca"]._fechar.pressed.emit()
	await quadros()
	verificar("fechar devolve controle", not interface._telas["guia_pesca"].visible and jogador.movimento_habilitado)
	if "--capturar" in OS.get_cmdline_user_args():
		root.size = Vector2i(1408, 1152)
		root.content_scale_size = Vector2i(704, 576)
		jogador.camera.position_smoothing_enabled = false
		jogador.camera.zoom = Vector2.ONE
		jogador.camera.set_as_top_level(true)
		jogador.camera.global_position = Vector2(352, 288)
		await quadros(30)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://arte/previas/praia/praia_jogo.png")
		if "--mar-animado" in OS.get_cmdline_user_args():
			DirAccess.make_dir_recursive_absolute("/tmp/algoland-praia-mar")
			praia.set_process(false)
			for i in 24:
				praia.material_mar.set_shader_parameter("tempo", i * 0.2)
				await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("/tmp/algoland-praia-mar/quadro_%02d.png" % i)
			praia.set_process(true)
		zona.abrir_tela()
		await quadros(30)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://arte/previas/praia/catalogo_nilo.png")
		interface._telas["guia_pesca"]._fechar.pressed.emit()
	# O segundo jogador conversa e atravessa sozinho, mantendo o primeiro na praia.
	root.get_node("Saves").trocar("coop")
	root.get_node("Fazenda").definir_clima_hoje(0)
	root.get_node("Transicao").hora_salva = 12.0
	change_scene_to_file("res://cenas/praia.tscn")
	await quadros(40)
	await create_timer(0.3).timeout
	var coop: Node = root.get_node("Cooperativo")
	var p2: Node2D = coop.jogador2()
	verificar("segundo jogador criado na praia", p2 != null)
	if p2 != null:
		var p1: Node2D = coop._jogador1()
		coop.dispositivo_p1 = 41
		coop.dispositivo_p2 = 40
		coop._reconfigurar_entrada()
		p1.position = Vector2(208, 184)
		p2.position = Vector2(432, 184)
		await quadros()
		await apertar_interacao()
		await apertar_interacao(40)
		verificar("P1 e P2 sentam simultaneamente nos bancos da praia", p1.esta_sentado and p2.esta_sentado)
		await create_timer(0.65).timeout
		await apertar_interacao(40)
		verificar("controle de P2 levanta sem afetar P1", not p2.esta_sentado and p1.esta_sentado and not corpo_bloqueado(p2, p2.position))
		await apertar_interacao()
		verificar("P1 levanta sem sentar novamente no mesmo toque", not p1.esta_sentado and not corpo_bloqueado(p1, p1.position))
		var nilo_coop := current_scene.get_node("Nilo")
		var conversa_coop := nilo_coop.get_node("Interacao")
		p2.position = Vector2(368, 406)
		await quadros()
		conversa_coop.abrir_tela_p2()
		await quadros()
		var interface2: Node = coop.interface_p2()
		var guia2: Control = interface2._telas["guia_pesca"]
		verificar("catálogo abre somente para P2", guia2.visible and not root.get_node("EventosJogo").interface_p1()._telas["guia_pesca"].visible)
		verificar("P1 continua livre durante conversa de P2", p1.movimento_habilitado and not p2.movimento_habilitado)
		verificar("catálogo cabe na metade de P2", Rect2(Vector2.ZERO, guia2.size).encloses(guia2.painel.get_global_rect()))
		guia2._fechar.pressed.emit()
		await quadros()
		verificar("fechar libera P2", p2.movimento_habilitado and not guia2.visible)
		coop.viajar_local(p2, "res://cenas/cidade.tscn", "praia")
		await quadros(40)
		verificar("P2 visita cidade enquanto P1 fica na praia", coop.cena_de(p2).get("local") == "cidade" and coop.cena_de(p1).get("local") == "praia")
		verificar("praia e cidade têm mundos separados", p1.get_world_2d() != p2.get_world_2d())
		coop.viajar_local(p2, "res://cenas/praia.tscn", "cidade")
		await quadros(40)
		verificar("P2 retorna à praia compartilhada", p1.get_world_2d() == p2.get_world_2d())
		current_scene.get_node("Iluminacao").definir_hora(18)
		var nilo_casa: Node2D = current_scene.get_node("Nilo")
		p1.position = Vector2(336, 64)
		p2.position = Vector2(390, 220)
		nilo_casa.atualizar_rotina()
		coop.viajar_local(p2, "res://cenas/palafita.tscn", "entrada")
		await quadros(40)
		var casa: Node = coop.cena_de(p2)
		verificar("P2 entra na palafita sem levar P1", casa.get("local") == "palafita" and coop.cena_de(p1).get("local") == "praia")
		var nilo_interior: Node2D = casa.get_node("Nilo")
		verificar("Nilo não duplica enquanto caminha para casa", nilo_casa.visible and not nilo_interior.visible)
		nilo_casa.set_physics_process(false)
		for i in 2400:
			if not nilo_casa.visible:
				break
			nilo_casa._physics_process(1.0 / 30)
			if i % 100 == 0:
				await quadros(1)
		await quadros(20)
		verificar("mesmo Nilo chega ao interior no cooperativo", not nilo_casa.visible and nilo_interior.visible)
		coop.viajar_local(p2, "res://cenas/praia.tscn", "palafita")
		await quadros(40)
		verificar("P2 volta da palafita para a praia compartilhada", p1.get_world_2d() == p2.get_world_2d())
	print("Praia: %d verificações, %d falhas." % [verificacoes, falhas])
	current_scene.queue_free()
	current_scene = null
	await quadros()
	quit(1 if falhas else 0)
