extends SceneTree

var falhas := 0
var capturar := false
var Posto: GDScript
func _initialize() -> void: rodar.call_deferred()
func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ",nome)
	if not ok: falhas += 1
func quadros(n := 10) -> void:
	for i in n:
		await process_frame
		await physics_frame
func foto(nome: String) -> void:
	if not capturar: return
	await RenderingServer.frame_post_draw
	var pasta := "res://arte/previas/dialogos/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(pasta))
	root.get_texture().get_image().save_png(pasta+nome+".png")
func rodar() -> void:
	await process_frame
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"): quit(1); return
	capturar = "--capturar" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless"
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = Vector2i(576,324)
	root.size = Vector2i(1152,648)
	Posto = load("res://codigo/cidade/atendimento_cidade.gd")
	root.get_node("Introducao").pular_prologo()
	var cidade := root.get_node("Cidade")
	var calendario := root.get_node("Calendario")
	calendario.dia = 1
	cidade.apagar()
	for local in Posto.POSTOS:
		var caminho := "res://cenas/palafita.tscn" if local == "palafita" else "res://cenas/cidade/%s.tscn" % local
		root.get_node("Transicao").hora_salva = 19 if local == "pousada" else (16 if local == "sede" else 9)
		change_scene_to_file(caminho)
		await quadros(30)
		var cena := current_scene
		var luz := cena.get_node("Iluminacao")
		luz.set_process(false)
		var posto := cena.get_node("Interior/Atendimento")
		var jogador := cena.get_node("Jogador")
		var interface := cena.get_node("Interface")
		var tela: Control = interface._telas.conversa_cidade
		# Aguarda a presença real pelo sistema de trajetos, sem interferir na partida do usuário.
		var npc: Node2D = cena.get_node("Nilo") if posto.id == "nilo" else cena.moradores[posto.id]
		npc.visible = true
		npc._saindo = false
		npc.agenda.local = local
		npc.set_physics_process(false)
		jogador.position = posto.global_position
		await quadros()
		verificar(local+": posto na frente do móvel e alcançável",posto.jogador_perto)
		verificar(local+": atendimento presente e no expediente",Posto.impedimento(cena,posto.id,posto.modo) == "")
		var interagivel = load("res://codigo/logica/interagivel.gd")
		verificar(local+": móvel tem prioridade apenas na sua zona",interagivel.eh_o_mais_proximo(posto,jogador))
		var inicio: Transform2D = jogador.global_transform
		inicio.origin = posto.global_position+Vector2(24,0)
		var mascara: int = jogador.collision_mask
		jogador.collision_mask = 64
		verificar(local+": acesso frontal livre de colisões",not jogador.test_move(inicio,Vector2(-24,0)))
		jogador.collision_mask = mascara
		await foto("acesso-"+local)
		var amizade: int = cidade.amizade.get(posto.id,0)
		posto.abrir_tela()
		await quadros()
		verificar(local+": serviço abre diretamente",tela.visible and tela._submenu == posto.modo and tela._menu_assuntos.visible)
		verificar(local+": atendimento não aumenta amizade",cidade.amizade.get(posto.id,0) == amizade and not cidade.conversas.has(posto.id))
		verificar(local+": painel e textos cabem",Rect2(Vector2.ZERO,tela.size).encloses(tela.painel.get_global_rect()))
		verificar(local+": instrução com margem dentro do painel",tela.painel.get_global_rect().grow(-8).encloses(tela._resumo_servico.get_global_rect()) and tela._resumo_servico.size.y >= tela._resumo_servico.get_minimum_size().y)
		if local == "venda":
			verificar("venda: botoes compactos",tela._botoes.all(func(b): return b.size.y <= 32))
			verificar("venda: duas opcoes sem rolagem ou setas",tela._botoes.size() == 2 and not tela._subir_respostas.get_parent().visible and tela._rolagem.get_global_rect().encloses(tela._opcoes.get_global_rect()))
		await foto("balcao-"+local)
		if local == "carpintaria":
			for tamanho in [Vector2i(288,512),Vector2i(320,324)]:
				root.content_scale_size = tamanho
				root.size = tamanho*2
				root.get_node("Controle").usando_toque = tamanho.x < 300
				await quadros()
				verificar("construção cabe em "+str(tamanho),Rect2(Vector2.ZERO,tela.size).encloses(tela.painel.get_global_rect()))
				await foto("bancada-"+str(tamanho.x))
			root.get_node("Controle").usando_toque = false
			root.content_scale_size = Vector2i(576,324)
			root.size = Vector2i(1152,648)
			await quadros()
		if local == "venda" or local == "enfermaria":
			var nome := "SEMENTES" if local == "venda" else "POCOES"
			var opcoes: Array = tela._botoes.filter(func(b): return b.text == nome)
			verificar(local+": ação comercial preservada",opcoes.size() == 1)
			if opcoes.size(): opcoes[0].pressed.emit()
			await quadros()
			var destino := "mercante" if local == "venda" else "caldeirao"
			verificar(local+": abre interface específica",interface._telas_abertas.has(destino))
			interface._fechar_tela(destino)
		else: interface._fechar_tela("conversa_cidade")
		posto.abrir_tela()
		await quadros()
		luz.definir_hora(5)
		verificar(local+": fechar expediente invalida uma ação já aberta",not tela._validar_atendimento())
		interface._fechar_tela("conversa_cidade")
		luz.definir_hora(19 if local == "pousada" else (16 if local == "sede" else 9))
		# Ausência e expediente são revalidados, inclusive depois de abrir o balcão.
		npc.visible = false
		verificar(local+": ausência impede atendimento",Posto.impedimento(cena,posto.id,posto.modo) != "")
		posto.abrir_tela()
		await quadros()
		verificar(local+": balcão sem atendente informa e não vende",tela._botoes.is_empty() and not tela._menu_assuntos.visible)
		interface._fechar_tela("conversa_cidade")
		npc.visible = true
		luz.definir_hora(5)
		verificar(local+": expediente fechado",Posto.impedimento(cena,posto.id,posto.modo) != "")
		if local == "pousada":
			verificar("cozinha disponível pelo fogão mesmo fora do balcão",Posto.impedimento(cena,"bardo","cozinha") == "" and cena.has_node("Interior/Cozinha"))
		cidade.conversar(posto.id,jogador)
		await quadros()
		verificar(local+": voltar ao NPC limpa modo de serviço",tela._atendimento == "" and tela._submenu == "" and not tela._menu_assuntos.visible)
		interface._fechar_tela("conversa_cidade")
		cidade.conversas.clear()
	# Missão principal, adiar sem insistência e entrega contextual continuam acessíveis.
	change_scene_to_file("res://cenas/cidade.tscn")
	await quadros(30)
	var jogador_missao := current_scene.get_node("Jogador")
	var interface_missao := current_scene.get_node("Interface")
	var dialogo: Control = interface_missao._telas.conversa_cidade
	cidade.conversar("lia",jogador_missao)
	await quadros()
	interface_missao._fechar_tela("conversa_cidade")
	cidade.conversar("lia",jogador_missao)
	await quadros()
	verificar("missão principal aparece naturalmente ao falar com Lia",dialogo._pedido == "limiar_vigilia" and dialogo._botoes.size() == 2)
	dialogo._adiar_pedido()
	await quadros()
	cidade.conversar("lia",jogador_missao)
	await quadros()
	verificar("adiar preserva a missão e não repete a mesma oferta",dialogo._pedido != "limiar_vigilia" and not cidade.missoes.has("limiar_vigilia"))
	interface_missao._fechar_tela("conversa_cidade")
	cidade.aceitar("limiar_vigilia")
	root.get_node("Progresso").checkpoint_max = 1
	cidade.conversar("lia",jogador_missao)
	await quadros()
	verificar("pedido pronto tem prioridade e opção de entrega",dialogo._pedido == "limiar_vigilia" and dialogo._botoes.any(func(b): return b.text == "ENTREGAR" and not b.disabled))
	dialogo._entregar("limiar_vigilia")
	await quadros()
	verificar("entrega volta à fala e avança história",cidade.missoes.limiar_vigilia.estado == "concluida" and dialogo._pedido == "" and not dialogo._menu_assuntos.visible)
	interface_missao._fechar_tela("conversa_cidade")
	# P1 conversa enquanto P2 usa o fogão: modos e telas não se misturam.
	root.get_node("Saves").trocar("coop")
	root.get_node("Transicao").hora_salva = 19
	change_scene_to_file("res://cenas/cidade/pousada.tscn")
	await quadros(40)
	var coop := root.get_node("Cooperativo")
	var p1: Node2D = coop._jogador1()
	var p2: Node2D = coop.jogador2()
	p2.global_position = current_scene.get_node("Interior/Cozinha").global_position
	await quadros()
	p1.global_position = p2.global_position+Vector2(8,0)
	await quadros()
	current_scene.get_node("Interior/Cozinha").abrir_tela()
	await quadros()
	verificar("P1 usa o próprio atendimento mesmo com P2 mais perto",root.get_node("EventosJogo").interface_p1()._telas.conversa_cidade.visible and not coop.interface_p2()._telas.conversa_cidade.visible)
	root.get_node("EventosJogo").interface_p1()._fechar_tela("conversa_cidade")
	cidade.conversar("bardo",p1)
	await quadros()
	current_scene.get_node("Interior/Cozinha").abrir_tela_p2()
	await quadros()
	var t1: Control = root.get_node("EventosJogo").interface_p1()._telas.conversa_cidade
	var t2: Control = coop.interface_p2()._telas.conversa_cidade
	verificar("P1 permanece conversando enquanto P2 cozinha",t1.visible and t1._atendimento == "" and not t1._menu_assuntos.visible and t2.visible and t2._atendimento == "cozinha" and t2._menu_assuntos.visible)
	await foto("conversa-e-cozinha-coop")
	root.get_node("EventosJogo").interface_p1()._fechar_tela("conversa_cidade")
	coop.interface_p2()._fechar_tela("conversa_cidade")
	p2.set_physics_process(false)
	coop.sair()
	print("FALHAS: ",falhas)
	quit(1 if falhas else 0)
