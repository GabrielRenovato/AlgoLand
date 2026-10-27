extends SceneTree
## Revisa as 7 animações Mixamo do lote de 27/10 no personagem 3D (render interno, sem o mapa):
## machado e maça (arma), guarda sem escudo, dash, dano, morte e soltura do arco. Save isolado.
const SAIDA := "res://arte/previas/personagens/base_3d/mixamo_lote2/"
const CASOS := [["pesada","machado"],["pesada","maca"],["guarda_livre","espada_basica"],["avanco",""],["ferido",""],["morrer",""],["arco_soltura","arco_curto"]]
func _initialize(): rodar.call_deferred()
func rodar():
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	assert(DisplayServer.get_name() != "headless")
	root.get_node("Introducao").pular_prologo()
	change_scene_to_file("res://cenas/fazenda.tscn")
	for i in 35: await process_frame
	root.get_node("Transicao").limpar()
	root.get_node("PainelDebug")._ativar_base_3d(true, false)
	var j = current_scene.get_node("Jogador")
	var h = j.get_node("HeroiBase3D")
	for i in 20: await process_frame
	h.set_process(false)
	var lado: int = h._vp.size.x
	var corte := Rect2i(lado*3/10, lado/5, lado*2/5, lado*3/5)
	var folha := Image.create(corte.size.x*5, corte.size.y*CASOS.size(), false, Image.FORMAT_RGBA8)
	folha.fill(Color("5d6b55"))
	var ausentes := []
	for linha in CASOS.size():
		var acao: String = CASOS[linha][0]
		var arma: String = CASOS[linha][1]
		j.usando_espada = arma in ["machado","maca","espada_basica"]
		j.usando_arco = arma.begins_with("arco")
		j.usando_lanca = false
		j.usando_escudo = false
		if arma != "": j.id_arma_atual = arma
		h._modelo.rotation.y = PI/4.0
		var nome: String = "mixamo/BowRecoil" if acao == "arco_soltura" else h._nome_animacao(acao)
		if not h._player.has_animation(nome):
			ausentes.append(nome)
			continue
		h._acao = "arco" if acao == "arco_soltura" else acao
		var anim: Animation = h._player.get_animation(nome)
		for q in 5:
			h._player.play(nome, 0.0)
			h._player.speed_scale = 0.0
			var f := q/4.0
			if acao == "pesada": f = lerpf(h.JANELA_PESADA.x, h.JANELA_PESADA.y, f)
			if acao == "avanco": f = lerpf(h.JANELA_DASH.x, h.JANELA_DASH.y, f)
			h._player.seek(minf(f, 0.999)*anim.length, true)
			h._encaixar_espada(acao == "guarda_livre")
			h._encaixar_arma_pesada(acao == "pesada")
			for i in 3: await process_frame
			await RenderingServer.frame_post_draw
			var img: Image = h._vp.get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			folha.blend_rect(img, corte, Vector2i(q*corte.size.x, linha*corte.size.y))
		print("LOTE2 ", acao, " ", arma, " -> ", nome, " ", snappedf(anim.length, 0.01), "s")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA))
	folha.resize(folha.get_width()*3/5, folha.get_height()*3/5, Image.INTERPOLATE_LANCZOS)
	folha.save_png(SAIDA+"folha.png")
	print("LOTE2 ausentes=", ausentes)
	quit()
