extends SceneTree
## Renderização isolada do GLB exportado. Não carrega autoloads ou saves.
var vp: SubViewport
const ESCALA_CHEFE := 1.5

func _initialize() -> void:
	rodar.call_deferred()

func capturar(destino: String) -> void:
	for i in 5: await process_frame
	await RenderingServer.frame_post_draw
	assert(vp.get_texture().get_image().save_png(destino) == OK)

func rodar() -> void:
	var origem := OS.get_environment("ALGOLAND_LORDE_MODELO")
	var saida := OS.get_environment("ALGOLAND_LORDE_PREVIAS")
	DirAccess.make_dir_recursive_absolute(saida)
	var doc := GLTFDocument.new()
	var estado := GLTFState.new()
	assert(doc.append_from_file(origem, estado) == OK)
	assert(estado.json.get("skins", []).size() == 1)
	assert(estado.json.get("animations", []).size() == 5)
	vp = SubViewport.new()
	vp.size = Vector2i(768,768)
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var modelo := doc.generate_scene(estado)
	vp.add_child(modelo)
	var aabb := AABB()
	var primeiro := true
	var triangulos := 0
	for instancia in modelo.find_children("*", "MeshInstance3D", true, false):
		var caixa: AABB = instancia.global_transform * instancia.get_aabb()
		aabb = caixa if primeiro else aabb.merge(caixa)
		primeiro = false
		for indice in instancia.mesh.get_surface_count():
			var material = instancia.mesh.surface_get_material(indice)
			if material is BaseMaterial3D:
				material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			var arrays: Array = instancia.mesh.surface_get_arrays(indice)
			triangulos += arrays[Mesh.ARRAY_INDEX].size() / 3
	var ambiente := WorldEnvironment.new()
	ambiente.environment = Environment.new()
	ambiente.environment.background_mode = Environment.BG_COLOR
	ambiente.environment.background_color = Color("c7c5bc")
	ambiente.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambiente.environment.ambient_light_color = Color("c2cedb")
	ambiente.environment.ambient_light_energy = .48
	vp.add_child(ambiente)
	var piso := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(200,200)
	piso.mesh = plano
	piso.position.y = -.005
	var tinta := StandardMaterial3D.new()
	tinta.albedo_color = Color("aaa99f")
	tinta.roughness = 1
	piso.material_override = tinta
	vp.add_child(piso)
	for dados in [[Vector3(-3,5,4),Color("ffe5c8"),.85],[Vector3(4,3,1),Color("bdd5f5"),.35]]:
		var luz := DirectionalLight3D.new()
		vp.add_child(luz)
		luz.position = dados[0]*ESCALA_CHEFE
		luz.look_at(Vector3(0,1,0)*ESCALA_CHEFE)
		luz.light_color = dados[1]
		luz.light_energy = dados[2]
		luz.shadow_enabled = dados[2] > .5
	var camera := Camera3D.new()
	vp.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.35*ESCALA_CHEFE
	camera.position = Vector3(0,3.1,6)*ESCALA_CHEFE
	camera.look_at(Vector3(0,1.15,0)*ESCALA_CHEFE)
	camera.current = true
	piso.visible = false
	ambiente.environment.background_color = Color("e6e3d9")
	for detalhe in [
		["mao_direita_frente",Vector3(-.98,1.13,5),Vector3(-.98,1.13,.22),.60],
		["mao_direita_obliqua",Vector3(-2.4,1.55,3),Vector3(-.98,1.12,.22),.65],
		["mao_direita_lateral",Vector3(-3,1.2,.22),Vector3(-.98,1.12,.22),.65],
		["mao_esquerda_frente",Vector3(.84,.76,5),Vector3(.84,.72,.15),.55],
		["mao_esquerda_obliqua",Vector3(3,.9,2),Vector3(.84,.72,.15),.60],
		["pes",Vector3(0,.5,4),Vector3(0,.10,.25),1.15]]:
		camera.position = detalhe[1]*ESCALA_CHEFE
		camera.look_at(detalhe[2]*ESCALA_CHEFE)
		camera.size = detalhe[3]*ESCALA_CHEFE
		await capturar(saida.path_join(detalhe[0]+".png"))
	if OS.get_cmdline_user_args().has("--maos"):
		print("LORDE_GOBLIN_MAOS_CAPTURADAS")
		quit()
		return
	piso.visible = true
	ambiente.environment.background_color = Color("c7c5bc")
	camera.size = 3.35*ESCALA_CHEFE
	camera.position = Vector3(0,3.1,6)*ESCALA_CHEFE
	camera.look_at(Vector3(0,1.15,0)*ESCALA_CHEFE)
	var vistas := ["frente","tres_quartos_direita","perfil_direito","costas_direita",
		"costas","costas_esquerda","perfil_esquerdo","tres_quartos_esquerda"]
	for i in vistas.size():
		modelo.rotation.y = i*TAU/8
		await capturar(saida.path_join(vistas[i]+".png"))
	modelo.rotation.y = 0
	camera.size = 1.05*ESCALA_CHEFE
	camera.position = Vector3(0,2.18,5)*ESCALA_CHEFE
	camera.look_at(Vector3(0,1.74,.15)*ESCALA_CHEFE)
	await capturar(saida.path_join("rosto.png"))
	camera.size = .85*ESCALA_CHEFE
	camera.position = Vector3(-.98,1.8,5)*ESCALA_CHEFE
	camera.look_at(Vector3(-.98,1.13,.21)*ESCALA_CHEFE)
	await capturar(saida.path_join("empunhadura.png"))
	# Referência existente de 1,35 m no mesmo chão e na mesma câmera.
	var doc_comum := GLTFDocument.new()
	var estado_comum := GLTFState.new()
	var caminho_comum := origem.get_base_dir().get_base_dir().path_join("goblin_comum_3d/goblin_comum.glb")
	assert(doc_comum.append_from_file(caminho_comum,estado_comum) == OK)
	var comum := doc_comum.generate_scene(estado_comum)
	comum.position.x = 2.2
	vp.add_child(comum)
	camera.size = 5.7
	camera.position = Vector3(.35,4.5,8)
	camera.look_at(Vector3(.35,1.65,0))
	await capturar(saida.path_join("comparacao_porte.png"))
	comum.queue_free()
	camera.size = 3.35*ESCALA_CHEFE
	camera.position = Vector3(0,3.1,6)*ESCALA_CHEFE
	camera.look_at(Vector3(0,1.15,0)*ESCALA_CHEFE)
	# Mesma câmera frontal elevada do mundo: a pixelização ocorre após o 3D.
	vp.size = Vector2i(224,224)
	vp.msaa_3d = Viewport.MSAA_DISABLED
	await capturar(saida.path_join("escala_jogo.png"))
	# Composição visual sobre uma captura do mapa real, sem iniciar uma partida.
	piso.visible = false
	vp.transparent_bg = true
	ambiente.environment.background_mode = Environment.BG_CLEAR_COLOR
	ambiente.environment.ambient_light_energy = .30
	for luz in vp.find_children("*", "DirectionalLight3D", false, false):
		luz.light_energy *= .60
	var mapa := Image.load_from_file(OS.get_environment("ALGOLAND_LORDE_CAVERNA"))
	var composicao := SubViewport.new()
	composicao.size = mapa.get_size()
	composicao.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(composicao)
	var fundo := Sprite2D.new()
	fundo.centered = false
	fundo.texture = ImageTexture.create_from_image(mapa)
	composicao.add_child(fundo)
	var sombra := Polygon2D.new()
	var pontos := PackedVector2Array()
	for i in 32:
		pontos.append(Vector2(cos(i*TAU/32)*43,sin(i*TAU/32)*13))
	sombra.polygon = pontos
	sombra.color = Color(0,0,0,.26)
	sombra.position = Vector2(570,415)
	composicao.add_child(sombra)
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture = vp.get_texture()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ONE*.75*ESCALA_CHEFE
	sprite.position = sombra.position-camera.unproject_position(Vector3.ZERO)*.75*ESCALA_CHEFE
	sombra.scale = Vector2.ONE*ESCALA_CHEFE
	composicao.add_child(sprite)
	for i in 6: await process_frame
	await RenderingServer.frame_post_draw
	assert(composicao.get_texture().get_image().save_png(saida.path_join("na_caverna.png")) == OK)
	composicao.queue_free()
	piso.visible = true
	vp.transparent_bg = false
	ambiente.environment.background_mode = Environment.BG_COLOR
	ambiente.environment.ambient_light_energy = .48
	for luz in vp.find_children("*", "DirectionalLight3D", false, false):
		luz.light_energy /= .60
	var animadores := modelo.find_children("*", "AnimationPlayer", true, false)
	assert(animadores.size() == 1)
	var animador := animadores[0] as AnimationPlayer
	var nome: StringName = "parado"
	animador.get_animation(nome).loop_mode = Animation.LOOP_LINEAR
	animador.play(nome)
	var inicio := Time.get_ticks_msec()
	var amostra := 0
	while Time.get_ticks_msec()-inicio < 6500:
		await process_frame
		if Time.get_ticks_msec()-inicio >= amostra*400:
			await RenderingServer.frame_post_draw
			vp.get_texture().get_image().save_png(saida.path_join("parado_%02d.png" % amostra))
			amostra += 1
	var relatorio := {"motor":Engine.get_version_info().string,"importacao":true,
		"triangulos":triangulos,"limites_min":[aabb.position.x,aabb.position.y,aabb.position.z],
		"limites_max":[aabb.end.x,aabb.end.y,aabb.end.z],"vistas":8,
		"animacao":String(nome),"reproducao_segundos":6.5,"quadros_capturados":amostra,
		"saves":"projeto mínimo sem autoloads"}
	var arquivo := FileAccess.open(saida.path_join("revisao_godot.json"),FileAccess.WRITE)
	arquivo.store_string(JSON.stringify(relatorio,"\t"))
	print("LORDE_GOBLIN_REVISAO_OK ",JSON.stringify(relatorio))
	quit()
