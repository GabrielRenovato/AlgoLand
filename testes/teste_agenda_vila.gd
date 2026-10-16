extends SceneTree

## Agenda da vila (codigo/globais/agenda_vila.gd): aviso da festa de sábado na taverna e o pombo-correio com as cartas
## de pedido, no jogo solo, no cooperativo (duas metades) e no toque (Android simulado). Saves isolados.
const P2 := 40
var Dados: GDScript
var falhas := 0
var coop: Node
var agenda: Node
var cidade_estado: Node
var calendario: Node

func _initialize() -> void:
	_rodar()

func verificar(nome: String, ok: bool, detalhe := "") -> void:
	print(("OK " if ok else "FALHA ") + nome + ("" if ok or detalhe == "" else ": " + detalhe))
	if not ok:
		falhas += 1

func quadros(n := 8) -> void:
	for i in n:
		await process_frame

func _luz() -> Node:
	return current_scene.get_node("Iluminacao")

func _banners() -> Array:
	var textos := []
	for hud in get_nodes_in_group("hud"):
		textos.append(hud.rotulo_banner.text)
	return textos

func _limpar_banners() -> void:
	for hud in get_nodes_in_group("hud"):
		hud.rotulo_banner.text = ""

## Hora e dia do relógio da vila, e a agenda conferindo como no jogo
func _no_horario(dia: int, hora: float) -> void:
	calendario.dia = dia
	_luz().definir_hora(hora)
	agenda.verificar()
	await quadros(2)

func _esperar_pouso(pombo: Node, limite := 8.0) -> bool:
	var tempo := 0.0
	while is_instance_valid(pombo) and pombo.estado != pombo.Estado.POUSADO and tempo < limite:
		await process_frame
		tempo += 1.0 / 60.0
	await quadros(4)
	return is_instance_valid(pombo) and pombo.estado == pombo.Estado.POUSADO

func _apertar(acao: String) -> void:
	Input.action_press(acao)
	await process_frame
	await process_frame
	Input.action_release(acao)
	await quadros(4)

func _carta(interface: Node) -> Node:
	return interface._telas["conversa_cidade"]

func _botao(tela: Node, texto: String) -> Button:
	for botao in tela._botoes:
		if botao.text == texto:
			return botao
	return null

func _resetar_cartas() -> void:
	cidade_estado.missoes = {}
	cidade_estado.cartas = {}
	cidade_estado.carta_aberta = ""
	agenda.anunciados.clear()
	cidade_estado.carta_pendente = false
	agenda.esperando_sair = false

func _rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"):
		push_error("Execute pelo testar_coop.py com save isolado.")
		quit(1)
		return
	await process_frame
	Dados = load("res://codigo/cidade/dados_cidade.gd")
	coop = root.get_node("Cooperativo")
	agenda = root.get_node("AgendaVila")
	cidade_estado = root.get_node("Cidade")
	calendario = root.get_node("Calendario")
	root.size = Vector2i(1440, 648)
	# Solo primeiro: o save "coop" reabre o jogador 2
	root.get_node("Saves").trocar("solo")
	root.get_node("Introducao").pular_prologo()
	if coop.ativo:
		coop.sair()
	for nome in ["InventarioJogador", "InventarioJogador2"]:
		root.get_node(nome).limpar()
		root.get_node(nome).criar_itens_iniciais()
	verificar("a agenda fica desligada nos testes ate ser chamada", not agenda.ligada)
	await _eventos_solo()
	await _pombo_solo()
	await _cartas_misteriosas()
	await _pombo_toque()
	await _coop()
	print("FALHAS: ", falhas)
	quit(1 if falhas else 0)

# --- Festa de sábado ------------------------------------------------------------------------------------------------

func _eventos_solo() -> void:
	_resetar_cartas()
	calendario.dia = 5
	change_scene_to_file("res://cenas/cidade.tscn")
	await quadros(30)
	# O pombo também viria às 9h: aqui só os avisos (todas as cartas já lidas)
	for id in Dados.MISSOES:
		cidade_estado.cartas[id] = 1
	_limpar_banners()
	await _no_horario(5, 19.0)
	verificar("sexta a noite nao anuncia festa", _banners() == [""], str(_banners()))
	await _no_horario(6, 9.0)
	verificar("sabado de manha: convite da festa no banner", _banners() == ["HOJE TEM FESTA NA TAVERNA"], str(_banners()))
	verificar("convite diz o horario", get_nodes_in_group("hud")[0].subtitulo_banner.text.contains("18H"))
	_limpar_banners()
	await _no_horario(6, 12.0)
	verificar("o convite nao se repete no mesmo dia", _banners() == [""], str(_banners()))
	await _no_horario(6, 18.0)
	verificar("as 18h: a festa comecou", _banners() == ["A FESTA NA TAVERNA COMECOU!"], str(_banners()))
	_limpar_banners()
	await _no_horario(7, 1.0)
	# (à meia-noite o HUD mostra o aviso de cansaço no mesmo banner)
	verificar("depois da meia-noite a mesma festa nao e anunciada de novo", not _banners().has("A FESTA NA TAVERNA COMECOU!"), str(_banners()))
	# Trocar de cena não repete o aviso (o registro é da agenda, não do HUD)
	change_scene_to_file("res://cenas/fazenda.tscn")
	await quadros(30)
	_limpar_banners()
	await _no_horario(6, 19.0)
	verificar("na fazenda, depois de anunciada, a festa nao repete", _banners() == [""], str(_banners()))
	# Chegando a festa já começada (carregou o jogo de madrugada), o aviso aparece uma vez
	agenda.anunciados.clear()
	await _no_horario(14, 0.5)
	verificar("madrugada de domingo: anuncia a festa de sabado em andamento (chave do sabado)", agenda.anunciados.keys() == ["festa_sabado:comecou:13"], str(agenda.anunciados.keys()))
	verificar("mural de sabado mostra a festa", _mural_tem_festa())

func _mural_tem_festa() -> bool:
	calendario.dia = 6
	var tela: Node = root.get_node("EventosJogo").interface_p1()._telas["mural_cidade"]
	tela._atualizar()
	for filho in tela._lista.get_children():
		if filho is Label and filho.text.contains("FESTA NA TAVERNA"):
			return true
	return false

# --- Pombo-correio (solo, teclado/controle) -------------------------------------------------------------------------

## Casa da fazenda -> dormir -> sair pela porta: só então o pombo vem
func _dormir_e_sair(espera_carta := true) -> void:
	change_scene_to_file("res://cenas/casa.tscn")
	await quadros(30)
	calendario.dormir()
	agenda.verificar()
	await quadros(2)
	if espera_carta:
		verificar("dormiu: carta pendente, mas dentro de casa o pombo nao vem", cidade_estado.carta_pendente and agenda.pombo == null)
	current_scene.get_node("SaidaCasa")._atravessar(coop._jogador1())
	var limite := 0
	while (current_scene == null or not current_scene.scene_file_path.ends_with("fazenda.tscn") or root.get_node("Transicao").ocupada) and limite < 600:
		await process_frame
		limite += 1
	await quadros(10)
	agenda.verificar()
	await quadros(2)

func _pombo_solo() -> void:
	_resetar_cartas()
	calendario.dia = 2
	change_scene_to_file("res://cenas/fazenda.tscn")
	await quadros(30)
	await _no_horario(2, 10.0)
	verificar("sem dormir o pombo nao vem (nao chega a qualquer momento)", agenda.pombo == null)
	await _dormir_e_sair()
	var jogador: Node2D = coop._jogador1()
	var interface: Node = root.get_node("EventosJogo").interface_p1()
	var pombo: Node2D = agenda.pombo
	verificar("ao sair de casa depois de dormir, o pombo-correio vem", pombo != null and current_scene.scene_file_path.ends_with("fazenda.tscn") and pombo.get_parent() == current_scene)
	if pombo == null:
		return
	verificar("traz o primeiro pedido (Lia)", pombo.missao == "boas_vindas", pombo.missao)
	verificar("banner avisa a carta", _banners() == ["POMBO-CORREIO!"], str(_banners()))
	verificar("chega voando de longe", pombo.global_position.distance_to(jogador.global_position) > 200.0 and pombo.altura > 0.0)
	verificar("pousa ao lado do jogador", await _esperar_pouso(pombo) and pombo.global_position.distance_to(jogador.global_position) < 30.0)
	verificar("pousado mostra o aviso de interagir", pombo._aviso.visible)
	verificar("envelope no chao a frente dele", pombo._envelope.visible and pombo.altura == 0.0)
	await _apertar("open_menu")
	var tela := _carta(interface)
	verificar("interagir abre a carta na caixa de conversa", interface._telas_abertas.has("conversa_cidade") and tela._carta)
	verificar("titulo: CARTA DE LIA", tela._titulo.text == "CARTA DE LIA", tela._titulo.text)
	verificar("a carta tem o pedido e a recompensa", tela._fala.text.contains("CONHECA SEUS VIZINHOS") and tela._fala.text.contains("Brasas"))
	verificar("botoes ACEITAR e DEPOIS", _botao(tela, "ACEITAR") != null and _botao(tela, "DEPOIS") != null)
	verificar("ler a carta nao conta como conversa (sem amizade)", int(cidade_estado.amizade.get("lia", 0)) == 0)
	_botao(tela, "ACEITAR").pressed.emit()
	await quadros()
	verificar("ACEITAR aceita o pedido", cidade_estado.missoes.get("boas_vindas", {}).get("estado", "") == "aceita")
	verificar("depois de aceitar: diz com quem entregar e oferece FECHAR", tela._fala.text.contains("Lia") and _botao(tela, "FECHAR") != null, tela._fala.text)
	_botao(tela, "FECHAR").pressed.emit()
	await quadros()
	verificar("fechar devolve o movimento", not interface._telas_abertas.has("conversa_cidade") and jogador.movimento_habilitado)
	verificar("carta lida: nada mais pendente hoje", cidade_estado.cartas.has("boas_vindas") and not cidade_estado.carta_pendente)
	verificar("o pombo vai embora", is_instance_valid(pombo) and pombo.estado == pombo.Estado.PARTINDO)
	await create_timer(3.0).timeout
	verificar("e some depois de voar", not is_instance_valid(pombo) and agenda.pombo == null)
	agenda.verificar()
	verificar("um pombo por noite dormida", agenda.pombo == null)
	# Noite seguinte: o próximo pedido; o jogador se afasta e o pombo vai atrás; DEPOIS fecha sem aceitar
	await _dormir_e_sair()
	pombo = agenda.pombo
	verificar("depois de dormir de novo traz o proximo pedido", pombo != null and pombo.missao == "passeio")
	if pombo == null:
		return
	await _esperar_pouso(pombo)
	jogador = coop._jogador1()
	jogador.global_position += Vector2(0, 120)
	await quadros(4)
	verificar("jogador longe: o pombo levanta voo atras dele", pombo.estado == pombo.Estado.CHEGANDO)
	verificar("e pousa de novo ao lado", await _esperar_pouso(pombo) and pombo.global_position.distance_to(jogador.global_position) < 30.0)
	await _apertar("open_menu")
	tela = _carta(root.get_node("EventosJogo").interface_p1())
	_botao(tela, "DEPOIS").pressed.emit()
	await quadros()
	verificar("DEPOIS nao aceita o pedido", not cidade_estado.missoes.has("passeio") and cidade_estado.cartas.has("passeio"))
	verificar("o pedido continua no mural/morador", cidade_estado.proxima_carta() == "horta")
	await create_timer(3.0).timeout
	# Ignorado: o pombo vai embora e a carta espera a próxima saída de casa
	await _dormir_e_sair()
	pombo = agenda.pombo
	verificar("terceira noite: pombo vem", pombo != null)
	if pombo != null:
		pombo.alvo = null
		await quadros(2)
		verificar("sem o destinatario por perto ele vai embora", pombo.estado == pombo.Estado.PARTINDO)
		await create_timer(3.0).timeout
		verificar("sem entregar a carta continua pendente", cidade_estado.carta_pendente and not cidade_estado.cartas.has("horta"))
		agenda.verificar()
		verificar("ainda la fora: nao volta na hora", agenda.pombo == null)
		change_scene_to_file("res://cenas/casa.tscn")
		await quadros(30)
		agenda.verificar()
		change_scene_to_file("res://cenas/fazenda.tscn")
		await quadros(30)
		agenda.verificar()
		verificar("na proxima saida de casa ele volta com a carta", agenda.pombo != null and agenda.pombo.missao == "horta")
		if agenda.pombo != null:
			agenda.pombo.queue_free()
			agenda.pombo = null
	var luz := _luz()
	luz.em_arena = true
	verificar("na arena (relogio proprio) a agenda nao roda", agenda.hora_da_vila() < 0.0)
	luz.em_arena = false

# --- Cartas sem remetente --------------------------------------------------------------------------------------------

func _ler_carta_do_pombo() -> Node:
	var pombo: Node2D = agenda.pombo
	if pombo == null:
		return null
	await _esperar_pouso(pombo)
	await _apertar("open_menu")
	return _carta(root.get_node("EventosJogo").interface_p1())

func _cartas_misteriosas() -> void:
	_resetar_cartas()
	var progresso := root.get_node("Progresso")
	# Sábado -> dorme -> domingo de manhã: carta sem remetente, mesmo havendo pedidos
	calendario.dia = 13
	_limpar_banners()
	await _dormir_e_sair()
	var pombo: Node2D = agenda.pombo
	verificar("domingo: o pombo traz carta sem remetente", pombo != null and pombo.missao == "misterio_1", str(pombo.missao if pombo else null))
	if pombo == null:
		return
	verificar("misterio: envelope de selo roxo", pombo._envelope.texture == pombo.TEXTURA_ENVELOPE_MISTERIO)
	verificar("misterio: banner diz que nao tem remetente", get_nodes_in_group("hud")[0].subtitulo_banner.text == "CARTA SEM REMETENTE")
	var brasas_antes: int = progresso.brasas
	var tela: Node = await _ler_carta_do_pombo()
	verificar("misterio: titulo CARTA SEM REMETENTE", tela._titulo.text == "CARTA SEM REMETENTE", tela._titulo.text)
	verificar("misterio: bilhete assinado so com ?", tela._fala.text.contains("- ?") and tela._fala.text.contains("verao passado"))
	verificar("misterio: so GUARDAR (nada para aceitar)", _botao(tela, "GUARDAR") != null and _botao(tela, "ACEITAR") == null)
	_botao(tela, "GUARDAR").pressed.emit()
	await quadros()
	verificar("misterio: lida fica registrada e os pedidos continuam", cidade_estado.cartas.has("misterio_1") and cidade_estado.proxima_carta() == "boas_vindas")
	verificar("misterio: carta sem presente nao mexe nas Brasas", progresso.brasas == brasas_antes)
	await create_timer(3.0).timeout
	# Segunda-feira com pedido: volta a ser o pedido
	verificar("segunda-feira volta a ser pedido", cidade_estado.carta_do_dia() == "boas_vindas" or calendario.dia_da_semana() == 6)
	# Sem pedidos a entregar, as cartas misteriosas vêm em qualquer manhã, na ordem
	for id in Dados.MISSOES:
		cidade_estado.cartas[id] = 1
	cidade_estado.cartas["misterio_2"] = 1
	await _dormir_e_sair()
	pombo = agenda.pombo
	verificar("sem pedidos: carta misteriosa num dia comum", pombo != null and pombo.missao == "misterio_3" and calendario.dia_da_semana() != 6)
	brasas_antes = progresso.brasas
	tela = await _ler_carta_do_pombo()
	verificar("misterio com presente: o bilhete avisa as Brasas", tela != null and tela._fala.text.contains("3 Brasas"))
	if tela != null:
		_botao(tela, "GUARDAR").pressed.emit()
		await quadros()
	verificar("misterio com presente: ganha as Brasas uma vez", progresso.brasas == brasas_antes + 3, str(progresso.brasas - brasas_antes))
	await create_timer(3.0).timeout
	# Tudo lido: dormir não deixa carta pendente e o pombo não vem
	for carta in Dados.CARTAS_MISTERIOSAS:
		cidade_estado.cartas[carta["id"]] = 1
	await _dormir_e_sair(false)
	verificar("tudo lido: sem carta pendente e sem pombo", not cidade_estado.carta_pendente and agenda.pombo == null)

# --- Toque (Android) ------------------------------------------------------------------------------------------------

func _pombo_toque() -> void:
	_resetar_cartas()
	var controle := root.get_node("Controle")
	controle.usando_toque = true
	controle._tirar_mouse_das_acoes()
	change_scene_to_file("res://cenas/fazenda.tscn")
	await quadros(40)
	var interface: Node = root.get_node("EventosJogo").interface_p1()
	cidade_estado.marcar_carta_pendente()
	await _no_horario(8, 7.0)
	var pombo: Node2D = agenda.pombo
	verificar("toque: o pombo vem tambem na fazenda", pombo != null and pombo.get_parent() == current_scene)
	if pombo == null:
		controle.usando_toque = false
		return
	await _esperar_pouso(pombo)
	verificar("toque: aviso mostra AGIR", pombo._rotulo_tecla.text == "AGIR", pombo._rotulo_tecla.text)
	pombo._rotulo_tecla.pressed.emit()
	await quadros()
	verificar("toque: tocar no aviso abre a carta", interface._telas_abertas.has("conversa_cidade") and _carta(interface)._carta)
	_botao(_carta(interface), "ACEITAR").pressed.emit()
	await quadros()
	_botao(_carta(interface), "FECHAR").pressed.emit()
	await quadros()
	verificar("toque: pedido aceito pela carta", cidade_estado.missoes.has("boas_vindas"))
	controle.usando_toque = false
	await create_timer(3.0).timeout

# --- Cooperativo ----------------------------------------------------------------------------------------------------

func _coop() -> void:
	_resetar_cartas()
	root.get_node("Saves").trocar("coop")
	root.get_node("Introducao").pular_prologo()
	coop.entrar(P2)
	coop.dispositivo_p1 = coop.SEM_CONTROLE
	coop.dispositivo_p2 = P2
	coop._reconfigurar_entrada()
	change_scene_to_file("res://cenas/cidade.tscn")
	await quadros(40)
	verificar("coop: duas metades com HUD", get_nodes_in_group("hud").size() == 2, str(get_nodes_in_group("hud").size()))
	# Os dois veem o aviso da festa
	for id in Dados.MISSOES:
		cidade_estado.cartas[id] = 1
	_limpar_banners()
	await _no_horario(20, 9.0)
	verificar("coop: o convite aparece nas duas metades", _banners() == ["HOJE TEM FESTA NA TAVERNA", "HOJE TEM FESTA NA TAVERNA"], str(_banners()))
	cidade_estado.cartas = {}
	# P1 dentro de uma casa: a carta vai para o P2, que está na praça
	var p1: Node2D = coop._jogador1()
	var p2: Node2D = coop.jogador2()
	await coop.viajar_local(p1, "res://cenas/cidade/casa_bento.tscn", "entrada")
	await quadros()
	verificar("coop: P1 dentro de casa nao recebe pombo", not agenda.pode_receber(p1))
	cidade_estado.marcar_carta_pendente()
	await _no_horario(22, 7.0)
	var pombo: Node2D = agenda.pombo
	verificar("coop: o pombo vai para o P2 ao ar livre", pombo != null and pombo.alvo == p2)
	if pombo == null:
		return
	verificar("coop: pousa ao lado do P2", await _esperar_pouso(pombo) and pombo.global_position.distance_to(p2.global_position) < 30.0)
	var interface2: Node = coop.interface_p2()
	await _apertar("p2_open_menu")
	verificar("coop: botao do P2 abre a carta na metade dele", interface2._telas_abertas.has("conversa_cidade") and _carta(interface2)._carta)
	verificar("coop: a metade do P1 continua livre", root.get_node("EventosJogo").interface_p1()._telas_abertas.is_empty())
	_botao(_carta(interface2), "ACEITAR").pressed.emit()
	await quadros()
	_botao(_carta(interface2), "FECHAR").pressed.emit()
	await quadros()
	verificar("coop: pedido aceito vale para os dois (progresso compartilhado)", cidade_estado.missoes.has("boas_vindas"))
	verificar("coop: P2 volta a andar", p2.movimento_habilitado and interface2._telas_abertas.is_empty())
	await create_timer(3.0).timeout
	coop.sair()
	await quadros()
