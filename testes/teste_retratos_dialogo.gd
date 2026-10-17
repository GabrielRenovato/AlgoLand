extends SceneTree

var falhas := 0

func _initialize() -> void:
	_rodar.call_deferred()

func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ",nome)
	if not ok:
		falhas += 1

func quadros(n := 4) -> void:
	for i in n:
		await process_frame

func foto(nome: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://arte/previas/dialogos/%s.png" % nome)

func _rodar() -> void:
	if not String(ProjectSettings.get_setting("application/config/custom_user_dir_name","")).begins_with("AlgoLand testes"):
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://arte/previas/dialogos"))
	var manifesto: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://arte/fontes/npcs/retratos/geracao.json"))
	for nome in manifesto["personagens"]:
		var folha: Texture2D = load("res://assets/npcs/retratos/%s.png" % nome)
		var imagem := folha.get_image()
		var boca: Array = manifesto["personagens"][nome]["boca"]
		var recorte := Rect2i(boca[0],boca[1],boca[2],boca[3])
		var alterados := 0
		var fora := 0
		for y in 128:
			for x in 128:
				if (imagem.get_pixel(x,y).a > 0 or imagem.get_pixel(x+128,y).a > 0) and imagem.get_pixel(x,y) != imagem.get_pixel(x+128,y):
					alterados += 1
					if not recorte.has_point(Vector2i(x,y)):
						fora += 1
		verificar(nome+": boca muda sem tremer o retrato",alterados > 0 and fora == 0)
		verificar(nome+": grade e transparência corretas",imagem.get_size() == Vector2i(256,128) and imagem.get_pixel(0,0).a == 0)
	root.get_node("Introducao").pular_prologo()
	change_scene_to_file("res://cenas/cidade.tscn")
	await quadros(40)
	current_scene.get_node("Iluminacao").definir_hora(12)
	current_scene.get_node("Iluminacao").set_process(false)
	var cidade: Node = root.get_node("Cidade")
	var jogador: Node = current_scene.get_node("Jogador")
	var interface: Node = current_scene.get_node("Interface")
	var tela: Control = interface._telas["conversa_cidade"]
	cidade.conversar("mercador",jogador)
	await quadros(5)
	tela._falar("Que bom encontrar voce por aqui! A vila esta cheia de historias e hoje trouxe sementes novas para a primavera. Depois da pesca, passe na pousada e converse com nossos vizinhos. Sempre ha alguma novidade esperando por voce na proxima esquina.".repeat(3))
	var poses := {}
	for i in 8:
		await create_timer(0.09).timeout
		poses[tela._retrato.quadro] = true
		await foto("fala_%d" % i)
	verificar("boca anima enquanto as letras aparecem",poses.size() == 2 and tela._retrato.falando)
	tela._avancar_fala()
	await quadros(3)
	verificar("completar o texto para a boca",tela._fala.visible_ratio == 1 and not tela._retrato.falando and tela._retrato.quadro == 0)
	verificar("fala longa dividida em páginas",tela._paginas.size() > 1)
	var pagina_anterior: int = tela._pagina
	tela._avancar_fala()
	await create_timer(0.14).timeout
	verificar("próxima página retoma a fala",tela._pagina == pagina_anterior+1 and tela._retrato.falando)
	interface._fechar_tela("conversa_cidade")
	await quadros(3)
	verificar("fechar para a boca e libera movimento",not tela._retrato.falando and tela._retrato.quadro == 0 and jogador.movimento_habilitado)
	for id in current_scene.moradores:
		cidade.conversar(id,jogador)
		await quadros(4)
		tela._avancar_fala()
		await quadros(3)
		await foto(id)
		interface._fechar_tela("conversa_cidade")
		await quadros(3)
	cidade.conversar("bardo",jogador)
	await quadros(4)
	tela._avancar_fala()
	while tela._pagina+1 < tela._paginas.size():
		tela._avancar_fala()
		tela._avancar_fala()
	tela._avancar_fala()
	await quadros(5)
	verificar("respostas aparecem após leitura",tela._menu_assuntos.visible)
	await foto("respostas")
	root.get_node("Progresso").refeicao = ""
	tela._abrir_submenu("cozinha")
	await quadros(5)
	verificar("cardápio longo tem rolagem e ações acessíveis",tela._menu_assuntos.visible and tela._botoes.size() >= 10 and tela._rolagem.follow_focus)
	await foto("cozinha")
	interface._fechar_tela("conversa_cidade")
	tela.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	tela.size = Vector2(240,270)
	await quadros(6)
	cidade.conversar("lia",jogador)
	await quadros(4)
	var dentro := Rect2(Vector2.ZERO,tela.size)
	verificar("fala cabe na vista de 240 px",dentro.encloses(tela.painel.get_global_rect()) and (not tela._fala.visible or tela.painel.get_global_rect().encloses(tela._fala.get_global_rect())))
	tela._avancar_fala()
	await create_timer(0.3).timeout
	await foto("estreito")
	interface._fechar_tela("conversa_cidade")
	print("FALHAS: ",falhas)
	quit(1 if falhas else 0)
