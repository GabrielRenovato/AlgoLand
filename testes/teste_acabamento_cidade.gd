extends SceneTree
## Registra os componentes antes esquecidos, com saves isolados e quatro estações.
var falhas:=0
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
	pasta=ProjectSettings.globalize_path("res://arte/previas/acabamento_cidade")
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
	conferir(current_scene.get_node_or_null("Decoracao/correio_60_280")==null,"Correio removido da decoração")
	conferir(current_scene.get_node_or_null("Decoracao/Obstaculos/correio_60_280")==null,"Sem colisão invisível do correio")
	var galinha: Sprite2D=current_scene.get_node("Decoracao").find_child("galinha_*",false,false).get_node("Imagem")
	conferir(galinha.texture.resource_path.ends_with("galinha_bento.png") and galinha.hframes==4,"Bento usa a animação canônica de bicar")
	var abrigo: Sprite2D=current_scene.get_node("QuintalCarpinteiro/AbrigoDasAves/Imagem")
	conferir(abrigo.scale==Vector2(.25,.25),"Galinheiro do carpinteiro em alta resolução")
	var portal: Sprite2D=current_scene.get_node("PortalArena/Arco")
	conferir(portal.hframes==9 and portal.scale==Vector2(.25,.25),"Portal novo mantém animação e tamanho lógico")
	var agua: TileMapLayer=current_scene.get_node("Terrains/SuperficieAgua")
	var mascara_agua: Image=load("res://assets/cenario/algoland_original/mascara_agua.png").get_image()
	for e in 4:
		current_scene.get_node("Terrains/Estacoes").definir_estacao(e,true)
		await esperar(40)
		for nome in ["CercasJardins","LimitesVila","QuintalCarpinteiro"]:
			var cercas=current_scene.get_node(nome)
			conferir(not cercas._pecas.is_empty(),"Cerca integrada: "+nome)
			for sprite: Sprite2D in cercas._pecas:
				var pe:=Vector2i(sprite.global_position-Vector2(0,1))
				var celula:=agua.local_to_map(Vector2(pe))
				if agua.get_cell_source_id(celula)==3:
					var pixel:=agua.get_cell_atlas_coords(celula)*16+pe-celula*16
					conferir(mascara_agua.get_pixelv(pixel).r<.5,"Base de cerca fora da água: "+nome)
				conferir(sprite.texture.resource_path.begins_with("res://assets/cenario/cidade/complementos/cercas/"),"Sem cerca antiga: "+nome)
				conferir(sprite.scale==Vector2(.25,.25),"Escala preservada: "+nome)
				conferir(sprite.texture.resource_path.contains(["primavera","verao","outono","inverno"][e]),"Estação da cerca: "+nome)
		conferir(abrigo.texture.resource_path.begins_with("res://assets/cenario/cidade/enfeites_detalhados/galinheiro/"),"Abrigo usa conjunto frontal sazonal")
		conferir(portal.texture.resource_path.begins_with("res://assets/cenario/cidade/complementos/portal/"),"Portal sazonal integrado")
		for ponto in [["praca",Vector2(336,275)],["portal",Vector2(488,120)],["bento",Vector2(160,455)],["carpinteiro",Vector2(818,295)],["taverna",Vector2(240,370)]]:
			camera.global_position=ponto[1]
			await foto(ponto[0]+"-"+str(e))
	current_scene.get_node("Terrains/Estacoes").definir_estacao(0,true)
	for morador in current_scene.moradores.values():
		morador.hide()
		morador.set_physics_process(false)
	for nome in ["PlacaFazenda","PlacaPraia"]:
		var placa=current_scene.get_node("Terrains/"+nome)
		jogador.position=placa.global_position+Vector2(0,20)
		camera.global_position=placa.global_position
		await esperar(60)
		conferir(placa._imagem.texture.resource_path.contains("complementos/placa_saida/"),"Placa nova: "+nome)
		conferir(placa._balao.visible and placa._balao.size.x>=placa._balao.get_minimum_size().x,"Texto cabe no balão: "+nome)
		conferir(placa._balao.position.y+placa._balao.size.y<=-42,"Margem entre texto e placa: "+nome)
		await foto(nome)
	jogador.position=Vector2(4000,4000)
	root.content_scale_size=Vector2i(1024,576)
	root.size=Vector2i(2048,1152)
	camera.global_position=Vector2(512,288)
	await foto("cidade_completa")
	print("ACABAMENTO CIDADE: quatro estações, cercas, portal, placas e aves; ",falhas," falhas")
	quit(1 if falhas else 0)
