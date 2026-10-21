extends SceneTree
const Profundidade := preload("res://codigo/globais/profundidade.gd")
var falhas:=0
func _initialize() -> void:rodar.call_deferred()
func esperar(n:=4) -> void:
	for i in n:await process_frame
func verificar(ok: bool, mensagem: String) -> void:
	if not ok:
		falhas+=1
		push_error(mensagem)
func rodar() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"):
		quit(1)
		return
	root.get_node("Introducao").pular_prologo()
	root.get_node("Transicao").hora_salva=12.0
	change_scene_to_file("res://cenas/cidade.tscn")
	await esperar(25)
	root.get_node("Transicao").limpar()
	var vila: Node2D=current_scene
	var jogador: CharacterBody2D=vila.get_node("Jogador")
	jogador.set_physics_process(false)
	for morador in vila.moradores.values():
		morador.set_physics_process(false)
	vila.apoio_helena.set_physics_process(false)
	var helena: CharacterBody2D = vila.moradores["helena"]
	helena.collision_mask = 64
	var ponte: Node2D = vila.find_child("ponte_676_298", true, false)
	verificar(ponte != null, "Ponte detalhada integrada ao layout")
	if ponte == null:
		quit(1)
		return
	verificar(ponte.get_node("Apoios").z_index < ponte.get_node("Piso").z_index, "Apoios ficam sob o piso")
	verificar(ponte.get_node("CorrimaoNorte").z_index < Profundidade.z_de(275), "Corrimão norte atrás de quem atravessa")
	verificar(ponte.get_node("CorrimaoSul").z_index > Profundidade.z_de(281) + 6, "Corrimão sul cobre todas as camadas do personagem")
	verificar(ponte.get_node("CorrimaoSul").z_index < Profundidade.z_de(304), "Personagem na margem sul passa à frente")
	jogador.aparencia_raven={"versao":1,"pele":0,"roupa":1,"cabelo":1,"cor":[0.25,0.3,0.4,1.0]}
	jogador.collision_mask=64
	DirAccess.make_dir_recursive_absolute("/tmp/algoland-ponte-cidade")
	var vp:=SubViewport.new()
	vp.size=Vector2i(720,400)
	vp.world_2d=vila.get_world_2d()
	vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var camera:=Camera2D.new()
	camera.position=Vector2(676,276)
	camera.zoom=Vector2(4,4)
	vp.add_child(camera)
	camera.make_current()
	for e in 4:
		root.get_node("Calendario").dia=1+e*28
		vila.get_node("Terrains/Estacoes").definir_estacao(e, true)
		vila._aplicar_terreno(e)
		await esperar(3)
		for camada in ["Piso", "Apoios", "CorrimaoNorte", "CorrimaoSul"]:
			var imagem: Sprite2D = ponte.get_node(camada + "/Imagem")
			verificar(imagem.texture.resource_path.contains(["primavera", "verao", "outono", "inverno"][e]), "Camada acompanha estação visual: " + camada)
		jogador.position=Vector2(628,264)
		var leste:=jogador.move_and_collide(Vector2(96,0))
		verificar(leste==null,"Travessia oeste-leste livre")
		var oeste:=jogador.move_and_collide(Vector2(-96,0))
		verificar(oeste==null,"Travessia leste-oeste livre")
		jogador.position=Vector2(676,264)
		var sul:=jogador.move_and_collide(Vector2(0,70))
		verificar(sul!=null and jogador.position.y+11<=285.1,"Beirada sul segura os pés sobre o piso")
		jogador.position=Vector2(676,264)
		var norte:=jogador.move_and_collide(Vector2(0,-70))
		verificar(norte!=null and jogador.position.y+11>=267.9,"Beirada norte segura os pés sobre o piso")
		# As pontas dos corrimãos estão em terra; não podem depender da colisão
		# do rio, senão seria possível atravessar os postes pelas cabeceiras.
		for x in [640, 712]:
			jogador.position = Vector2(x, 264)
			verificar(jogador.move_and_collide(Vector2(0, 70)) != null and jogador.position.y + 11 <= 288, "Corrimão sul bloqueia na cabeceira %d" % x)
			jogador.position = Vector2(x, 264)
			verificar(jogador.move_and_collide(Vector2(0, -70)) != null and jogador.position.y + 11 >= 261, "Corrimão norte bloqueia na cabeceira %d" % x)
		helena.position = Vector2(628, 264)
		verificar(helena.move_and_collide(Vector2(96, 0)) == null, "Cadeira real atravessa oeste-leste")
		verificar(helena.move_and_collide(Vector2(-96, 0)) == null, "Cadeira real atravessa leste-oeste")
		var rota: PackedVector2Array=vila.caminho_entre(Vector2(628,264),Vector2(724,264),vila._navegacao_cadeira)
		verificar(not rota.is_empty() and rota[-1].distance_to(Vector2(724,264))<24,"Navegação da cadeira atravessa a ponte")
		jogador.position=Vector2(676,270)
		jogador.z_index = Profundidade.z_de(jogador.position.y + 11)
		jogador._direcao_ataque=Vector2.DOWN
		jogador.get_node("HeroiRaven")._process(0.0)
		await esperar(3)
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png("/tmp/algoland-ponte-cidade/estacao_%d.png" % e)
	# Também testa a prévia F3 sem mudar o calendário: a estação visual manda.
	vila.get_node("Terrains/Estacoes").definir_estacao(0, true)
	vila._aplicar_terreno(0)
	await esperar(3)
	verificar(ponte.get_node("Piso/Imagem").texture.resource_path.contains("primavera"), "Prévia visual prevalece sobre calendário de inverno")
	for pose in [{"nome":"atras_norte", "ponto":Vector2(640, 243)}, {"nome":"na_ponte", "ponto":Vector2(676, 264)}, {"nome":"frente_sul", "ponto":Vector2(640, 295)}]:
		jogador.position = pose.ponto
		jogador.z_index = Profundidade.z_de(jogador.position.y + 11)
		await esperar(3)
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png("/tmp/algoland-ponte-cidade/%s.png" % pose.nome)
	jogador.position = Vector2(676, 264)
	jogador.z_index = Profundidade.z_de(275)
	vp.size = Vector2i(960, 576)
	camera.zoom = Vector2(2, 2)
	await esperar(3)
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png("/tmp/algoland-ponte-cidade/vista_geral.png")
	print("PONTE: ",falhas," falhas; travessia, cabeceiras, profundidade, cadeira física, navegação, prévia e quatro estações.")
	quit(1 if falhas else 0)
