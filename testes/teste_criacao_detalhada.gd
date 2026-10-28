extends SceneTree

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
	root.get_texture().get_image().save_png("/tmp/algoland-criacao-%s.png" % nome)
func rodar() -> void:
	await process_frame
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"): quit(1); return
	root.mode = Window.MODE_WINDOWED
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	root.content_scale_size = Vector2i(576,324)
	root.size = Vector2i(1152,648)
	var tela = load("res://codigo/ui/tela_criacao_personagem.gd").new()
	tela.trocar_cena = false
	tela.caminho_save = "user://criacao_detalhada_teste.json"
	root.add_child(tela)
	current_scene = tela
	await quadros(40)
	tela._escolher_peca_3d("cabelo", "cabelo_cacheado")
	tela._escolher_peca_3d("camisa", "blusa_bufante")
	tela._botoes_pele[1].pressed.emit()
	tela._casas_cor[6].pressed.emit()
	tela._campo_nome.text = "AVENTUREIROX"
	var direcao_inicial: int = tela._direcao
	for i in 180: tela._process(1.0/60.0)
	verificar("previa nao gira automaticamente",tela._direcao == direcao_inicial)
	tela._girar(1)
	verificar("setas continuam girando a previa",tela._direcao == posmod(direcao_inicial+1,4))
	tela._girar(-1)
	for tamanho in [Vector2i(576,324),Vector2i(480,270),Vector2i(288,216),Vector2i(288,512),Vector2i(320,324)]:
		root.content_scale_size = tamanho
		root.size = tamanho*2
		await quadros(15)
		verificar("paineis sem corte vertical",Rect2(Vector2.ZERO,tela.size).grow(-6).encloses(tela._painel_edicao.get_global_rect()) and Rect2(Vector2.ZERO,tela.size).grow(-6).encloses(tela._painel_previa.get_global_rect()))
		verificar("criacao sem corte horizontal %s" % str(tamanho), tela._colunas.size.x <= tela.size.x-16)
		for aba in 3:
			tela._abrir_aba(aba)
			await quadros()
			verificar("conteudo afastado da moldura %d %s" % [aba,str(tamanho)],tela._painel_edicao.get_global_rect().grow(-6).encloses(tela._linhas_edicao.get_global_rect()))
			verificar("campo nome cabe %d %s" % [aba,str(tamanho)],tela._campo_nome.size.x >= tela._campo_nome.get_minimum_size().x)
			for botao in [tela._botao_voltar,tela._botao_aleatorio,tela._botao_confirmar]+tela._botoes_aba:
				var texto: Vector2 = botao.get_theme_font("font").get_string_size(botao.text,HORIZONTAL_ALIGNMENT_LEFT,-1,botao.get_theme_font_size("font_size"))
				verificar("rotulo cabe %s %s" % [botao.text,str(tamanho)],texto.x+botao.get_theme_stylebox("normal").get_minimum_size().x <= botao.size.x+1)
			if tamanho == Vector2i(576,324): await foto("pc-"+str(aba))
			if tamanho == Vector2i(288,512):
				await quadros()
				await foto("celular-"+str(aba))
			verificar("pagina cabe no conteudo",tela._conteudo.get_global_rect().grow(1).encloses(tela._paginas[aba].get_global_rect()))
			for botao in [tela._botao_voltar,tela._botao_confirmar]:
				verificar("rodape sempre visivel",Rect2(Vector2.ZERO,tela.size).grow(-6).encloses(botao.get_global_rect()))
			for botao: Button in tela._botoes_estrutura:
				if botao.icon != null:
					verificar("seta cabe dentro da moldura",botao.get_theme_constant("icon_max_width") <= minf(botao.size.x,botao.size.y)-8)
			if tamanho == Vector2i(288,216):
				tela._botao_confirmar.grab_focus()
				await quadros()
				await foto("compacto-"+str(aba))
				tela._botoes_aba[aba].grab_focus()
	tela._ao_nome_alterado("AVENTUREIROX")
	tela.confirmar()
	var dados: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(tela.caminho_save))
	verificar("confirmacao preserva escolhas e nome",dados.apelido == "AVENTUREIROX" and dados.roupas_3d.cabelo == "cabelo_cacheado" and dados.roupas_3d.camisa == "blusa_bufante" and dados.aparencia_raven.pele == 1)
	current_scene = null
	tela.queue_free()
	await quadros()
	print("CRIACAO DETALHADA: ",falhas," falhas")
	quit(1 if falhas else 0)
