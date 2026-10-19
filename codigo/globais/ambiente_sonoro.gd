extends Node

const RAIZ := "res://assets/audio/trilhas/"
var tema := ""
var ambiente := ""
var _musica: Array[AudioStreamPlayer] = []
var _ambiente: AudioStreamPlayer
var _cache := {}
var _ativo := 0
var _tempo := 0.0
var _tween: Tween

func _ready() -> void:
	name = "AmbienteSonoro"
	process_mode = Node.PROCESS_MODE_ALWAYS
	preload("res://codigo/dados/mixagem_audio.gd").aplicar(preload("res://codigo/globais/opcoes_jogo.gd").carregar())
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.bus = "Musica"
		player.volume_db = -80
		add_child(player)
		_musica.append(player)
	_ambiente = AudioStreamPlayer.new()
	_ambiente.bus = "Ambiente"
	_ambiente.volume_db = -23
	add_child(_ambiente)

func _faixa(id: String) -> AudioStream:
	if not _cache.has(id):
		var faixa := load(RAIZ+id+".wav") as AudioStreamWAV
		if faixa == null: return null
		# O importador pode comprimir o WAV: bytes comprimidos não são quadros de áudio.
		var quadros := roundi(faixa.get_length()*faixa.mix_rate)
		faixa.loop_mode = AudioStreamWAV.LOOP_FORWARD
		faixa.loop_begin = 0
		faixa.loop_end = quadros
		_cache[id] = faixa
	return _cache[id]

func definir(novo_tema: String, novo_ambiente: String = "") -> void:
	if novo_tema != tema:
		tema = novo_tema
		if _tween != null and _tween.is_valid(): _tween.kill()
		var anterior := _ativo
		_ativo = 1 - _ativo
		_musica[_ativo].stream = _faixa(tema)
		_musica[_ativo].volume_db = -70
		_musica[_ativo].play()
		_tween = create_tween().set_parallel(true)
		_tween.tween_property(_musica[anterior],"volume_db",-70.0,1.4)
		_tween.tween_property(_musica[_ativo],"volume_db",-17.0,1.4)
		_tween.chain().tween_callback(_musica[anterior].stop)
	if novo_ambiente != ambiente:
		ambiente = novo_ambiente
		_ambiente.stop()
		if ambiente != "":
			_ambiente.stream = _faixa(ambiente)
			_ambiente.play()

func _process(delta: float) -> void:
	_tempo -= delta
	if _tempo > 0: return
	_tempo = 0.5
	var cena := get_tree().current_scene
	if cena == null: return
	var gerentes := get_tree().get_nodes_in_group("gerenciador_andar")
	if not gerentes.is_empty():
		var gerente = gerentes[0]
		var bioma: String = load("res://codigo/fendas/catalogo_andares.gd").dados(gerente.onda_atual).bioma
		definir("guardiao" if gerente.etapa == gerente.Etapa.GUARDIAO else "fenda", "caverna" if bioma.begins_with("caverna") else "bosque")
		return
	var caminho := cena.scene_file_path
	if caminho.ends_with("praia.tscn") or caminho.ends_with("palafita.tscn"):
		definir("praia","mar")
	elif caminho.ends_with("fazenda.tscn"):
		definir("fazenda","bosque")
	else:
		definir("vila", "bosque" if caminho.ends_with("cidade.tscn") else "")
