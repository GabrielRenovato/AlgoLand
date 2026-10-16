extends Control

## Catálogo ilustrado apresentado pelo Nilo. Ícones originais, sem inventário ou recompensas.
const CATALOGO := "res://assets/pesca/catalogo.json"
var painel: PanelContainer
var _fechar: Button
var _grade: GridContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = preload("res://recursos/ui/tema_sidebar.tres")
	painel = PanelContainer.new()
	painel.set_anchors_preset(Control.PRESET_CENTER)
	var moldura := StyleBoxTexture.new()
	moldura.texture = preload("res://assets/ui/craftpix-net-420010-pixel-game-user-interface-for-platformer/1 Interface/TileMap.png")
	moldura.region_rect = Rect2(96, 64, 48, 48)
	for lado in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		moldura.set_texture_margin(lado, 16)
		moldura.set_content_margin(lado, 12)
	painel.add_theme_stylebox_override("panel", moldura)
	add_child(painel)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 8)
	painel.add_child(coluna)
	var cabecalho := HBoxContainer.new()
	coluna.add_child(cabecalho)
	var vara := TextureRect.new()
	vara.texture = preload("res://assets/pesca/vara.png")
	vara.texture_filter = TEXTURE_FILTER_NEAREST
	vara.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vara.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vara.custom_minimum_size = Vector2(28, 28)
	cabecalho.add_child(vara)
	var titulo := Label.new()
	titulo.text = "NILO — PESCADOR"
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cabecalho.add_child(titulo)
	_fechar = Button.new()
	_fechar.text = "FECHAR"
	_fechar.pressed.connect(func(): EventosJogo.fechar_tela_de(get_parent(), "guia_pesca"))
	cabecalho.add_child(_fechar)
	var fala := Label.new()
	fala.text = "Moro na palafita aqui na praia.\nDe manha preparo as redes; depois vou ao pier.\nVeja os peixes que conheco:"
	fala.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	coluna.add_child(fala)
	var rolagem := ScrollContainer.new()
	rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	coluna.add_child(rolagem)
	_grade = GridContainer.new()
	_grade.columns = 3
	_grade.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rolagem.add_child(_grade)
	var catalogo: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CATALOGO))
	for peixe: Dictionary in catalogo["peixes"].values():
		var linha := HBoxContainer.new()
		linha.custom_minimum_size.y = 32
		_grade.add_child(linha)
		var icone := TextureRect.new()
		icone.texture = load(peixe["icone"])
		icone.texture_filter = TEXTURE_FILTER_NEAREST
		icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icone.custom_minimum_size = Vector2(24, 24)
		linha.add_child(icone)
		var nome := Label.new()
		nome.text = peixe["nome"] + "\n" + ("Mar" if peixe["ambiente"] == "mar" else "Rio")
		nome.add_theme_font_size_override("font_size", 8)
		linha.add_child(nome)
	resized.connect(_ajustar)
	_ajustar()

func _ajustar() -> void:
	var largura := minf(460, maxf(240, size.x - 24))
	var altura := minf(294, maxf(180, size.y - 24))
	painel.offset_left = -largura / 2
	painel.offset_right = largura / 2
	painel.offset_top = -altura / 2
	painel.offset_bottom = altura / 2
	_grade.columns = 3 if largura >= 380 else 2

func focar_inicio() -> void:
	_fechar.grab_focus()
