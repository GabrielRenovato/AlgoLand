extends SceneTree
var falhas := 0
var capturas := "res://capturas-mapas-campanha"
func _initialize() -> void: rodar.call_deferred()
func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ",nome)
	if not ok:falhas += 1
func quadros(n := 8) -> void:
	for i in n:
		await process_frame
		await physics_frame
func foto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	verificar("captura " + nome,root.get_texture().get_image().save_png(capturas.path_join(nome+".png")) == OK)

func cor_no_mapa(imagem: Image, mapa: Control, ponto: Vector2) -> Color:
	var proporcao := Vector2(imagem.get_size())/Vector2(root.content_scale_size)
	var retangulo: Rect2 = mapa._campo_regional.retangulo_mapa()
	var pixel := Vector2i((retangulo.position+ponto/Vector2(1536,1024)*retangulo.size)*proporcao)
	return imagem.get_pixelv(pixel)

func mudancas_no_mapa(antes: Image, depois: Image, mapa: Control, centro: Vector2) -> int:
	var total := 0
	for y in range(-8,9,2):
		for x in range(-8,9,2):
			var p := centro+Vector2(x,y)
			if cor_no_mapa(antes,mapa,p)!=cor_no_mapa(depois,mapa,p): total+=1
	return total
func rodar() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes") or DisplayServer.get_name() == "headless":
		quit(1);return
	for argumento in OS.get_cmdline_user_args():
		if argumento.begins_with("--capturas="):capturas=argumento.trim_prefix("--capturas=")
	DirAccess.make_dir_recursive_absolute(capturas)
	root.mode=Window.MODE_WINDOWED
	root.content_scale_size=Vector2i(576,324)
	root.size=Vector2i(1152,648)
	change_scene_to_file("res://cenas/campanha/seletor_campanha.tscn")
	await quadros(15)
	var mapa=current_scene
	verificar("entrada começa no mapa-múndi",mapa.tela=="mundo")
	verificar("tabuleiro mostra somente a primeira peça",mapa._nos.size()==1 and mapa._nos.has("andar_01") and not mapa._nos.has("andar_02"))
	verificar("peça usa renderização 3D transparente",mapa._nos.andar_01.imagem is ViewportTexture and mapa._nos.andar_01.reliquia.transparent_bg)
	var reliquia = mapa._nos.andar_01.reliquia
	var rotacao: float = reliquia.peca.rotation.y
	var altura: float = reliquia.peca.position.y
	await quadros(15)
	verificar("relíquia gira no próprio eixo",absf(reliquia.peca.rotation.y-rotacao)>0.01)
	verificar("relíquia flutua sobre a célula",absf(reliquia.peca.position.y-altura)>0.001)
	mapa._mundo.material.set_shader_parameter("instante_forcado",0.0)
	await quadros(3)
	await RenderingServer.frame_post_draw
	var antes := root.get_texture().get_image()
	mapa._mundo.material.set_shader_parameter("instante_forcado",2.0)
	await quadros(3)
	await RenderingServer.frame_post_draw
	var depois := root.get_texture().get_image()
	var alterados := 0
	for y in range(100,antes.get_height()-120,8):
		for x in range(0,20,2):
			if antes.get_pixel(x,y) != depois.get_pixel(x,y): alterados += 1
	verificar("água muda na renderização real",alterados>15)
	var ponto := Vector2i(int(antes.get_width()*0.72),int(antes.get_height()*0.48))
	var a := antes.get_pixelv(ponto)
	var b := depois.get_pixelv(ponto)
	verificar("ondulação não deforma a terra",Vector3(a.r,a.g,a.b).distance_to(Vector3(b.r,b.g,b.b))<0.01)
	await foto("01-agua-animada")
	mapa._mundo.material.set_shader_parameter("instante_forcado",-1.0)
	mapa.selecionar("andar_01")
	await foto("01-mapa-mundi")
	verificar("mapa-múndi dispensa painel de confirmação",not mapa._rodape.visible)
	var centro: Vector2 = mapa._nos.andar_01.get_global_rect().get_center()
	for pressionado in [true,false]:
		var clique := InputEventMouseButton.new()
		clique.position = centro
		clique.button_index = MOUSE_BUTTON_LEFT
		clique.pressed = pressionado
		root.push_input(clique,true)
	verificar("clique direto inicia transição",mapa._em_transicao and mapa._transicao.visible)
	await create_timer(0.08).timeout
	await foto("01-transicao-dominio")
	await create_timer(0.45).timeout
	await quadros()
	verificar("clique abre minimapa sem confirmação",mapa.tela=="regioes" and mapa._nos.size()==12 and not mapa._em_transicao and not mapa._transicao.visible)
	var campo = mapa._campo_regional
	verificar("mapa usa a ilustração original fixa",campo.imagem.texture.resource_path=="res://assets/ui/campanha/mapa_primeira_raiz_cartoon.png" and campo.imagem.material==null)
	verificar("textura mantém a resolução original",campo.imagem.texture.get_size()==Vector2(1536,1024))
	verificar("mapa mantém mipmaps para reduzir serrilhado",campo.imagem.texture.get_image().has_mipmaps())
	campo.focar(Vector2(0.5,0.48),false)
	await quadros(3)
	await RenderingServer.frame_post_draw
	var mapa_antes := root.get_texture().get_image()
	await create_timer(0.45).timeout
	await RenderingServer.frame_post_draw
	var mapa_depois := root.get_texture().get_image()
	verificar("imagem permanece estática sem efeitos sobrepostos",mudancas_no_mapa(mapa_antes,mapa_depois,mapa,Vector2(928,656))==0)
	await foto("04-mapa-fixo")
	for tamanho_hd in [Vector2i(1920,1080),Vector2i(2560,1440)]:
		root.size=tamanho_hd
		mapa.selecionar("moinho")
		await create_timer(0.3).timeout
		await quadros(3)
		await foto("05-desktop-%dx%d" % [tamanho_hd.x,tamanho_hd.y])
	# Mesmo um save com todas as conquistas não reabre o estágio 5.
	var concluidas_antes: Array = mapa.controlador.progresso._concluidas.duplicate()
	mapa.controlador.progresso._concluidas = mapa._catalogo.missoes.keys()
	mapa.mostrar_regioes()
	mapa.selecionar("moinho")
	verificar("mapa bloqueia estágio 5 para save avançado",mapa._entrar.disabled and not mapa._nos.moinho.disponivel and mapa.entrar_selecionado()==ERR_UNAVAILABLE)
	await quadros(4)
	await foto("05-estagio-5-bloqueado")
	mapa.controlador.progresso._concluidas = concluidas_antes
	mapa.mostrar_regioes()
	root.size=Vector2i(1152,648)
	await quadros(3)
	mapa.selecionar("vila")
	verificar("cidade mostra requisito antes da chegada",mapa._entrar.disabled)
	mapa.selecionar("bastiao")
	verificar("dungeon principal não pula campanha",mapa.entrar_selecionado()==ERR_UNAVAILABLE)
	mapa.selecionar("chegada")
	for tamanho in [Vector2i(576,324),Vector2i(288,512),Vector2i(320,324)]:
		root.content_scale_size=tamanho
		root.size=tamanho*2
		await quadros(12)
		var tela:=Rect2(Vector2.ZERO,Vector2(tamanho))
		verificar("rodapé e botão cabem em %s" % tamanho,tela.encloses(mapa._rodape.get_global_rect()) and tela.encloses(mapa._entrar.get_global_rect()))
		verificar("água e terreno cobrem a tela toda em %s" % tamanho,mapa._campo_regional.cobertura_agua().grow(0.1).encloses(tela))
		verificar("faixa de viagem permanece compacta em %s" % tamanho,mapa._rodape.size.y<=70)
		for id in mapa._nos:
			verificar("marcador %s dentro do mapa %s" % [id,tamanho],Rect2(Vector2.ZERO,mapa._campo_regional.camada.size).encloses(mapa._nos[id].get_rect()))
			mapa.selecionar(id)
			await create_timer(0.3).timeout
			var seguro := Rect2(Vector2(0,48),Vector2(tamanho.x,tamanho.y-122))
			verificar("câmera revela %s sem HUD por cima em %s" % [id,tamanho],seguro.encloses(mapa._nos[id].get_global_rect()))
			verificar("nome e botão respeitam a moldura de %s em %s" % [id,tamanho],mapa._rodape.get_global_rect().grow(-8).encloses(mapa._nome.get_global_rect()) and mapa._rodape.get_global_rect().grow(-8).encloses(mapa._entrar.get_global_rect()))
		mapa.selecionar("vila")
		await create_timer(0.3).timeout
		await foto("02-vila-%dx%d" % [tamanho.x,tamanho.y])
		mapa._campo_regional.focar(Vector2(0.5,0.5),false)
		var camera_antes: Vector2 = mapa._campo_regional.camada.position
		var arrastar := InputEventScreenDrag.new()
		arrastar.position = Vector2(tamanho.x*0.8,tamanho.y*0.5)
		arrastar.relative = Vector2(-35,20)
		root.push_input(arrastar,true)
		verificar("arrasto desloca o mapa em %s" % tamanho,camera_antes.distance_to(mapa._campo_regional.camada.position)>1)
		mapa.selecionar("chegada")
		mapa._selecionar_vizinho(Vector2.UP)
		verificar("seta escolhe outro destino em %s" % tamanho,mapa.selecionado!="chegada")
		mapa.selecionar("chegada")
		await create_timer(0.3).timeout
		await foto("02-regioes-%dx%d" % [tamanho.x,tamanho.y])
		mapa._clicar_estagio("chegada")
		await quadros(8)
		var dialogo = mapa.dialogo_salas
		verificar("clique no estágio abre salas %s" % tamanho,is_instance_valid(dialogo) and dialogo.regiao=="chegada")
		verificar("diálogo cabe na tela %s" % tamanho,Rect2(Vector2.ZERO,Vector2(tamanho)).encloses(dialogo.painel.get_global_rect()))
		for texto in dialogo.painel.find_children("*","Label",true,false):
			var area: Rect2=texto.get_global_rect()
			var pai: Node=texto.get_parent()
			while pai!=null:
				if pai is Control and pai.clip_contents:area=area.intersection(pai.get_global_rect())
				pai=pai.get_parent()
			if area.has_area():verificar("texto cabe no diálogo %s" % tamanho,dialogo.painel.get_global_rect().grow(-8).encloses(area))
		await foto("06-salas-%dx%d" % [tamanho.x,tamanho.y])
		dialogo.fechar()
		await quadros(3)
		mapa._voltar.pressed.emit()
		await quadros()
		verificar("voltar retorna aos andares",mapa.tela=="mundo")
		verificar("painel permanece oculto no tabuleiro %s" % tamanho,not mapa._rodape.visible)
		await foto("03-mundo-%dx%d" % [tamanho.x,tamanho.y])
		var miniatura: Control = mapa._nos.andar_01
		verificar("miniatura cabe em %s" % tamanho,Rect2(Vector2.ZERO,mapa._conteudo.size).encloses(miniatura.get_rect()))
		verificar("domínio ocupa uma única célula em %s" % tamanho,mapa.retangulo_celula("andar_01").grow(0.01).encloses(miniatura.get_global_rect()))
		verificar("peça mantém escala de uma célula em %s" % tamanho,miniatura.size.x<mapa._tabuleiro.size.x*0.11 and miniatura.size.y<mapa._tabuleiro.size.y*0.11)
		if tamanho == Vector2i(288,512):
			for pressionado in [true,false]:
				var toque := InputEventScreenTouch.new()
				toque.position = miniatura.get_global_rect().get_center()
				toque.pressed = pressionado
				root.push_input(toque,true)
		else:
			var confirmar := InputEventAction.new()
			confirmar.action = "ui_accept"
			confirmar.pressed = true
			Input.parse_input_event(confirmar)
			await quadros(2)
			confirmar = InputEventAction.new()
			confirmar.action = "ui_accept"
			Input.parse_input_event(confirmar)
		await create_timer(0.5).timeout
		await quadros()
		verificar("entrada direta funciona em %s" % tamanho,mapa.tela=="regioes" and not mapa._em_transicao)
		mapa.selecionar("chegada")
	root.content_scale_size=Vector2i(576,324)
	root.size=Vector2i(1152,648)
	await quadros()
	mapa._entrar.pressed.emit()
	await quadros(3)
	mapa.dialogo_salas.jogar_solo()
	await quadros(45)
	verificar("entrar carrega a região selecionada",current_scene.scene_file_path=="res://cenas/campanha/percurso_prototipo.tscn" and current_scene.regiao=="chegada")
	current_scene.voltar_ao_mapa()
	await quadros(15)
	verificar("sair da região retorna ao mapa regional",current_scene.scene_file_path=="res://cenas/campanha/seletor_campanha.tscn" and current_scene.tela=="regioes")
	verificar("retorno da partida posiciona destinos sem depender do tabuleiro",current_scene._nos.chegada.position.length()>30 and current_scene._campo_regional.cobertura_agua().grow(0.1).encloses(Rect2(Vector2.ZERO,Vector2(576,324))))
	current_scene.queue_free();current_scene=null
	await quadros()
	print("FALHAS: ",falhas)
	quit(falhas)
