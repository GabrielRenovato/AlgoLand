extends SceneTree

## Regressão da moldura vazia que crescia para fora da tela ao conversar com Orion.
var falhas := 0

func _initialize() -> void: rodar.call_deferred()

func quadros(n := 12) -> void:
	for i in n:
		await process_frame
		await physics_frame

func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ", nome)
	if not ok: falhas += 1

func foto(nome: String) -> void:
	if DisplayServer.get_name() == "headless" or not "--capturar" in OS.get_cmdline_user_args(): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/algoland-guia-" + nome + ".png")

func rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"):
		quit(1)
		return
	await process_frame
	root.get_node("Introducao").pular_prologo()
	root.get_node("Progresso").iniciar_partida()
	root.get_node("Transicao").limpar()
	change_scene_to_file("res://cenas/fendas/andar_01.tscn")
	await quadros(20)
	var jogador: Node2D = current_scene.get_node("Jogador")
	jogador.set_physics_process(false)
	var gerente: Node = current_scene.get_node("enemySpawner/GerenciadorOndas")
	gerente.etapa = gerente.Etapa.CONCLUIDO
	gerente.onda_atual = 2
	await gerente._abrir_janela_entre_ondas()
	var ui: Node = current_scene.get_node("Interface")
	var loja: Control = ui._telas["mercante"]
	for tamanho in [Vector2i(576,324), Vector2i(288,216)]:
		root.content_scale_size = tamanho
		root.size = tamanho * 2
		await quadros(20)
		for abertura in 2:
			gerente.guia.interacao.abrir_tela()
			await quadros(40)
			var painel: Control = loja.get_node("Painel")
			var limite := Rect2(Vector2.ZERO, Vector2(tamanho)).grow(-7*preload("res://codigo/ui/escala_interface.gd").fator(ui))
			verificar("conversa abre melhorias " + str(tamanho), loja.is_visible_in_tree() and loja._conversa_guia.is_visible_in_tree())
			verificar("moldura cabe na tela " + str(tamanho), limite.encloses(painel.get_global_transform_with_canvas() * Rect2(Vector2.ZERO,painel.size)))
			verificar("titulo e fechar ficam acessiveis " + str(tamanho), painel.get_global_rect().encloses(loja.get_node("Painel/Linhas/Cabecalho").get_global_rect()))
			verificar("conteudo visivel dentro da moldura " + str(tamanho), painel.get_global_rect().encloses(loja._conversa_guia.get_global_rect()))
			var abas := [loja._aba_loja, loja._aba_bigorna, loja._aba_encantar]
			verificar("saque removido dos servicos", loja.find_child("AbaSaque", true, false) == null)
			verificar("abas tem medidas iguais " + str(tamanho), abas.all(func(b): return b.size.is_equal_approx(abas[0].size)))
			var casas: Array = loja._botoes_loja["totens"]
			verificar("melhorias em duas linhas de tres casas quadradas", loja._grade_itens.columns == 3 and casas.size() == 6 and casas.all(func(b): return is_equal_approx(b.size.x,b.size.y)))
			verificar("botoes do rodape tem largura igual", absf(loja._botao_cidade.size.x-loja._botao_proxima.size.x)<=1.0)
			verificar("avanco permanece visivel na tela pequena", painel.get_global_rect().encloses(loja._linha_arena.get_global_rect()))
			await foto("conversa_" + str(tamanho.x))
			ui._fechar_tela("mercante")
			await quadros()
			verificar("fechar recolhe conversa e mochila", not loja.is_visible_in_tree() and not ui._telas["inventario"].visible)
	root.content_scale_size = Vector2i(576,324)
	root.size = Vector2i(1152,648)
	var camera := Camera2D.new()
	current_scene.add_child(camera)
	camera.zoom = Vector2(3,3)
	camera.global_position = gerente.guia.global_position - Vector2(0,10)
	camera.make_current()
	for direcao in [Vector2.DOWN, Vector2.RIGHT, Vector2.UP, Vector2.LEFT]:
		jogador.global_position = gerente.guia.global_position + direcao*30
		await quadros()
		await foto("roupa_" + str(int(gerente.guia.sprite.frame/7)))
	current_scene.queue_free()
	await quadros()
	print("Dialogo guia: %d falhas" % falhas)
	quit(1 if falhas else 0)
