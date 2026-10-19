extends SceneTree
## Previa real do veio em cada estacao. Exige projeto com saves isolados.
func _initialize() -> void: rodar.call_deferred()
func quadros(n := 10) -> void:
	for i in n:
		await physics_frame
		await process_frame
func foto(nome: String) -> void:
	await quadros()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://arte/previas/mineracao_arena/"+nome+".png")
func rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name","")).begins_with("AlgoLand testes"):
		push_error("Use o projeto de testes com saves isolados.")
		quit(1)
		return
	await process_frame
	root.get_node("Saves").trocar("solo")
	root.get_node("Introducao").pular_prologo()
	root.get_node("Progresso").apagar()
	preload("res://codigo/globais/opcoes_jogo.gd").fechar_mini_tutorial()
	var inv=root.get_node("InventarioJogador")
	inv.limpar()
	inv.criar_itens_iniciais()
	root.get_node("Transicao").limpar()
	root.content_scale_size=Vector2i(576,324)
	change_scene_to_file("res://cenas/cenario.tscn")
	await quadros(35)
	var gerenciador=current_scene.get_node("enemySpawner/GerenciadorOndas")
	gerenciador.parar_ondas()
	gerenciador.onda_atual=6
	gerenciador.atualizar_ui()
	get_first_node_in_group("hud_p1").rotulo_onda.text="ONDA %d" % gerenciador.onda_atual
	var mineracao=current_scene.get_node("MineracaoArena")
	await mineracao.preparar_onda(6)
	await quadros()
	if mineracao._veios.is_empty(): quit(1); return
	var veio: Node2D=mineracao._veios.values()[0]
	var jogador=current_scene.get_node("Jogador")
	jogador.set_physics_process(false)
	jogador.global_position=veio.global_position-Vector2(0,31)
	jogador._direcao_ataque=Vector2.DOWN
	jogador.z_index=preload("res://codigo/globais/profundidade.gd").z_de(jogador.global_position.y+11)
	jogador.camera.position_smoothing_enabled=false
	jogador.camera.reset_smoothing()
	var barra=get_first_node_in_group("hud_p1").barra_armas
	var indice: int=inv.indice_de(inv.buscar_por_tipo("picareta"))
	barra.escolher(indice)
	for clima in get_nodes_in_group("clima"): clima.definir_clima(0,true)
	var luz=current_scene.get_node("Iluminacao")
	luz.set_process(false)
	luz.definir_hora(12)
	luz._aplicar()
	var estacoes=current_scene.get_node("Terrains/Estacoes")
	DirAccess.make_dir_recursive_absolute("res://arte/previas/mineracao_arena")
	for estacao in 4:
		estacoes.definir_estacao(estacao,true)
		await foto(mineracao.ESTACOES[estacao])
		print("ESTACAO ",estacao," textura=",veio.get_node("Pedra").texture.resource_path)
	estacoes.definir_estacao(0,true)
	await quadros()
	mineracao.pedir_golpe(jogador)
	await create_timer(0.16).timeout
	await foto("minerando")
	current_scene.queue_free()
	current_scene=null
	await quadros()
	quit()
