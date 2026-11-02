extends CanvasLayer

## Tela de carregamento da campanha: imagem do local, nome e um trecho da história enquanto o mapa é montado.
## Cobre o intervalo em que o jogador já existe e o terreno ainda não (antes aparecia um fundo cinza com o personagem).
## Na primeira visita da sessão espera um toque ou tecla depois de a história aparecer; nas seguintes fecha sozinha.
signal fechada
const Estilo := preload("res://codigo/ui/estilo_campanha.gd")
const IMAGENS := "res://assets/campanha/carregamento/%s.jpg"
const TEMPO_MINIMO_PRIMEIRA := 4.0
const TEMPO_MINIMO_REPETIDA := 1.4
const DADOS := {
	"chegada": {"titulo": "CLAREIRAS DA CHEGADA", "etiqueta": "Primeira Raiz  ·  Prólogo",
		"historia": ["Algo chamou você para cá, e a floresta ainda guarda o calor dessa chegada: raízes que brilham, sulcos no chão e um tecido azul preso a um poste antigo.",
			"Alguém deixou socorro para quem viesse antes de você. Pegue o que encontrar, desconfie do que se mexe sob as raízes e siga a trilha até a estrada."],
		"dica": "Ainda não é hora de entender. É hora de sobreviver."},
	"estrada": {"titulo": "ESTRADA DOS CARRETEIROS", "etiqueta": "Primeira Raiz  ·  A estrada interrompida",
		"historia": ["A estrada que ligava a vila aos campos foi cortada. Restam rastros de carreto, lenha espalhada e um trabalhador assustado demais para falar.",
			"Todos nesta estrada têm uma versão do que aconteceu. Nenhuma delas combina com as outras."],
		"dica": "Olhe os rastros antes de acreditar em qualquer história."},
	"vila": {"titulo": "VILA DAS FLORES", "etiqueta": "Primeira Raiz  ·  Abrigo",
		"historia": ["Uma vila pequena que aprendeu a fechar os portões cedo. Dara vigia a entrada, e Lia e Estela sabem mais do que contam.",
			"Pouca gente aqui confia em quem chega de fora. Ganhe essa confiança aos poucos."],
		"dica": "Converse com todos: cada morador guarda uma peça do que acontece."},
	"moinho": {"titulo": "BACIA DO MOINHO", "etiqueta": "Primeira Raiz  ·  O circuito antigo",
		"historia": ["A roda parou, mas a água continua sumindo por canais que não aparecem nos mapas da vila. Sob o lodo, inscrições antigas ainda mostram como distribuir a corrente.",
			"Restaure os registros, libere o eixo e investigue a escadaria no centro da bacia. Algo guarda a ligação entre o moinho e as raízes."],
		"dica": "Observe a placa do circuito antes de testar a pressão."},
	"pomar": {"titulo": "POMAR DAS CERCAS PARTIDAS", "etiqueta": "Primeira Raiz  ·  O pomar",
		"historia": ["As cercas do pomar foram quebradas por dentro. Raízes sobem junto dos brotos e há sulcos novos na terra, que ninguém da vila admite ter visto.",
			"Algo se move debaixo do chão. Descubra o que é antes que chegue às casas."],
		"dica": "Siga os sulcos: eles mostram o caminho do que fugiu."}
}
var ativa := false
var _id := ""
var _primeira := false
var _pronto := false
var _finalizando := false
var _tempo := 0.0
var _fundo: ColorRect
var _raiz: Control
var _caixa: BoxContainer
var _imagem: TextureRect
var _quadro: Control
var _historia: Label
var _barra: ProgressBar
var _estado: Label
var _aviso: Label
var _progresso := 0.0
var _revelar: Tween
var _zoom: Tween

func mostrar(id: String) -> void:
	_id = id if DADOS.has(id) else "chegada"
	var vistas: Dictionary = get_tree().get_meta("carregamento_visto", {})
	_primeira = not vistas.has(_id)
	vistas[_id] = true
	get_tree().set_meta("carregamento_visto", vistas)
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	ativa = true
	_construir()
	_atualizar_layout()
	_raiz.resized.connect(_atualizar_layout)

func _construir() -> void:
	var dados: Dictionary = DADOS[_id]
	_raiz = Control.new()
	_raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_raiz.theme = preload("res://recursos/ui/tema_sidebar.tres")
	_raiz.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_raiz.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_raiz)
	_fundo = ColorRect.new()
	_fundo.color = Color(0.035, 0.05, 0.04)
	_fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_fundo)
	var margem := MarginContainer.new()
	margem.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for lado in ["left", "right", "top", "bottom"]:
		margem.add_theme_constant_override("margin_" + lado, 8)
	margem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(margem)
	_caixa = BoxContainer.new()
	_caixa.add_theme_constant_override("separation", 12)
	_caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margem.add_child(_caixa)
	# Imagem do local, com moldura e zoom lento.
	var moldura := PanelContainer.new()
	Estilo.painel(moldura,false,4)
	moldura.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	moldura.size_flags_vertical = Control.SIZE_EXPAND_FILL
	moldura.size_flags_stretch_ratio = 1.5
	_caixa.add_child(moldura)
	_quadro = Control.new()
	_quadro.clip_contents = true
	_quadro.custom_minimum_size = Vector2(120, 90)
	moldura.add_child(_quadro)
	_imagem = TextureRect.new()
	_imagem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_imagem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_imagem.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var caminho: String = IMAGENS % _id
	if ResourceLoader.exists(caminho):
		_imagem.texture = load(caminho)
	elif FileAccess.file_exists(caminho):
		# Ainda não importada (cópia de testes): lê o arquivo direto.
		var bruta := Image.load_from_file(ProjectSettings.globalize_path(caminho))
		if bruta != null: _imagem.texture = ImageTexture.create_from_image(bruta)
	_imagem.pivot_offset = Vector2(160, 100)
	_quadro.add_child(_imagem)
	_quadro.resized.connect(func(): _imagem.pivot_offset = _quadro.size * 0.5)
	_zoom = create_tween()
	_zoom.tween_property(_imagem, "scale", Vector2(1.09, 1.09), 14.0)
	# Painel com a história e o andamento.
	var papel := PanelContainer.new()
	Estilo.painel(papel,false,10)
	papel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	papel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_caixa.add_child(papel)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 3)
	papel.add_child(coluna)
	_rotulo(coluna, dados.etiqueta, 8, Color("805532"))
	_rotulo(coluna, dados.titulo, 12, Color("493020"))
	_historia = _rotulo(coluna, "\n".join(PackedStringArray(dados.historia)), 8, Color("493020"))
	_historia.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_historia.visible_ratio = 0.0
	var dica := _rotulo(coluna, dados.dica, 8, Color("805532"))
	dica.size_flags_vertical = Control.SIZE_SHRINK_END
	var andamento := HBoxContainer.new()
	coluna.add_child(andamento)
	_estado = _rotulo(andamento, "CARREGANDO", 8, Color("805532"))
	_barra = ProgressBar.new()
	_barra.show_percentage = false
	_barra.custom_minimum_size.y = 8
	_barra.add_theme_stylebox_override("background", Estilo.superficie(Color("19271f"),Estilo.BRONZE,0))
	var preenchimento := Estilo.superficie(Color("5a7750"),Color("5a7750"),0)
	_barra.add_theme_stylebox_override("fill", preenchimento)
	coluna.add_child(_barra)
	_aviso = _rotulo(coluna, "Toque ou pressione uma tecla", 8, Color("493020"))
	_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aviso.modulate.a = 0.0
	# A história aparece enquanto o mapa carrega.
	var duracao := clampf(float(_historia.text.length()) * 0.022, 2.0, 6.0)
	_revelar = create_tween()
	_revelar.tween_property(_historia, "visible_ratio", 1.0, duracao)

func _rotulo(pai: Node, texto: String, tamanho: int, cor: Color) -> Label:
	var r := Label.new()
	r.text = texto
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_theme_font_override("font",Estilo.FONTE_TITULO if tamanho>=12 else Estilo.FONTE)
	r.add_theme_font_size_override("font_size", tamanho)
	r.add_theme_color_override("font_color",Estilo.VERDE if tamanho>=12 else (Estilo.SUAVE if cor==Color("805532") else Estilo.TINTA))
	r.add_theme_constant_override("line_spacing",0)
	pai.add_child(r)
	return r

## Em tela deitada: imagem ao lado do texto. Em retrato: imagem em cima.
func _atualizar_layout() -> void:
	if _raiz == null or _caixa == null: return
	_caixa.vertical = _raiz.size.x < _raiz.size.y * 1.1

func definir_progresso(valor: float, texto := "") -> void:
	_progresso = maxf(_progresso, clampf(valor, 0.0, 1.0))
	if not texto.is_empty() and is_instance_valid(_estado): _estado.text = texto

func _process(delta: float) -> void:
	if not ativa: return
	_tempo += delta
	if is_instance_valid(_barra): _barra.value = lerpf(_barra.value, _progresso * 100.0, minf(delta * 8.0, 1.0))
	if _finalizando and not _pronto and _tempo >= (TEMPO_MINIMO_PRIMEIRA if _primeira else TEMPO_MINIMO_REPETIDA) \
			and (not _primeira or _historia.visible_ratio >= 1.0):
		_pronto = true
		if not _primeira: _fechar()
	if _pronto and _primeira and ativa and is_instance_valid(_aviso):
		_aviso.modulate.a = 0.6 + 0.4 * sin(_tempo * 4.0)

func _input(evento: InputEvent) -> void:
	if not ativa: return
	var pressionou: bool = (evento is InputEventKey and evento.pressed and not evento.echo) \
		or (evento is InputEventMouseButton and evento.pressed) or (evento is InputEventScreenTouch and evento.pressed) \
		or (evento is InputEventJoypadButton and evento.pressed)
	if not pressionou: return
	get_viewport().set_input_as_handled()
	if _historia.visible_ratio < 1.0:
		if _revelar != null and _revelar.is_valid(): _revelar.kill()
		_historia.visible_ratio = 1.0
	elif _pronto:
		_fechar()

## Chamada quando o mapa está montado: sobe a barra a 100% e libera o fechamento.
func finalizar() -> void:
	_progresso = 1.0
	_finalizando = true
	if is_instance_valid(_estado): _estado.text = "PRONTO"
	await fechada

func _fechar() -> void:
	if not ativa: return
	ativa = false
	if _zoom != null and _zoom.is_valid(): _zoom.kill()
	var t := create_tween()
	t.tween_property(_raiz, "modulate:a", 0.0, 0.5)
	await t.finished
	fechada.emit()
	queue_free()
