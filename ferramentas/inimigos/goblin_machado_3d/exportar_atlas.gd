extends SceneTree
## Captura o goblin do machado com o mesmo quadro, pivot e filtro do goblin da adaga.
const SAIDA := "res://assets/inimigos/goblin_machado_3d/atlas/"
const ACOES := ["parado","correr","ataque_1","ataque_2","ferido","morrer"]

func _initialize() -> void:
	rodar.call_deferred()

func rodar() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA))
	var vp := SubViewport.new()
	vp.size=Vector2i(160,160);vp.own_world_3d=true;vp.transparent_bg=true
	vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(vp)
	var doc:=GLTFDocument.new();var estado:=GLTFState.new()
	assert(doc.append_from_file("res://assets/inimigos/goblin_machado_3d/goblin_machado_animado.glb",estado)==OK)
	var modelo:=doc.generate_scene(estado);vp.add_child(modelo)
	var ambiente:=WorldEnvironment.new();ambiente.environment=Environment.new()
	ambiente.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	ambiente.environment.ambient_light_color=Color("c5d1df");ambiente.environment.ambient_light_energy=.4;vp.add_child(ambiente)
	for item in [[Vector3(-3,5,4),.8,Color("ffe4bb")],[Vector3(4,3,2),.35,Color("b8d3ff")]]:
		var luz:=DirectionalLight3D.new();vp.add_child(luz);luz.position=item[0]
		luz.look_at(Vector3(0,.7,0));luz.light_energy=item[1];luz.light_color=item[2]
	var camera:=Camera3D.new();vp.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=3.0;camera.position=Vector3(0,1.65,5);camera.look_at(Vector3(0,.85,0))
	var final:=SubViewport.new();final.size=Vector2i(160,160);final.transparent_bg=true
	final.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(final)
	var sprite:=Sprite2D.new();sprite.centered=false;sprite.texture=vp.get_texture();sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var material:=ShaderMaterial.new();material.shader=load("res://codigo/jogador/contorno_pixel_base_3d.gdshader");sprite.material=material;final.add_child(sprite)
	var animador:AnimationPlayer=modelo.find_children("*","AnimationPlayer",true,false)[0]
	var ficha:Dictionary={"quadro":[160,160],"grade":[12,4],"pivo":[camera.unproject_position(Vector3.ZERO).x,camera.unproject_position(Vector3.ZERO).y],"animacoes":{}}
	for nome in ACOES:
		var clip:Animation=animador.get_animation(nome);clip.loop_mode=Animation.LOOP_NONE
		var atlas:=Image.create(1920,640,false,Image.FORMAT_RGBA8)
		animador.play(nome);animador.pause()
		for direcao in 4:
			modelo.rotation.y=[0.0,PI/2,PI,-PI/2][direcao]
			for quadro in 12:
				var tempo:=clip.length*float(quadro)/(12.0 if nome in ["parado","correr"] else 11.0)
				animador.seek(tempo,true)
				await RenderingServer.frame_post_draw
				await RenderingServer.frame_post_draw
				atlas.blit_rect(final.get_texture().get_image(),Rect2i(0,0,160,160),Vector2i(quadro*160,direcao*160))
		assert(atlas.save_png(SAIDA+nome+".png")==OK)
		ficha.animacoes[nome]={"duracao":clip.length,"loop":nome in ["parado","correr"]}
		if nome.begins_with("ataque_"):
			ficha.animacoes[nome].impacto=0.6223 if nome=="ataque_1" else 0.756
	FileAccess.open(SAIDA+"animacoes.json",FileAccess.WRITE).store_string(JSON.stringify(ficha,"  "))
	print("ATLAS_GOBLIN_MACHADO_OK")
	quit()
