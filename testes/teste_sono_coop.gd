extends SceneTree

## Sono no cooperativo (pedido de 2026-10-16): quem deita espera o parceiro (e pode levantar com B), a noite só passa com
## os dois deitados, e depois todas as iluminações abertas vão para as 6h (antes a casa voltava na hora em que dormiram).
## Saves isolados obrigatórios.

const P1 := 41
const P2 := 40

var falhas := 0
var coop: Node
var transicao: Node
var calendario: Node

func _initialize() -> void:
	_rodar()

func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ", nome)
	if not ok:
		falhas += 1

func quadros(n := 4) -> void:
	for i in n:
		await process_frame

func botao(dispositivo: int, indice: int) -> void:
	for pressionado in [true, false]:
		var evento := InputEventJoypadButton.new()
		evento.device = dispositivo
		evento.button_index = indice
		evento.pressed = pressionado
		Input.parse_input_event(evento)
		await quadros(3)

func _rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"):
		push_error("Use saves isolados.")
		quit(1)
		return
	await process_frame
	coop = root.get_node("Cooperativo")
	transicao = root.get_node("Transicao")
	calendario = root.get_node("Calendario")
	root.get_node("Saves").trocar("coop")
	root.get_node("Introducao").pular_prologo()
	for nome in ["InventarioJogador", "InventarioJogador2"]:
		root.get_node(nome).limpar()
		root.get_node(nome).criar_itens_iniciais()
	coop.entrar(P2)
	coop.dispositivo_p1 = P1
	coop.dispositivo_p2 = P2
	coop._reconfigurar_entrada()
	transicao.hora_salva = 21.0
	change_scene_to_file("res://cenas/cidade.tscn")
	await quadros(40)
	var p1: Node2D = coop._jogador1()
	var p2: Node2D = coop.jogador2()
	verificar("dois jogadores na vila", p1 != null and p2 != null)
	if p1 == null or p2 == null:
		quit(1)
		return
	# Cada um entra sozinho na casa: ela abre num ambiente à parte, com a iluminação dela
	await coop.viajar_local(p1, "res://cenas/casa.tscn", "entrada")
	await quadros(10)
	await coop.viajar_local(p2, "res://cenas/casa.tscn", "entrada")
	await quadros(20)
	verificar("os dois na casa", p1.get_world_2d() == p2.get_world_2d() and p1.get_world_2d() != current_scene.get_world_2d())
	for luz in get_nodes_in_group("iluminacao"):
		luz.definir_hora(21.0)
	var dia: int = calendario.dia

	# Só o P1 deita: espera, sem a noite passar
	transicao.dormir("cama", p1)
	await quadros(90)
	verificar("P1 deitado esperando (some ou na cama)", not p1.visible and not p1.movimento_habilitado)
	verificar("sozinho a noite nao passa", calendario.dia == dia and not transicao.ocupada)
	verificar("P2 continua livre", p2.visible and p2.movimento_habilitado)
	# P1 desiste com B
	await quadros(30)
	await botao(P1, JOY_BUTTON_B)
	await quadros(6)
	verificar("B levanta o P1 da espera", p1.visible and p1.movimento_habilitado and transicao._esperando_dormir.is_empty())
	verificar("cama livre de novo", get_nodes_in_group("cama").all(func(cama): return not cama.deitado))

	# Agora os dois deitam (P2 primeiro, para variar)
	transicao.dormir("cama", p2)
	await quadros(30)
	verificar("P2 esperando o P1", not p2.visible and calendario.dia == dia)
	transicao.dormir("cama", p1)
	var passou := false
	for i in 600:
		await process_frame
		if not transicao.ocupada and calendario.dia == dia + 1:
			passou = true
			break
	verificar("com os dois deitados a noite passa", passou)
	await quadros(10)
	var horas := []
	for luz in get_nodes_in_group("iluminacao"):
		horas.append(snappedf(luz.hora, 0.1))
	verificar("todas as iluminacoes acordam as 6h %s" % [horas], not horas.is_empty() and horas.all(func(h): return h >= 6.0 and h < 6.5))
	_conferir_relogios("ambiente")
	verificar("os dois acordam visiveis e livres", p1.visible and p2.visible and p1.movimento_habilitado and p2.movimento_habilitado)
	verificar("nao acordam um em cima do outro", p1.global_position.distance_to(p2.global_position) > 4.0)
	verificar("ninguem fica na fila de espera", transicao._esperando_dormir.is_empty() and transicao._deitados.is_empty())
	await _vila_fazenda_casa()
	await _casa_como_cena_principal()
	coop.sair()
	await quadros()
	print("FALHAS: ", falhas)
	quit(1 if falhas else 0)

## O que o jogador vê: o texto do relógio no HUD de cada metade
func _conferir_relogios(caso: String) -> void:
	var textos := []
	for hud in get_nodes_in_group("hud"):
		if hud.get("rotulo_hora") != null and hud.rotulo_hora.visible:
			textos.append(hud.rotulo_hora.text)
	verificar("%s: relogio dos HUDs marca 06h %s" % [caso, textos], not textos.is_empty() and textos.all(func(t): return t.begins_with("06:")))

## Os dois entram juntos (a casa é a cena principal) e dormem
func _casa_como_cena_principal() -> void:
	transicao.hora_salva = 22.0
	change_scene_to_file("res://cenas/casa.tscn")
	await quadros(40)
	var p1: Node2D = coop._jogador1()
	var p2: Node2D = coop.jogador2()
	var dia: int = calendario.dia
	transicao.dormir("cama", p1)
	await quadros(20)
	transicao.dormir("cama", p2)
	var passou := false
	for i in 600:
		await process_frame
		if not transicao.ocupada and calendario.dia == dia + 1:
			passou = true
			break
	await quadros(10)
	verificar("casa principal: noite passa com os dois", passou)
	var horas := []
	for luz in get_nodes_in_group("iluminacao"):
		horas.append(snappedf(luz.hora, 0.1))
	# A casa não tem iluminação própria (o relógio some lá dentro): a hora certa vale na saída
	verificar("casa principal: hora guardada para a saida e 6h", is_equal_approx(transicao.hora_salva, 6.0))
	await coop.viajar_local(p1, "res://cenas/fazenda.tscn", "casa")
	await quadros(10)
	await coop.viajar_local(p2, "res://cenas/fazenda.tscn", "casa")
	await quadros(30)
	horas.clear()
	for luz in get_nodes_in_group("iluminacao"):
		horas.append(snappedf(luz.hora, 0.1))
	print("DEBUG saida: luzes=%s hora_salva=%s" % [horas, transicao.hora_salva])
	_conferir_relogios("saindo da casa")

## O caso relatado: vila às 22h -> fazenda -> casa, os dois dormem e saem para a fazenda. A fazenda (ambiente com
## iluminação própria) ficava escura às 22h porque só a primeira iluminação voltava para as 6h
func _vila_fazenda_casa() -> void:
	transicao.hora_salva = 22.0
	change_scene_to_file("res://cenas/cidade.tscn")
	await quadros(40)
	var p1: Node2D = coop._jogador1()
	var p2: Node2D = coop.jogador2()
	for jogador in [p1, p2]:
		await coop.viajar_local(jogador, "res://cenas/fazenda.tscn", "cidade")
		await quadros(10)
	for jogador in [p1, p2]:
		await coop.viajar_local(jogador, "res://cenas/casa.tscn", "entrada")
		await quadros(10)
	for luz in get_nodes_in_group("iluminacao"):
		luz.definir_hora(22.0)
	var luzes := get_nodes_in_group("iluminacao").size()
	verificar("vila+fazenda abertas: %d iluminacoes" % luzes, luzes >= 2)
	var dia: int = calendario.dia
	transicao.dormir("cama", p1)
	await quadros(20)
	transicao.dormir("cama", p2)
	for i in 600:
		await process_frame
		if not transicao.ocupada and calendario.dia == dia + 1:
			break
	await quadros(10)
	for jogador in [p1, p2]:
		await coop.viajar_local(jogador, "res://cenas/fazenda.tscn", "casa")
		await quadros(10)
	await quadros(20)
	var horas := []
	for luz in get_nodes_in_group("iluminacao"):
		horas.append(snappedf(luz.hora, 0.1))
	verificar("vila>fazenda>casa: dia virou", calendario.dia == dia + 1)
	verificar("vila>fazenda>casa: todas as luzes de manha %s" % [horas], horas.all(func(h): return h >= 6.0 and h < 6.6))
	_conferir_relogios("vila>fazenda>casa, de volta na fazenda")
