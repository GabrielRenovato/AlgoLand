extends SceneTree

## Prévia e margens da tela inicial; não entra na partida nem altera seus saves.
var falhas := 0
func _initialize() -> void: rodar.call_deferred()
func quadros(n := 10) -> void:
	for i in n:
		await process_frame
		await physics_frame
func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ",nome)
	if not ok: falhas += 1
func foto(nome: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var prefixo := "antes" if "--antes" in OS.get_cmdline_user_args() else ("com-save" if "--com-save" in OS.get_cmdline_user_args() else "depois")
	root.get_texture().get_image().save_png("/tmp/algoland-inicio-%s-%s.png" % [prefixo,nome])
func rodar() -> void:
	await process_frame
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"): quit(1); return
	if "--com-save" in OS.get_cmdline_user_args():
		var arquivo := FileAccess.open("user://configuracao_jogador.json",FileAccess.WRITE)
		arquivo.store_string("{}")
		arquivo.close()
		arquivo = null
	change_scene_to_file("res://cenas/inicio_do_jogo.tscn")
	await quadros(40)
	root.mode = Window.MODE_WINDOWED
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	var inicio = current_scene
	var raiz: Control = inicio.get_node("Interface/Raiz")
	for tamanho in [Vector2i(576,324),Vector2i(720,324),Vector2i(480,270),Vector2i(288,216),Vector2i(288,512),Vector2i(320,324)]:
		root.content_scale_size = tamanho
		root.size = tamanho*2
		await quadros(15)
		verificar("menu dentro das margens %s" % str(tamanho), Rect2(Vector2.ZERO,raiz.size).grow(-12).encloses(inicio._menu_painel.get_global_rect()))
		verificar("logo separado do menu %s" % str(tamanho),inicio._logo.get_global_rect().end.y+4 <= inicio.menu.get_global_rect().position.y)
		verificar("logo dentro da moldura %s" % str(tamanho),inicio._menu_painel.get_global_rect().grow(-10).encloses(inicio._logo.get_global_rect()))
		for botao: Button in inicio.menu.get_children():
			if not botao.visible: continue
			var texto := botao.get_theme_font("font").get_string_size(botao.text,HORIZONTAL_ALIGNMENT_LEFT,-1,botao.get_theme_font_size("font_size"))
			var margens := botao.get_theme_stylebox("normal").get_minimum_size()
			verificar("texto cabe: %s %s" % [botao.text,str(tamanho)],texto.x + margens.x <= botao.size.x+1 and texto.y + margens.y <= botao.size.y+1)
		verificar("todos os botoes visiveis sem corte %s" % str(tamanho),inicio._rolagem_menu.get_global_rect().grow(1).encloses(inicio.menu.get_global_rect()))
		await foto("%dx%d" % [tamanho.x,tamanho.y])
		for par in [[inicio.botao_opcoes,inicio.painel_opcoes,"opcoes"],[inicio.botao_creditos,inicio.painel_creditos,"creditos"],[inicio._botao_coop,inicio._moldura_coop,"coop"],[inicio.botao_novo_jogo,inicio.confirmar_novo_jogo,"confirmacao"]]:
			if par[2] == "confirmacao":
				inicio._abrir_painel(inicio.confirmar_novo_jogo,inicio.botao_novo_jogo,inicio.botao_nao)
			else:
				par[0].pressed.emit()
			await quadros()
			verificar("painel %s cabe %s" % [par[2],str(tamanho)],Rect2(Vector2.ZERO,raiz.size).grow(-8).encloses(par[1].get_global_rect()))
			if par[2] == "confirmacao":
				var conteudo: Control = inicio._rolagens_paineis[inicio.confirmar_novo_jogo]
				var area: Rect2 = conteudo.get_parent().get_global_rect()
				for botao: Button in [inicio.botao_sim,inicio.botao_nao]:
					verificar("confirmacao sem corte: %s %s" % [botao.text,tamanho],area.encloses(botao.get_global_rect()))
					var texto := botao.get_theme_font("font").get_string_size(botao.text,HORIZONTAL_ALIGNMENT_LEFT,-1,botao.get_theme_font_size("font_size"))
					var folga := botao.get_theme_stylebox("normal").get_minimum_size()
					verificar("texto e margens da confirmacao: %s %s" % [botao.text,tamanho],texto.x+folga.x <= botao.size.x+1 and texto.y+folga.y <= botao.size.y+1)
				verificar("pergunta sem corte %s" % tamanho,area.encloses(conteudo.get_node("Pergunta").get_global_rect()))
				await foto("confirmacao-%dx%d" % [tamanho.x,tamanho.y])
			if tamanho == Vector2i(576,324) or tamanho == Vector2i(288,216): await foto("%s-%dx%d" % [par[2],tamanho.x,tamanho.y])
			inicio._fechar_painel()
			await quadros(3)
	current_scene.queue_free()
	current_scene = null
	await quadros()
	print("INICIO DETALHADO: ",falhas," falhas")
	quit(1 if falhas else 0)
