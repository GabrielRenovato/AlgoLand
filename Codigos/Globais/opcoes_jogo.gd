extends RefCounted

const CAMINHO := "user://opcoes.cfg"
const SECAO := "opcoes"

static func carregar() -> Dictionary:
	var opcoes := {"volume": 1.0, "tela_cheia": true, "max_fps": 60}
	var config := ConfigFile.new()
	if config.load(CAMINHO) != OK:
		return opcoes
	opcoes["volume"] = clampf(float(config.get_value(SECAO, "volume", 1.0)), 0.0, 1.0)
	opcoes["tela_cheia"] = bool(config.get_value(SECAO, "tela_cheia", true))
	opcoes["max_fps"] = maxi(int(config.get_value(SECAO, "max_fps", 60)), 0)
	return opcoes

static func salvar(opcoes: Dictionary) -> void:
	var config := ConfigFile.new()
	config.set_value(SECAO, "volume", opcoes.get("volume", 1.0))
	config.set_value(SECAO, "tela_cheia", opcoes.get("tela_cheia", true))
	config.set_value(SECAO, "max_fps", opcoes.get("max_fps", 60))
	config.save(CAMINHO)

static func aplicar(opcoes: Dictionary) -> void:
	var volume: float = opcoes.get("volume", 1.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(volume))
	var modo := DisplayServer.WINDOW_MODE_FULLSCREEN if opcoes.get("tela_cheia", true) else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != modo:
		DisplayServer.window_set_mode(modo)
	Engine.max_fps = opcoes.get("max_fps", 60)
