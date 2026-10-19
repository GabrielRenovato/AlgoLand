extends SceneTree

## Captura os onze terrenos reais nas quatro estações, somente com saves isolados.
var Catalogo: GDScript
func _initialize() -> void: rodar.call_deferred()
func quadros(n := 5) -> void:
	for i in n:
		await physics_frame
		await process_frame
func rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name","")).begins_with("AlgoLand testes") or DisplayServer.get_name()=="headless":
		quit(1)
		return
	await process_frame
	Catalogo=load("res://codigo/fendas/catalogo_andares.gd")
	var saida := "res://arte/previas/fenda/jornada/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(saida))
	var vista := SubViewport.new()
	vista.disable_3d=true
	vista.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	vista.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(vista)
	var andares: Array[int] = []
	for n in range(1,12): andares.append(n)
	for argumento in OS.get_cmdline_user_args():
		if argumento.begins_with("--andares="):
			andares.clear()
			for numero in argumento.trim_prefix("--andares=").split(","):
				if numero.to_int()<1 or numero.to_int()>11:
					quit(1)
					return
				andares.append(numero.to_int())
	for andar in andares:
		vista.world_2d=World2D.new()
		var terreno: Node2D = load("res://cenas/fendas/terreno_%02d.tscn" % andar).instantiate()
		vista.add_child(terreno)
		var camera:=Camera2D.new()
		vista.add_child(camera)
		var dados: Dictionary=Catalogo.dados(andar)
		var largura: float=float(dados.limites[2])+256
		var altura: float=float(dados.limites[3])+128
		var zoom := 1280.0/largura
		vista.size=Vector2i(1280,roundi(altura*zoom))
		camera.position=Vector2(dados.limites[0]+dados.limites[2]*.5,dados.limites[1]+dados.limites[3]*.5)
		camera.zoom=Vector2.ONE*zoom
		camera.make_current()
		await quadros()
		for estacao in 4:
			terreno.get_node("Estacoes").definir_estacao(estacao,true)
			await quadros()
			await RenderingServer.frame_post_draw
			vista.get_texture().get_image().save_png(saida+"terreno_%02d_estacao_%d.png" % [andar,estacao])
		# Recorte nativo ampliado do encontro central para revisar pisos, bordas e camadas.
		vista.size=Vector2i(1152,648)
		camera.position=terreno.get_node("Setores").get_child(1).position
		camera.zoom=Vector2(2,2)
		terreno.get_node("Estacoes").definir_estacao(0,true)
		await quadros()
		await RenderingServer.frame_post_draw
		vista.get_texture().get_image().save_png(saida+"detalhe_%02d.png" % andar)
		print("RENDER ANDAR ",andar," quatro estacoes e detalhe")
		terreno.queue_free()
		camera.queue_free()
		await quadros(3)
	vista.queue_free()
	await quadros()
	quit()
