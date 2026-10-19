extends SceneTree

## Pesca em cooperativo: os dois jogadores pescam ao mesmo tempo na praia compartilhada. Cada um tem a própria sessão,
## minijogo na própria metade da tela, mochila de peixes e vara; cancelar/terminar um não afeta o outro.
## Saves isolados obrigatórios.

const P1 := 41
const P2 := 40

var falhas := 0

func _initialize() -> void:
	_rodar()

func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ", nome)
	if not ok:
		falhas += 1

func quadros(n := 4) -> void:
	for i in n:
		await physics_frame
		await process_frame

func _rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"):
		push_error("Use saves isolados.")
		quit(1)
		return
	await process_frame
	var Sessao := load("res://codigo/pesca/sessao_pesca.gd")
	root.get_node("Saves").trocar("coop")
	root.get_node("Introducao").pular_prologo()
	for nome in ["InventarioJogador", "InventarioJogador2"]:
		root.get_node(nome).limpar()
		root.get_node(nome).criar_itens_iniciais()
	var coop: Node = root.get_node("Cooperativo")
	coop.entrar(P2)
	coop.dispositivo_p1 = P1
	coop.dispositivo_p2 = P2
	coop._reconfigurar_entrada()
	root.get_node("Fazenda").definir_clima_hoje(0)
	root.get_node("Transicao").hora_salva = 12.0
	change_scene_to_file("res://cenas/praia.tscn")
	await quadros(40)
	var praia := current_scene
	var p1: CharacterBody2D = coop._jogador1()
	var p2: CharacterBody2D = coop.jogador2()
	verificar("os dois jogadores na praia", p1 != null and p2 != null and p1.get_world_2d() == p2.get_world_2d())
	if p1 == null or p2 == null:
		quit(1)
		return
	var leste: Area2D = praia.get_node("PescaPierLeste")
	var oeste: Area2D = praia.get_node("PescaOeste")
	var fazenda: Node = root.get_node("Fazenda")
	p1.global_position = leste.global_position
	p2.global_position = oeste.global_position
	await quadros(8)
	for quem in [p1,p2]: root.get_node("EventosJogo").inventario_de(quem).definir_vara_na_mao(true)
	verificar("os dois podem pescar", leste.pode_interagir_para(p1) and oeste.pode_interagir_para(p2))
	for quem in [p1,p2]:
		Input.action_press(quem.acao("attack"))
		quem._pedido_ataque = true
		quem.logica_combo_ataque()
	await quadros(3)
	verificar("cada um tem a própria sessão", Sessao.em_andamento(p1) and Sessao.em_andamento(p2) and p1.get_node("SessaoPesca") != p2.get_node("SessaoPesca"))
	verificar("cada jogador carrega sua própria força",p1.get_node("SessaoPesca").estado == Sessao.Estado.CARREGANDO and p2.get_node("SessaoPesca").estado == Sessao.Estado.CARREGANDO)
	Input.action_release(p1.acao("attack"))
	await quadros(3)
	verificar("soltar P1 não lança a linha de P2",p1.get_node("SessaoPesca").estado == Sessao.Estado.LANCANDO and p2.get_node("SessaoPesca").estado == Sessao.Estado.CARREGANDO)
	Input.action_release(p2.acao("attack"))
	await quadros(3)
	verificar("os dois travam o próprio movimento", not p1.movimento_habilitado and not p2.movimento_habilitado)
	verificar("não dá para lançar de novo na mesma sessão", not leste.pode_interagir_para(p1) and not oeste.pode_interagir_para(p2))
	# P2 cancela antes do minigame sem mexer em P1.
	var s1: Node = p1.get_node("SessaoPesca")
	var s2: Node = p2.get_node("SessaoPesca")
	s2._guarda_entrada = 0.0
	s2._terminar()
	await quadros(4)
	verificar("cancelar P2 libera só P2", not Sessao.em_andamento(p2) and p2.movimento_habilitado and Sessao.em_andamento(p1) and not p1.movimento_habilitado)
	oeste.abrir_tela_p2()
	await quadros(3)
	s2 = p2.get_node("SessaoPesca")
	# Pula as esperas: os dois peixes beliscam e viram minijogos.
	for s in [s1, s2]:
		s._guarda_entrada = 0.0
		s._esperar()
		s._espera = 0.0
	await quadros(4)
	verificar("os dois peixes beliscam", s1.estado == s1.Estado.BELISCANDO and s2.estado == s2.Estado.BELISCANDO)
	s1._puxar()
	s2._puxar()
	await quadros(3)
	var m1: Control = s1._minijogo
	var m2: Control = s2._minijogo
	verificar("dois minijogos distintos", m1 != null and m2 != null and m1 != m2)
	var i1: Node = root.get_node("EventosJogo").interface_p1()
	var i2: Node = coop.interface_p2()
	verificar("cada minijogo na interface do dono", m1.get_parent() == i1 and m2.get_parent() == i2 and i1 != i2)
	verificar("minijogos apontam para o dono", m1.jogador == p1 and m2.jogador == p2)
	var antes1: int = int(fazenda.total_de_peixes(p1))
	var antes2: int = int(fazenda.total_de_peixes(p2))
	# P1 vence, P2 perde: resultados independentes.
	m1._encerrar(true)
	m2._encerrar(false)
	await create_timer(0.5).timeout
	verificar("P1 pegou o peixe, P2 não", int(fazenda.total_de_peixes(p1)) == antes1 + 1 and int(fazenda.total_de_peixes(p2)) == antes2)
	verificar("P2 liberado após falhar, P1 comemorando", not Sessao.em_andamento(p2) and p2.movimento_habilitado and Sessao.em_andamento(p1))
	await create_timer(2.6).timeout
	verificar("P1 liberado ao fim", not Sessao.em_andamento(p1) and p1.movimento_habilitado)
	verificar("nenhum minijogo sobrou nas interfaces", not is_instance_valid(m1) or m1.is_queued_for_deletion())
	# Os dois vencem ao mesmo tempo.
	leste.abrir_tela()
	oeste.abrir_tela_p2()
	await quadros(3)
	s1 = p1.get_node("SessaoPesca")
	s2 = p2.get_node("SessaoPesca")
	for s in [s1, s2]:
		s._guarda_entrada = 0.0
		s._esperar()
		s._espera = 0.0
	await quadros(4)
	s1._puxar()
	s2._puxar()
	await quadros(3)
	var t1: int = int(fazenda.total_de_peixes(p1))
	var t2: int = int(fazenda.total_de_peixes(p2))
	s1._minijogo._encerrar(true)
	s2._minijogo._encerrar(true)
	await create_timer(0.5).timeout
	verificar("os dois pescam, cada peixe na mochila certa", int(fazenda.total_de_peixes(p1)) == t1 + 1 and int(fazenda.total_de_peixes(p2)) == t2 + 1)
	await create_timer(2.6).timeout
	verificar("os dois liberados", not Sessao.em_andamento(p1) and not Sessao.em_andamento(p2) and p1.movimento_habilitado and p2.movimento_habilitado)
	# P2 sai da cena no meio da pescaria (viaja sozinho): sem crash e P1 intacto.
	p1.global_position = leste.global_position
	await quadros(4)
	var args := OS.get_cmdline_user_args()
	if "--ambos" in args or "--so-p1" in args:
		leste.abrir_tela()
	if "--ambos" in args or "--so-p2" in args:
		oeste.abrir_tela_p2()
	await quadros(3)
	coop.viajar_local(p2, "res://cenas/cidade.tscn", "praia")
	await quadros(60)
	verificar("P1 segue pescando enquanto P2 viaja", Sessao.em_andamento(p1) or p1.movimento_habilitado)
	verificar("P2 não ficou preso numa sessão", not Sessao.em_andamento(p2) and p2.movimento_habilitado)
	# O inverso: P1 pescando sai pela porta da praia para a cidade; P2 continua na praia, sem ser arrastado.
	if "--p1-sai" in args:
		coop.viajar_local(p2, "res://cenas/praia.tscn", "cidade")
		await quadros(60)
		p1.global_position = leste.global_position
		p2.global_position = oeste.global_position
		await quadros(4)
		leste.abrir_tela()
		oeste.abrir_tela_p2()
		await quadros(3)
		var porta: Area2D
		for no in praia.get_children():
			if no.get("cena_destino") == "res://cenas/cidade.tscn":
				porta = no
		p1.get_node("SessaoPesca")._terminar()
		await quadros(3)
		verificar("P1 pescando não atravessa; cancelar libera", p1.movimento_habilitado)
		p1.global_position = porta.global_position
		await quadros(6)
		verificar("porta liberada para o P1", porta.pode_interagir_para(p1))
		porta._atravessar(p1)
		await quadros(60)
		verificar("P1 foi para a cidade", coop.cena_de(p1).scene_file_path == "res://cenas/cidade.tscn")
		verificar("P2 ficou na praia", coop.cena_de(p2).scene_file_path == "res://cenas/praia.tscn")
		verificar("mundos separados", p1.get_world_2d() != p2.get_world_2d())
		verificar("P2 continua pescando", Sessao.em_andamento(p2) and not p2.movimento_habilitado)
		verificar("P1 não ficou preso na pesca", not Sessao.em_andamento(p1) and p1.movimento_habilitado)
	print("FALHAS: ", falhas)
	quit(1 if falhas else 0)
