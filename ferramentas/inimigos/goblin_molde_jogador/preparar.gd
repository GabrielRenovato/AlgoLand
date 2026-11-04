extends SceneTree
## Derivação do CorpoBase e do rig do jogador. Nenhuma malha do molde é substituída.
const FONTE := "res://cenas/personagem/base_3d/personagem.scn"
const DESTINO := "res://assets/inimigos/goblin_molde_jogador/goblin.scn"
const PREVIAS := "res://arte/previas/inimigos/goblin_molde_jogador/"
const PALETA := {"pele_sombra":"485234", "pele_meio":"6d8143", "pele_base":"90a951", "pele_luz":"b9cc75", "short_sombra":"30291f", "short_base":"584632", "short_luz":"79603f", "cor_rosto":"30331d", "branco_olho":"eee0ae", "cor_olhos":"d99d28"}
var vp: SubViewport
var camera: Camera3D

func _initialize() -> void:
	rodar.call_deferred()

func material(cor: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(cor)
	m.roughness = .88
	return m

func elipsoide(pai: Node3D, nome: String, pos: Vector3, tamanho: Vector3, cor: String) -> void:
	var n := MeshInstance3D.new()
	n.name = nome
	var forma := SphereMesh.new()
	forma.radius = .5
	forma.height = 1
	forma.radial_segments = 20
	forma.rings = 12
	n.mesh = forma
	n.material_override = material(cor)
	n.position = pos
	n.scale = tamanho
	pai.add_child(n)

func orelha(pai: Node3D, lado: float) -> void:
	# Espaço do osso da cabeça, com a mesma ampliação usada pelo jogador.
	var v := PackedVector3Array([
		Vector3(.071*lado,.100,.004), Vector3(.106*lado,.151,.000),
		Vector3(.235*lado,.205,-.021), Vector3(.173*lado,.086,.008),
		Vector3(.103*lado,.061,.017), Vector3(.130*lado,.116,.039),
		Vector3(.132*lado,.116,-.027)])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 5:
		for indice in [5,k,(k+1)%5,6,(k+1)%5,k]: st.add_vertex(v[indice])
	st.generate_normals()
	var n := MeshInstance3D.new()
	n.name = "OrelhaPontudaDireita" if lado < 0 else "OrelhaPontudaEsquerda"
	n.mesh = st.commit()
	var m := material("90a951")
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	n.material_override = m
	pai.add_child(n)
	var interno := SurfaceTool.new()
	interno.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p in [Vector3(.105*lado,.108,.030),Vector3(.204*lado,.183,-.006),Vector3(.151*lado,.099,.034)]: interno.add_vertex(p)
	interno.generate_normals()
	var concha := MeshInstance3D.new()
	concha.mesh = interno.commit()
	concha.name = "InteriorOrelha"
	var mi := material("7b624b")
	mi.cull_mode = BaseMaterial3D.CULL_DISABLED
	concha.material_override = mi
	pai.add_child(concha)

func donos(no: Node, dono: Node) -> void:
	for filho in no.get_children():
		filho.owner = dono
		donos(filho, dono)

func montar() -> Node3D:
	var goblin := Node3D.new()
	goblin.name = "GoblinMoldeJogador"
	goblin.scale = Vector3.ONE * .82
	var modelo: Node3D = load(FONTE).instantiate()
	modelo.scene_file_path = "" # Gravar uma derivação única, sem duplicar os nós da instância fonte.
	goblin.add_child(modelo)
	var corpo: MeshInstance3D = modelo.find_child("CorpoBase",true,false)
	corpo.material_override = corpo.material_override.duplicate()
	for chave in PALETA: corpo.material_override.set_shader_parameter(chave,Color(PALETA[chave]))
	var cores := {"Camisa":"69513a", "Calca":"47483e", "Botas":"503e2d", "Cabelo":"35362c"}
	for nome in cores:
		var peca: MeshInstance3D = modelo.find_child(nome,true,false)
		peca.material_override = peca.material_override.duplicate()
		peca.material_override.set_shader_parameter("cor",Color(cores[nome]))
		if nome == "Cabelo":
			peca.material_override.set_shader_parameter("usar_textura_cabelo",false)
	for nome in ["EncaixeCostas","EncaixeMao"]:
		var acessorio := modelo.find_child(nome,true,false)
		if acessorio != null: acessorio.free()
	var s: Skeleton3D = modelo.find_children("*","Skeleton3D",true,false)[0]
	for malha in modelo.find_children("*","MeshInstance3D",true,false):
		if malha.skin != null: malha.skeleton = malha.get_path_to(s)
	var cabeca := BoneAttachment3D.new()
	cabeca.name = "TracosGoblin"
	cabeca.bone_name = "DEF-head"
	s.add_child(cabeca)
	orelha(cabeca,-1)
	orelha(cabeca,1)
	elipsoide(cabeca,"NarizGoblin",Vector3(0,.105,.113),Vector3(.076,.060,.088),"90a951")
	for lado in [-1,1]:
		var presa := MeshInstance3D.new()
		presa.name = "Presa"
		var forma := CylinderMesh.new()
		forma.top_radius = .001
		forma.bottom_radius = .009
		forma.height = .044
		forma.radial_segments = 12
		presa.mesh = forma
		presa.material_override = material("e5d5a2")
		presa.position = Vector3(lado*.039,.065,.112)
		cabeca.add_child(presa)
	# Volumes de rosto largos o bastante para permanecer legíveis na grade de 160 px.
	elipsoide(cabeca,"Mandibula",Vector3(0,.048,.080),Vector3(.110,.047,.067),"6d8143")
	elipsoide(cabeca,"Boca",Vector3(0,.069,.119),Vector3(.086,.010,.009),"30331d")
	for lado in [-1,1]:
		elipsoide(cabeca,"Narina",Vector3(lado*.022,.093,.153),Vector3(.014,.010,.008),"485234")
		elipsoide(cabeca,"MacaRosto",Vector3(lado*.063,.101,.077),Vector3(.044,.029,.034),"90a951")
		elipsoide(cabeca,"Sobrancelha",Vector3(lado*.043,.162,.085),Vector3(.068,.022,.028),"485234")
		var sobrancelha := cabeca.get_child(cabeca.get_child_count()-1) as Node3D
		sobrancelha.rotation.z = lado*.24
	var argola := MeshInstance3D.new()
	argola.name = "ArgolaOrelha"
	var aro := TorusMesh.new()
	aro.inner_radius = .013
	aro.outer_radius = .021
	aro.rings = 16
	aro.ring_segments = 8
	argola.mesh = aro
	argola.material_override = material("bd9145")
	argola.position = Vector3(-.164,.096,.020)
	argola.rotation.x = PI/2
	cabeca.add_child(argola)
	var animador: AnimationPlayer = modelo.find_children("*","AnimationPlayer",true,false)[0]
	animador.autoplay = "Idle_Loop"
	return goblin

func luz(pos: Vector3, energia: float, cor: String) -> void:
	var n := DirectionalLight3D.new()
	vp.add_child(n)
	n.position = pos
	n.look_at(Vector3(0,.7,0))
	n.light_energy = energia
	n.light_color = Color(cor)

func foto(nome: String) -> void:
	for i in 5:
		await physics_frame
		await process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(PREVIAS+nome+".png")

func rodar() -> void:
	var goblin := montar()
	root.add_child(goblin)
	donos(goblin,goblin)
	var cena := PackedScene.new()
	cena.pack(goblin)
	ResourceSaver.save(cena,DESTINO,ResourceSaver.FLAG_COMPRESS)
	goblin.queue_free()
	await process_frame
	if DisplayServer.get_name() == "headless":
		quit()
		return
	vp = SubViewport.new()
	vp.size = Vector2i(1200,900)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_4X
	root.add_child(vp)
	var ambiente := WorldEnvironment.new()
	ambiente.environment = Environment.new()
	ambiente.environment.background_mode = Environment.BG_COLOR
	ambiente.environment.background_color = Color("35423c")
	ambiente.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambiente.environment.ambient_light_color = Color("c5d1df")
	ambiente.environment.ambient_light_energy = .4
	vp.add_child(ambiente)
	luz(Vector3(-3,5,4),.8,"ffe4bb")
	luz(Vector3(4,3,2),.35,"b8d3ff")
	camera = Camera3D.new()
	vp.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.5
	camera.position = Vector3(0,2.3,5)
	camera.look_at(Vector3(0,.72,0))
	var jogador: Node3D = load(FONTE).instantiate()
	vp.add_child(jogador)
	jogador.position.x = -.55
	var espada := jogador.find_child("EncaixeCostas",true,false)
	if espada != null: espada.visible = false
	goblin = load(DESTINO).instantiate()
	vp.add_child(goblin)
	goblin.position.x = .55
	for modelo in [jogador,goblin]:
		var s: Skeleton3D = modelo.find_children("*","Skeleton3D",true,false)[0]
		for malha in modelo.find_children("*","MeshInstance3D",true,false):
			if malha.skin != null: malha.skeleton = malha.get_path_to(s)
		var a: AnimationPlayer = modelo.find_children("*","AnimationPlayer",true,false)[0]
		a.play("Idle_Loop")
		a.advance(.1)
	await foto("comparacao_jogador")
	jogador.queue_free()
	goblin.position.x = 0
	camera.size = 1.9
	vp.size = Vector2i(900,1000)
	for d in 4:
		goblin.rotation.y = d * PI/2
		await foto("direcao_%d"%d)
	goblin.rotation.y = PI*.18
	await foto("tres_quartos")
	var animador: AnimationPlayer = goblin.find_children("*","AnimationPlayer",true,false)[0]
	animador.play("Walk_Loop")
	animador.pause()
	var tempo := animador.get_animation("Walk_Loop").length
	for quadro in 12:
		animador.seek(tempo*quadro/12.0,true)
		await foto("andar_%02d"%quadro)
	FileAccess.open(PREVIAS+"tempos.json",FileAccess.WRITE).store_string(JSON.stringify({"andar":tempo,"quadros":12}))
	print("GOBLIN_MOLDE_SALVO ",DESTINO)
	vp.queue_free()
	await process_frame
	await process_frame
	quit()
