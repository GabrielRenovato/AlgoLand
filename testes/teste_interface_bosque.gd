extends SceneTree

var falhas := 0
func _initialize() -> void:
	_rodar.call_deferred()
func quadros(n := 10) -> void:
	for i in n:
		await process_frame
		await physics_frame
func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ", nome)
	if not ok: falhas += 1
func foto(nome: String) -> void:
	await quadros()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://arte/previas/interface_bosque/"+nome+".png")
func conferir_moldura(nome: String, painel: Control, tela: Control) -> void:
	var area := Rect2(Vector2.ZERO,tela.size).grow(-7)
	verificar(nome+" preserva margem da janela",area.encloses(Rect2(painel.position,painel.size)))
	if painel is PanelContainer:
		var interior := painel.get_global_rect().grow(-8)
		for filho in painel.get_children():
			if filho is Control and filho.visible:
				verificar(nome+" conteudo afastado da borda",interior.encloses(filho.get_global_rect()))

func _rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"):
		quit(1)
		return
	await process_frame
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = Vector2i(576,324)
	root.size = Vector2i(1152,648)
	DirAccess.make_dir_recursive_absolute("res://arte/previas/interface_bosque")
	change_scene_to_file("res://cenas/inicio_do_jogo.tscn")
	await quadros(50)
	await foto("menu_pc")
	var inicio = current_scene
	root.content_scale_size = Vector2i(288,216)
	root.size = Vector2i(864,648)
	await quadros(12)
	await foto("menu_mobile")
	inicio.botao_opcoes.pressed.emit()
	await quadros(12)
	conferir_moldura("opcoes iniciais mobile",inicio.painel_opcoes,inicio.get_node("Interface/Raiz"))
	await foto("opcoes_iniciais_mobile")
	inicio._fechar_painel()
	inicio.botao_creditos.pressed.emit()
	await foto("creditos_mobile")
	inicio._fechar_painel()
	current_scene.queue_free()
	await quadros()
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = Vector2i(576,324)
	root.size = Vector2i(1152,648)
	var criacao = load("res://codigo/ui/tela_criacao_personagem.gd").new()
	criacao.trocar_cena = false
	root.add_child(criacao)
	current_scene = criacao
	await quadros(35)
	verificar("criacao PC cabe na tela", criacao._colunas.size.x <= criacao.size.x and not criacao._colunas.vertical)
	await foto("criacao_pc")
	criacao._abrir_aba(1)
	await foto("criacao_roupas_pc")
	criacao._abrir_aba(2)
	await foto("criacao_cores_pc")
	criacao._abrir_aba(0)
	root.get_node("Controle").usando_toque = true
	root.content_scale_size = Vector2i(288,216)
	root.size = Vector2i(864,648)
	await quadros(20)
	verificar("criacao mobile usa coluna sem corte horizontal", criacao._colunas.vertical and criacao._colunas.size.x <= criacao.size.x)
	await foto("criacao_mobile")
	criacao._botao_confirmar.grab_focus()
	await foto("criacao_mobile_rodape")
	current_scene = null
	criacao.queue_free()
	await quadros()
	root.get_node("Controle").usando_toque = false
	root.content_scale_size = Vector2i(576,324)
	root.size = Vector2i(1152,648)
	root.get_node("Introducao").pular_prologo()
	change_scene_to_file("res://cenas/cidade/forja.tscn")
	await quadros(30)
	var ui = current_scene.get_node("Interface")
	ui._abrir_tela("inventario")
	await foto("mochila_pc")
	ui._fechar_tela("inventario")
	ui._abrir_tela("forja")
	await quadros(12)
	conferir_moldura("forja PC",ui._telas["forja"].painel,ui._telas["forja"])
	await foto("forja_pc")
	ui._fechar_tela("forja")
	root.get_node("Cidade").conversar("ferreiro", current_scene.get_node("Jogador"))
	await quadros()
	ui._telas["conversa_cidade"]._avancar_fala()
	await foto("dialogo_pc")
	ui._fechar_tela("conversa_cidade")
	for nome in ["mercante","caldeirao","acampamento","mistica","pausa"]:
		ui._abrir_tela(nome)
		await foto(nome+"_pc")
		ui._fechar_tela(nome)
	root.get_node("Controle").usando_toque = true
	root.content_scale_size = Vector2i(288,216)
	root.size = Vector2i(864,648)
	ui._abrir_tela("forja")
	await quadros(15)
	var forja: Control = ui._telas["forja"]
	verificar("forja mobile cabe na tela", forja.painel.size.x <= forja.size.x and forja.painel.size.y <= forja.size.y)
	conferir_moldura("forja mobile",forja.painel,forja)
	verificar("mobile oferece receitas com largura inteira",forja._receitas_coluna.visible and not forja._papel.visible)
	await foto("forja_mobile")
	forja._selecionar("arco_curto")
	await quadros(10)
	verificar("selecionar abre detalhes com largura inteira",forja._papel.visible and not forja._receitas_coluna.visible and forja._fabricar.visible)
	for linha in forja._custos.get_children():
		verificar("materiais alinham icone nome quantidade sem sobreposicao",linha.get_child(0).get_rect().end.x <= linha.get_child(1).position.x and linha.get_child(1).get_rect().end.x <= linha.get_child(2).position.x)
	await foto("forja_materiais_mobile")
	ui._fechar_tela("forja")
	root.get_node("Cidade").conversar("ferreiro",current_scene.get_node("Jogador"))
	await quadros()
	ui._telas["conversa_cidade"]._avancar_fala()
	await foto("dialogo_mobile")
	ui._fechar_tela("conversa_cidade")
	ui._abrir_tela("inventario")
	await foto("mochila_mobile")
	ui._fechar_tela("inventario")
	for tamanho in [Vector2i(288,216),Vector2i(384,240)]:
		root.content_scale_size = tamanho
		root.size = tamanho*2
		await quadros(10)
		for nome in ["mercante","caldeirao","acampamento","mistica","pausa","dormir","fim_partida","bau","guia_pesca","comercio","mural_cidade","desafio_arena"]:
			ui._abrir_tela(nome)
			await quadros(12)
			conferir_moldura(nome+str(tamanho),ui._paineis[nome],ui._telas[nome])
			if tamanho.x == 288:
				await foto(nome+"_mobile")
				if nome in ["mercante","bau"]:
					verificar(nome+" alterna mochila sem sobrepor",ui._troca_companheira.visible and not ui._telas["inventario"].visible)
					ui._troca_companheira.pressed.emit()
					await quadros(10)
					verificar(nome+" mostra mochila e preserva contexto",ui._telas["inventario"].visible and not ui._telas[nome].visible)
					await foto(nome+"_mochila_mobile")
			ui._fechar_tela(nome)
		ui._abrir_tela("pausa")
		ui._telas["pausa"]._mostrar(1)
		await quadros(12)
		conferir_moldura("opcoes pausa "+str(tamanho),ui._paineis["pausa"],ui._telas["pausa"])
		await foto("opcoes_pausa_mobile")
		ui._fechar_tela("pausa")
	root.get_node("Controle").usando_toque = false
	root.content_scale_size = Vector2i(576,324)
	root.size = Vector2i(1152,648)
	var opcoes_script = load("res://codigo/globais/opcoes_jogo.gd")
	var opcoes: Dictionary = opcoes_script.carregar()
	for escala in [0.75,1.5]:
		opcoes.escala_interface = escala
		opcoes_script.aplicar(opcoes)
		opcoes_script.salvar(opcoes)
		await quadros(15)
		for nome in ["forja","acampamento","pausa","guia_pesca"]:
			ui._abrir_tela(nome)
			await quadros(15)
			conferir_moldura(nome+" escala "+str(escala),ui._paineis[nome],ui._telas[nome])
			ui._fechar_tela(nome)
	opcoes.escala_interface = 1.0
	opcoes_script.aplicar(opcoes)
	opcoes_script.salvar(opcoes)
	change_scene_to_file("res://cenas/fazenda.tscn")
	await quadros(20)
	await foto("hud_fazenda_pc")
	change_scene_to_file("res://cenas/cenario.tscn")
	await quadros(24)
	var informacoes: Node = current_scene.get_node("Interface/Hud/InfoTab") if current_scene.has_node("Interface/Hud/InfoTab") else current_scene.find_child("InfoTab",true,false)
	if informacoes != null:
		informacoes.get_node("InformacaoPersonagem").show()
		informacoes.atualizar_menu()
		await foto("atributos_pc")
	root.get_node("Saves").trocar("coop")
	change_scene_to_file("res://cenas/cidade/forja.tscn")
	await quadros(30)
	root.get_node("EventosJogo").interface_p1()._abrir_tela("forja")
	root.get_node("Cooperativo").interface_p2()._abrir_tela("inventario")
	await foto("coop")
	root.get_node("Cooperativo").sair()
	current_scene.queue_free()
	current_scene = null
	ui = null
	forja = null
	informacoes = null
	criacao = null
	await quadros(12)
	print("Interface Bosque: %d falhas" % falhas)
	quit(falhas)
