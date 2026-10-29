extends Node
## Duas maquetes 3D compartilhadas por mapa; colisões e extração usam os sprites originais.
const PINTURA := preload("res://codigo/cenario/arvore_pintada_3d.gdshader")
const ACABAMENTO := preload("res://codigo/jogador/contorno_pixel_base_3d.gdshader")
var terreno: Node2D
var registros: Array[Dictionary] = []
var maquetes: Array[Dictionary] = []
var estacao := -1
var ativas: Dictionary = {}
var toco_3d: Dictionary = {}
var _materiais: Dictionary = {}

func configurar(mapa: Node2D) -> void:
	name="ArvoresFazenda3D"
	terreno=mapa
	mapa.add_child(self)
	for sprite in mapa.get_node("Objetos3D").get_children():
		if not sprite is Sprite2D or not sprite.texture is AtlasTexture:continue
		var especie: String=sprite.texture.resource_name
		if especie not in ["arvore","arvore_var"]:continue
		registros.append({"sprite":sprite,"tipo":0 if especie=="arvore" else 1,"escala":sprite.scale})
	for tipo in 2:maquetes.append(_maquete(tipo))
	toco_3d=_modelar_toco()
	aplicar(maxi(mapa.get_node("Estacoes").estacao_atual,0))

func _material(cor: String,casca := false) -> ShaderMaterial:
	var chave := cor+str(casca)
	if _materiais.has(chave):return _materiais[chave]
	var m := ShaderMaterial.new()
	m.shader=PINTURA
	m.set_shader_parameter("cor",Color(cor))
	m.set_shader_parameter("casca",casca)
	_materiais[chave]=m
	return m

func _ramo(raiz: Node3D,a: Vector3,b: Vector3,raio: float) -> void:
	var m := MeshInstance3D.new()
	var forma := CylinderMesh.new()
	forma.top_radius=raio*.45;forma.bottom_radius=raio;forma.height=a.distance_to(b);forma.radial_segments=7
	m.mesh=forma;m.position=(a+b)*.5;m.quaternion=Quaternion(Vector3.UP,(b-a).normalized())
	m.set_meta("inicio_ramo",a);m.set_meta("fim_ramo",b);m.set_meta("raio_ramo",raio)
	m.material_override=_material("86552f",true)
	raiz.add_child(m)

func _copa(raiz: Node3D,pos: Vector3,tamanho: Vector3,cor: String,agulhas := false) -> MeshInstance3D:
	# Folhas com ponta, nervura elevada e duas faces de luz; nenhuma esfera de copa.
	var rng := RandomNumberGenerator.new()
	rng.seed=absi(int(pos.x*9317+pos.y*1783+pos.z*6151))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var quantidade := 110 if not agulhas else 85
	for i in quantidade:
		var angulo := i*2.399963
		var altura := 1.0-2.0*(i+.5)/quantidade
		var raio := sqrt(maxf(0,1.0-altura*altura))
		var direcao := Vector3(cos(angulo)*raio,altura,sin(angulo)*raio)
		var centro := direcao*tamanho*.44*rng.randf_range(.55,1.0)
		var comprimento := rng.randf_range(.25,.42) if not agulhas else rng.randf_range(.28,.53)
		var largura := comprimento*(.43 if not agulhas else .19)
		var eixo := Vector3(cos(angulo),rng.randf_range(-.25,.6),sin(angulo)).normalized()
		var lado := eixo.cross(Vector3.UP).normalized()
		var normal := lado.cross(eixo).normalized()
		var pontos := [centro-eixo*comprimento*.47,centro+lado*largura,centro+eixo*comprimento*.58,centro-lado*largura,centro+normal*.045]
		var luz := rng.randf_range(.82,1.22)
		for face in [[0,1,4],[1,2,4],[2,3,4],[3,0,4]]:
			st.set_color(Color(luz,luz,luz))
			for indice in face:st.add_vertex(pontos[indice])
	st.generate_normals()
	var m := MeshInstance3D.new()
	m.name="RamoAgulhas" if agulhas else "FolhasRecortadas"
	m.mesh=st.commit();m.position=pos
	m.material_override=_material(cor);raiz.add_child(m)
	return m

func _neve_pousada(raiz: Node3D,pos: Vector3,tamanho: Vector3,cor: String) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var forma := PrismMesh.new()
	forma.size=tamanho
	m.name="NeveSobreGalho";m.mesh=forma;m.position=pos
	m.material_override=_material(cor);raiz.add_child(m)
	return m

func _maquete(tipo: int) -> Dictionary:
	var vp := SubViewport.new()
	vp.name="Carvalho3D" if tipo==0 else "Pinheiro3D"
	vp.size=Vector2i(384,384);vp.transparent_bg=true;vp.own_world_3d=true
	vp.render_target_update_mode=SubViewport.UPDATE_ONCE
	vp.msaa_3d=Viewport.MSAA_DISABLED
	add_child(vp)
	var raiz := Node3D.new()
	raiz.name="ModeloArvore";vp.add_child(raiz)
	var camera := Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=6.2
	vp.add_child(camera)
	camera.position=Vector3(0,8.2,10);camera.look_at(Vector3(0,2.2,0))
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees=Vector3(-40,-35,0);luz.light_energy=1.0;vp.add_child(luz)
	var ambiente := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode=Environment.BG_COLOR;env.background_color=Color(0,0,0,0)
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("aabbd0");env.ambient_light_energy=.65
	ambiente.environment=env;vp.add_child(ambiente)
	var copas: Array[MeshInstance3D]=[]
	var neves: Array[MeshInstance3D]=[]
	_ramo(raiz,Vector3.ZERO,Vector3(.06,3.65 if tipo==0 else 4.35,0),.23 if tipo==0 else .16)
	for i in 5:
		var angulo := i*TAU/5.
		_ramo(raiz,Vector3(0,.28,0),Vector3(cos(angulo)*.48,.035,sin(angulo)*.33),.12)
	if tipo==0:
		for i in 7:
			var angulo := i*TAU/7.
			var ponta := Vector3(cos(angulo)*1.15,2.35+(i%3)*.23,sin(angulo)*.65)
			var partida := Vector3(0,1.5+(i%2)*.3,0)
			_ramo(raiz,partida,ponta,.105)
			var neve_ramo := _neve_pousada(raiz,(partida+ponta)*.5+Vector3(0,.07,0),Vector3(.18,partida.distance_to(ponta)*.78,.10),"e1e9e7")
			neve_ramo.quaternion=Quaternion(Vector3.UP,(ponta-partida).normalized())
			neves.append(neve_ramo)
			for grupo in 3:
				var centro := ponta+Vector3(cos(angulo)*grupo*.17,.28+grupo*.32,sin(angulo)*grupo*.14)
				var broto := centro+Vector3(0,.22,0)
				_ramo(raiz,ponta,broto,.042)
				for ramo_fino in [-1,1]:
					_ramo(raiz,ponta.lerp(broto,.6),broto+Vector3(ramo_fino*.20,.18,-.14),.022)
				copas.append(_copa(raiz,centro,Vector3(1.44,1.05,1.24),"658c3d"))
		copas.append(_copa(raiz,Vector3(0,3.68,0),Vector3(2.0,1.45,1.65),"7a9d43"))
	else:
		for nivel in 5:
			var altura := 1.35+nivel*.58
			var raio := 1.35-nivel*.205
			for i in 7:
				var angulo := i*TAU/7.+nivel*.3
				var ponta := Vector3(cos(angulo)*raio*.69,altura-.14,sin(angulo)*raio*.69)
				_ramo(raiz,Vector3(0,altura+.1,0),ponta,.055)
				copas.append(_copa(raiz,ponta,Vector3(raio, .62,raio*.88),"466b3a",true))
				neves.append(_neve_pousada(raiz,ponta+Vector3(0,.20,0),Vector3(raio*.66,.13,raio*.48),"e4ece9"))
		copas.append(_copa(raiz,Vector3(0,4.10,0),Vector3(.55,.95,.55),"5c7f3b",true))
	var acabamento := ShaderMaterial.new()
	acabamento.shader=ACABAMENTO;acabamento.set_shader_parameter("tons",14.)
	return {"viewport":vp,"modelo":raiz,"camera":camera,"copas":copas,"neve":neves,"acabamento":acabamento}

func aplicar(indice: int) -> void:
	if bool(terreno.get_meta("visual_tiny",false)):return
	if indice!=estacao:
		estacao=indice
		_atualizar_estacao_toco(indice)
		for tipo in 2:
			var dados: Dictionary=maquetes[tipo]
			var cores: Array=[
				["719d45","628c38","86a94a","567b32"],
				["56863b","49782f","6b9841","3c682c"],
				["c88932","b5672d","d7a348","a5562d"],
				["56754b","47653c","6a8551","3f5e38"]
			][indice] if tipo==0 else ["50723b","3f6536","678445","385d32"]
			for i in dados.copas.size():
				var copa: MeshInstance3D=dados.copas[i]
				copa.visible=tipo==1 or indice!=3
				copa.material_override=_material(cores[i%cores.size()])
			for neve in dados.neve:neve.visible=indice==3
			dados.viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
	for registro in registros:
		var sprite: Sprite2D=registro.sprite
		if not is_instance_valid(sprite):continue
		if ativas.has(sprite):continue
		var dados: Dictionary=maquetes[registro.tipo]
		sprite.texture=dados.viewport.get_texture()
		sprite.scale=registro.escala/3.0
		sprite.set_meta("escala_render_arvore_3d",1.0/3.0)
		sprite.offset=-dados.camera.unproject_position(Vector3.ZERO)
		sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.material=dados.acabamento
	for toco in terreno.get_node("Extracao")._tocos.values():vestir_toco(toco)
	_atualizar_areas_tocos.call_deferred()

func reagir_ao_corte(sprite: Sprite2D,ponto_golpe: Vector2,derrubar := false,impacto := Callable()) -> bool:
	if bool(terreno.get_meta("visual_tiny",false)):return false
	var registro := {}
	for r in registros:
		if r.sprite==sprite:registro=r;break
	if registro.is_empty():return false
	var ativa: Node=ativas.get(sprite)
	if not is_instance_valid(ativa):
		var economico := OS.has_feature("mobile") or "--fisica-mobile" in OS.get_cmdline_user_args()
		if ativas.size()>=(2 if economico else 4):return false
		ativa=preload("res://codigo/cenario/fisica_arvore_3d.gd").new()
		ativa.name="Fisica_"+str(sprite.name)
		terreno.add_child(ativa)
		ativas[sprite]=ativa
		ativa.configurar(self,sprite,maquetes[registro.tipo],registro.escala,ponto_golpe)
	if derrubar:ativa.derrubar(impacto)
	else:ativa.receber_golpe()
	return true

func finalizar_fisica(sprite: Sprite2D,derrubada: bool) -> void:
	ativas.erase(sprite)
	if is_instance_valid(sprite) and not derrubada:
		sprite.visible=true
		aplicar(estacao)

func _modelar_toco() -> Dictionary:
	var vp := SubViewport.new()
	vp.name="TocoModelado3D";vp.size=Vector2i(128,128);vp.transparent_bg=true;vp.own_world_3d=true
	vp.msaa_3d=Viewport.MSAA_DISABLED;vp.render_target_update_mode=SubViewport.UPDATE_ONCE
	add_child(vp)
	var raiz := Node3D.new();raiz.name="TocoComRaizes";vp.add_child(raiz)
	var camera := Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=6.2/3.
	vp.add_child(camera);camera.position=Vector3(0,6.4,10);camera.look_at(Vector3(0,.4,0))
	var luz := DirectionalLight3D.new();luz.rotation_degrees=Vector3(-40,-35,0);luz.light_energy=1.
	vp.add_child(luz)
	var ambiente := WorldEnvironment.new();var env := Environment.new()
	env.background_mode=Environment.BG_COLOR;env.background_color=Color(0,0,0,0)
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("aabbd0");env.ambient_light_energy=.65
	ambiente.environment=env;vp.add_child(ambiente)
	# Mesmo raio, altura do corte e raízes da árvore adulta.
	_ramo(raiz,Vector3.ZERO,Vector3(.011,.68,0),.23)
	(raiz.get_child(0).mesh as CylinderMesh).top_radius=.206
	for i in 5:
		var angulo := i*TAU/5.
		_ramo(raiz,Vector3(0,.28,0),Vector3(cos(angulo)*.48,.035,sin(angulo)*.33),.12)
	var madeira := MeshInstance3D.new();madeira.name="SuperficieCorte"
	var disco := CylinderMesh.new();disco.top_radius=.199;disco.bottom_radius=.199;disco.height=.016;disco.radial_segments=14
	madeira.mesh=disco;madeira.position=Vector3(.011,.687,0)
	var pintura := ShaderMaterial.new();pintura.shader=preload("res://codigo/cenario/madeira_cortada_3d.gdshader")
	madeira.material_override=pintura;raiz.add_child(madeira)
	var neve := _neve_pousada(raiz,Vector3(0,.705,-.045),Vector3(.23,.05,.12),"e1e9e7")
	return {"viewport":vp,"camera":camera,"modelo":raiz,"pintura":pintura,"neve":neve}

func _atualizar_estacao_toco(indice: int) -> void:
	if toco_3d.is_empty():return
	toco_3d.pintura.set_shader_parameter("cor",Color(["c19455","c69a5c","bc884b","ad9974"][indice]))
	toco_3d.neve.visible=indice==3
	toco_3d.viewport.render_target_update_mode=SubViewport.UPDATE_ONCE

func vestir_toco(toco: Sprite2D,arvore: Sprite2D=null) -> bool:
	if toco_3d.is_empty() or bool(terreno.get_meta("visual_tiny",false)):return false
	var escala: Vector2=toco.get_meta("escala_base_toco_3d",Vector2.ONE)
	if arvore != null:
		for r in registros:
			if r.sprite==arvore:escala=r.escala;break
	toco.set_meta("escala_base_toco_3d",escala)
	toco.set_meta("toco_3d",true)
	toco.texture=toco_3d.viewport.get_texture()
	toco.offset=-toco_3d.camera.unproject_position(Vector3.ZERO)
	toco.scale=escala/3.
	toco.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	toco.material=maquetes[0].acabamento
	return true

func _atualizar_areas_tocos() -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var extracao := terreno.get_node("Extracao")
	for toco in extracao._tocos.values():
		if is_instance_valid(toco):extracao._area_real_do_sprite(toco)
