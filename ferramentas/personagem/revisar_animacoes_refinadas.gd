extends SceneTree

## Captura as camadas reais de combate, em quatro direções, com save isolado.
const SAIDA := "res://arte/previas/personagens/refinado/revisao/"
var viewport: SubViewport
var jogador: Node
var capturas := 0

func _initialize() -> void:
	_rodar()

func _rodar() -> void:
	if ProjectSettings.get_setting("application/config/name") != "AlgoLand testes Carrasco":
		push_error("Execute com saves isolados.")
		quit(1)
		return
	await process_frame
	var arena := load("res://cenas/cenario.tscn").instantiate() as Node
	root.add_child(arena)
	current_scene = arena
	await process_frame
	jogador = arena.get_node("Jogador")
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	jogador.cor_cabelo = Color("603520")
	jogador.pecas_cavaleiro = 0
	jogador.raizes_armadura = {}
	jogador.definir_aparencia(0,2)
	viewport = SubViewport.new()
	viewport.size = Vector2i(128,128)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(viewport)
	var fundo := ColorRect.new()
	fundo.color = Color("303039")
	fundo.size = viewport.size
	viewport.add_child(fundo)
	jogador.reparent(viewport)
	jogador.process_mode = Node.PROCESS_MODE_DISABLED
	jogador.camera.enabled = false
	jogador.position = Vector2(64,64)
	jogador.scale = Vector2(2,2)
	jogador._arvore_animacao.active = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA))
	for arma in ["espada_basica","espada_gemea","machado","maca","lanca_basica"]:
		var familia := "spear" if arma == "lanca_basica" else "sword"
		var nome_folha: String = familia if arma in ["espada_basica","lanca_basica"] else arma
		if familia == "sword":
			jogador.id_arma_atual = arma
			jogador.atualizar_texturas_espada()
		else:
			jogador.atualizar_texturas_lanca()
		for golpe in range(1,4):
			var folha := Image.create(1024,512,false,Image.FORMAT_RGBA8)
			for direcao in 4:
				var nome := "%s_slash_%d_%s" % [familia,golpe,["down","up","right","left"][direcao]]
				var animacao: Animation = jogador.reprodutor_anim.get_animation(nome)
				jogador.reprodutor_anim.play(nome)
				for etapa in 8:
					jogador.reprodutor_anim.seek(animacao.length*etapa/8.0,true,true)
					_somente("AttackSwordAnimation" if familia == "sword" else "AttackSpearAnimation")
					for camada in jogador.get_node("CompositeSprites/"+("AttackSwordAnimation" if familia == "sword" else "AttackSpearAnimation")).get_children():
						if camada is CanvasItem:
							camada.visible = camada.name != "Escudo"
					await _capturar(folha,etapa,direcao)
			folha.save_png(SAIDA+"%s_%d.png" % [nome_folha,golpe])
	jogador.reprodutor_anim.stop()
	for arma in ["arco_curvo","arco_curto","arco_longo"]:
		jogador.id_arco_atual = arma
		jogador.atualizar_texturas_arco()
		for pagina in [2,3]:
			var folha := Image.create(1024,512,false,Image.FORMAT_RGBA8)
			for direcao in 4:
				for etapa in 8:
					jogador.no_arco._pagina = pagina
					jogador.no_arco._estado = jogador.no_arco.Estado.DISPARANDO
					jogador.no_arco._linha = direcao
					jogador.no_arco._indice = etapa
					jogador.no_arco._aplicar_texturas()
					jogador.no_arco._aplicar_quadro()
					# p2 é a sequência de carregar, presente nas linhas 0–3.
					if pagina == 2:
						for camada in [jogador.no_arco._corpo,jogador.no_arco._roupa,jogador.no_arco._cabelo,jogador.no_arco._arco,jogador.no_arco._aljava]:
							camada.frame = direcao*8+etapa
					_somente("Arco")
					await _capturar(folha,etapa,direcao)
			folha.save_png(SAIDA+("arco" if arma == "arco_curvo" else arma)+"_%d.png" % pagina)
	viewport.queue_free()
	arena.queue_free()
	current_scene = null
	await process_frame
	print("Composições de combate capturadas: ",capturas)
	quit()

func _somente(nome: String) -> void:
	for filho in jogador.get_node("CompositeSprites").get_children():
		if filho is CanvasItem:
			filho.visible = filho.name == nome

func _capturar(folha: Image, coluna: int, linha: int) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var imagem := viewport.get_texture().get_image()
	var desenhados := 0
	var fundo := imagem.get_pixel(0,0)
	for y in 128:
		for x in 128:
			if imagem.get_pixel(x,y) != fundo:
				desenhados += 1
	if desenhados < 100:
		push_error("Composição vazia: coluna %d, linha %d" % [coluna,linha])
		quit(1)
		return
	folha.blit_rect(imagem,Rect2i(0,0,128,128),Vector2i(coluna*128,linha*128))
	capturas += 1
