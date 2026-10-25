extends PanelContainer

## Resultado na interface do dono: o zoom da câmera não amplia o texto.
const Peixes := preload("res://codigo/pesca/peixes.gd")
const Qualidade := preload("res://codigo/pesca/qualidade_peixe.gd")
const Raridades := preload("res://codigo/dados/raridades.gd")
const Estilo := preload("res://codigo/ui/estilo_inicio_detalhado.gd")
const FONTE := preload("res://assets/ui/Planes_ValMore.ttf")
var jogador: Node2D

func _rotulo(texto: String, tamanho: int, cor: Color) -> Label:
	var rotulo := Label.new()
	rotulo.text = texto
	rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rotulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rotulo.add_theme_font_override("font", FONTE)
	rotulo.add_theme_font_size_override("font_size", tamanho)
	rotulo.add_theme_color_override("font_color", cor)
	return rotulo

func iniciar(quem: Node2D, peixe: String, qualidade: int, xp: int) -> void:
	name = "ResultadoCaptura"
	jogador = quem
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 40
	var pedra := peixe == "pedra_vara"
	var cor := Color("8bdcf7") if pedra else Raridades.cor(Peixes.raridade(peixe))
	Estilo.painel(self, false, 10, true)
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 6)
	linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(linha)
	var icone := TextureRect.new()
	icone.name = "PeixeCapturado"
	icone.texture = Peixes.icone(peixe)
	icone.modulate = cor if pedra else Color.WHITE
	icone.custom_minimum_size = Vector2(16, 16)
	icone.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icone.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	linha.add_child(icone)
	var textos := VBoxContainer.new()
	textos.name = "TextosCaptura"
	textos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	textos.add_theme_constant_override("separation", 1)
	textos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	linha.add_child(textos)
	var nome := _rotulo(Peixes.nome(peixe), 8, cor)
	textos.add_child(nome)
	var grau := clampi(qualidade, 0, 3)
	var detalhe: String = "REFINAMENTO" if pedra else Qualidade.NOMES[grau]
	if not pedra and xp > 0: detalhe += " | +%d XP" % xp
	textos.add_child(_rotulo(detalhe, 7, Color("c6ac86") if pedra else Qualidade.CORES[grau]))
	var largura_texto := 0.0
	for rotulo: Label in textos.get_children():
		largura_texto = maxf(largura_texto, FONTE.get_string_size(rotulo.text, HORIZONTAL_ALIGNMENT_LEFT, -1, rotulo.get_theme_font_size("font_size")).x)
	var largura := clampf(largura_texto + 42, 96, 164)
	custom_minimum_size.x = largura
	size = Vector2(largura, get_combined_minimum_size().y)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.16)
	_process(0)

func _process(_delta: float) -> void:
	if not is_instance_valid(jogador) or not is_instance_valid(get_parent()):
		queue_free()
		return
	size.y = get_combined_minimum_size().y
	# A projeção usa o viewport do personagem, inclusive em cada metade do cooperativo.
	var para_interface := get_canvas_transform().affine_inverse()
	var mundo_para_tela := get_viewport().get_canvas_transform()
	var acima := para_interface * (mundo_para_tela * (jogador.global_transform * Vector2(0, -26)))
	position = Vector2(roundf(acima.x - size.x / 2), maxf(4, roundf(acima.y - size.y - 4)))
