extends RefCounted

const CAMINHO := "user://opcoes.cfg"
const SECAO := "opcoes"
# Ver Controle: "auto" escolhe pelo nome do controle conectado
const LAYOUTS_CONTROLE := ["auto", "xbox", "nintendo", "playstation"]

static func carregar() -> Dictionary:
	var opcoes := {"volume": 1.0, "tela_cheia": true, "max_fps": 60, "layout_controle": "auto", "vibracao": true}
	var config := ConfigFile.new()
	if config.load(CAMINHO) != OK:
		return opcoes
	opcoes["volume"] = clampf(float(config.get_value(SECAO, "volume", 1.0)), 0.0, 1.0)
	opcoes["tela_cheia"] = bool(config.get_value(SECAO, "tela_cheia", true))
	opcoes["max_fps"] = maxi(int(config.get_value(SECAO, "max_fps", 60)), 0)
	var layout := str(config.get_value(SECAO, "layout_controle", "auto"))
	opcoes["layout_controle"] = layout if layout in LAYOUTS_CONTROLE else "auto"
	opcoes["vibracao"] = bool(config.get_value(SECAO, "vibracao", true))
	return opcoes

static func salvar(opcoes: Dictionary) -> void:
	var config := ConfigFile.new()
	config.set_value(SECAO, "volume", opcoes.get("volume", 1.0))
	config.set_value(SECAO, "tela_cheia", opcoes.get("tela_cheia", true))
	config.set_value(SECAO, "max_fps", opcoes.get("max_fps", 60))
	config.set_value(SECAO, "layout_controle", opcoes.get("layout_controle", "auto"))
	config.set_value(SECAO, "vibracao", opcoes.get("vibracao", true))
	config.save(CAMINHO)

static func aplicar(opcoes: Dictionary) -> void:
	var volume: float = opcoes.get("volume", 1.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(volume))
	var modo := DisplayServer.WINDOW_MODE_FULLSCREEN if opcoes.get("tela_cheia", true) else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != modo:
		DisplayServer.window_set_mode(modo)
	Engine.max_fps = opcoes.get("max_fps", 60)
	# O Controle é um autoload; ao abrir o jogo ele mesmo lê estas opções (ver Controle._ready)
	var arvore := Engine.get_main_loop() as SceneTree
	var controle: Node = arvore.root.get_node_or_null("Controle") if arvore != null else null
	if controle != null:
		controle.vibracao_ligada = opcoes.get("vibracao", true)
		controle.definir_preferencia_layout(opcoes.get("layout_controle", "auto"))
