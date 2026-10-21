extends SceneTree
## Revisão sazonal real e regressões de corte, pedras, plantio e comparação visual.
const SAIDA := "res://arte/previas/fazenda/natureza_detalhada/"
var falhas := 0
var camera: Camera2D
func _initialize() -> void: _rodar.call_deferred()
func verificar(ok: bool,texto: String) -> void:
	if not ok:
		falhas+=1
		push_error(texto)
func quadros(n:=8) -> void:
	for i in n: await process_frame
func foto(nome: String,centro: Vector2,zoom:=Vector2.ONE) -> void:
	camera.position=centro
	camera.zoom=zoom
	await quadros()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(SAIDA+nome+".png")
func conferir_fase(e: int,paredao: TileMapLayer) -> void:
	# Compara pixels reais da borda superior com o chão subjacente na mesma
	# posição mundial. Também detecta um reinício dos UVs em cada célula.
	camera.position=Vector2(560,60)
	camera.zoom=Vector2(2,2)
	await quadros()
	await RenderingServer.frame_post_draw
	var com:=root.get_texture().get_image()
	paredao.hide()
	await quadros(2)
	await RenderingServer.frame_post_draw
	var sem:=root.get_texture().get_image()
	paredao.show()
	var pe:=float(paredao.get_used_rect().end.y*16)
	var y:=roundi((pe-64.0+2.0-60.0)*3.0+576.0)
	var soma:=0.0
	var amostras:=0
	for x in range(120,com.get_width()-120,6):
		var a:=com.get_pixel(x,y)
		var b:=sem.get_pixel(x,y)
		soma+=absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)
		amostras+=3
	var erro:=soma/float(amostras)*255.0
	print("Continuidade estação ",e,": diferença média ",erro," /255")
	verificar(erro<5.0,"fase e cor contínuas no topo do barranco, estação "+str(e))
func _rodar() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"):
		quit(1)
		return
	await process_frame
	root.get_node("Saves").trocar("solo")
	root.get_node("Introducao").pular_prologo()
	var fazenda: Node=root.get_node("Fazenda")
	fazenda.apagar()
	root.get_node("Transicao").hora_salva=12.0
	root.mode=Window.MODE_WINDOWED
	root.size=Vector2i(1728,1152)
	root.content_scale_size=Vector2i(1152,768)
	change_scene_to_file("res://cenas/fazenda.tscn")
	await quadros(20)
	var terreno:=current_scene.get_node("Terrains")
	var estacoes:=terreno.get_node("Estacoes")
	var natureza:=terreno.get_node("NaturezaFazenda")
	var extracao:=terreno.get_node("Extracao")
	current_scene.get_node("Jogador").set_physics_process(false)
	for hud in get_nodes_in_group("hud"): hud.hide()
	for no in current_scene.find_children("*","CanvasLayer",true,false): no.hide()
	var luz:=current_scene.get_node("Iluminacao")
	luz.definir_hora(12.0)
	luz.set_process(false)
	luz._aplicar()
	camera=Camera2D.new()
	current_scene.add_child(camera)
	camera.make_current()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA))
	var posicoes: Dictionary={}
	for sprite in terreno.get_node("Objetos3D").get_children():
		posicoes[sprite]=[sprite.position,sprite.scale]
	var obstaculos: Dictionary={}
	for no in terreno.get_node("Obstaculos").get_children():
		if no is CollisionPolygon2D: obstaculos[no]=no.polygon.duplicate()
	var terra: TileMapLayer=terreno.get_node("Terra")
	var celulas:=terra.get_used_cells()
	for y in range(24,27):
		for x in range(13,18):
			var celula:=Vector2i(x,y)
			fazenda.entulho.erase(celula)
			fazenda.solo[celula]={"molhado":x>=16,"planta":"","dias":0,"murcha":false}
	fazenda.entulho_alterado.emit(Vector2i.ZERO)
	terreno.get_node("Plantio").queue_redraw()
	for e in 4:
		estacoes.definir_estacao(e,true)
		estacoes.meteorologia.definir_clima(0,true)
		await quadros()
		verificar(natureza.estacao==e and natureza.ativo,"troca sazonal da natureza")
		var grama: Texture2D=terreno.get_node("ChaoFazenda")._material.get_shader_parameter("grama")
		for dados: Dictionary in natureza._fontes_paredao.values():
			verificar(dados.material.get_shader_parameter("grama")==grama,"barranco compartilha a grama sazonal do chão")
			var textura: Texture2D=dados.material.get_shader_parameter("barranco")
			verificar(natureza.NOMES[e] in textura.resource_path,"rocha do barranco troca com a estação")
		verificar(terra.get_used_cells()==celulas,"células de plantio preservadas")
		for sprite in posicoes: verificar(posicoes[sprite]==[sprite.position,sprite.scale],"base e escala preservadas")
		for no in obstaculos: verificar(obstaculos[no]==no.polygon,"colisão física preservada")
		for sprite in terreno.get_node("Objetos3D").get_children():
			if sprite.has_meta("arte_natureza"):
				var arte: Texture2D=sprite.material.get_shader_parameter("arte")
				verificar(arte.get_size()==Vector2(512,512) and natureza.NOMES[e] in arte.resource_path,"árvore detalhada sazonal")
				if sprite.get_meta("arte_natureza")=="carvalho":
					verificar(arte.get_image().get_used_rect().size.y>=384,"carvalho adulto conserva altura legível no cenário")
		await foto("fazenda_%d" % e,Vector2(576,384))
		await conferir_fase(e,terreno.get_node("Penhasco"))
		await foto("barranco_%d" % e,Vector2(560,60),Vector2(2,2))
		await foto("pedreira_%d" % e,Vector2(880,155),Vector2(2,2))
		await foto("pomar_%d" % e,Vector2(900,530),Vector2(2,2))
		await foto("terra_%d" % e,Vector2(265,405),Vector2(2,2))
	var pedra: Dictionary=extracao.recursos.filter(func(r): return r.tipo=="pedra")[0]
	var detalhes: TileMapLayer=terreno.get_node("Detalhes")
	verificar(detalhes.get_cell_source_id(pedra.celula)>=0,"pedra fixa existente")
	for i in 3: extracao.impacto("picareta",terreno.to_global(pedra.pos))
	verificar(detalhes.get_cell_source_id(pedra.celula)<0,"pedra detalhada some ao quebrar")
	var arvore: Dictionary=extracao.recursos.filter(func(r): return r.tipo=="arvore")[0]
	var adulta: Sprite2D=terreno.get_node(arvore.no)
	for i in 4: extracao.impacto("machado",terreno.to_global(arvore.pos))
	var queda: Sprite2D=extracao.get_node_or_null("Queda_"+String(arvore.chave))
	verificar(queda!=null and queda.material==adulta.material,"queda conserva a arte nova e seu recorte")
	await foto("corte",arvore.pos-Vector2(0,35),Vector2(3,3))
	var troca:=current_scene.get_node("ComparacaoTiny")
	troca.definir_ativo(true)
	verificar(not natureza.ativo,"comparação Tiny desativa acabamento")
	troca.definir_ativo(false)
	verificar(natureza.ativo,"comparação restaura acabamento")
	await foto("retorno",Vector2(576,384))
	root.size=Vector2i(1728,288)
	root.content_scale_size=Vector2i(1152,192)
	for e in 4:
		estacoes.definir_estacao(e,true)
		estacoes.meteorologia.definir_clima(0,true)
		await foto("faixa_%d" % e,Vector2(560,50),Vector2(2,2))
	print("Natureza fazenda: ",falhas," falhas; quatro estações e interações conferidas.")
	quit(1 if falhas else 0)
