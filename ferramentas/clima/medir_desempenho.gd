extends SceneTree
## Medição reproduzível; somente em projeto com saves isolados.
func _initialize() -> void:
	rodar.call_deferred()
func rodar() -> void:
	if not OS.get_user_data_dir().contains("AlgoLand testes"):
		quit(1)
		return
	await process_frame
	var nome := "cenario"
	for argumento in OS.get_cmdline_user_args():
		if argumento in ["cidade", "fazenda"]:
			nome = argumento
	root.get_node("Introducao").pular_prologo()
	var cena: Node = load("res://cenas/%s.tscn" % nome).instantiate()
	root.add_child(cena)
	current_scene = cena
	for i in 12:
		await process_frame
	var clima: Node = get_first_node_in_group("clima")
	clima.modo_economico = "--economico" in OS.get_cmdline_user_args()
	var t := Time.get_ticks_usec()
	clima.invalidar_coberturas()
	clima._coberto(Vector2(-99999,-99999))
	print("PERFIL ",nome," coberturas=",clima._coberturas.size()," coleta_us=",Time.get_ticks_usec()-t)
	t = Time.get_ticks_usec()
	for i in 1000:
		clima._coberto(Vector2(-99999,-99999))
	print("PERFIL consultas_1000_us=",Time.get_ticks_usec()-t)
	for estado in [0, 2, 5, 6]:
		clima.definir_clima(estado, true)
		var total := 0
		var pico := 0
		for i in 120:
			t = Time.get_ticks_usec()
			clima._process(1.0/60.0)
			var custo := Time.get_ticks_usec()-t
			total += custo
			pico = maxi(pico,custo)
		print("PERFIL estado=",estado," medio_us=",total/120.0," pico_us=",pico)
	if "--capturar" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute("/tmp/algoland-clima-android-previas")
		for estado in [3, 6]:
			clima.definir_clima(estado, true)
			for i in 4: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/algoland-clima-android-previas/%s_%d.png" % [nome,estado])
	cena.queue_free()
	await process_frame
	quit()
