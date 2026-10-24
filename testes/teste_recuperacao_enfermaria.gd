extends SceneTree
var falhas := 0
func _initialize() -> void: rodar.call_deferred()
func esperar(n := 15) -> void:
	for i in n: await process_frame
func verificar(ok: bool, mensagem: String) -> void:
	print("OK " if ok else "FALHA ",mensagem)
	if not ok: falhas += 1
func rodar() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"): quit(1); return
	await process_frame
	root.get_node("Introducao").pular_prologo()
	root.mode = Window.MODE_WINDOWED
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	root.content_scale_size = Vector2i(576,324)
	root.size = Vector2i(1152,648)
	root.get_node("Transicao").hora_salva = 23
	change_scene_to_file("res://cenas/cenario.tscn")
	await esperar(40)
	var jogador = current_scene.get_node("Jogador")
	jogador.receber_hitkill_chefe()
	await esperar()
	var tela = current_scene.get_node("Interface")._telas.fim_partida
	verificar(tela.visible and jogador.estaMorto,"morte real abre a confirmacao")
	tela._botao_voltar.pressed.emit()
	var transicao = root.get_node("Transicao")
	for i in 900:
		await process_frame
		if not transicao.ocupada and current_scene.scene_file_path == transicao.ENFERMARIA: break
	verificar(current_scene.scene_file_path == transicao.ENFERMARIA,"retorno chega a enfermaria")
	if current_scene.scene_file_path != transicao.ENFERMARIA: quit(1); return
	jogador = current_scene.get_node("Jogador")
	var dialogo = root.get_node("EventosJogo").interface_p1()._telas.introducao
	for i in 180:
		await process_frame
		if dialogo.visible: break
	verificar(dialogo.visible,"Rosa inicia a conversa")
	verificar(not jogador.estaMorto and jogador.hp_atual > 0,"jogador recuperado")
	verificar(jogador.esta_sentado and not jogador.visible,"paciente permanece no leito")
	verificar(jogador.position.distance_to(current_scene.LEITO_FERIDO) < 30,"posicao usa escala logica da cama")
	var rosa = current_scene.moradores.curandeira
	verificar(rosa.visible and not rosa.dormindo and rosa.cuidando_de_paciente,"Rosa acorda para atender")
	await esperar(20)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/algoland-enfermaria-recuperacao.png")
	if dialogo.visible: dialogo._fechar_fala()
	for i in 180:
		await process_frame
		if jogador.movimento_habilitado and jogador.visible and not jogador.esta_sentado and jogador.is_physics_processing(): break
	verificar(jogador.visible and jogador.movimento_habilitado and jogador.is_physics_processing() and not jogador.esta_sentado,"conversa devolve visibilidade e movimento")
	verificar(not rosa.cuidando_de_paciente,"Rosa retoma a rotina")
	verificar(jogador.position.is_equal_approx(current_scene.LEITO_FERIDO + Vector2(0,26)),"jogador levanta ao pe do leito")
	var colisao: KinematicCollision2D = jogador.move_and_collide(Vector2(0,8),true)
	verificar(colisao == null,"saida do leito livre")
	print("RECUPERACAO ENFERMARIA: ",falhas," falhas")
	quit(1 if falhas else 0)
