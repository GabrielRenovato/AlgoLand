extends CanvasLayer
## Painel de desempenho para diagnosticar travadas no celular: abra o jogo com ?desempenho no endereço
## (ou --desempenho no PC). Mostra quadros por segundo, tempo de quadro, chamadas de desenho, memória de vídeo e total.
const INTERVALO := 0.5
var _rotulo: Label
var _tempo := 0.0
var _pior_quadro := 0.0
var _texturas_texto := ""
var _tempo_texturas := 4.0

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rotulo = Label.new()
	_rotulo.position = Vector2(4, 28)
	_rotulo.add_theme_font_size_override("font_size", 8)
	_rotulo.add_theme_color_override("font_color", Color("b8ff9a"))
	_rotulo.add_theme_color_override("font_outline_color", Color.BLACK)
	_rotulo.add_theme_constant_override("outline_size", 3)
	_rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rotulo)
	process_priority = 200

func _process(delta: float) -> void:
	_pior_quadro = maxf(_pior_quadro, delta)
	_tempo += delta
	_tempo_texturas += delta
	if _tempo_texturas >= 5.0:
		_tempo_texturas = 0.0
		_texturas_texto = _maiores_texturas()
	if _tempo < INTERVALO:
		return
	_tempo = 0.0
	var mb := 1.0 / 1048576.0
	var dpr: Variant = JavaScriptBridge.eval("window.devicePixelRatio", true) if OS.has_feature("web") else 1.0
	_rotulo.text = "FPS %d | pior quadro %d ms | processo %.1f ms\nchamadas %d | objetos %d | nos %d\nvideo %d MB (texturas %d MB) | memoria %d MB\njanela %s | dpr %s" % [
		Engine.get_frames_per_second(), roundi(_pior_quadro * 1000.0), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) * mb, Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) * mb, Performance.get_monitor(Performance.MEMORY_STATIC) * mb,
		str(DisplayServer.window_get_size()), str(dpr)] + _texturas_texto
	_pior_quadro = 0.0

## Texturas em uso pelos nós da cena (sem repetir), maiores primeiro: mostra onde está a memória de vídeo
func _maiores_texturas() -> String:
	var vistas := {}
	var pilha: Array[Node] = [get_tree().root]
	while not pilha.is_empty():
		var no: Node = pilha.pop_back()
		pilha.append_array(no.get_children())
		var textura: Texture2D = null
		if no is Sprite2D or no is Sprite3D:
			textura = no.texture
		elif no is TextureRect:
			textura = no.texture
		elif no is TileMapLayer and no.tile_set != null:
			for i in no.tile_set.get_source_count():
				var fonte = no.tile_set.get_source(no.tile_set.get_source_id(i))
				if fonte is TileSetAtlasSource and fonte.texture != null:
					_somar(vistas, fonte.texture)
		if textura != null:
			_somar(vistas, textura)
	var lista: Array = vistas.values()
	lista.sort_custom(func(a, b): return a[0] > b[0])
	var total := 0.0
	for item in lista: total += item[0]
	var linhas := "\ntexturas dos nos: %d, %d MB (se RGBA)" % [lista.size(), roundi(total)]
	for i in mini(6, lista.size()):
		linhas += "\n  %d MB %s" % [roundi(lista[i][0]), lista[i][1].get_file()]
	return linhas

func _somar(vistas: Dictionary, textura: Texture2D) -> void:
	var chave: String = textura.resource_path if textura.resource_path != "" else str(textura.get_instance_id())
	if vistas.has(chave):
		return
	var base: Texture2D = textura.atlas if textura is AtlasTexture and textura.atlas != null else textura
	var tamanho := Vector2(base.get_width(), base.get_height())
	vistas[chave] = [tamanho.x * tamanho.y * 4.0 / 1048576.0, base.resource_path if base.resource_path != "" else chave]
