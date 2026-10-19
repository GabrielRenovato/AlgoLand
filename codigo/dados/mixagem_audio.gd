extends RefCounted
const BUSES := {"Musica":"volume_musica", "Efeitos":"volume_efeitos", "Ambiente":"volume_ambiente"}
static func preparar() -> void:
	for nome in BUSES:
		if AudioServer.get_bus_index(nome) < 0:
			AudioServer.add_bus()
			var indice := AudioServer.bus_count - 1
			AudioServer.set_bus_name(indice,nome)
			AudioServer.set_bus_send(indice,"Master")
static func aplicar(opcoes: Dictionary) -> void:
	preparar()
	for nome in BUSES:
		var volume := clampf(float(opcoes.get(BUSES[nome],0.6 if nome == "Musica" else 1.0)),0,1)
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(nome),linear_to_db(volume))
		AudioServer.set_bus_mute(AudioServer.get_bus_index(nome),volume <= 0)
