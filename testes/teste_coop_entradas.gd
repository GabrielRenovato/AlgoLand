extends SceneTree

## Contrato de todas as entradas de jogo: controles reais simulados, sem acionar métodos de gameplay.
const P1 := 41
const P2 := 40
var falhas := 0
var verificacoes := 0
var coop: Node

func _initialize() -> void:
	_rodar()

func verificar(nome: String, ok: bool) -> void:
	verificacoes += 1
	print("OK " if ok else "FALHA ", nome)
	if not ok:
		falhas += 1

func enviar(evento: InputEvent, pressionado: bool) -> void:
	if evento is InputEventJoypadButton:
		evento.pressed = pressionado
	elif evento is InputEventJoypadMotion:
		evento.axis_value = signf(evento.axis_value) if pressionado else 0.0
	Input.parse_input_event(evento)
	Input.flush_buffered_events()

func _rodar() -> void:
	if not ProjectSettings.get_setting("application/config/use_custom_user_dir", false) or not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"):
		push_error("Execute pelo testar_coop.py com save isolado.")
		quit(1)
		return
	await process_frame
	coop = root.get_node("Cooperativo")
	root.get_node("Saves").trocar("coop")
	root.get_node("Introducao").pular_prologo()
	coop.dispositivo_p1 = P1
	coop.dispositivo_p2 = P2
	coop._reconfigurar_entrada()
	for acao in coop.ACOES_P2:
		var eventos := InputMap.action_get_events(acao)
		var quantidade := 0
		for modelo in eventos:
			if not (modelo is InputEventJoypadButton or modelo is InputEventJoypadMotion):
				continue
			quantidade += 1
			for dispositivo in [P1, P2, 42]:
				var evento: InputEvent = modelo.duplicate()
				evento.device = dispositivo
				enviar(evento, true)
				verificar("%s %s device %d: somente dono recebe" % [acao, modelo.as_text(), dispositivo], Input.is_action_pressed(acao) == (dispositivo == P1) and Input.is_action_pressed("p2_" + acao) == (dispositivo == P2))
				enviar(evento, false)
				verificar("%s device %d: soltura sem comando preso" % [acao, dispositivo], not Input.is_action_pressed(acao) and not Input.is_action_pressed("p2_" + acao))
		verificar(acao + ": tem entrada de controle", quantidade > 0)
		verificar(acao + ": mesma zona morta em P2", is_equal_approx(InputMap.action_get_deadzone(acao), InputMap.action_get_deadzone("p2_" + acao)))
		for evento in InputMap.action_get_events("p2_" + acao):
			verificar(acao + ": P2 não recebe teclado/mouse", (evento is InputEventJoypadButton or evento is InputEventJoypadMotion) and evento.device == P2)
	# Trocar os dispositivos deve remover os vínculos antigos.
	coop.dispositivo_p1 = P2
	coop.dispositivo_p2 = P1
	coop._reconfigurar_entrada()
	var ataque := InputEventJoypadButton.new()
	ataque.device = P1
	ataque.button_index = JOY_BUTTON_X
	enviar(ataque, true)
	verificar("reatribuição troca o dono do controle", Input.is_action_pressed("p2_attack") and not Input.is_action_pressed("attack"))
	enviar(ataque, false)
	coop.sair()
	for acao in coop.ACOES_P2:
		verificar("saída remove ação p2_" + acao, not InputMap.has_action("p2_" + acao))
	verificar("saída restaura controle solo", InputMap.action_get_events("attack").any(func(e): return e is InputEventJoypadButton and e.device == -1))
	print("VERIFICACOES: ", verificacoes, " FALHAS: ", falhas)
	quit(1 if falhas else 0)
