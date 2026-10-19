extends SceneTree
## Captura comparações no cenário real, sem acessar a partida do usuário.
var falhas := 0

func _initialize() -> void:
	rodar.call_deferred()

func quadros(n := 8) -> void:
	for i in n:
		await physics_frame
		await process_frame

func foto(nome: String) -> void:
	await quadros()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://arte/previas/npcs_base/"+nome+".png")

func rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes") or DisplayServer.get_name() == "headless":
		push_error("Use renderização gráfica e saves isolados.")
		quit(1)
		return
	await process_frame
	root.get_node("Saves").trocar("solo")
	root.get_node("Introducao").pular_prologo()
	root.get_node("Progresso").apagar()
	preload("res://codigo/globais/opcoes_jogo.gd").fechar_mini_tutorial()
	root.get_node("Calendario").dia = 1
	root.get_node("Fazenda").definir_clima_hoje(0)
	root.get_node("Transicao").hora_salva = 12.0
	root.content_scale_size = Vector2i(576,324)
	root.size = Vector2i(1152,648)
	change_scene_to_file("res://cenas/cidade.tscn")
	await quadros(35)
	root.get_node("Transicao").limpar()
	DirAccess.make_dir_recursive_absolute("res://arte/previas/npcs_base")
	var dados: GDScript = load("res://codigo/cidade/dados_cidade.gd")
	var praca: Vector2 = dados.ponto("praca")
	preparar_cena(praca+Vector2(0,75))
	var ids := ["mercador", "ferreiro", "bento"]
	for npc in current_scene.moradores.values():
		npc.set_physics_process(false)
		npc.calar()
		npc.visible = false
	for i in ids.size():
		var npc: Node2D = current_scene.moradores[ids[i]]
		npc.visible = true
		npc.global_position = praca+Vector2((i-1)*38,35)
		npc.z_index = preload("res://codigo/globais/profundidade.gd").z_de(npc.position.y+9)
		npc._atualizar_visual_chuva(0)
		npc.sprite.frame = 0
	await foto("moradores_vila")
	for linha in 4:
		for id in ids:
			current_scene.moradores[id].sprite.frame = linha*7+2
		await foto("direcao_%d" % linha)
	for id in ids:
		var npc: Node2D = current_scene.moradores[id]
		npc._atualizar_visual_chuva(preload("res://codigo/dados/estados_clima.gd").Estado.CHUVA_LEVE)
		npc.sprite.frame = 0
	await foto("capas_chuva")
	change_scene_to_file("res://cenas/cidade/forja.tscn")
	await quadros(35)
	root.get_node("Transicao").limpar()
	preparar_cena(Vector2(360,155))
	var ivo: Node2D = current_scene.moradores["ferreiro"]
	ivo.calar()
	await foto("ivo_oficina")
	# Exercita o animador real e a colisão, sem trocar a rotina no jogo.
	var inicio := ivo.position
	ivo._ir_ate(inicio+Vector2(30,0))
	var vistos := {}
	for i in 110:
		await physics_frame
		vistos[ivo.sprite.frame] = true
	if ivo.position.distance_to(inicio) <= 3 or vistos.size() < 3:
		push_error("Ivo não caminhou com a nova folha: " + str(vistos.keys()))
		falhas += 1
	print("CAMINHADA IVO: quadros=",vistos.keys()," deslocamento=",ivo.position.distance_to(inicio))
	var jogador: Node2D = current_scene.get_node("Jogador")
	jogador.visible = true
	root.get_node("Cidade").conversar("ferreiro",jogador)
	await quadros()
	var ui: Node = current_scene.get_node("Interface")
	ui._telas["conversa_cidade"]._avancar_fala()
	await foto("dialogo_ivo")
	ui._fechar_tela("conversa_cidade")
	root.get_node("Calendario").dia = 6
	root.get_node("Transicao").hora_salva = 19.0
	change_scene_to_file("res://cenas/cidade/pousada.tscn")
	await quadros(30)
	root.get_node("Transicao").limpar()
	var lugar: Vector2 = dados.LUGARES_FESTA["ferreiro"]
	preparar_cena(lugar+Vector2(0,30))
	for npc in current_scene.moradores.values():
		npc.set_physics_process(false)
		npc.calar()
	ivo = current_scene.moradores["ferreiro"]
	ivo.visible = true
	ivo._saindo = false
	ivo.position = lugar+Vector2(0,-12)
	ivo.agenda = {"local":"pousada", "ponto":lugar, "festa":true}
	for i in 30:
		ivo.caminho.clear()
		ivo.assento.atualizar(ivo,0.1)
	if ivo.assento.estado != "sentado":
		push_error("Ivo não completou a transição no banco: "+ivo.assento.estado)
		falhas += 1
	await foto("ivo_sentado")
	print("REVISAO IVO: ",falhas," falhas")
	quit(falhas)

func preparar_cena(posicao: Vector2) -> void:
	var luz: Node = current_scene.get_node("Iluminacao")
	luz.set_process(false)
	luz.definir_hora(12)
	luz._aplicar()
	for clima in get_nodes_in_group("clima"):
		clima.definir_clima(0,true)
	var jogador: Node2D = current_scene.get_node("Jogador")
	jogador.set_physics_process(false)
	jogador.global_position = posicao
	jogador.visible = false
	jogador.camera.zoom = Vector2(2,2)
	jogador.camera.offset = Vector2(0,-35)
	jogador.camera.position_smoothing_enabled = false
	jogador.camera.reset_smoothing()
	for hud in get_nodes_in_group("hud"):
		hud.visible = false
