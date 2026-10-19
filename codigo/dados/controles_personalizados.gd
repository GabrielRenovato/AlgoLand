extends RefCounted

const CAMINHO := "user://opcoes.cfg"
const ACOES := {"move_up":"MOVER PARA CIMA", "move_down":"MOVER PARA BAIXO", "move_left":"MOVER PARA ESQUERDA", "move_right":"MOVER PARA DIREITA", "attack":"ATACAR / USAR", "aparar":"DEFENDER", "rolar":"ESQUIVAR", "open_menu":"INTERAGIR", "open_inventory":"MOCHILA", "open_map":"MAPA", "usar_pocao":"BEBER POCAO", "colher":"COLHER / MOVER ITEM", "arma_proxima":"PROXIMA ARMA", "fileira_proxima":"PROXIMA FILEIRA", "ferramenta_anterior":"ITEM ANTERIOR", "ferramenta_proxima":"PROXIMO ITEM", "pausar":"PAUSAR"}
static var _padroes := {}

static func preparar() -> void:
	if not _padroes.is_empty(): return
	for acao in ACOES:
		_padroes[acao] = InputMap.action_get_events(acao).duplicate(true)

static func _secao(lado: int, controle: bool) -> String:
	return "controle_p%d" % lado if controle else "teclado"

static func _mesmo(a: InputEvent, b: InputEvent, controle: bool) -> bool:
	if not controle: return a is InputEventKey and b is InputEventKey and a.physical_keycode == b.physical_keycode
	if a is InputEventJoypadButton and b is InputEventJoypadButton: return a.button_index == b.button_index
	return a is InputEventJoypadMotion and b is InputEventJoypadMotion and a.axis == b.axis and signf(a.axis_value) == signf(b.axis_value)

static func alterar(acao: String, evento: InputEvent, lado := 1, controle := false) -> String:
	preparar()
	if not ACOES.has(acao): return "ACAO DESCONHECIDA"
	var nome: String = "p2_"+acao if lado == 2 else acao
	if not InputMap.has_action(nome): return "JOGADOR INDISPONIVEL"
	if not controle and (not evento is InputEventKey or evento.physical_keycode == 0): return "ESCOLHA UMA TECLA"
	if controle and not (evento is InputEventJoypadButton or evento is InputEventJoypadMotion): return "ESCOLHA UM BOTAO OU EIXO"
	for outra in ACOES:
		if outra == acao: continue
		var nome_outra: String = "p2_"+outra if lado == 2 else outra
		if not InputMap.has_action(nome_outra): continue
		for atual in InputMap.action_get_events(nome_outra):
			if _mesmo(atual,evento,controle): return "JA USADO: " + ACOES[outra]
	var config := ConfigFile.new()
	config.load(CAMINHO)
	var dado := {"tecla":int(evento.physical_keycode)} if evento is InputEventKey else ({"botao":int(evento.button_index)} if evento is InputEventJoypadButton else {"eixo":int(evento.axis),"valor":float(evento.axis_value)})
	config.set_value(_secao(lado,controle),acao,dado)
	if config.save(CAMINHO) != OK: return "NAO FOI POSSIVEL SALVAR"
	aplicar()
	return ""

static func aplicar() -> void:
	preparar()
	var config := ConfigFile.new()
	config.load(CAMINHO)
	for lado in [1,2]:
		for acao in ACOES:
			var nome: String = "p2_"+acao if lado == 2 else acao
			if not InputMap.has_action(nome): continue
			for controle in [false,true]:
				if lado == 2 and not controle: continue
				var device := -1
				for atual in InputMap.action_get_events(nome):
					if atual is InputEventJoypadButton or atual is InputEventJoypadMotion: device = atual.device
				var personalizados: Dictionary = config.get_value(_secao(lado,controle),acao,{})
				var eventos: Array = []
				if personalizados.is_empty():
					for padrao in _padroes[acao]:
						if (padrao is InputEventJoypadButton or padrao is InputEventJoypadMotion) if controle else padrao is InputEventKey: eventos.append(padrao.duplicate())
				else:
					var evento: InputEvent
					if personalizados.has("tecla"):
						evento = InputEventKey.new()
						evento.physical_keycode = int(personalizados.tecla)
					elif personalizados.has("botao"):
						evento = InputEventJoypadButton.new()
						evento.button_index = int(personalizados.botao)
					else:
						evento = InputEventJoypadMotion.new()
						evento.axis = int(personalizados.get("eixo",0))
						evento.axis_value = float(personalizados.get("valor",1.0))
					eventos.append(evento)
				for atual in InputMap.action_get_events(nome):
					if (atual is InputEventJoypadButton or atual is InputEventJoypadMotion) if controle else atual is InputEventKey: InputMap.action_erase_event(nome,atual)
				for novo in eventos:
					if controle: novo.device = device
					InputMap.action_add_event(nome,novo)
	var instancia := (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Controle")
	if instancia != null: instancia.dicas_alteradas.emit()

static func restaurar(lado := 1, controle := false) -> bool:
	var config := ConfigFile.new()
	config.load(CAMINHO)
	config.erase_section(_secao(lado,controle))
	if config.save(CAMINHO) != OK: return false
	aplicar()
	return true

static func rotulo(acao: String, lado: int, controle: bool) -> String:
	var nome: String = "p2_"+acao if lado == 2 else acao
	if not InputMap.has_action(nome): return "-"
	for evento in InputMap.action_get_events(nome):
		if not controle and evento is InputEventKey: return OS.get_keycode_string(evento.physical_keycode)
		if controle and evento is InputEventJoypadButton: return "BOTAO %d" % evento.button_index
		if controle and evento is InputEventJoypadMotion: return "EIXO %d %s" % [evento.axis,"+" if evento.axis_value>0 else "-"]
	return "-"
