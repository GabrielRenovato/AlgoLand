extends SceneTree
## Captura o GLB real com o filtro do jogo; atlas compartilhado por todos os goblins.
const SAIDA := "res://assets/inimigos/goblin_capuz_3d/atlas/"
func _initialize() -> void: rodar.call_deferred()
func rodar() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA))
	var vp := SubViewport.new()
	vp.size=Vector2i(160,160);vp.own_world_3d=true;vp.transparent_bg=true
	vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var doc := GLTFDocument.new();var estado := GLTFState.new()
	assert(doc.append_from_file("res://assets/inimigos/goblin_capuz_3d/goblin_capuz_animado.glb",estado)==OK)
	var modelo := doc.generate_scene(estado);vp.add_child(modelo)
	var ambiente := WorldEnvironment.new();ambiente.environment=Environment.new()
	ambiente.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	ambiente.environment.ambient_light_color=Color("c5d1df");ambiente.environment.ambient_light_energy=.4
	vp.add_child(ambiente)
	for item in [[Vector3(-3,5,4),.8,Color("ffe4bb")],[Vector3(4,3,2),.35,Color("b8d3ff")]]:
		var luz := DirectionalLight3D.new();vp.add_child(luz);luz.position=item[0]
		luz.look_at(Vector3(0,.7,0));luz.light_energy=item[1];luz.light_color=item[2]
	var camera := Camera3D.new();vp.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=3.0;camera.position=Vector3(0,1.65,5);camera.look_at(Vector3(0,.85,0))
	var final := SubViewport.new();final.size=Vector2i(160,160);final.transparent_bg=true
	final.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(final)
	var sprite := Sprite2D.new();sprite.centered=false;sprite.texture=vp.get_texture();sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var material := ShaderMaterial.new();material.shader=load("res://codigo/jogador/contorno_pixel_base_3d.gdshader");sprite.material=material;final.add_child(sprite)
	var a: AnimationPlayer=modelo.find_children("*","AnimationPlayer",true,false)[0]
	var ficha := {"quadro":[160,160],"pivo":[camera.unproject_position(Vector3.ZERO).x,camera.unproject_position(Vector3.ZERO).y],"animacoes":{}}
	# nome: [quadros, colunas, início da fonte, fim da fonte (0 = clipe inteiro), duração no jogo (0 = a da fonte), laço]
	# Mais quadros deixam a animação fluida (eram 12 por clipe: o parado rodava a 3 fps). Direção d ocupa as linhas
	# d*R..d*R+R-1 (R = quadros/colunas); o quadro do Sprite2D é direcao*quadros+q, com hframes=colunas.
	# O recorte do ferido (só o tranco) cabe no recuo de 0,2 s do inimigo; a morte pula o cambaleio longo e cai logo.
	var clipes := {
		"parado":[24,12,0.0,0.0,0.0,true],
		"correr":[16,16,0.0,0.0,0.0,true],
		"ataque_1":[24,12,0.35,1.55,0.0,false],
		"ferido":[8,8,0.0,0.6,0.22,false],
		"morrer":[24,12,0.6,3.1,1.4,false]}
	for nome in ["parado","correr","ataque_1","ferido","morrer"]:
		var cfg:Array=clipes[nome]
		var quadros:int=cfg[0];var colunas:int=cfg[1];var linhas:=quadros/colunas
		var clipe:=a.get_animation(nome);clipe.loop_mode=Animation.LOOP_NONE
		var inicio:float=cfg[2]
		var fim:float=minf(float(cfg[3]),clipe.length) if float(cfg[3])>0.0 else clipe.length
		var duracao_fonte:=fim-inicio
		var duracao:float=float(cfg[4]) if float(cfg[4])>0.0 else duracao_fonte
		var atlas:=Image.create(colunas*160,4*linhas*160,false,Image.FORMAT_RGBA8)
		a.play(nome);a.pause()
		for d in 4:
			modelo.rotation.y=[0.0,PI/2,PI,-PI/2][d]
			for q in quadros:
				var tempo:=inicio+duracao_fonte*q/(float(quadros) if cfg[5] else float(quadros-1))
				a.seek(tempo,true)
				await RenderingServer.frame_post_draw
				await RenderingServer.frame_post_draw
				atlas.blit_rect(final.get_texture().get_image(),Rect2i(0,0,160,160),Vector2i((q%colunas)*160,(d*linhas+q/colunas)*160))
		assert(atlas.save_png(SAIDA+nome+".png")==OK)
		ficha.animacoes[nome]={"duracao":duracao,"inicio_fonte":inicio,"fim_fonte":fim,"loop":cfg[5],"quadros":quadros,"colunas":colunas}
		if nome=="ataque_1":ficha.animacoes[nome].impacto=clampf((.97-inicio)/duracao_fonte,.1,.9)
	FileAccess.open(SAIDA+"animacoes.json",FileAccess.WRITE).store_string(JSON.stringify(ficha,"  "))
	print("ATLAS_GOBLIN_OK")
	quit()
