extends SceneTree
## Reprodução no mapa com o jogador real e save exclusivo para revisão.
var pasta_saida := "/tmp/algoland-machado-2d-reproducao/"
var direcao := "direita"
var capturas: Array[Image] = []
var instantes: Array[float] = []

func _initialize() -> void:
	for argumento in OS.get_cmdline_user_args():
		if argumento.begins_with("--direcao="):
			direcao = argumento.trim_prefix("--direcao=")
	if direcao not in ["direita","baixo","cima","esquerda"]:
		quit(1)
		return
	if direcao != "direita": pasta_saida = "/tmp/algoland-machado-2d-reproducao-"+direcao+"/"
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
	var corrida = load("res://cenas/inimigos/goblin_machado_2d_visual.tscn").instantiate()
	var combo = load("res://cenas/inimigos/goblin_machado_2d_visual.tscn").instantiate()
	cena.add_child(corrida)
	cena.add_child(combo)
	corrida.position = Vector2(-8,92)
	combo.position = Vector2(64,92)
	corrida.z_index = preload("res://codigo/globais/profundidade.gd").z_de(92)
	combo.z_index = corrida.z_index
	var tem_corrida: bool = corrida.sprite_frames.has_animation("correr_"+direcao)
	corrida.tocar("correr" if tem_corrida else "parado",direcao)
	# Direções com somente corrida usam outra corrida como comparação visual.
	var somente_corrida: bool = not combo.sprite_frames.has_animation("ataque_"+direcao)
	var direcao_referencia := "direita" if direcao == "esquerda" else "baixo"
	if somente_corrida:
		combo.tocar("correr",direcao_referencia)
	else:
		combo.tocar("ataque",direcao)
	var registro: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/inimigos/goblin_machado_2d/registro_animacoes.json"))
	var duracao_combo := 0.0
	var acao_referencia := "ataque_"+direcao_referencia if somente_corrida else "ataque_"+direcao
	for duracao in registro.animacoes[acao_referencia].duracoes_ms:
		duracao_combo += float(duracao) / 1000.0
	var segundo_combo := duracao_combo + 0.4
	var inicio := Time.get_ticks_msec()
	var repetiu := false
	var captura_mapa: Image
	while (Time.get_ticks_msec() - inicio)/1000.0 < segundo_combo + duracao_combo + 0.15:
		var tempo := (Time.get_ticks_msec() - inicio)/1000.0
		if tempo >= segundo_combo and not repetiu and not somente_corrida:
			combo.tocar("ataque",direcao)
			repetiu = true
		await RenderingServer.frame_post_draw
		var imagem := root.get_texture().get_image()
		if capturas.is_empty(): captura_mapa = imagem
		capturas.append(_recortar(imagem,Rect2i(400,300,390,115)))
		instantes.append(tempo)
		await create_timer(0.02).timeout
	captura_mapa.save_png(pasta_saida + "no-mapa.png")
	for i in capturas.size(): capturas[i].save_png(pasta_saida + "reproducao-%03d.png" % i)
	FileAccess.open(pasta_saida + "instantes.json",FileAccess.WRITE).store_string(JSON.stringify(instantes))
	if not tem_corrida:
		print("GOBLIN_MACHADO_2D_REPRODUCAO: ",direcao,"; guarda e dois ataques no mapa, ao lado do player")
		quit()
		return
	capturas.clear()
	instantes.clear()
	cena.jogador.hide()
	combo.hide()
	var origem := Vector2(-40,92) if direcao == "direita" else Vector2(-8,52)
	var sentido := Vector2.RIGHT if direcao == "direita" else Vector2.DOWN
	if direcao == "cima":
		origem = Vector2(-8,132)
		sentido = Vector2.UP
	if direcao == "esquerda":
		origem = Vector2(40,92)
		sentido = Vector2.LEFT
	var recorte := Rect2i(440,300,300,115) if direcao in ["direita","esquerda"] else Rect2i(470,230,240,270)
	corrida.position = origem
	corrida.tocar("correr",direcao)
	corrida.frame = 0
	inicio = Time.get_ticks_msec()
	while Time.get_ticks_msec() - inicio < 960:
		var tempo := (Time.get_ticks_msec() - inicio)/1000.0
		corrida.position = origem + sentido * 100 * tempo
		corrida.z_index = preload("res://codigo/globais/profundidade.gd").z_de(corrida.position.y)
		await RenderingServer.frame_post_draw
		capturas.append(_recortar(root.get_texture().get_image(),recorte))
		instantes.append(tempo)
		await create_timer(0.02).timeout
	for i in capturas.size(): capturas[i].save_png(pasta_saida + "deslocamento-%03d.png" % i)
	FileAccess.open(pasta_saida + "instantes_deslocamento.json",FileAccess.WRITE).store_string(JSON.stringify(instantes))
	print("GOBLIN_MACHADO_2D_REPRODUCAO: ",direcao,"; mapa carregado, corrida de referencia, mais de quatro ciclos de corrida e dois com deslocamento a 100 px/s")
	quit()

func _recortar(imagem: Image, regiao: Rect2i) -> Image:
	var fator := Vector2(imagem.get_size()) / Vector2(1152,648)
	return imagem.get_region(Rect2i(Vector2(regiao.position) * fator, Vector2(regiao.size) * fator))
