extends SceneTree

var falhas := 0
var capturar := false
const PASTA := "res://arte/previas/carpintaria/"

func _initialize() -> void: rodar.call_deferred()
func quadros(n := 12) -> void:
	for i in n:
		await process_frame
		await physics_frame
func verificar(texto: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ",texto)
	if not ok: falhas += 1
func foto(nome: String) -> void:
	if not capturar: return
	await quadros(3)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PASTA))
	root.get_texture().get_image().save_png(PASTA+nome+".png")

func rodar() -> void:
	await process_frame
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"): quit(1); return
	capturar = "--capturar" in OS.get_cmdline_user_args() and DisplayServer.get_name()!="headless"
	root.mode = Window.MODE_WINDOWED
	root.get_node("Introducao").pular_prologo()
	root.get_node("Transicao").hora_salva = 9
	root.get_node("Fazenda").clima_hoje = 0
	root.content_scale_size = Vector2i(576,324)
	root.size = Vector2i(1152,648)
	change_scene_to_file("res://cenas/cidade/carpintaria.tscn")
	await quadros(40)
	var casa = current_scene
	casa.get_node("Iluminacao").definir_hora(9)
	casa.get_node("Iluminacao").set_process(false)
	var helena = casa.moradores.helena
	var clara = casa.moradores.clara
	var apoio = casa.apoio_helena
	var jogador = casa.get_node("Jogador")
	jogador.position = Vector2(544,476)
	for id in ["osvaldo","helena","clara"]:
		var npc = casa.moradores[id]
		verificar("28 poses com altura dos moradores existentes: "+id,npc.sprite.hframes==7 and npc.sprite.vframes==4 and load("res://codigo/cidade/dados_cidade.gd").geometria_sprite(id).altura_mapa<=31)
	# Sem filha disponível, o caminho pode existir, mas a cadeira permanece parada.
	clara.visible = false
	helena._ir_ate(Vector2(264,450))
	var inicio: Vector2 = helena.position
	await quadros(30)
	verificar("Helena espera ajuda sem mover a cadeira sozinha",helena.position.distance_to(inicio)<0.1)
	clara.visible = true
	clara.position = helena.position+Vector2(0,20)
	await quadros(30)
	verificar("Clara assume os apoios e anima a dupla",apoio.estado=="empurrando" and not clara.sprite.visible and helena.sprite.texture.resource_path.ends_with("clara_empurrando_helena.png"))
	verificar("cadeira avança com a filha acompanhando",helena.position.distance_to(inicio)>1 and clara.position.distance_to(helena.position)<=21)
	var pausada: Vector2 = helena.position
	root.get_node("Cidade").conversar("clara",jogador)
	await quadros(8)
	verificar("conversar com Clara pausa a cadeira",helena.position.distance_to(pausada)<0.1)
	casa.get_node("Interface")._fechar_tela("conversa_cidade")
	await capturar_comparacao(casa)
	await testar_saida_assistida()
	print("FALHAS: ",falhas)
	quit(falhas)

func capturar_comparacao(casa: Node) -> void:
	if not capturar: return
	for npc in casa.moradores.values():
		npc.set_physics_process(false)
		npc.get_node("IndicadorPedido").process_mode = Node.PROCESS_MODE_DISABLED
		npc.get_node("IndicadorPedido").hide()
		npc.visible = npc.id in ["helena","clara"]
	for hud in get_nodes_in_group("hud"): hud.visible = false
	var helena = casa.moradores.helena
	var camera = casa.get_node("Jogador").camera
	camera.zoom = Vector2(3,3)
	camera.set_as_top_level(true)
	camera.global_position = Vector2(192,450)
	helena.position = Vector2(192,450)
	for direcao in 4:
		helena._linha = direcao
		for fase in 6:
			helena._tempo = fase/8.0
			casa.apoio_helena.depois_de_mover(true)
			await foto("clara-empurrando-%d-%d" % [direcao,fase])
	casa.apoio_helena._separar(false)
	var ids := ["ferreiro","curandeira","lia","osvaldo","helena","clara"]
	var nomes := ["Ivo","Rosa","Lia","Osvaldo","Helena","Clara"]
	for i in ids.size():
		var npc = casa.moradores[ids[i]]
		npc.visible = true
		npc.position = Vector2(72+i*40,450)
		var nome := Label.new()
		nome.text = nomes[i]
		nome.add_theme_font_override("font",load("res://assets/ui/Planes_ValMore.ttf"))
		nome.add_theme_font_size_override("font_size",7)
		nome.position = Vector2(npc.position.x-20,405)
		nome.size = Vector2(40,12)
		nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nome.z_as_relative = false
		nome.z_index = 1000
		casa.add_child(nome)
	camera.zoom = Vector2(2,2)
	camera.set_as_top_level(true)
	camera.global_position = Vector2(160,448)
	for hud in get_nodes_in_group("hud"): hud.visible = false
	for direcao in 4:
		for id in ids: casa.moradores[id].sprite.frame = direcao*7
		await foto("familia-no-jogo-"+str(direcao))

func testar_saida_assistida() -> void:
	# Nova cena remove os atores posicionados apenas para a comparação visual.
	change_scene_to_file("res://cenas/cidade/carpintaria.tscn")
	await quadros(40)
	var casa = current_scene
	var helena = casa.moradores.helena
	var clara = casa.moradores.clara
	var luz = casa.get_node("Iluminacao")
	luz.definir_hora(10)
	luz.set_process(false)
	casa.get_node("Jogador").position = Vector2(544,476)
	helena.atualizar_rotina()
	clara.atualizar_rotina()
	var trajetos: Dictionary = root.get_node("Cidade").trajetos_moradores
	verificar("mapa descarregado conserva chegada conjunta",trajetos.has("helena") and trajetos.has("clara") and trajetos.helena.chegada==trajetos.clara.chegada)
	var juntas := true
	for i in 2400:
		if i%30==0: await physics_frame
		helena._physics_process(1.0/60)
		clara._physics_process(1.0/60)
		if casa.apoio_helena.estado=="empurrando" and clara.position.distance_to(helena.position)>21: juntas=false
		if not helena.visible: break
	verificar("saída para a praça mantém filha e cadeira juntas",juntas and not helena.visible and not clara.visible)
	if helena.visible or clara.visible:
		print("Estado saída: ",casa.apoio_helena.estado," Helena ",helena.position," Clara ",clara.position," rotas ",helena.caminho.size(),"/",clara.caminho.size()," saindo ",helena._saindo,"/",clara._saindo)
		print("Pontos: ",helena.caminho)
		if not helena.caminho.is_empty():
			var colisao := KinematicCollision2D.new()
			if helena.test_move(helena.global_transform,helena.position.direction_to(helena.caminho[0]),colisao): print("Bloqueio: ",colisao.get_collider().get_path())
