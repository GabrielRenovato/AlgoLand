extends SceneTree
## Importa diretamente o recurso exportado, sem autoloads ou saves.
var vp: SubViewport
var camera: Camera3D
var animador: AnimationPlayer
var modelo: Node3D
var saida: String
var visual: Node3D
var amostras := {}

func _initialize() -> void:
	rodar.call_deferred()

func capturar(nome: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	assert(vp.get_texture().get_image().save_png(saida.path_join(nome+".png")) == OK)

func buscar(t: float) -> void:
	animador.seek(t,true)
	visual.amostrar_efeitos(animador.assigned_animation,t)
	for sk: Skeleton3D in modelo.find_children("*","Skeleton3D",true,false):
		sk.force_update_all_bone_transforms()

func rodar() -> void:
	saida = OS.get_environment("ALGOLAND_LORDE_PREVIAS").path_join("animacoes")
	if OS.get_cmdline_user_args().has("--pixel"):
		saida=saida.path_join("pixel_art")
	DirAccess.make_dir_recursive_absolute(saida)
	var doc := GLTFDocument.new()
	var estado := GLTFState.new()
	estado.bake_fps = 60
	assert(doc.append_from_file(OS.get_environment("ALGOLAND_LORDE_MODELO"),estado)==OK)
	print("ANIMACOES_IMPORTADAS ",estado.json.get("animations",[]).map(func(a):return a.get("name")))
	vp=SubViewport.new()
	vp.size=Vector2i(720,720)
	vp.own_world_3d=true
	vp.msaa_3d=Viewport.MSAA_4X
	if OS.get_cmdline_user_args().has("--pixel"):
		vp.size=Vector2i(224,224)
		vp.msaa_3d=Viewport.MSAA_DISABLED
	vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	modelo=doc.generate_scene(estado)
	visual=Node3D.new()
	visual.set_script(load("res://modelo_lorde_goblin_3d.gd"))
	visual.add_child(modelo)
	vp.add_child(visual)
	visual.set_process(false)
	animador=modelo.find_children("*","AnimationPlayer",true,false)[0]
	animador.stop()
	for mesh: MeshInstance3D in modelo.find_children("*","MeshInstance3D",true,false):
		# AABB padrão só cobre repouso: ampliar para não descartar o martelo.
		mesh.extra_cull_margin=12
		for i in mesh.mesh.get_surface_count():
			var mat=mesh.mesh.surface_get_material(i)
			if mat is BaseMaterial3D:mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var world:=WorldEnvironment.new()
	world.environment=Environment.new()
	world.environment.background_mode=Environment.BG_COLOR
	world.environment.background_color=Color("c7c5bc")
	world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color=Color("c2cedb")
	world.environment.ambient_light_energy=.48
	vp.add_child(world)
	var floor_mesh:=MeshInstance3D.new()
	var plane:=PlaneMesh.new();plane.size=Vector2(40,40)
	floor_mesh.mesh=plane;floor_mesh.position.y=-.008
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color("aaa99f");mat.roughness=1
	floor_mesh.material_override=mat
	vp.add_child(floor_mesh)
	for data in [[Vector3(-4,8,6),Color("ffe5c8"),.85],[Vector3(6,5,2),Color("bdd5f5"),.35]]:
		var light:=DirectionalLight3D.new();vp.add_child(light)
		light.position=data[0];light.look_at(Vector3(0,1.5,0));light.light_color=data[1];light.light_energy=data[2];light.shadow_enabled=data[2]>.5
	camera=Camera3D.new();vp.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.current=true
	camera.size=9.8;camera.position=Vector3(0,7,12);camera.look_at(Vector3(0,2,0))
	var keys := {}
	for nome in animador.get_animation_list():
		if not visual.DADOS_ATAQUES.data.has(String(nome)):continue
		var info: Dictionary = visual.DADOS_ATAQUES.data[String(nome)]
		var dur := float(info["duracao_s"])
		var tempos: Array = [0.0,float(info["pegada_dupla"][0])]
		for evento in info["eventos"]:tempos.append(float(evento["tempo_s"]))
		for frac in [.25,.5,.75]:tempos.append(dur*frac)
		tempos.append(float(info["pegada_dupla"][1]));tempos.append(dur)
		tempos.sort();keys[String(nome)]=tempos

	for nome in keys:
		animador.play(nome);animador.pause()
		var duration:=animador.get_animation(nome).length
		amostras[nome]={"duracao_s":duration,"fps_previa":20,"quadros":[]}
		for i in range(keys[nome].size()):
			buscar(keys[nome][i]);await capturar(nome+"_pose_%02d"%i)
		if OS.get_cmdline_user_args().has("--poses"):continue
		for i in range(int(ceil(duration*20))+1):
			var t:=minf(i/20.0,duration);buscar(t)
			var nome_frame: String=nome+"_%03d"%i
			await capturar(nome_frame)
			amostras[nome]["quadros"].append({"arquivo":nome_frame+".png","tempo_s":t})
	# Vista lateral do contato com o chão e da empunhadura em cada ação.
	camera.size=9.8;camera.position=Vector3(12,5,0);camera.look_at(Vector3(0,2,0))
	for nome in keys:
		animador.play(nome);animador.pause()
		for i in range(keys[nome].size()):
			buscar(keys[nome][i]);await capturar(nome+"_lateral_%02d"%i)
	var sk: Skeleton3D=modelo.find_children("*","Skeleton3D",true,false)[0]
	for nome in keys:
		animador.play(nome);animador.pause();buscar(float(visual.DADOS_ATAQUES.data[nome]["eventos"][-1 if nome=="impacto_area" else 0]["tempo_s"]))
		await process_frame
		var mao:=sk.global_transform*sk.get_bone_global_pose(sk.find_bone("mao_D")).origin
		var outra_mao:=sk.global_transform*sk.get_bone_global_pose(sk.find_bone("mao_E")).origin
		var centro_maos: Vector3=(mao+outra_mao)*.5
		camera.size=1.5;camera.position=centro_maos+Vector3(-.7,-.20,2.8);camera.look_at(centro_maos)
		await capturar(nome+"_pegada")
	# Mesma câmera e mesmo enquadramento; apenas a resolução nativa muda.
	vp.size=Vector2i(224,224)
	vp.msaa_3d=Viewport.MSAA_DISABLED
	camera.size=9.8;camera.position=Vector3(0,7,12);camera.look_at(Vector3(0,2,0))
	for nome in keys:
		animador.play(nome);animador.pause()
		buscar(float(visual.DADOS_ATAQUES.data[nome]["eventos"][-1 if nome=="impacto_area" else 0]["tempo_s"])+.12)
		await capturar(nome+"_escala_jogo")
	var f:=FileAccess.open(saida.path_join("revisao_poses.json" if OS.get_cmdline_user_args().has("--poses") else "revisao_animacoes.json"),FileAccess.WRITE);f.store_string(JSON.stringify(amostras,"\t"));f.close()
	print("LORDE_ANIMACOES_CAPTURADAS")
	quit()
