extends CanvasLayer
## Painel do grupo no canto da tela: nome, vida e estado de cada jogador da sala.
const Parceiro := preload("res://codigo/coop_online/parceiro_coop.gd")
const FONTE := preload("res://assets/ui/Planes_ValMore.ttf")
const LARGURA_BARRA := 70.0
var _caixa: VBoxContainer
var _linhas: Array[Dictionary] = []
var _rodape: Label

func _init() -> void:
	layer = 7

func _ready() -> void:
	_caixa = VBoxContainer.new()
	_caixa.position = Vector2(8, 84)
	_caixa.add_theme_constant_override("separation", 3)
	_caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_caixa)
	_rodape = Label.new()
	_rodape.add_theme_font_override("font", FONTE)
	_rodape.add_theme_font_size_override("font_size", 7)
	_rodape.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7, 0.8))
	_rodape.add_theme_constant_override("outline_size", 2)
	_rodape.add_theme_color_override("font_outline_color", Color.BLACK)

## membros: [{nome, hp, hpm, caido, vaga, eu}] na ordem da sala.
func atualizar(membros: Array, rodape: String) -> void:
	while _linhas.size() < membros.size(): _criar_linha()
	for i in _linhas.size():
		var linha := _linhas[i]
		linha.raiz.visible = i < membros.size()
		if i >= membros.size(): continue
		var m: Dictionary = membros[i]
		var cor: Color = Parceiro.CORES_VAGA[clampi(int(m.vaga), 0, 3)]
		var fracao := clampf(float(m.hp) / float(maxi(int(m.hpm), 1)), 0.0, 1.0)
		var caido: bool = m.caido
		linha.nome.text = "%s%s" % [str(m.nome), " (VOCE)" if m.eu else ""]
		linha.nome.add_theme_color_override("font_color", cor if not caido else Color(0.6, 0.55, 0.55))
		linha.vida.size.x = LARGURA_BARRA * fracao
		linha.vida.color = Color("66d96b") if fracao > 0.5 else (Color("f2c14e") if fracao > 0.25 else Color("e0524d"))
		linha.valor.text = "CAIDO" if caido else "%d/%d" % [int(m.hp), int(m.hpm)]
	_rodape.text = rodape
	if _rodape.get_parent() == null: _caixa.add_child(_rodape)
	else: _caixa.move_child(_rodape, _caixa.get_child_count() - 1)

func _criar_linha() -> void:
	var raiz := PanelContainer.new()
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.07, 0.04, 0.09, 0.72)
	estilo.set_corner_radius_all(2)
	estilo.content_margin_left = 6
	estilo.content_margin_right = 5
	estilo.content_margin_top = 2
	estilo.content_margin_bottom = 3
	raiz.add_theme_stylebox_override("panel", estilo)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 1)
	coluna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(coluna)
	var nome := Label.new()
	nome.add_theme_font_override("font", FONTE)
	nome.add_theme_font_size_override("font_size", 8)
	nome.add_theme_constant_override("outline_size", 2)
	nome.add_theme_color_override("font_outline_color", Color.BLACK)
	coluna.add_child(nome)
	var linha_barra := HBoxContainer.new()
	linha_barra.add_theme_constant_override("separation", 4)
	linha_barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coluna.add_child(linha_barra)
	var fundo := ColorRect.new()
	fundo.color = Color(0.2, 0.12, 0.16)
	fundo.custom_minimum_size = Vector2(LARGURA_BARRA, 5)
	fundo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	linha_barra.add_child(fundo)
	var vida := ColorRect.new()
	vida.size = Vector2(LARGURA_BARRA, 5)
	fundo.add_child(vida)
	var valor := Label.new()
	valor.add_theme_font_override("font", FONTE)
	valor.add_theme_font_size_override("font_size", 7)
	valor.add_theme_color_override("font_color", Color("f7e5bd"))
	linha_barra.add_child(valor)
	_caixa.add_child(raiz)
	_linhas.append({"raiz": raiz, "nome": nome, "vida": vida, "valor": valor})
