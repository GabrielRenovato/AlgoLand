extends SceneTree
## Escolhe o andar 50 no mapa do portal (como o jogador), confere ouro e entrada,
## atravessa o portal e confere o andar 50 com o jogador visível. Save isolado.
const SAIDA := "res://arte/previas/checkpoints/"
var falhas := 0
func conferir(ok: bool, texto: String) -> void:
	print(("OK   " if ok else "FALHA ") + texto)
	if not ok: falhas += 1
func _initialize(): rodar.call_deferred()
func rodar():
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	assert(DisplayServer.get_name() != "headless")
	var P = root.get_node("Progresso")
	var dados = root.get_node("DadosJogo")
	root.get_node("Introducao").pular_prologo()
	P.partida_ativa = false
	P.maior_onda_vencida = 49
	P.recorde_onda = 50
	root.get_node("Transicao").limpar()
	change_scene_to_file("res://cenas/cidade.tscn")
	for i in 60: await process_frame
	var jogador = current_scene.get_node("Jogador")
	dados.moedas = 100
	conferir(P.partida_ativa and P.pode_escolher_checkpoint(), "cidade abriu partida que ainda aceita checkpoint")
	root.get_node("EventosJogo").abrir_tela_de(jogador, "desafio_arena")
	for i in 10: await process_frame
	var mapa = null
	for no in root.find_children("MapaJornada", "", true, false):
		if no.is_visible_in_tree(): mapa = no
	conferir(mapa != null and mapa.escolher_checkpoint, "mapa do portal permite escolher")
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA))
	mapa._pagina = 4
	mapa._preencher()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(SAIDA+"mapa_antes.png")
	mapa._pagina = 4
	mapa._preencher()
	await process_frame
	var marco: Button = mapa._marcos.get(50)
	conferir(marco != null, "andar 50 aparece no mapa")
	marco.pressed.emit()
	for i in 10: await process_frame
	var esperado: int = P.ouro_checkpoint(50)
	conferir(P.onda_inicial == 50 and dados.moedas == 100 + esperado, "andar 50 escolhido, ouro %d (+%d)" % [dados.moedas, esperado])
	conferir(esperado < P.ouro_estimado_ate(50), "ouro menor que jogar desde o 1")
	var tela = null
	for no in root.find_children("*", "", true, false):
		if no.get("modo_desafio") == true and no.is_visible_in_tree(): tela = no
	conferir(tela != null and tela._entrada_portal.text.ends_with("ANDAR 50"), "botao do portal diz ANDAR 50 (%s)" % (tela._entrada_portal.text if tela else "-"))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(SAIDA+"mapa_andar_50.png")
	print("PASSO entrando")
	root.get_node("Transicao").entrar_na_arena()
	var T = root.get_node("Transicao")
	for i in 900:
		await process_frame
		if i % 100 == 0: print("PASSO ", i, " ", current_scene.scene_file_path if current_scene else "-", " ocupada=", T.ocupada)
		if current_scene != null and current_scene.scene_file_path.contains("fendas/andar_") and not T.ocupada: break
	for i in 90: await process_frame
	var g = get_first_node_in_group("gerenciador_ondas")
	conferir(g != null and g.onda_atual == 50, "entrou no andar 50 (onda_atual=%s, cena=%s)" % [g.onda_atual if g else -1, current_scene.scene_file_path])
	var j = current_scene.get_node_or_null("Jogador")
	conferir(j != null and j.get_node("HeroiRaven").is_visible_in_tree(), "jogador visivel no andar")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(SAIDA+"andar_50.png")
	print("CHECKPOINT MAPA: %d falhas" % falhas)
	quit()
