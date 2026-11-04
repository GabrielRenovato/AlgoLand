extends SceneTree
## Captura o terreno e os objetos reais da dungeon em save isolado, sem criar boss temporário.
func _initialize() -> void:renderizar.call_deferred()
func quadros(n:=4) -> void:
	for i in n:
		await physics_frame
		await process_frame
func salvar(vista:SubViewport,nome:String) -> void:
	await quadros()
	await RenderingServer.frame_post_draw
	var destino:="res://arte/previas/fenda/jornada/"+nome+".png"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destino.get_base_dir()))
	assert(vista.get_texture().get_image().save_png(destino)==OK)
func renderizar() -> void:
	if DisplayServer.get_name()=="headless" or not str(ProjectSettings.get_setting("application/config/custom_user_dir_name","")).begins_with("AlgoLand testes"):
		quit(1);return
	await process_frame
	var cena:=Node2D.new();root.add_child(cena);current_scene=cena
	var vista:=SubViewport.new();vista.size=Vector2i(1152,648);vista.disable_3d=true;vista.world_2d=World2D.new()
	vista.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	vista.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	cena.add_child(vista)
	var dungeon:Node2D=load("res://codigo/campanha/dungeon_comporta.gd").new();vista.add_child(dungeon)
	while not dungeon.pronta:await quadros(2)
	for mob in dungeon.inimigos:mob.set_physics_process(false)
	var camera:=Camera2D.new();vista.add_child(camera);camera.make_current()
	camera.position=Vector2(-448,592);camera.zoom=Vector2(2,2)
	await salvar(vista,"goblins_04")
	for estacao in 4:
		dungeon.terreno.get_node("Estacoes").definir_estacao(estacao,true)
		await salvar(vista,"acampamento_04_estacao_%d" % estacao)
	for quadro in 8:
		await create_timer(1.0/6.0).timeout
		await salvar(vista,"fogueira_04_quadro_%d" % quadro)
	camera.position=Vector2(1200,-24)
	for estacao in 4:
		dungeon.terreno.get_node("Estacoes").definir_estacao(estacao,true)
		await salvar(vista,"comporta_04_estacao_%d" % estacao)
	camera.position=Vector2.ZERO;camera.zoom=Vector2.ONE*(1280.0/3040.0);vista.size=Vector2i(1280,896)
	await salvar(vista,"dungeon_comporta_04")
	# Oclusão real: cada espécie dos dois lados da mesma rocha nativa.
	var rochas:Array=dungeon.terreno.get_node("Objetos3D").get_children().filter(func(n):return n is Sprite2D and n.has_meta("decoracao_fenda"))
	rochas.sort_custom(func(a,b):return a.global_position.distance_to(Vector2(-400,720))<b.global_position.distance_to(Vector2(-400,720)))
	var rocha:Sprite2D=rochas[0]
	camera.position=rocha.global_position+Vector2(0,-20);camera.zoom=Vector2(4,4);vista.size=Vector2i(512,384)
	for mob in dungeon.inimigos:mob.hide()
	for especie in 2:
		var mob:Node2D=dungeon.inimigos[especie];mob.show();mob.ia_habilitada=false;mob.set_physics_process(true)
		for lado in ["atras","frente"]:
			mob.global_position=rocha.global_position+Vector2(0,-20 if lado=="atras" else 20)
			await salvar(vista,"oclusao_goblin_%d_%s" % [especie,lado])
		mob.set_physics_process(false);mob.hide()
	print("RENDER_GOBLINS_GRUTA_OK: ocupacao, quatro estacoes e vista geral")
	current_scene=null;cena.queue_free()
	await quadros(2)
	quit()
