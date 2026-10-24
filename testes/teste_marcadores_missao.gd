extends SceneTree

var falhas := 0
func _initialize() -> void: rodar.call_deferred()
func quadros(n := 8) -> void:
	for i in n: await process_frame
func conferir(ok: bool, texto: String) -> void:
	if not ok:
		falhas += 1
		print("FALHA ",texto)
func foto(nome: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await quadros()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/algoland-missao-"+nome+".png")
func rodar() -> void:
	await process_frame
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"):
		quit(1)
		return
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1152,648)
	root.content_scale_size = Vector2i(576,324)
	root.get_node("Introducao").pular_prologo()
	var cidade := root.get_node("Cidade")
	cidade.apagar()
	root.get_node("Progresso").apagar()
	root.get_node("Transicao").hora_salva = 12
	change_scene_to_file("res://cenas/cidade.tscn")
	await quadros(35)
	current_scene.set_process(false)
	var jogador: Node2D = current_scene.get_node("Jogador")
	jogador.set_physics_process(false)
	jogador.position = Vector2(336,352)
	var lia: Node2D = current_scene.moradores.lia
	lia.set_physics_process(false)
	lia.position = jogador.position+Vector2(48,-24)
	lia.z_as_relative = false
	lia.z_index = load("res://codigo/globais/profundidade.gd").z_de(lia.position.y+9)
	lia.show()
	var marcador: Node2D = lia.get_node("IndicadorPedido")
	marcador._atualizar()
	conferir(marcador._circulo.get_theme_stylebox("panel") is StyleBoxFlat,"círculo preservado no marcador")
	conferir(marcador.position.length()<55,"marcador permanece junto ao NPC")
	conferir(is_equal_approx(marcador.position.x+9,0),"círculo centralizado sobre a cabeça")
	conferir(marcador.position.y+18<=9-float(load("res://codigo/cidade/dados_cidade.gd").geometria_sprite("lia").altura_mapa)-3,"círculo acima do topo da cabeça com margem")
	conferir(marcador.is_visible_in_tree() and marcador._rotulo.text=="!","missão disponível usa exclamação")
	await foto("disponivel")
	cidade.aceitar("boas_vindas")
	for id in ["mercador","curandeira","bardo","mistica","bento"]: cidade.conversas[id] = true
	cidade.alterado.emit()
	conferir(marcador.pronto and marcador._rotulo.text=="?" and marcador._rotulo.get_theme_color("font_color")==Color("ffe07a"),"entrega pronta usa interrogação amarela, com prioridade sobre outras ofertas")
	await foto("entregar")
	var fala: Label = lia.get("_balao")
	fala.size=Vector2(136,40)
	fala.position=Vector2(-68,-70)
	fala.show()
	marcador._process(0)
	conferir(is_equal_approx(marcador.position.x+9,0) and marcador.position.y+18<fala.position.y,"balão longo mantém o círculo centralizado acima da fala")
	conferir(not Rect2(lia.global_position+marcador.position,Vector2(18,18)).intersects(Rect2(lia.global_position+fala.position,fala.size)),"círculo não invade o balão de fala")
	fala.hide()
	for medida in [Vector2i(288,216),Vector2i(288,512),Vector2i(320,324)]:
		root.content_scale_size = medida
		root.size = medida*2
		await quadros()
		conferir(marcador._rotulo.size.x>=marcador._rotulo.get_minimum_size().x and marcador._rotulo.size.y>=marcador._rotulo.get_minimum_size().y,"símbolo cabe em "+str(medida))
		await foto("entregar-%dx%d" % [medida.x,medida.y])
	# Etapas bloqueadas por uma missão anterior não anunciam ofertas.
	var ivo: Node2D = current_scene.moradores.ferreiro
	ivo.get_node("IndicadorPedido")._atualizar()
	conferir(not ivo.get_node("IndicadorPedido").visible,"missão bloqueada não mostra exclamação")
	print("MARCADORES MISSAO: ",falhas," falhas")
	quit(1 if falhas else 0)
