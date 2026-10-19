extends "res://testes/teste_rolagem_mural.gd"

const Opcoes := preload("res://codigo/globais/opcoes_jogo.gd")

func conferir(jogador: Node2D, nome: String) -> void:
	var agenda: Node = root.get_node("AgendaVila")
	agenda.enviar_pombo(jogador,"horta")
	await quadros(6)
	var lado := "hud_p2" if jogador.eh_p2 else "hud_p1"
	var hud: Node = get_first_node_in_group(lado)
	var faixa: Control = hud.faixa_banner
	var inicio := faixa.position
	var estavel := true
	var dentro := true
	for i in 60:
		await process_frame
		estavel = estavel and faixa.position.is_equal_approx(inicio)
		var area: Rect2 = faixa.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,faixa.size)
		dentro = dentro and faixa.get_viewport_rect().grow(1).encloses(area)
	verificar("pombo anuncia a carta: " + nome,hud.rotulo_banner.text == "POMBO-CORREIO!" and faixa.visible)
	verificar("aviso permanece parado: " + nome,estavel)
	verificar("aviso permanece dentro da tela: " + nome,dentro)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/algoland-banner-pombo-"+nome+".png")

func escala(valor: float, lado := 1) -> void:
	var opcoes := Opcoes.carregar(lado)
	opcoes.escala_interface = valor
	Opcoes.aplicar(opcoes,lado)
	await quadros(6)

func rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"):
		quit(1)
		return
	await process_frame
	root.mode = Window.MODE_WINDOWED
	root.get_node("Saves").trocar("solo")
	root.get_node("Introducao").pular_prologo()
	root.content_scale_size = Vector2i(576,324)
	root.size = Vector2i(1152,648)
	change_scene_to_file("res://cenas/praia.tscn")
	await quadros(20)
	for valor in [0.75,1.0,1.25,1.5]:
		await escala(valor)
		await conferir(current_scene.get_node("Jogador"),"desktop_%d" % roundi(valor*100))
	root.get_node("Controle").usando_toque = true
	root.content_scale_size = Vector2i(288,216)
	await escala(1.0)
	await conferir(current_scene.get_node("Jogador"),"toque")
	# Reorganizar um aviso aberto também não pode introduzir movimento acumulado.
	root.content_scale_size = Vector2i(576,324)
	await conferir(current_scene.get_node("Jogador"),"redimensionado")
	root.get_node("Saves").trocar("coop")
	root.get_node("Introducao").pular_prologo()
	root.get_node("Controle").usando_toque = false
	root.content_scale_size = Vector2i(1152,648)
	change_scene_to_file("res://cenas/praia.tscn")
	await quadros(20)
	await escala(0.75,1)
	await escala(1.5,2)
	var coop: Node = root.get_node("Cooperativo")
	await conferir(coop._jogador1(),"coop_p1")
	await conferir(coop.jogador2(),"coop_p2")
	current_scene.queue_free()
	await quadros()
	print("Banner pombo: %d falhas" % falhas)
	quit(1 if falhas else 0)
