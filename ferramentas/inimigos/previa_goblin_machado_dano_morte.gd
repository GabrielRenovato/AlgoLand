extends SceneTree
## Reprodução no mapa com o jogador real e save exclusivo para revisão.
var pasta_saida := "/tmp/algoland-machado-dano-morte/"
var capturas: Array[Image] = []
var instantes: Array[float] = []

func _initialize() -> void:
	rodar.call_deferred()

func rodar() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes goblin adaga"):
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(pasta_saida)
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
	var limite := Time.get_ticks_msec() + 30000
	while not is_instance_valid(cena.terreno) and Time.get_ticks_msec() < limite:
		await process_frame
	if not is_instance_valid(cena.terreno):
		push_error("Prévia sem terreno: não validar sobre fundo vazio.")
		quit(1)
		return
	await create_timer(1.0).timeout
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1152,648)
	cena.jogador.set_physics_process(false)
	cena.jogador.global_position = Vector2(-64,80)
	for mob in get_nodes_in_group("enemy"):
		mob.set_physics_process(false)
		mob.hide()
	for camera_antiga in cena.find_children("*","Camera2D",true,false):
		camera_antiga.enabled = false
	var camera := Camera2D.new()
	cena.add_child(camera)
	camera.global_position = Vector2(0,60)
	camera.make_current()
	cena.hud.hide()
	cena.interface.hide()
	var atores: Array[AnimatedSprite2D] = []
	var direcoes := ["direita","esquerda","baixo","cima"]
	cena.jogador.global_position = Vector2(-115,80)
	for i in direcoes.size():
		var ator = load("res://cenas/inimigos/goblin_machado_2d_visual.tscn").instantiate()
		cena.add_child(ator)
		ator.position = Vector2(-65+i*65,92)
		ator.z_index = preload("res://codigo/globais/profundidade.gd").z_de(92)
		ator.reiniciar(direcoes[i])
		atores.append(ator)
	var estados: Array[Dictionary] = []
	var inicio := Time.get_ticks_msec()
	var danificou := false
	var matou := false
	while (Time.get_ticks_msec()-inicio)/1000.0<3.0:
		var tempo := (Time.get_ticks_msec()-inicio)/1000.0
		if tempo>=.2 and not danificou:
			for i in atores.size(): atores[i].tocar("ferido",direcoes[i])
			danificou = true
		if tempo>=.9 and not matou:
			for i in atores.size(): atores[i].tocar("morte",direcoes[i])
			matou = true
		await RenderingServer.frame_post_draw
		var imagem := root.get_texture().get_image()
		capturas.append(_recortar(imagem,Rect2i(260,265,780,160)))
		instantes.append(tempo)
		var ficha := {"tempo":tempo,"atores":[]}
		for ator in atores: ficha.atores.append({"animacao":String(ator.animation),"quadro":ator.frame})
		estados.append(ficha)
		await create_timer(.02).timeout
	for i in capturas.size(): capturas[i].save_png(pasta_saida+"dano-morte-%03d.png"%i)
	FileAccess.open(pasta_saida+"instantes.json",FileAccess.WRITE).store_string(JSON.stringify(instantes))
	FileAccess.open(pasta_saida+"estados.json",FileAccess.WRITE).store_string(JSON.stringify(estados))
	print("GOBLIN_MACHADO_DANO_MORTE: quatro direcoes; dano, recuperacao, queda e corpo final, save isolado")
	quit()

func _recortar(imagem: Image, regiao: Rect2i) -> Image:
	var fator := Vector2(imagem.get_size()) / Vector2(1152,648)
	return imagem.get_region(Rect2i(Vector2(regiao.position) * fator, Vector2(regiao.size) * fator))
