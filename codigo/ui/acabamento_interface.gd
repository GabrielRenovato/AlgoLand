extends Node

## Adapta apenas molduras do conjunto antigo. Conserva geometria, fontes, ícones,
## filtros dos sprites e estados funcionais; acompanha controles criados em tempo de execução.
const FecharJanela := preload("res://codigo/ui/fechar_janela.gd")
const Estilo := preload("res://codigo/ui/estilo_inicio_detalhado.gd")
var _pendentes := {}
var _agendado := false
var aplicacoes := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_observar)
	_visitar(get_tree().root)

func _visitar(no: Node) -> void:
	_observar(no)
	for filho in no.get_children(true): _visitar(filho)

func _observar(no: Node) -> void:
	if not (no is Button or no is Panel or no is PanelContainer or no is NinePatchRect or no is LineEdit): return
	if no.name == "AcabamentoInicio": return
	if no.has_meta("observado_acabamento"): return
	no.set_meta("observado_acabamento",true)
	no.theme_changed.connect(_agendar.bind(no))
	no.draw.connect(_ao_desenhar.bind(no))
	_agendar(no)

func _agendar(no: Control) -> void:
	if not is_instance_valid(no): return
	_pendentes[no.get_instance_id()] = true
	if _agendado: return
	_agendado = true
	_aplicar_pendentes.call_deferred()

func _aplicar_pendentes() -> void:
	_agendado = false
	var ids := _pendentes.keys()
	_pendentes.clear()
	for id in ids:
		var no := instance_from_id(id) as Control
		if is_instance_valid(no) and no.is_inside_tree(): _aplicar(no)

func _origem(textura: Texture2D) -> String:
	while textura is AtlasTexture: textura = textura.atlas
	return textura.resource_path if textura != null else ""

func _legado(textura: Texture2D) -> bool:
	var caminho := _origem(textura)
	return "/ui/bosque/" in caminho or "/1 Interface/TileMap.png" in caminho

func _celula(textura: Texture2D) -> Vector2i:
	var caminho := _origem(textura)
	if "primario" in caminho: return Vector2i(0,1)
	if "pergaminho" in caminho or "botao" in caminho: return Vector2i(1,0)
	if "slot" in caminho: return Vector2i(1,1)
	return Vector2i.ZERO

func _escala(textura: Texture2D, botao := false) -> float:
	if "slot" in _origem(textura): return 32.0
	return 16.0 if botao else 8.0

func _espaco(original: StyleBox) -> StyleBoxEmpty:
	var estilo := StyleBoxEmpty.new()
	for lado in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]: estilo.set_content_margin(lado,original.get_margin(lado))
	return estilo

func _pintar(no: Control, textura: Texture2D, botao := false, cor := Color.WHITE) -> void:
	var arte: NinePatchRect = no.get_meta("arte_acabamento") if no.has_meta("arte_acabamento") else null
	if not is_instance_valid(arte):
		arte = Estilo.fundo(no,_celula(textura),_escala(textura,botao),true)
		no.set_meta("arte_acabamento",arte)
	else:
		var recorte := arte.texture as AtlasTexture
		var lado := Estilo.ATLAS.get_width()/2.0
		var regiao := Rect2(Vector2(_celula(textura))*lado,Vector2.ONE*lado)
		if recorte.region != regiao:
			recorte = recorte.duplicate()
			recorte.region = regiao
			arte.texture = recorte
		var escala := _escala(textura,botao)
		arte.set_meta("escala_pintura",escala)
		arte.scale = Vector2.ONE/escala
		arte.size = no.size*escala
	no.set_meta("cor_acabamento",cor)
	arte.modulate = cor
	aplicacoes += 1

func _aplicar(no: Control) -> void:
	if no is Button and (no.has_meta("fechar_circular") or no.text.strip_edges().to_upper() in ["X","FECHAR","×"]):
		FecharJanela.ligar(no)
		return
	if no is NinePatchRect:
		if no.texture != null and _legado(no.texture):
			_pintar(no,no.texture)
			no.texture = null
		return
	if no is Button:
		var normal := no.get_theme_stylebox("normal")
		if normal is StyleBoxTexture and _legado(normal.texture): _pintar(no,normal.texture,true,normal.modulate_color)
		for estado in ["normal","hover","pressed","hover_pressed","disabled","focus"]:
			var estilo := no.get_theme_stylebox(estado)
			if estilo is StyleBoxTexture and _legado(estilo.texture): no.add_theme_stylebox_override(estado,_espaco(estilo))
		_atualizar_botao(no)
	elif no is LineEdit:
		var normal := no.get_theme_stylebox("normal")
		if normal is StyleBoxTexture and _legado(normal.texture): _pintar(no,normal.texture)
		for estado in ["normal","read_only","focus"]:
			var estilo := no.get_theme_stylebox(estado)
			if estilo is StyleBoxTexture and _legado(estilo.texture): no.add_theme_stylebox_override(estado,_espaco(estilo))
	else:
		var estilo := no.get_theme_stylebox("panel")
		if estilo is StyleBoxTexture and _legado(estilo.texture):
			_pintar(no,estilo.texture,false,estilo.modulate_color)
			no.add_theme_stylebox_override("panel",_espaco(estilo))

func _ao_desenhar(no: Control) -> void:
	if no is Button: _atualizar_botao(no)
	if no is NinePatchRect:
		if no.texture != null and _legado(no.texture): _agendar(no)

func _atualizar_botao(botao: Button) -> void:
	var arte: NinePatchRect = botao.get_meta("arte_acabamento") if botao.has_meta("arte_acabamento") else null
	if not is_instance_valid(arte): return
	var cor: Color = botao.get_meta("cor_acabamento",Color.WHITE)
	if botao.disabled: cor *= Color(0.65,0.65,0.65)
	elif botao.is_pressed(): cor *= Color(0.9,0.9,0.9)
	elif botao.has_focus() or botao.is_hovered(): cor *= Color(1.12,1.08,1.0)
	if not arte.modulate.is_equal_approx(cor): arte.modulate = cor
