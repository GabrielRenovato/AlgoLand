extends SceneTree

var falhas := 0
func _initialize() -> void: rodar.call_deferred()
func quadros(n := 12) -> void:
	for i in n:
		await process_frame
		await physics_frame
func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ",nome)
	if not ok: falhas += 1
func foto(nome: String) -> void:
	await quadros()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://arte/previas/interface_bosque/"+nome+".png")
func janelas(no: Node, resultado: Array) -> void:
	for filho in no.get_children(true):
		if filho is Window and filho != root and filho.visible: resultado.append(filho)
		janelas(filho,resultado)
func rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name","")).begins_with("AlgoLand testes"):
		quit(1)
		return
	await process_frame
	root.get_node("Saves").trocar("solo")
	root.get_node("Introducao").pular_prologo()
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = Vector2i(576,324)
	root.size = Vector2i(1152,648)
	change_scene_to_file("res://cenas/inicio_do_jogo.tscn")
	await quadros(35)
	var inicio = current_scene
	var vila = inicio.get_node("Interface/Raiz/VilaViva")
	var dia: int = root.get_node("Calendario").dia
	var missoes: Dictionary = root.get_node("Cidade").missoes.duplicate(true)
	var memoria: Dictionary = root.get_node("Cidade").memoria.duplicate(true)
	var antes_camera: Vector2 = vila._camera.position
	var antes_npc: Vector2 = vila._moradores[0].position
	for i in 200:
		vila._process(0.05)
		for ator in vila._moradores: ator._process(0.05)
	verificar("vila tem seis moradores animados",vila._moradores.size()==6)
	verificar("camera percorre vila e moradores caminham",vila._camera.position.distance_to(antes_camera)>3 and vila._moradores[0].position.distance_to(antes_npc)>3)
	verificar("moradores passeiam sem baloes",vila._moradores.all(func(ator): return ator.find_children("*","Control",true,false).is_empty()))
	verificar("apresentacao nao altera dia missoes ou memoria",root.get_node("Calendario").dia==dia and root.get_node("Cidade").missoes==missoes and root.get_node("Cidade").memoria==memoria)
	var distancia_guardada: float = vila._distancia
	vila._distancia = 100.0
	vila._atualizar_camera(0)
	var centro_anterior: Vector2 = vila._camera.get_screen_center_position()
	var quadros_parados := 0
	var maior_salto := 0.0
	for quadro in 120:
		vila._atualizar_camera(1.0/60)
		var centro: Vector2 = vila._camera.get_screen_center_position()
		var passo := centro.distance_to(centro_anterior)
		if passo < 0.001: quadros_parados += 1
		maior_salto = maxf(maior_salto,passo)
		centro_anterior = centro
	verificar("camera avanca continuamente sem saltos em 60 fps",quadros_parados<=2 and maior_salto<0.2)
	vila._distancia = distancia_guardada
	vila._atualizar_camera(0)
	for estacao in 4:
		root.get_node("Calendario").dia = 1+30*estacao
		root.get_node("Calendario").estacao_mudou.emit(estacao)
		await quadros()
		verificar("fundo sazonal integrado "+str(estacao),vila._fundo.texture.resource_path.ends_with(["primavera.png","verao.png","outono.png","inverno.png"][estacao]))
		await foto("inicio_vila_"+str(estacao)+"_pc")
		if estacao == 0 and OS.get_cmdline_user_args().has("--capturar-animacao"):
			DirAccess.make_dir_recursive_absolute("/tmp/algoland-vila-animada")
			for quadro in 80:
				await create_timer(0.1).timeout
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("/tmp/algoland-vila-animada/%03d.png" % quadro)
	verificar("titulo separado dos botoes",inicio.titulo.get_global_rect().end.y+4 <= inicio.menu.get_global_rect().position.y)
	verificar("menu PC preserva margem",Rect2(Vector2.ZERO,inicio.get_node("Interface/Raiz").size).grow(-12).encloses(inicio._menu_painel.get_global_rect()))
	inicio.botao_opcoes.pressed.emit()
	await foto("inicio_opcoes_pc")
	inicio._fechar_painel()
	inicio._botao_coop.pressed.emit()
	await quadros()
	verificar("coop tem moldura propria",inicio._moldura_coop.visible)
	await foto("inicio_coop_pc")
	inicio._fechar_painel()
	var transicao = root.get_node("Transicao")
	for tamanho in [Vector2i(576,324),Vector2i(288,216),Vector2i(384,240)]:
		root.content_scale_size = tamanho
		root.size = tamanho*2
		await quadros(15)
		print("LAYOUT ",tamanho," raiz=",inicio.get_node("Interface/Raiz").size," painel=",inicio._menu_painel.get_global_rect())
		verificar("inicio responsivo "+str(tamanho),Rect2(Vector2.ZERO,inicio.get_node("Interface/Raiz").size).grow(-12).encloses(inicio._menu_painel.get_global_rect()))
		verificar("grade adapta menu "+str(tamanho),inicio.menu.columns==(2 if tamanho.x<480 or tamanho.y<300 else 1))
		if tamanho.x == 288: await foto("inicio_vila_mobile")
		transicao._carregador.iniciar("res://cenas/cenario.tscn","VILA DAS FLORES")
		transicao._carregador.atualizar(0.42)
		await quadros(15)
		var carregador: Control = transicao._carregador
		verificar("loading preserva margens "+str(tamanho),Rect2(Vector2.ZERO,carregador.size).grow(-10).encloses(carregador.painel.get_global_rect()))
		verificar("loading mostra percentual e destino",carregador._percentual.text=="42%" and carregador._destino.text=="ARENA")
		if tamanho.x != 384: await foto("carregamento_"+("pc" if tamanho.x==576 else "mobile"))
		carregador.hide()
	root.content_scale_size = Vector2i(576,324)
	root.size = Vector2i(1152,648)
	await quadros()
	var amostras := []
	transicao.progresso_carregamento.connect(func(_caminho: String, valor: float): amostras.append(valor))
	var erro: Error = await transicao.carregar_cena("res://cenas/fazenda.tscn")
	verificar("loading real troca cena e encerra painel",erro==OK and current_scene.scene_file_path=="res://cenas/fazenda.tscn" and not transicao._carregador.visible)
	verificar("progresso real vai de zero a um",amostras.size()>=2 and amostras[0]==0.0 and amostras[-1]==1.0 and amostras.all(func(valor): return valor>=0 and valor<=1))
	erro = await transicao.carregar_cena("res://cenas/nao_existe.tscn")
	verificar("destino invalido preserva cena e libera painel",erro==ERR_FILE_NOT_FOUND and not transicao._carregando and current_scene.scene_file_path=="res://cenas/fazenda.tscn")
	var inv = root.get_node("InventarioJogador")
	inv.mochila[0] = DadosItem.de_fazenda("semente:cenoura",5)
	inv.mochila_alterada.emit()
	var ui = root.get_node("EventosJogo").interface_p1()
	ui._abrir_tela("inventario")
	await quadros(20)
	var item = ui._telas["inventario"]._slots_mochila[0].item_ui()
	var dica: Control = item._make_custom_tooltip("")
	print("DICA ",dica.get_combined_minimum_size())
	verificar("semente tem altura compacta antes do primeiro layout",dica.get_combined_minimum_size().y>30 and dica.get_combined_minimum_size().y<100)
	dica.free()
	ProjectSettings.set_setting("gui/timers/tooltip_delay_sec",0.05)
	var movimento := InputEventMouseMotion.new()
	movimento.position = item.get_global_rect().get_center()
	root.push_input(movimento,true)
	await create_timer(0.8).timeout
	var popups := []
	janelas(root,popups)
	verificar("tooltip nativo foi exibido",not popups.is_empty())
	for popup in popups:
		print("POPUP ",popup.name," ",popup.size)
		verificar("popup real de semente nao ocupa a tela",popup.size.y<140)
	await foto("tooltip_semente_corrigido_pc")
	ui._fechar_tela("inventario")
	current_scene.queue_free()
	current_scene = null
	await quadros()
	print("Inicio e carregamento: %d falhas" % falhas)
	quit(1 if falhas else 0)
