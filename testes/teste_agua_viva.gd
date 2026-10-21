extends SceneTree
## Capturas reais e regressão de animação, máscara e estações, em save isolado.
var falhas:=0
func _initialize() -> void:rodar.call_deferred()
func esperar(n:=4) -> void:
	for i in n:await process_frame
func verificar(ok: bool, mensagem: String) -> void:
	if not ok:
		falhas+=1
		push_error(mensagem)

func conferir_mascara(helper: RefCounted, centro: Vector2) -> void:
	var vp:=SubViewport.new()
	vp.size=Vector2i(320,240)
	vp.world_2d=World2D.new()
	vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var camera:=Camera2D.new()
	camera.position=centro
	camera.zoom=Vector2(2,2)
	vp.add_child(camera)
	camera.make_current()
	var origem: Vector2=helper.material.get_shader_parameter("origem")
	var tamanho: Vector2=helper.material.get_shader_parameter("tamanho")
	var mascara: Image=helper.material.get_shader_parameter("contorno").get_image()
	var plano:=Polygon2D.new()
	plano.polygon=PackedVector2Array([origem,origem+Vector2(tamanho.x,0),origem+tamanho,origem+Vector2(0,tamanho.y)])
	plano.material=helper.material.duplicate()
	vp.add_child(plano)
	var fotos: Array[Image]=[]
	for tempo in [0.0,1.0]:
		plano.material.set_shader_parameter("tempo_revisao",tempo)
		await esperar(2)
		await RenderingServer.frame_post_draw
		fotos.append(vp.get_texture().get_image())
	var dentro:=0
	var fora:=0
	for y in 240:
		for x in 320:
			if fotos[0].get_pixel(x,y)==fotos[1].get_pixel(x,y):continue
			var ponto: Vector2=centro+Vector2(x+0.5-160,y+0.5-120)/2.0-origem
			var pixel:=Vector2i(ponto.floor())
			if Rect2i(Vector2i.ZERO,mascara.get_size()).has_point(pixel) and mascara.get_pixelv(pixel).r>0.5:dentro+=1
			else:fora+=1
	verificar(dentro>100,"GPU: animação modifica a superfície da água")
	verificar(fora==0,"GPU: animação não altera nenhum pixel fora da água")
	vp.queue_free()
	await esperar(2)
func rodar() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes") or DisplayServer.get_name()=="headless":
		quit(1)
		return
	root.get_node("Introducao").pular_prologo()
	root.get_node("Transicao").hora_salva=12.0
	root.get_node("Fazenda").definir_clima_hoje(0)
	DirAccess.make_dir_recursive_absolute("/tmp/algoland-agua-viva")
	for local in ["fazenda","cidade","fendas/terreno_05"]:
		var cena: Node2D=load("res://cenas/%s.tscn" % local).instantiate()
		root.add_child(cena)
		current_scene=cena
		await esperar(12)
		var terreno: Node2D=cena.get_node("Terrains") if cena.has_node("Terrains") else cena
		var helper: RefCounted
		var centro: Vector2
		if local=="fazenda":
			helper=terreno.get_node("Lago")._agua_viva
			centro=terreno.get_node("Lago").global_position
		elif local=="cidade":
			helper=cena._agua_viva
			var camada: TileMapLayer=cena.get_node("Terrains/SuperficieAgua")
			var celulas:=camada.get_used_cells()
			centro=camada.to_global(camada.map_to_local(celulas[celulas.size()/2]))
		else:
			helper=terreno.get_node("Estacoes")._agua_viva
			var dados: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://codigo/fendas/plantas/andar_05.json"))
			centro=Vector2(dados.lago.lobos[0][0],dados.lago.lobos[0][1])
		verificar(helper.material!=null,local+": água integrada")
		var vp:=SubViewport.new()
		vp.size=Vector2i(640,480)
		vp.world_2d=cena.get_world_2d()
		vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		vp.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		root.add_child(vp)
		var camera:=Camera2D.new()
		camera.position=centro
		camera.zoom=Vector2(2,2)
		vp.add_child(camera)
		camera.make_current()
		var nome: String=local.replace("/","_")
		for e in 4:
			if local=="cidade":cena._aplicar_terreno(e)
			else:terreno.get_node("Estacoes").definir_estacao(e,true)
			verificar(is_equal_approx(helper.material.get_shader_parameter("inverno"),1.0 if e==3 else 0.0),nome+": tratamento sazonal")
			await esperar(3)
			await RenderingServer.frame_post_draw
			vp.get_texture().get_image().save_png("/tmp/algoland-agua-viva/%s_%d.png" % [nome,e])
		if local=="cidade":cena._aplicar_terreno(0)
		else:terreno.get_node("Estacoes").definir_estacao(0,true)
		await conferir_mascara(helper,centro)
		var imagens: Array[Image]=[]
		for quadro in 24:
			await RenderingServer.frame_post_draw
			imagens.append(vp.get_texture().get_image())
			await create_timer(1.0/12.0).timeout
		var diferentes:=0
		for y in range(0,480,2):
			for x in range(0,640,2):
				if imagens[0].get_pixel(x,y)!=imagens[12].get_pixel(x,y):diferentes+=1
		verificar(diferentes>60,nome+": superfície e reflexos realmente animam")
		for i in imagens.size():imagens[i].save_png("/tmp/algoland-agua-viva/%s_anim_%02d.png" % [nome,i])
		vp.queue_free()
		cena.queue_free()
		current_scene=null
		await esperar(5)
	print("AGUA VIVA: ",falhas," falhas; fazenda, rios da cidade e fendas, quatro estações e animação real.")
	quit(1 if falhas else 0)
