extends Control

const IconesItens := preload("res://Codigos/UI/icones_itens.gd")
const Encantamentos := preload("res://Codigos/DadosLocais/encantamentos.gd")
const Conjuntos := preload("res://Codigos/DadosLocais/conjuntos_armadura.gd")
const FONTE_DICA := preload("res://UI/Planes_ValMore.ttf")
const COR_DICA_DETALHE := Color(0.7, 0.68, 0.64)
const EstiloSlot := preload("res://Codigos/UI/estilo_slot.gd")
const Raridades := preload("res://Codigos/DadosLocais/raridades.gd")
## Cor das linhas de afixo no tooltip
const COR_AFIXO := Color(0.55, 0.95, 0.65)

const ESCALA_PREVIEW := 1.2
const BRILHO_HOVER := Color(1.15, 1.15, 1.15, 1.0)
# Item reservado (ex.: na bigorna) fica acinzentado, sem transparencia
const COR_EM_USO := Color(0.4, 0.4, 0.4, 1.0)

var dados: DadosItem
var em_uso: bool = false

var _filtro_mouse_original: MouseFilter = MOUSE_FILTER_STOP
var _arrastando: bool = false

@onready var moldura: Panel = $Panel
@onready var icone: TextureRect = $Icone

func _ready() -> void:
	mouse_entered.connect(_ao_mouse_entrar)
	mouse_exited.connect(_ao_mouse_sair)

func exibir(item: DadosItem) -> void:
	dados = item
	modulate = Color.WHITE
	if item == null:
		icone.texture = null
		tooltip_text = ""
		return
	icone.texture = IconesItens.obter(item, get_tree())
	# O quadrado do item (o sprite de slot da interface) na cor da raridade, por cima do quadrado do slot
	moldura.add_theme_stylebox_override("panel", EstiloSlot.caixa_raridade(item.raridade))
	# O texto é a versão simples (acessibilidade/testes); o desenho da dica vem de _make_custom_tooltip
	tooltip_text = "%s  NV %d  %s" % [item.nome(), item.nivel, Raridades.nome(item.raridade)]

## Dica do item no estilo do jogo (a caixa vem do tema global: TooltipPanel com a moldura de slot do pack):
## nome na cor da raridade, nível e raridade embaixo e, se tiver, o encantamento na cor do elemento
func _make_custom_tooltip(_texto: String) -> Object:
	return tooltip_do_item()

## O mesmo desenho da dica do mouse, para quem mostra o detalhe sem o mouse (o controle)
func tooltip_do_item() -> Control:
	if dados == null:
		return null
	var linhas := VBoxContainer.new()
	linhas.add_theme_constant_override("separation", 0)
	linhas.add_child(_linha_dica(dados.nome(), dados.cor_raridade()))
	linhas.add_child(_linha_dica("NV %d  %s" % [dados.nivel, Raridades.nome(dados.raridade)], dados.cor_raridade()))
	if dados.raridade != "comum" and dados.categoria in ["arma", "escudo", "cabeca", "corpo", "luvas", "botas"]:
		linhas.add_child(_linha_dica("+%d%% STATUS" % roundi((dados.multiplicador_raridade() - 1.0) * 100.0), COR_DICA_DETALHE))
	for id in dados.afixos:
		linhas.add_child(_linha_dica(Raridades.texto_afixo(id, dados.afixos[id]), COR_AFIXO))
	if dados.encantamento != "":
		linhas.add_child(_linha_dica("%s NV %d" % [Encantamentos.nome(dados.encantamento), dados.nivel_encantamento],
				Encantamentos.cor(dados.encantamento)))
	var conjunto := Conjuntos.de_tipo(dados.tipo)
	if conjunto != null:
		var quantidade: int = conjunto.quantidade(InventarioJogador.equipados)
		linhas.add_child(_linha_dica("CONJUNTO %s %d/4" % [conjunto.NOME, quantidade], dados.cor_raridade()))
		if conjunto.TIPO_BONUS == "raio":
			linhas.add_child(_linha_dica("4 PECAS: %d%% RAIO AO ACERTAR" % roundi(conjunto.CHANCE_BONUS * 100), COR_DICA_DETALHE))
			linhas.add_child(_linha_dica("DANO %d%%  RECARGA %dS" % [roundi(conjunto.MULT_DANO_BONUS * 100), roundi(conjunto.RECARGA_BONUS)], COR_DICA_DETALHE))
		elif conjunto.TIPO_BONUS == "congelamento":
			linhas.add_child(_linha_dica("4 PECAS: %d%% CONGELAR AO ACERTAR" % roundi(conjunto.CHANCE_BONUS * 100), COR_DICA_DETALHE))
			linhas.add_child(_linha_dica("DURACAO %dS  RECARGA %dS" % [roundi(conjunto.DURACAO_BONUS), roundi(conjunto.RECARGA_BONUS)], COR_DICA_DETALHE))
		elif conjunto.TIPO_BONUS == "status":
			var valores: Dictionary = conjunto.get_script_constant_map()
			linhas.add_child(_linha_dica("4 PECAS: +%d%% DEFESA, +%d%% VITALIDADE" % [roundi(float(valores.get("BONUS_DEFESA", 0.0)) * 100), roundi(float(valores.get("BONUS_VITALIDADE", 0.0)) * 100)], COR_DICA_DETALHE))
	return linhas

func _linha_dica(texto: String, cor: Color) -> Label:
	var rotulo := Label.new()
	rotulo.text = texto
	rotulo.add_theme_font_override("font", FONTE_DICA)
	rotulo.add_theme_font_size_override("font_size", 10)
	rotulo.add_theme_color_override("font_color", cor)
	return rotulo

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		# Sem isso o item (acima do slot na ordem de picking) engoliria o drop
		_filtro_mouse_original = mouse_filter
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	elif what == NOTIFICATION_DRAG_END:
		mouse_filter = _filtro_mouse_original
		if _arrastando:
			_arrastando = false
			moldura.visible = true
			icone.visible = true

func _get_drag_data(_posicao: Vector2) -> Variant:
	if dados == null or em_uso or not is_visible_in_tree():
		return null
	# Armas, escudo e armaduras usam os slots do modelo de inventário.
	if not dados.categoria in ["arma", "escudo", "cabeca", "corpo", "luvas", "botas"]:
		return null
	PreviewArrasto.mostrar(_criar_preview())
	_arrastando = true
	moldura.visible = false
	icone.visible = false
	modulate = Color.WHITE
	return {"item": dados, "origem": self, "tipo_item": dados.tipo}

func _criar_preview() -> Control:
	var raiz := Control.new()
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var conteudo := Control.new()
	conteudo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	conteudo.size = size
	conteudo.scale = Vector2.ONE * ESCALA_PREVIEW
	conteudo.position = -size * ESCALA_PREVIEW / 2.0
	raiz.add_child(conteudo)

	var copia_moldura := Panel.new()
	copia_moldura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copia_moldura.add_theme_stylebox_override("panel", moldura.get_theme_stylebox("panel"))
	copia_moldura.position = moldura.position
	copia_moldura.size = moldura.size
	conteudo.add_child(copia_moldura)

	var copia_icone := TextureRect.new()
	copia_icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copia_icone.texture = icone.texture
	copia_icone.expand_mode = icone.expand_mode
	copia_icone.stretch_mode = icone.stretch_mode
	copia_icone.position = icone.position
	copia_icone.size = icone.size
	conteudo.add_child(copia_icone)
	return raiz

func _ao_mouse_entrar() -> void:
	if not get_viewport().gui_is_dragging() and not em_uso:
		modulate = BRILHO_HOVER

func _ao_mouse_sair() -> void:
	modulate = Color.WHITE

# Usados pelo slot da bigorna (Codigos/Logicas/slot.gd)
func obter_tipo_item() -> String:
	return dados.tipo if dados != null else ""

func obter_cor_raridade() -> Color:
	return dados.cor_raridade() if dados != null else Color.WHITE

## O item está numa casa da mochila (não equipado)
func esta_na_mochila() -> bool:
	return dados != null and InventarioJogador.indice_de(dados) != -1

func obter_raridade() -> String:
	return dados.raridade if dados != null else "comum"

func obter_textura_icone() -> Texture2D:
	return icone.texture

func definir_em_uso(valor: bool) -> void:
	em_uso = valor
	icone.modulate = COR_EM_USO if valor else Color.WHITE
