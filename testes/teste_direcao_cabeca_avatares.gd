extends SceneTree
## Exercita os consumidores reais sem orientar a cabeça manualmente.
var falhas := 0
var verificacoes := 0
func _initialize() -> void: rodar.call_deferred()
func conferir(ok: bool, texto: String) -> void:
	verificacoes += 1
	if not ok:
		falhas += 1
		push_error(texto)
func esperar() -> void:
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
func conferir_direcao(avatar: Node, direcao: int, contexto: String) -> void:
	var cabeca = avatar.heroi._cabeca_referencia
	conferir(cabeca.visible, contexto+": cabeça canônica ativa")
	conferir(cabeca._direcao==direcao*2, contexto+": cabeça acompanha corpo, direção "+str(direcao)+", vista "+str(cabeca._direcao))
func rodar() -> void:
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	assert(DisplayServer.get_name()!="headless")
	root.get_node("Ranking").conexao_habilitada=false
	root.get_node("Introducao").pular_prologo()
	root.size=Vector2i(1152,648)
	root.content_scale_size=Vector2i(576,324)
	var remoto=load("res://codigo/cidade/jogador_lobby.gd").new()
	root.add_child(remoto)
	remoto.set_process(false)
	remoto.atualizar({"id":"teste","apelido":"Direção","direcao":0,"x":100,"y":100},{"versao":1},true)
	await esperar()
	var avatar=remoto.corpo
	var folha:=Image.create(320*4,320*2,false,Image.FORMAT_RGBA8)
	for correndo in [false,true]:
		for direcao in [0,1,2,3,0,2,1,3]:
			avatar.pose(correndo,direcao,.1)
			await esperar()
			conferir_direcao(avatar,direcao,"Lobby "+("correndo" if correndo else "parado"))
			var imagem: Image=avatar.heroi._vp.get_texture().get_image()
			imagem.resize(320,320,Image.INTERPOLATE_NEAREST)
			folha.blit_rect(imagem,Rect2i(0,0,320,320),Vector2i(direcao*320,320 if correndo else 0))
	folha.save_png("/tmp/algoland-direcao-cabeca-lobby.png")
	# A prévia de criação também desativa o processamento do herói.
	for direcao in 4:
		avatar.mostrar(avatar.aparencia_raven,avatar.roupas_3d,direcao)
		await esperar()
		conferir_direcao(avatar,direcao,"Prévia")
	var carregador=root.get_node("Transicao")._carregador
	carregador.iniciar("res://cenas/casa.tscn","VILA DAS FLORES")
	await esperar()
	for i in 6:
		carregador._process(.08)
		await esperar()
		conferir_direcao(carregador._avatar,1,"Carregamento")
	root.get_texture().get_image().save_png("/tmp/algoland-direcao-cabeca-carregamento.png")
	carregador.hide()
	# Sinal do rig pode ser emitido na remoção do avatar; não acessar transforms globais.
	root.remove_child(remoto)
	remoto.corpo.heroi._cabeca_referencia._atualizar_inclinacao()
	remoto.queue_free()
	print("DIREÇÃO CABEÇA AVATARES: ",verificacoes," verificações, ",falhas," falhas")
	quit(1 if falhas else 0)
