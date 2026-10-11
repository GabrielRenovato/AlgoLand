extends SceneTree
# Ferramenta de verificacao visual: renderiza recortes do mundo de uma cena (terreno/cenario/inicio) em PNG.
# Precisa de janela (nao headless). Uso:
#   godot --path . --script res://ferramentas/arena/render_arena.gd -- <cena.tscn> <arquivo_tomadas.json> <pasta_saida>
# O JSON e uma lista de tomadas: {"nome":"x","estacao":0..3 ou -1,"cx":0,"cy":0,"w":888,"h":707,"zoom":2.0,
#   "sem_luz":true,"colisoes":false,"alfa_objetos":1.0}.
# "estacao" chama definir_estacao(i, true) no no "Estacoes" da cena (se existir).
# ATENCAO: se QUALQUER tomada pedir "colisoes", a execucao inteira mostra colisoes e navegacao; use um JSON separado.

var _tomadas: Array = []
var _pasta := ""
var _cena_path := ""
var _vp: SubViewport
var _cena: Node
var _camera: Camera2D
var _i := 0
var _fase := 0
var _espera := 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_cena_path = args[0]
	_tomadas = JSON.parse_string(FileAccess.get_file_as_string(args[1]))
	_pasta = args[2]
	# se alguma tomada pedir "colisoes", mostra formas de colisao e malha de navegacao (precisa ligar antes de instanciar)
	for t in _tomadas:
		if bool(t.get("colisoes", false)):
			debug_collisions_hint = true
			debug_navigation_hint = true
	DirAccess.make_dir_recursive_absolute(_pasta)
	_vp = SubViewport.new()
	_vp.size = Vector2i(800, 600)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.disable_3d = true
	root.add_child(_vp)
	_cena = load(_cena_path).instantiate()
	_vp.add_child(_cena)
	_camera = Camera2D.new()
	_vp.add_child(_camera)
	_camera.call_deferred("make_current")

func _achar(no: Node, nome: String) -> Node:
	return no.find_child(nome, true, false)

func _process(_delta: float) -> bool:
	if _i >= _tomadas.size():
		quit()
		return false
	var t: Dictionary = _tomadas[_i]
	if _fase == 0:
		var zoom: float = float(t.get("zoom", 2.0))
		_vp.size = Vector2i(int(float(t.get("w", 888)) * zoom), int(float(t.get("h", 707)) * zoom))
		_camera.position = Vector2(float(t.get("cx", 300)), float(t.get("cy", 140)))
		_camera.zoom = Vector2(zoom, zoom)
		var est := int(t.get("estacao", -1))
		var no := _achar(_cena, "Estacoes")
		if no and est >= 0:
			no.definir_estacao(est, true)
		var objetos := _cena.get_node_or_null("Objetos3D") as CanvasItem
		if objetos:
			objetos.modulate.a = float(t.get("alfa_objetos", 1.0))
		for l in _cena.find_children("*", "CanvasModulate", true, false):
			l.visible = not bool(t.get("sem_luz", true))
		_fase = 1
		_espera = 0
	else:
		_espera += 1
		if _espera >= 6:
			var img := _vp.get_texture().get_image()
			var caminho := "%s/%s.png" % [_pasta, t["nome"]]
			img.save_png(caminho)
			print("salvo: ", caminho, " ", img.get_size())
			_i += 1
			_fase = 0
	return false
