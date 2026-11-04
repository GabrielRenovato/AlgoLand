extends SceneTree
## Duas interfaces e dois personagens reais; o primeiro encaixe não depende de redimensionar a janela.
var falhas:=0
func _initialize(): rodar.call_deferred()
func aguardar(n:=15):
	for i in n: await process_frame; await physics_frame
func verificar(nome:String,ok:bool):
	print("OK " if ok else "FALHA ",nome)
	if not ok:falhas+=1
func rodar():
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"): quit(1);return
	DirAccess.make_dir_recursive_absolute("res://capturas-maestria-coop")
	root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1152,648);root.content_scale_size=Vector2i(576,324)
	root.get_node("Saves").trocar("coop")
	root.get_node("Introducao").pular_prologo()
	root.get_node("InventarioJogador").criar_itens_iniciais()
	root.get_node("InventarioJogador2").criar_itens_iniciais()
	change_scene_to_file("res://cenas/cidade.tscn")
	await aguardar(50)
	var coop:Node=root.get_node("Cooperativo")
	var eventos:Node=root.get_node("EventosJogo")
	var interfaces:Array=[eventos.interface_p1(),coop.interface_p2()]
	var caminhos:Array=[]
	for interface in interfaces:
		verificar("interface existe",interface!=null)
		if interface==null:quit(1);return
		interface._abrir_tela("maestria")
		await aguardar()
		var tela:Control=interface._telas.maestria
		var rect:Rect2=tela.painel.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,tela.painel.size)
		verificar("painel cabe desde primeira abertura",interface.get_viewport().get_visible_rect().encloses(rect))
		caminhos.append(tela.modelo.caminho)
		var jogador:Node=eventos.dono(tela)
		verificar("atalhos pertencem ao viewport do dono",jogador.maestria._camada.get_parent()==interface and jogador.maestria._camada.get_viewport()==interface.get_viewport())
	verificar("progresso do P2 separado",caminhos[0]!=caminhos[1])
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://capturas-maestria-coop/arvores.png")
	interfaces[1]._telas.maestria._abrir_detalhe("espada_0_1")
	await aguardar()
	var tela:Control=interfaces[1]._telas.maestria
	var popup:Rect2=tela._detalhe.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,tela._detalhe.size)
	verificar("tooltip dentro da metade do P2",interfaces[1].get_viewport().get_visible_rect().encloses(popup))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://capturas-maestria-coop/tooltip.png")
	print("FALHAS: ",falhas)
	quit(1 if falhas else 0)
