extends SceneTree
## Cena real, geometria e água preservadas; capturas nas quatro estações.
var falhas := 0
var pasta: String
func _initialize() -> void: rodar.call_deferred()
func esperar(n:=8) -> void:
	for i in n: await process_frame
func conferir(ok: bool,mensagem: String) -> void:
	if not ok:
		falhas+=1
		push_error(mensagem)
func foto(nome: String) -> void:
	await esperar()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(pasta+"/"+nome+".png")
func rodar() -> void:
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	root.get_node("Introducao").pular_prologo()
	root.get_node("Transicao").hora_salva=12.0
	root.mode=Window.MODE_WINDOWED
	root.content_scale_size=Vector2i(576,324)
	root.size=Vector2i(1152,648)
	pasta=ProjectSettings.globalize_path("res://arte/previas/chao_detalhado")
	DirAccess.make_dir_recursive_absolute(pasta)
	change_scene_to_file("res://cenas/cidade.tscn")
	await esperar(40)
	var jogador=current_scene.get_node("Jogador")
	jogador.set_physics_process(false)
	jogador.visible=false
	jogador.position=Vector2(4000,4000)
	var camera: Camera2D=jogador.camera
	camera.set_as_top_level(true)
	camera.limit_enabled=false
	camera.position_smoothing_enabled=false
	camera.zoom=Vector2.ONE
	for hud in get_nodes_in_group("hud"): hud.hide()
	if current_scene.has_node("Interface"): current_scene.get_node("Interface").hide()
	var luz=current_scene.get_node("Iluminacao")
	luz.set_process(false)
	luz.hora=12.0
	luz._aplicar()
	var camada: TileMapLayer=current_scene.get_node("Terrains/Terreno")
	var agua: TileMapLayer=current_scene.get_node("Terrains/SuperficieAgua")
	var chao=current_scene.get_node("Terrains/ChaoDetalhado")
	var original: PackedByteArray=camada.tile_map_data.duplicate()
	var original_agua: PackedByteArray=agua.tile_map_data.duplicate()
	conferir(chao.z_index==-999,"Chão sob personagens/objetos e sobre o terreno")
	var erros_agua:=0
	var distribuicao: Image=chao._renderizador.material.get_shader_parameter("distribuicao").get_image()
	var mascara_agua: Image=load("res://assets/cenario/algoland_original/mascara_agua.png").get_image()
	for celula in agua.get_used_cells():
		var atlas:=agua.get_cell_atlas_coords(celula)
		for y in 16:
			for x in 16:
				if mascara_agua.get_pixel(atlas.x*16+x,atlas.y*16+y).r<.5: continue
				var p: Vector2i=(celula*16+Vector2i(x,y)-Vector2i(chao.area.position))*4+Vector2i(2,2)
				var m: Color=distribuicao.get_pixelv(p)
				if m.r+m.g+m.b>.01: erros_agua+=1
	conferir(erros_agua==0,"Máscara do novo chão não invade a água")
	for e in 4:
		current_scene.get_node("Terrains/Estacoes").definir_estacao(e,true)
		await esperar(40)
		conferir(chao.estacao==e,"Chão acompanha F3: "+str(e))
		conferir(camada.tile_map_data==original and agua.tile_map_data==original_agua,"Células e índices preservados: "+str(e))
		for tipo in ["grama","pedra"]:
			var textura: Texture2D=chao._renderizador.material.get_shader_parameter(tipo)
			conferir(textura.resource_path.ends_with(tipo+"_"+chao.ESTACOES[e]+".png"),"Material sazonal: "+tipo)
			conferir(textura.get_image().has_mipmaps(),"Amostragem em escalas diferentes: "+tipo)
			var campo:=textura.get_image()
			if campo.is_compressed(): campo.decompress()
			var costura:=0.0
			for i in campo.get_width():
				var a:=campo.get_pixel(0,i)
				var b:=campo.get_pixel(campo.get_width()-1,i)
				var c:=campo.get_pixel(i,0)
				var d:=campo.get_pixel(i,campo.get_height()-1)
				costura+=absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)+absf(c.r-d.r)+absf(c.g-d.g)+absf(c.b-d.b)
			conferir(costura/float(campo.get_width()*6)<.015,"Emendas periódicas sem linha de exposição: "+tipo)
		for ponto in [["praca",Vector2(336,275)],["ponte",Vector2(676,275)],["quintal",Vector2(160,455)]]:
			camera.global_position=ponto[1]
			await foto(ponto[0]+"-"+str(e))
			if ponto[0]=="praca":
				chao.hide()
				camada.show()
				await foto("antes-"+str(e))
				chao.show()
				camada.hide()
		camera.global_position=Vector2(336,275)
		camera.zoom=Vector2(2,2)
		await foto("detalhe-"+str(e))
		camera.zoom=Vector2.ONE
	print("CHÃO DETALHADO: quatro estações, células e água; ",falhas," falhas")
	quit(1 if falhas else 0)
