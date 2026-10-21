extends SceneTree
var falhas := 0
func _initialize() -> void: rodar.call_deferred()
func esperar(n: int) -> void:
	for i in n: await process_frame
func conferir(ok: bool, mensagem: String) -> void:
	if not ok:
		falhas += 1
		push_error(mensagem)
func rodar() -> void:
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	root.get_node("Introducao").pular_prologo()
	change_scene_to_file("res://cenas/casa.tscn")
	await esperar(25)
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = Vector2i(576,324)
	root.size = Vector2i(1152,648)
	var jogador = current_scene.get_node("Jogador")
	jogador.set_physics_process(false)
	var cama = get_first_node_in_group("cama")
	var saida := ProjectSettings.globalize_path("res://arte/previas/cama_raven")
	DirAccess.make_dir_recursive_absolute(saida)
	for pele in 3:
		jogador.aparencia_raven = {"pele":pele,"cabelo":28,"roupa":8,"cor":[0.35,0.6,1,1]}
		await esperar(3)
		var dados: Dictionary = jogador.aparencia_raven.duplicate(true)
		cama.deitar(jogador)
		await esperar(3)
		var cabeca = cama.get_node("Cabeca")
		conferir(cabeca.get_child_count()==11,"Sono inclui corpo, roupa, cabelo e quatro peças")
		conferir(cabeca.get_node("Camada6").modulate.is_equal_approx(Color(0.35,0.6,1,1)),"Tintura preservada")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(saida+"/pele%d.png" % pele)
		cama.levantar()
		await esperar(3)
		conferir(jogador.visible and jogador.aparencia_raven==dados,"Acordar preserva aparência")
	for fonte: FontFile in [preload("res://assets/ui/Planes_ValMore.ttf"), preload("res://assets/ui/craftpix-net-775352-game-user-interface-pixel-art/6 Font/CraftPixNet Survival Kit.otf")]:
		for caractere in "áãçÇÃ·▲▼": conferir(fonte.has_char(caractere.unicode_at(0)),"Fonte contém "+caractere)
	print("CAMA RAVEN: ", falhas, " falhas")
	quit(1 if falhas else 0)
