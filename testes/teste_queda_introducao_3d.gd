extends SceneTree
## Executa a queda real com tempos reais, sem avançar os diálogos nem afetar saves externos.
var falhas := 0
func _initialize() -> void: rodar.call_deferred()
func conferir(ok: bool, texto: String) -> void:
	print("OK " if ok else "FALHA ",texto)
	if not ok: falhas += 1
func rodar() -> void:
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1152,648)
	root.get_node("Ranking").conexao_habilitada = false
	root.get_node("Progresso").apagar()
	root.get_node("Transicao").limpar()
	var intro = root.get_node("Introducao")
	intro.iniciar()
	root.get_node("InventarioJogador").criar_itens_iniciais(true)
	change_scene_to_file("res://cenas/cenario.tscn")
	var fases := {}
	var desceu := false
	var subiu := false
	for i in 200:
		await process_frame
		if current_scene==null: continue
		var sequencia := current_scene.get_node_or_null("SequenciaIntroducao")
		var jogador := current_scene.get_node_or_null("Jogador")
		if sequencia==null or jogador==null: continue
		var heroi = jogador.get_node("HeroiBase3D")
		fases[sequencia.reacao_queda] = true
		if heroi.position.y < -20: subiu = true
		if subiu and heroi.position.y>9: desceu = true
		if i in [10,25,45,65,85]:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/migracao-3d-queda-%03d.png"%i)
		if sequencia.reacao_queda=="PRONTO":
			conferir(heroi.is_processing(),"Animação normal é retomada após aterrissar")
			break
	conferir(subiu and desceu,"Modelo 3D desce do alto até o apoio dos pés")
	conferir(["CAINDO","IMPACTO","RECUPERANDO","PRONTO"].all(func(fase): return fases.has(fase)),"Queda real percorre suspensão, impacto e recuperação")
	print("QUEDA INTRODUCAO 3D: ",falhas," falhas")
	current_scene.queue_free()
	current_scene = null
	for i in 8: await process_frame
	quit(1 if falhas else 0)
