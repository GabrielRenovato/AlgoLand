extends SceneTree
const Varas := preload("res://codigo/pesca/varas.gd")
const Peixes := preload("res://codigo/pesca/peixes.gd")
const Metas := preload("res://codigo/pesca/desafios_pesca.gd")
var falhas := 0
func _initialize() -> void:
	_rodar.call_deferred()
func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ",nome)
	if not ok: falhas += 1
func quadros(n := 5) -> void:
	for i in n: await process_frame
func botao(indice: int) -> void:
	for pressionado in [true,false]:
		var evento := InputEventJoypadButton.new()
		evento.device = 40
		evento.button_index = indice
		evento.pressed = pressionado
		Input.parse_input_event(evento)
		await quadros(3)
func _rodar() -> void:
	if not String(ProjectSettings.get_setting("application/config/custom_user_dir_name","")).begins_with("AlgoLand testes"):
		quit(1)
		return
	var fazenda: Node = root.get_node("Fazenda")
	var coop: Node = root.get_node("Cooperativo")
	var cidade: Node = root.get_node("Cidade")
	root.get_node("Saves").trocar("coop")
	root.get_node("Introducao").pular_prologo()
	fazenda._zerar()
	coop.dispositivo_p1 = coop.SEM_CONTROLE
	coop.dispositivo_p2 = 40
	coop._reconfigurar_entrada()
	root.size = Vector2i(1440,648)
	change_scene_to_file("res://cenas/palafita.tscn")
	await quadros(40)
	current_scene.get_node("Iluminacao").definir_hora(12)
	current_scene.get_node("Iluminacao").set_process(false)
	var p1: Node = current_scene.get_node("Jogador")
	var p2: Node = coop.jogador2()
	var ui1: Node = root.get_node("EventosJogo").interface_p1()
	var ui2: Node = coop.interface_p2()
	verificar("varas novas começam no nível 1",Varas.nivel(p1)==1 and Varas.nivel(p2)==1)
	verificar("não refina sem pedras",not Varas.melhorar(p1))
	root.get_node("InventarioJogador").adicionar_coletavel("material", "pedra_vara", 13)
	for nv in range(2,6):
		var antes := Varas.pedras(p1)
		verificar("custo nv %d" % nv,Varas.custo(p1)==int(Varas.CUSTOS[nv]))
		verificar("refina nv %d uma vez com consumo exato" % nv,Varas.melhorar(p1) and Varas.nivel(p1)==nv and Varas.pedras(p1)==antes-int(Varas.CUSTOS[nv]))
	verificar("nível máximo não consome",not Varas.melhorar(p1) and Varas.pedras(p1)==0)
	verificar("P2 mantém vara e pedras próprias",Varas.nivel(p2)==1 and Varas.pedras(p2)==0)
	Varas.receber_pedra(p2)
	fazenda.salvar()
	fazenda.carregar()
	verificar("save restaura nível e pedras dos dois",Varas.nivel(p1)==5 and Varas.nivel(p2)==1 and Varas.pedras(p2)==1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 71423
	var pedras := 0
	for i in 100000:
		if Varas.sortear_pedra(rng): pedras += 1
	verificar("pedra muito rara, aproximadamente 0,25%",pedras>170 and pedras<340)
	fazenda.pesca_capturas_jogador["p1"] = 2
	verificar("não há pedra nas primeiras pescarias",not Varas.pode_pescar_pedra(p1))
	fazenda.pesca_capturas_jogador["p1"] = 30
	verificar("sorteio só começa após 30 capturas",Varas.pode_pescar_pedra(p1))
	Varas.receber_pedra(p1)
	fazenda.pesca_capturas_jogador["p1"] = 79
	verificar("intervalo mínimo impede pedras consecutivas",not Varas.pode_pescar_pedra(p1))
	fazenda.pesca_capturas_jogador["p1"] = 80
	verificar("50 capturas liberam novo sorteio",Varas.pode_pescar_pedra(p1))
	fazenda.salvar()
	fazenda.carregar()
	verificar("intervalo da pedra persiste no save",Varas.capturas(p1)==80 and int(fazenda.pesca_ultima_pedra["p1"])==30)
	verificar("54 espécies e desafios por espécie",Peixes.DADOS.size()==54 and Metas.DESAFIOS.size()>=60)
	for ambiente in ["mar","rio"]:
		for estacao in 4:
			var comuns := 0
			var sazonal := true
			for i in 5000:
				var id := Peixes.sortear(ambiente,estacao,rng)
				var epocas: Array = Peixes.DADOS[id]["estacoes"]
				sazonal = sazonal and (epocas.is_empty() or epocas.has(estacao))
				if Peixes.raridade(id)=="comum": comuns+=1
			verificar("%s estação %d respeita época e favorece fáceis" % [ambiente,estacao],sazonal and comuns>2700 and comuns<3400)
	var mini: Control = load("res://codigo/pesca/minijogo_pesca.gd").new()
	ui2.add_child(mini)
	mini.iniciar(p2,"CARPA",22,1)
	mini.decorrido = 100
	mini._novo_check()
	verificar("nível 1 tem zona ampla e erro tolerável",mini.tamanho_zona>1 and mini.ganho_bom==18 and mini.perda_erro==8 and mini.progresso==32)
	mini.iniciar(p2,"GUARDIAO DO LAGO",90,5)
	mini.decorrido = 100
	mini._novo_check()
	var zona_fraca: float = mini.tamanho_zona
	var velocidade_fraca: float = mini.ponteiro_velocidade
	mini.iniciar(p1,"GUARDIAO DO LAGO",90,5)
	mini.decorrido = 100
	mini._novo_check()
	verificar("peixe avançado quase impossível na vara fraca",zona_fraca<0.03 and mini.tamanho_zona>zona_fraca*10 and mini.ponteiro_velocidade<velocidade_fraca)
	mini.queue_free()
	var habilidade := load("res://codigo/pesca/progressao_pesca.gd")
	fazenda.pesca_xp = {"p1": habilidade.xp_para_nivel(30), "p2": habilidade.xp_para_nivel(70)}
	ui1._abrir_tela("inventario")
	ui2._abrir_tela("inventario")
	await create_timer(0.3).timeout
	var inv1: Node = ui1._telas["inventario"]
	var inv2: Node = ui2._telas["inventario"]
	inv1.selecionar_pagina(3)
	inv2.selecionar_pagina(3)
	await quadros(8)
	verificar("catálogo dentro da aba de cada inventário",inv1._pesca.visible and inv2._pesca.visible and inv1._pesca!=inv2._pesca)
	verificar("catálogo mostra todas as espécies",inv1._pesca._grade_peixes.get_child_count()==Peixes.DADOS.size() and inv1._pesca._grade_peixes.columns>=3)
	verificar("cada catálogo mostra XP do próprio jogador", inv1._pesca._lista.get_node("ProgressaoPesca").get_child(0).text.contains("NV 30") and inv2._pesca._lista.get_node("ProgressaoPesca").get_child(0).text.contains("NV 70"))
	if DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://arte/previas/pesca/progressao_99"))
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://arte/previas/pesca/progressao_99/coop.png")
	verificar("não pescado aparece preto",inv1._pesca._grade_peixes.get_child(0).get_node("Icone").modulate == Color.BLACK)
	verificar("cada catálogo mostra sua vara",inv1._pesca._lista.get_child(1).text.contains("NV 5") and inv2._pesca._lista.get_child(1).text.contains("NV 1"))
	inv1._pesca._desafios_pesca = true
	inv1._pesca._atualizar()
	verificar("desafios não trocam a aba do parceiro",not inv2._pesca._desafios_pesca and inv1._pesca._lista.get_child_count()>60)
	ui1._fechar_tela("inventario")
	ui2._fechar_tela("inventario")
	cidade.conversar("nilo",p1)
	await quadros()
	cidade.conversar("mercador",p2)
	await quadros()
	var d1: Node = ui1._telas["conversa_cidade"]
	var d2: Node = ui2._telas["conversa_cidade"]
	verificar("coop mantém conversas diferentes",d1._id_atual=="nilo" and d2._id_atual=="mercador" and d1._titulo.text=="NILO" and d2._titulo.text=="TOMAS")
	verificar("ambos os NPCs permanecem em conversa",cidade.em_conversa("nilo") and cidade.em_conversa("mercador"))
	ui1._fechar_tela("conversa_cidade")
	cidade.atender("nilo", "servicos", p1)
	await quadros()
	d1._ver_vara()
	await create_timer(0.35).timeout
	await quadros()
	var oficina: Control = ui1._telas["oficina_vara"]
	verificar("oficina mostra comparacao e nivel maximo",oficina.visible and oficina._comparacao.get_child_count()==2 and oficina._refinar.disabled and oficina._refinar.text.contains("MAXIMO"))
	await botao(JOY_BUTTON_B)
	verificar("B fecha somente a conversa do P2",not d2.visible and oficina.visible)
	ui1._fechar_tela("oficina_vara")
	print("FALHAS: ",falhas)
	quit(1 if falhas else 0)
