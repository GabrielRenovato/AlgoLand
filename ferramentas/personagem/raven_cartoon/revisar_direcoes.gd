extends SceneTree
const SAIDA = "res://arte/previas/personagens/raven_cartoon/corrida_direcoes_4/motor/"

func _initialize():
	rodar.call_deferred()

func rodar():
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	assert(DisplayServer.get_name() != "headless")
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1152, 560)
	var cena = load("res://ferramentas/personagem/raven_cartoon/previa_quatro_direcoes.tscn").instantiate()
	root.add_child(cena)
	current_scene = cena
	var atores = []
	for nome in ["frente", "costas", "direita", "esquerda"]:
		var ator = cena.get_node("Raven_" + nome)
		assert(ator.sprite_frames.get_frame_count("correr_" + nome) == 4)
		assert(ator.sprite_frames.get_animation_speed("correr_" + nome) == 10.0)
		assert(ator.offset == Vector2(-256, -850))
		atores.append(ator)
	var ciclos = [0]
	atores[0].animation_looped.connect(func(): ciclos[0] += 1)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA))
	var vistos = {}
	var mudancas = []
	var anterior = -1
	var inicio = Time.get_ticks_msec()
	while (vistos.size() < 4 or ciclos[0] < 2) and Time.get_ticks_msec()-inicio < 5000:
		await RenderingServer.frame_post_draw
		var quadro = atores[0].frame
		for ator in atores:
			assert(ator.frame == quadro)
		if quadro != anterior:
			mudancas.append([quadro, Time.get_ticks_msec()-inicio])
			anterior = quadro
		if not vistos.has(quadro):
			vistos[quadro] = true
			root.get_texture().get_image().save_png(SAIDA+"quadro_%02d.png" % (quadro+1))
		await process_frame
	assert(vistos.size() == 4 and ciclos[0] >= 2)
	FileAccess.open(SAIDA+"reproducao.json", FileAccess.WRITE).store_string(JSON.stringify({"direcoes": 4, "quadros_por_direcao": 4, "fps": 10, "ciclos_observados": ciclos[0], "trocas": mudancas}, "\t"))
	print("CARTOON: quatro direções sincronizadas, quatro quadros, 10fps, dois ciclos reproduzidos em save isolado.")
	cena.queue_free()
	await process_frame
	quit()
