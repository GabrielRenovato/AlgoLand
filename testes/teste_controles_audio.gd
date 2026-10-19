extends SceneTree
const Controles := preload("res://codigo/dados/controles_personalizados.gd")
const Opcoes := preload("res://codigo/globais/opcoes_jogo.gd")
var falhas := 0
func _initialize() -> void:
	_rodar.call_deferred()
func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ",nome)
	if not ok: falhas += 1
func _rodar() -> void:
	await process_frame
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"): quit(1); return
	var tecla := InputEventKey.new()
	tecla.physical_keycode = KEY_K
	verificar("remapeia e persiste ataque no teclado",Controles.alterar("attack",tecla) == "" and Controles.rotulo("attack",1,false) == "K")
	verificar("conflito de teclas é recusado",Controles.alterar("rolar",tecla) != "")
	Controles.aplicar()
	verificar("reaplicar preserva personalizacao",Controles.rotulo("attack",1,false) == "K")
	Controles.restaurar()
	verificar("restaurar devolve padrão",Controles.rotulo("attack",1,false) != "K")
	var opcoes := Opcoes.carregar()
	opcoes.volume_musica = 0.0
	opcoes.volume_efeitos = 0.3
	opcoes.volume_ambiente = 0.7
	Opcoes.salvar(opcoes)
	Opcoes.aplicar(opcoes)
	verificar("volumes independentes persistem",Opcoes.carregar().volume_efeitos == 0.3 and Opcoes.carregar().volume_ambiente == 0.7)
	verificar("musica pode ser silenciada sem efeitos",AudioServer.is_bus_mute(AudioServer.get_bus_index("Musica")) and not AudioServer.is_bus_mute(AudioServer.get_bus_index("Efeitos")))
	var ambiente = root.get_node("Sons/AmbienteSonoro")
	ambiente.definir("fazenda","bosque")
	verificar("trilha e ambiente usam canais distintos",ambiente._musica[ambiente._ativo].bus == "Musica" and ambiente._ambiente.bus == "Ambiente")
	verificar("trilha usa loop completo",ambiente._musica[ambiente._ativo].stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and ambiente._musica[ambiente._ativo].stream.loop_end > 0)
	for tema in ["vila","fazenda","praia","fenda","guardiao","bosque","mar","caverna"]:
		var faixa: AudioStreamWAV = ambiente._faixa(tema)
		verificar("faixa carregável "+tema,faixa != null)
		var origem := FileAccess.open("res://assets/audio/trilhas/"+tema+".wav",FileAccess.READ)
		var cabecalho := origem.get_buffer(44)
		var quadros_pcm := cabecalho.decode_u32(40)/cabecalho.decode_u16(32)
		verificar("loop respeita duração original mesmo comprimido "+tema,faixa.loop_end == quadros_pcm)
	print("FALHAS: ",falhas)
	quit(falhas)
