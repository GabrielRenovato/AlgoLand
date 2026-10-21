extends SceneTree
## Conferência das âncoras, colisões, animação e capturas reais nas quatro estações.
var falhas := 0
var pasta: String
func _initialize() -> void: rodar.call_deferred()
func esperar(n := 6) -> void:
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
	pasta=ProjectSettings.globalize_path("res://arte/previas/enfeites_detalhados")
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
	var decoracao=current_scene.get_node("Decoracao")
	var layout: Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/cenario/cidade/decoracao/decoracao.json"))
	var objetos: Array[Dictionary]=[]
	for item: Dictionary in layout:
		var dados:=preload("res://codigo/cidade/enfeites_detalhados.gd").dados(item.p)
		if dados.is_empty(): continue
		var nome: String="%s_%d_%d" % [String(item.p).get_file(),int(item.x),int(item.y)]
		var objeto: Node2D=decoracao.get_node(nome)
		var sprite: Sprite2D=objeto.get_node("Imagem")
		conferir(objeto.position==Vector2(item.x,item.y),"Posição preservada: "+nome)
		var resolucao: float=dados.get("resolucao",1.0)
		conferir(sprite.scale==Vector2.ONE/resolucao,"Escala lógica: "+nome)
		var usado: Array=item.usado
		conferir((sprite.offset*sprite.scale).is_equal_approx(Vector2(-float(usado[0])-float(usado[2])/2.0,-float(usado[1])-float(usado[3]))),"Pivô preservado: "+nome)
		if item.has("col"):
			var forma: CollisionShape2D=decoracao.get_node("Obstaculos/"+nome)
			conferir(forma.shape.size==Vector2(item.col[0],item.col[1]),"Colisão preservada: "+nome)
		objetos.append({"no":objeto,"sprite":sprite,"dados":dados})
	conferir(objetos.size()>20,"Enfeites detalhados integrados ao mapa")
	for e in 4:
		current_scene.get_node("Terrains/Estacoes").definir_estacao(e,true)
		await esperar(20)
		for entrada in objetos:
			var sprite: Sprite2D=entrada.sprite
			conferir(entrada.no.get_node("DetalheAmbiente").estacao==e,"Troca de estação: "+str(entrada.no.name))
			conferir(sprite.texture.resource_path==entrada.dados.texturas[e],"Textura sazonal: "+str(entrada.no.name))
			if entrada.dados.get("resolucao",1.0)>1: conferir(sprite.texture.get_image().has_mipmaps(),"Mipmaps: "+str(entrada.no.name))
			if entrada.dados.has("canvas_logico"):
				conferir((sprite.texture.get_size()*sprite.scale/Vector2(sprite.hframes,1)).is_equal_approx(Vector2(entrada.dados.canvas_logico[0],entrada.dados.canvas_logico[1])),"Canvas lógico: "+str(entrada.no.name))
		for ponto in [["praca",Vector2(336,275)],["quintal",Vector2(455,410)],["coreto",Vector2(548,300)],["horta",Vector2(160,455)],["piquenique",Vector2(600,460)]]:
			camera.global_position=ponto[1]
			await foto(ponto[0]+"-"+str(e))
	var fonte: Sprite2D=decoracao.get_node("fonte_anim_336_284/Imagem")
	conferir(fonte.hframes==1,"Estrutura da fonte separada da simulação")
	var agua_fonte=fonte.get_parent().get_node("AguaFonte")
	var quadro: PackedFloat32Array=agua_fonte.altura.duplicate()
	var passos: int=agua_fonte.passos
	var impactos: int=agua_fonte.impactos
	await create_timer(.85).timeout
	conferir(agua_fonte.passos>passos and agua_fonte.altura!=quadro,"Superfícies simuladas em tempo real")
	conferir(agua_fonte.impactos>impactos,"Jatos e gotas alimentam as ondas")
	var energia_superior:=0.0
	var energia_inferior:=0.0
	for i in agua_fonte.ativos:
		conferir(is_finite(agua_fonte.altura[i]),"Simulação estável")
		if i/96<27: energia_superior+=absf(agua_fonte.altura[i])
		else: energia_inferior+=absf(agua_fonte.altura[i])
	conferir(energia_superior>.01 and energia_inferior>.01,"As duas bacias têm ondas físicas")
	current_scene.get_node("Terrains/Estacoes").definir_estacao(0,true)
	await esperar(20)
	camera.global_position=Vector2(336,236)
	camera.zoom=Vector2(3,3)
	DirAccess.make_dir_recursive_absolute(pasta+"/fonte_movimento")
	for q in 16:
		await foto("fonte_movimento/%02d" % q)
		await create_timer(1.0/12.0).timeout
	camera.zoom=Vector2.ONE
	luz.hora=21.0
	luz._aplicar()
	camera.global_position=Vector2(336,275)
	await esperar(90)
	await foto("praca-noite")
	print("ENFEITES DETALHADOS: ",objetos.size()," objetos; 4 estações; ",falhas," falhas")
	quit(1 if falhas else 0)
