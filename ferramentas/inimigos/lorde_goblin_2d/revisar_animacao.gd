extends SceneTree
## Reprodução gráfica do recurso no mapa real; só aceita o save isolado de revisão.
const SAIDA := "/tmp/algoland-lorde2d-revisao/capturas/"

func _initialize() -> void:
	rodar.call_deferred()

func rodar() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes lorde2d"):
		push_error("A revisão exige save exclusivo.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(SAIDA)
	var catalogo: Dictionary = load("res://codigo/campanha/catalogo_campanha.gd").dados()
	var progresso = load("res://codigo/campanha/progresso_campanha.gd").new()
	progresso.iniciar("user://percurso_primeira_raiz", "prototipo")
	for missao in ["sobreviver_queda", "estrada_interrompida", "acolhimento", "pomar_sulcos", "defesa_da_vila"]:
		for objetivo in catalogo.missoes[missao].objetivos:
			progresso.registrar_objetivo(missao,objetivo.id)
	progresso.recompensas = progresso._concluidas.duplicate()
	progresso.salvar_retorno("moinho",Vector2(0,80))
	set_meta("campanha_destino","moinho")
	set_meta("campanha_nova_instancia",false)
	set_meta("dicas_vistas",{"golpe":true,"rebento":true})
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = Vector2i(576,324)
	root.size = Vector2i(1152,648)
	change_scene_to_file("res://cenas/campanha/percurso_prototipo.tscn")
	await scene_changed
	var cena = current_scene
	var limite := Time.get_ticks_msec()+30000
	while not is_instance_valid(cena.terreno) and Time.get_ticks_msec()<limite:
		await process_frame
	if not is_instance_valid(cena.terreno):
		push_error("Mapa real indisponível para revisão.")
		quit(1)
		return
	await create_timer(1.0).timeout
	cena.jogador.set_physics_process(false)
	# Os consumidores antigos têm âncoras próprias; comparar o apoio visível no chão.
	cena.jogador.global_position = Vector2(-65,94)
	for mob in get_nodes_in_group("enemy"):
		mob.set_physics_process(false)
		mob.hide()
	for antiga in cena.find_children("*","Camera2D",true,false): antiga.enabled=false
	var camera := Camera2D.new()
	cena.add_child(camera)
	camera.global_position = Vector2(0,75)
	camera.make_current()
	cena.hud.hide()
	cena.interface.hide()
	var comum: AnimatedSprite2D = load("res://cenas/inimigos/goblin_machado_2d_visual.tscn").instantiate()
	var lorde: AnimatedSprite2D = load("res://cenas/inimigos/lorde_goblin_2d_visual.tscn").instantiate()
	cena.add_child(comum)
	cena.add_child(lorde)
	comum.position = Vector2(-10,115)
	lorde.position = Vector2(65,105)
	comum.z_index = preload("res://codigo/globais/profundidade.gd").z_de(105)
	lorde.z_index = comum.z_index
	comum.play("parado_direita")
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(SAIDA+"no_mapa.png")
	var imagens: Array[Image] = []
	var instantes: Array[float] = []
	var quadros: Array[int] = []
	var repetiu := false
	var inicio := Time.get_ticks_msec()
	lorde.play("martelada_direita")
	while Time.get_ticks_msec()-inicio<2700:
		var tempo := (Time.get_ticks_msec()-inicio)/1000.0
		if tempo>=1.35 and not repetiu:
			lorde.stop()
			lorde.play("martelada_direita")
			repetiu=true
		await RenderingServer.frame_post_draw
		var imagem := root.get_texture().get_image()
		var fator := Vector2(imagem.get_size())/Vector2(1152,648)
		imagens.append(imagem.get_region(Rect2i(Vector2(375,180)*fator,Vector2(520,245)*fator)))
		instantes.append((Time.get_ticks_msec()-inicio)/1000.0)
		quadros.append(lorde.frame)
		await create_timer(0.015).timeout
	for i in imagens.size(): imagens[i].save_png(SAIDA+"motor_%03d.png"%i)
	FileAccess.open(SAIDA+"reproducao.json",FileAccess.WRITE).store_string(JSON.stringify({"instantes_s":instantes,"quadros":quadros,"save_isolado":OS.get_user_data_dir(),"ciclos":2},"\t"))
	print("LORDE_2D_REVISAO: dois ataques no mapa real, ao lado do jogador e do goblin comum; save isolado.")
	imagens.clear()
	cena.queue_free()
	await process_frame
	await process_frame
	quit()
