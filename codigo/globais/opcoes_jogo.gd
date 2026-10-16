extends RefCounted

const CAMINHO := "user://opcoes.cfg"
const SECAO := "opcoes"
## Preferências de interface guardadas fora das opções do menu (o menu regrava só a seção dele)
const SECAO_INTERFACE := "interface"
## Cooperativo: o jogador 2 tem as próprias opções do controle e da câmera (o resto vale para a janela toda)
const SECAO_P2 := "jogador2"
const CHAVES_POR_JOGADOR := ["vibracao", "zoom", "layout_controle"]
# Ver Controle: "auto" escolhe pelo nome do controle conectado
const LAYOUTS_CONTROLE := ["auto", "xbox", "nintendo", "playstation"]

## Zoom da câmera do jogador (opção ZOOM da pausa e do título): 1.0 = o tamanho de sempre
const ZOOMS := [0.75, 1.0, 1.25, 1.5, 2.0]
const ROTULOS_ZOOM := ["75%", "100%", "125%", "150%", "200%"]
static var _zoom := -1.0
static var _zoom_p2 := -1.0

static func zoom(lado := 1) -> float:
	if lado == 2:
		if _zoom_p2 < 0.0:
			_zoom_p2 = float(carregar(2)["zoom"])
		return _zoom_p2
	if _zoom < 0.0:
		_zoom = float(carregar()["zoom"])
	return _zoom

## lado 2: as opções da janela mais as do jogador 2 (CHAVES_POR_JOGADOR, na seção dele)
static func carregar(lado := 1) -> Dictionary:
	var opcoes := _carregar_secao(SECAO)
	if lado == 2:
		var proprias := _carregar_secao(SECAO_P2)
		for chave in CHAVES_POR_JOGADOR:
			opcoes[chave] = proprias[chave]
	return opcoes

static func _carregar_secao(secao: String) -> Dictionary:
	var opcoes := {"volume": 1.0, "tela_cheia": true, "max_fps": 60, "layout_controle": "auto", "vibracao": true, "zoom": 1.0}
	var config := ConfigFile.new()
	if config.load(CAMINHO) != OK:
		return opcoes
	opcoes["volume"] = clampf(float(config.get_value(secao, "volume", 1.0)), 0.0, 1.0)
	opcoes["tela_cheia"] = bool(config.get_value(secao, "tela_cheia", true))
	opcoes["max_fps"] = maxi(int(config.get_value(secao, "max_fps", 60)), 0)
	var layout := str(config.get_value(secao, "layout_controle", "auto"))
	opcoes["layout_controle"] = layout if layout in LAYOUTS_CONTROLE else "auto"
	opcoes["vibracao"] = bool(config.get_value(secao, "vibracao", true))
	var valor_zoom := float(config.get_value(secao, "zoom", 1.0))
	opcoes["zoom"] = valor_zoom if valor_zoom in ZOOMS else 1.0
	return opcoes

static func salvar(opcoes: Dictionary, lado := 1) -> void:
	var config := ConfigFile.new()
	# Lê o arquivo antes para não apagar o que outras partes guardam nele (ex.: o quadro de controles fechado)
	config.load(CAMINHO)
	if lado == 2:
		for chave in CHAVES_POR_JOGADOR:
			config.set_value(SECAO_P2, chave, opcoes[chave])
		config.save(CAMINHO)
		return
	config.set_value(SECAO, "volume", opcoes.get("volume", 1.0))
	config.set_value(SECAO, "tela_cheia", opcoes.get("tela_cheia", true))
	config.set_value(SECAO, "max_fps", opcoes.get("max_fps", 60))
	config.set_value(SECAO, "layout_controle", opcoes.get("layout_controle", "auto"))
	config.set_value(SECAO, "vibracao", opcoes.get("vibracao", true))
	config.set_value(SECAO, "zoom", opcoes.get("zoom", 1.0))
	config.save(CAMINHO)

## O jogador fechou o quadro de controles (X): fica fechado nas próximas vezes que abrir o jogo
static func mini_tutorial_fechado() -> bool:
	var config := ConfigFile.new()
	if config.load(CAMINHO) != OK:
		return false
	return bool(config.get_value(SECAO_INTERFACE, "mini_tutorial_fechado", false))

static func fechar_mini_tutorial() -> void:
	var config := ConfigFile.new()
	config.load(CAMINHO)
	config.set_value(SECAO_INTERFACE, "mini_tutorial_fechado", true)
	config.save(CAMINHO)

static func aplicar(opcoes: Dictionary, lado := 1) -> void:
	var arvore_p2 := Engine.get_main_loop() as SceneTree
	if lado == 2:
		_zoom_p2 = float(opcoes.get("zoom", 1.0))
		var controle_p2: Node = arvore_p2.root.get_node_or_null("Controle") if arvore_p2 != null else null
		if controle_p2 != null:
			controle_p2.vibracao_p2 = opcoes.get("vibracao", true)
			controle_p2.preferencia_layout_p2 = opcoes.get("layout_controle", "auto")
			controle_p2.dicas_alteradas.emit()
		if arvore_p2 != null:
			arvore_p2.call_group("camera_jogo", "aplicar_zoom")
		return
	var volume: float = opcoes.get("volume", 1.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(volume))
	var modo := DisplayServer.WINDOW_MODE_FULLSCREEN if opcoes.get("tela_cheia", true) else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != modo:
		DisplayServer.window_set_mode(modo)
	Engine.max_fps = opcoes.get("max_fps", 60)
	_zoom = float(opcoes.get("zoom", 1.0))
	# O Controle é um autoload; ao abrir o jogo ele mesmo lê estas opções (ver Controle._ready)
	var arvore := Engine.get_main_loop() as SceneTree
	var controle: Node = arvore.root.get_node_or_null("Controle") if arvore != null else null
	if controle != null:
		controle.vibracao_ligada = opcoes.get("vibracao", true)
		controle.definir_preferencia_layout(opcoes.get("layout_controle", "auto"))
	if arvore != null:
		arvore.call_group("camera_jogo", "aplicar_zoom")
