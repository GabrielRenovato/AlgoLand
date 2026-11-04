extends SceneTree
## Captura perseguição, golpes e morte do goblin real com save exclusivo.
var pasta_saida := "/tmp/algoland-adaga-integracao/"
var capturas: Array[Image] = []
var instantes: Array[float] = []
var estados: Array[Dictionary] = []
var inicio := 0
var goblin: Node2D
var somente_dano := false
var somente_morte := false
func _initialize() -> void: rodar.call_deferred()
func rodar() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes goblin adaga"):
		quit(1)
		return
	somente_dano = "--dano" in OS.get_cmdline_user_args()
	somente_morte = "--morte" in OS.get_cmdline_user_args()
	if somente_morte: pasta_saida = "/tmp/algoland-adaga-morte/"
	if somente_dano: pasta_saida = "/tmp/algoland-adaga-dano/"
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
		mob.queue_free()
	for camera_antiga in cena.find_children("*","Camera2D",true,false):
		camera_antiga.enabled = false
	var camera := Camera2D.new()
	cena.add_child(camera)
	camera.global_position = Vector2(0,60)
	camera.make_current()
	cena.hud.hide()
	cena.interface.hide()
	await process_frame
	goblin = load("res://cenas/inimigos/goblin_pomar.tscn").instantiate()
	goblin.position = cena._livre(Vector2(-8,80))
	cena.add_child(goblin)
	goblin._recarga = 100.0
	cena.jogador.invulneravel = true
	# O alvo segue o jogador real; nenhuma animação é forçada pelo capturador.
	goblin._jogador_cache = cena.jogador
	goblin._proxima_escolha_alvo = Time.get_ticks_msec()+30000
	await physics_frame
	var trecho := _escolher_trecho(cena)
	inicio = Time.get_ticks_msec()
	if somente_morte:
		await _capturar_mortes(cena,trecho)
		quit()
		return
	if somente_dano:
		goblin.ia_habilitada = false
		for rumo in [Vector2.RIGHT,Vector2.DOWN,Vector2.UP,Vector2.LEFT]:
			goblin.global_position = trecho
			goblin.definir_direcao_animacao(rumo)
			cena.jogador.global_position = trecho+Vector2(55,0)
			cena.jogador.z_index = preload("res://codigo/globais/profundidade.gd").z_de(cena.jogador.global_position.y+11.0)
			goblin._tocar("parado",true)
			await _capturar(.2)
			for repeticao in 2:
				goblin.receber_dano(1,-rumo*10.0)
				await _capturar(.65)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(pasta_saida+"no-mapa.png")
	else:
		for rumo in [Vector2.RIGHT,Vector2.DOWN,Vector2.UP,Vector2.LEFT]:
			goblin.global_position = trecho
			goblin.velocity = Vector2.ZERO
			goblin._tempo_rota = 0.0
			cena.jogador.global_position = trecho+rumo*100.0
			cena.jogador.z_index = preload("res://codigo/globais/profundidade.gd").z_de(cena.jogador.global_position.y+11.0)
			await _capturar(1.0)
		for rumo in [Vector2.RIGHT,Vector2.DOWN,Vector2.UP,Vector2.LEFT]:
			goblin._cancelar_golpe()
			goblin.global_position = trecho
			goblin.velocity = Vector2.ZERO
			goblin.esta_recuando = false
			cena.jogador.global_position = trecho+rumo*20.0
			cena.jogador.z_index = preload("res://codigo/globais/profundidade.gd").z_de(cena.jogador.global_position.y+11.0)
			goblin.chance_combo = 1.0
			goblin._recarga = 0.0
			await _capturar(.1)
			if rumo == Vector2.RIGHT:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(pasta_saida+"no-mapa.png")
			await _capturar(1.6)
		goblin.receber_dano(goblin.vida,Vector2.ZERO)
		await _capturar(1.15)
	for i in capturas.size(): capturas[i].save_png(pasta_saida+"integracao-%03d.png"%i)
	FileAccess.open(pasta_saida+"instantes.json",FileAccess.WRITE).store_string(JSON.stringify(instantes))
	FileAccess.open(pasta_saida+"estados.json",FileAccess.WRITE).store_string(JSON.stringify(estados))
	print("GOBLIN_ADAGA_INTEGRACAO: perseguição real, quatro posições de alvo, combo, morte, save isolado; capturas=",capturas.size())
	quit()

func _capturar(segundos: float) -> void:
	var ate := Time.get_ticks_msec()+int(segundos*1000.0)
	while Time.get_ticks_msec()<ate:
		if is_instance_valid(goblin):
			var camera := root.get_camera_2d()
			if camera != null: camera.global_position = goblin.global_position+Vector2(20,0)
		await RenderingServer.frame_post_draw
		var imagem := root.get_texture().get_image()
		var fator := Vector2(imagem.get_size())/Vector2(1152,648)
		capturas.append(imagem.get_region(Rect2i(Vector2(380,235)*fator,Vector2(430,210)*fator)))
		instantes.append(float(Time.get_ticks_msec()-inicio)/1000.0)
		if is_instance_valid(goblin):
			var textura := goblin.sprite.texture as AtlasTexture
			var quadro := -1 if textura == null else int(textura.region.position.x/640)+4*int(textura.region.position.y/640)
			estados.append({"tempo":instantes[-1],"acao":goblin.animacao,"clip":goblin._clip,"quadro":quadro,"x":goblin.position.x,"y":goblin.position.y,"impactos":goblin._impactos_resolvidos.size()})
		await create_timer(.02).timeout

func _escolher_trecho(cena: Node2D) -> Vector2:
	var pontos: Array[Vector2] = []
	for y in range(-384,385,64):
		for x in range(-576,577,64): pontos.append(Vector2(x,y))
	pontos.sort_custom(func(a,b): return a.distance_squared_to(Vector2(0,80))<b.distance_squared_to(Vector2(0,80)))
	var consulta := PhysicsShapeQueryParameters2D.new()
	var circulo := CircleShape2D.new()
	circulo.radius = 8.0
	consulta.shape = circulo
	consulta.collision_mask = 64
	var mapa: RID = goblin._agente.get_navigation_map()
	for centro in pontos:
		var livre := true
		for rumo in [Vector2.RIGHT,Vector2.DOWN,Vector2.UP,Vector2.LEFT]:
			for distancia in range(0,101,10):
				var ponto: Vector2 = centro+rumo*distancia
				consulta.transform = Transform2D(0,ponto)
				if not cena.get_world_2d().direct_space_state.intersect_shape(consulta,1).is_empty() or NavigationServer2D.map_get_closest_point(mapa,ponto).distance_to(ponto)>3.0:
					livre = false
					break
			if not livre: break
		if livre:
			print("GOBLIN_ADAGA_TRECHO_LIVRE: ",centro)
			return centro
	return cena._livre(Vector2(0,80))

func _capturar_mortes(cena: Node2D, trecho: Vector2) -> void:
	var atores: Array[Node2D] = []
	var rumos := [Vector2.RIGHT,Vector2.LEFT,Vector2.DOWN,Vector2.UP]
	var camera := root.get_camera_2d()
	camera.global_position = trecho+Vector2(15,-20)
	cena.jogador.global_position = trecho+Vector2(-120,0)
	for i in rumos.size():
		var ator = goblin if i==0 else load("res://cenas/inimigos/goblin_pomar.tscn").instantiate()
		if i>0: cena.add_child(ator)
		ator.ia_habilitada = false
		ator.set_physics_process(false)
		ator.global_position = trecho+Vector2(-65+i*50,0)
		ator.definir_direcao_animacao(rumos[i])
		ator._tocar("parado",true)
		atores.append(ator)
	var morreu := false
	inicio = Time.get_ticks_msec()
	var estados_morte: Array[Dictionary] = []
	while (Time.get_ticks_msec()-inicio)/1000.0<3.1:
		var tempo := (Time.get_ticks_msec()-inicio)/1000.0
		if tempo>=.25 and not morreu:
			for ator in atores:
				ator.receber_dano(ator.vida,Vector2.ZERO)
				ator.set_physics_process(true)
			morreu = true
		await RenderingServer.frame_post_draw
		var imagem := root.get_texture().get_image()
		var fator := Vector2(imagem.get_size())/Vector2(1152,648)
		capturas.append(imagem.get_region(Rect2i(Vector2(240,265)*fator,Vector2(800,170)*fator)))
		instantes.append(tempo)
		var ficha := {"tempo":tempo,"atores":[]}
		for ator in atores:
			if not is_instance_valid(ator):
				ficha.atores.append({"clip":"removido","quadro":-1})
				continue
			var textura := ator.sprite.texture as AtlasTexture
			ficha.atores.append({"clip":ator._clip,"quadro":int(textura.region.position.x/640)+4*int(textura.region.position.y/640),"alfa":ator.sprite.modulate.a,"rotacao":ator.sprite.rotation})
		estados_morte.append(ficha)
		await create_timer(.02).timeout
	for i in capturas.size(): capturas[i].save_png(pasta_saida+"morte-%03d.png"%i)
	FileAccess.open(pasta_saida+"instantes.json",FileAccess.WRITE).store_string(JSON.stringify(instantes))
	FileAccess.open(pasta_saida+"estados.json",FileAccess.WRITE).store_string(JSON.stringify(estados_morte))
	print("GOBLIN_ADAGA_MORTE: dano fatal real em quatro rumos, queda, repouso e limpeza, save isolado")
