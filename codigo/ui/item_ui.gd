extends Control

const IconesItens := preload("res://codigo/ui/icones_itens.gd")
const Encantamentos := preload("res://codigo/dados/encantamentos.gd")
const Conjuntos := preload("res://codigo/dados/conjuntos_armadura.gd")
const FONTE_DICA := preload("res://assets/ui/Planes_ValMore.ttf")
const COR_DICA_DETALHE := Color(0.7, 0.68, 0.64)
const EstiloSlot := preload("res://codigo/ui/estilo_slot.gd")
const Raridades := preload("res://codigo/dados/raridades.gd")
const Plantas := preload("res://codigo/dados/plantas.gd")
const NOMES_ESTACAO := ["PRIMAVERA", "VERAO", "OUTONO", "INVERNO"]
## Cor das linhas de afixo no tooltip
const COR_AFIXO := Color(0.55, 0.95, 0.65)

const ESCALA_PREVIEW := 1.2
const BRILHO_HOVER := Color(1.15, 1.15, 1.15, 1.0)
# Item reservado (ex.: na bigorna) fica acinzentado, sem transparencia
const COR_EM_USO := Color(0.4, 0.4, 0.4, 1.0)

var dados: DadosItem
var em_uso: bool = false

var _filtro_mouse_original: MouseFilter = MOUSE_FILTER_STOP
## Quantidade no canto (sementes empilhadas), criada na primeira vez que precisa
var _rotulo_quantidade: Label = null
var _arrastando: bool = false
var _estrela_qualidade: TextureRect

@onready var moldura: Panel = $Panel
@onready var icone: TextureRect = $Icone

func _ready() -> void:
	gui_input.connect(_ao_entrada)
	mouse_entered.connect(_ao_mouse_entrar)
	mouse_exited.connect(_ao_mouse_sair)

## Botão direito no item: o slot dono dele equipa (mochila) ou desequipa (slot de equipamento) na hora.
## Toque duplo (o celular não tem botão direito; o toque vira clique do mouse) faz o mesmo.
func _ao_entrada(evento: InputEvent) -> void:
	if evento is InputEventMouseButton and evento.pressed and (evento.button_index == MOUSE_BUTTON_RIGHT \
			or (evento.button_index == MOUSE_BUTTON_LEFT and evento.double_click)):
		var slot := get_parent()
		if slot != null and slot.has_method("equipar_com_botao_direito"):
			slot.equipar_com_botao_direito()
			accept_event()

func exibir(item: DadosItem) -> void:
	dados = item
	modulate = Color.WHITE
	if item == null:
		icone.texture = null
		tooltip_text = ""
		_mostrar_quantidade(0)
		if _estrela_qualidade != null: _estrela_qualidade.hide()
		return
	icone.texture = IconesItens.obter(item, get_tree() if is_inside_tree() else null)
	_mostrar_quantidade(item.quantidade if item.categoria in ["semente","peixe"] else 0)
	_mostrar_qualidade(item)
	# O quadrado do item (o sprite de slot da interface) na cor da raridade, por cima do quadrado do slot
	moldura.add_theme_stylebox_override("panel", EstiloSlot.caixa_raridade(item.raridade))
	# O texto é a versão simples (acessibilidade/testes); o desenho da dica vem de _make_custom_tooltip
	tooltip_text = "%s  NV %d  %s" % [item.nome(), item.nivel, Raridades.nome(item.raridade)]
	if item.categoria in ["semente","peixe"]:
		tooltip_text = "%s  x%d" % [item.nome(), item.quantidade]
	elif item.categoria == "ferramenta":
		tooltip_text = item.nome()
	elif item.categoria == "vara":
		tooltip_text = "%s  NV %d" % [item.nome(), item.nivel]

## Número pequeno no canto de baixo (quantas sementes há na casa); 0 esconde
func _mostrar_quantidade(quantos: int) -> void:
	if quantos <= 0:
		if _rotulo_quantidade != null:
			_rotulo_quantidade.visible = false
		return
	if _rotulo_quantidade == null:
		_rotulo_quantidade = Label.new()
		_rotulo_quantidade.name = "Quantidade"
		_rotulo_quantidade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rotulo_quantidade.add_theme_font_override("font", FONTE_DICA)
		_rotulo_quantidade.add_theme_font_size_override("font_size", 6)
		_rotulo_quantidade.add_theme_color_override("font_color", Color(1, 0.96, 0.82))
		_rotulo_quantidade.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.06, 1))
		_rotulo_quantidade.add_theme_constant_override("outline_size", 2)
		_rotulo_quantidade.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_rotulo_quantidade.size = Vector2(19, 8)
		_rotulo_quantidade.position = Vector2(0, 12)
		add_child(_rotulo_quantidade)
	_rotulo_quantidade.text = str(quantos)
	_rotulo_quantidade.visible = true

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
	linhas.add_child(linha_dica(dados.nome(), dados.cor_raridade()))
	if dados.categoria == "peixe":
		var qualidade := preload("res://codigo/pesca/qualidade_peixe.gd")
		var peixes := preload("res://codigo/pesca/peixes.gd")
		linhas.add_child(linha_dica("x%d  QUALIDADE %s" % [dados.quantidade,qualidade.NOMES[dados.qualidade]],qualidade.CORES[dados.qualidade]))
		linhas.add_child(linha_dica("%s | %s" % ["MAR" if peixes.catalogo()[dados.peixe()]["ambiente"]=="mar" else "AGUA DOCE",Raridades.nome(dados.raridade)],COR_DICA_DETALHE))
		linhas.add_child(linha_dica("VENDA: %d BRASAS CADA" % qualidade.valor(peixes.brasas(dados.peixe()),dados.qualidade),COR_DICA_DETALHE))
		return linhas
	if dados.categoria == "semente":
		var planta: Dictionary = Plantas.PLANTAS.get(dados.planta(), {})
		linhas.add_child(linha_dica("x%d  %s" % [dados.quantidade, String(Plantas.NOME_RARIDADE.get(dados.raridade, ""))], dados.cor_raridade()))
		linhas.add_child(linha_dica("CRESCE EM %s" % Plantas.texto_crescimento(dados.planta()), COR_DICA_DETALHE))
		linhas.add_child(linha_dica("PLANTE NA %s" % NOMES_ESTACAO[clampi(int(planta.get("estacao", 0)), 0, 3)], COR_DICA_DETALHE))
		return linhas
	if dados.categoria == "ferramenta":
		linhas.add_child(linha_dica("FERRAMENTA DA FAZENDA", COR_DICA_DETALHE))
		return linhas
	if dados.categoria == "vara":
		linhas.add_child(linha_dica("NV %d / 5  %s" % [dados.nivel, Raridades.nome(dados.raridade)], dados.cor_raridade()))
		linhas.add_child(linha_dica("REFINE COM O NILO PARA PESCAR PEIXES MAIS DIFICEIS", COR_DICA_DETALHE))
		return linhas
	linhas.add_child(linha_dica("NV %d  %s" % [dados.nivel, Raridades.nome(dados.raridade)], dados.cor_raridade()))
	if dados.raridade != "comum" and dados.categoria in ["arma", "escudo", "cabeca", "corpo", "luvas", "botas"]:
		linhas.add_child(linha_dica("+%d%% STATUS" % roundi((dados.multiplicador_raridade() - 1.0) * 100.0), COR_DICA_DETALHE))
	for id in dados.afixos:
		linhas.add_child(linha_dica(Raridades.texto_afixo(id, dados.afixos[id]), COR_AFIXO))
	if dados.encantamento != "":
		linhas.add_child(linha_dica("%s NV %d" % [Encantamentos.nome(dados.encantamento), dados.nivel_encantamento],
				Encantamentos.cor(dados.encantamento)))
	var conjunto := Conjuntos.de_tipo(dados.tipo)
	if conjunto != null:
		var quantidade: int = conjunto.quantidade(EventosJogo.inventario_de(self).equipados)
		linhas.add_child(linha_dica("CONJUNTO %s %d/4" % [conjunto.NOME, quantidade], dados.cor_raridade()))
		var fator_nivel: float = 1.0 + conjunto.Base.GANHO_POR_NIVEL * (clampi(dados.nivel, 1, 5) - 1)
		var parcial: float = conjunto.Base.FRACAO_PARCIAL
		if conjunto.TIPO_BONUS == "raio":
			for pecas in [conjunto.Base.PECAS_PARCIAL, conjunto.Base.PECAS_COMPLETO]:
				var f: float = fator_nivel * (parcial if pecas == conjunto.Base.PECAS_PARCIAL else 1.0)
				linhas.add_child(linha_dica("%d PECAS: %d%% RAIO AO ACERTAR" % [pecas, roundi(conjunto.CHANCE_BONUS * f * 100)], COR_DICA_DETALHE))
			linhas.add_child(linha_dica("DANO %d%%  RECARGA %dS" % [roundi(conjunto.MULT_DANO_BONUS * fator_nivel * 100), roundi(conjunto.RECARGA_BONUS)], COR_DICA_DETALHE))
		elif conjunto.TIPO_BONUS == "congelamento":
			for pecas in [conjunto.Base.PECAS_PARCIAL, conjunto.Base.PECAS_COMPLETO]:
				var f: float = fator_nivel * (parcial if pecas == conjunto.Base.PECAS_PARCIAL else 1.0)
				linhas.add_child(linha_dica("%d PECAS: %d%% CONGELAR AO ACERTAR" % [pecas, roundi(conjunto.CHANCE_BONUS * f * 100)], COR_DICA_DETALHE))
			linhas.add_child(linha_dica("DURACAO %dS  RECARGA %dS" % [roundi(conjunto.DURACAO_BONUS), roundi(conjunto.RECARGA_BONUS)], COR_DICA_DETALHE))
		elif conjunto.TIPO_BONUS == "status":
			var valores: Dictionary = conjunto.get_script_constant_map()
			for pecas in [conjunto.Base.PECAS_PARCIAL, conjunto.Base.PECAS_COMPLETO]:
				var f: float = fator_nivel * (parcial if pecas == conjunto.Base.PECAS_PARCIAL else 1.0)
				linhas.add_child(linha_dica("%d PECAS: +%d%% DEFESA, +%d%% VITALIDADE" % [pecas, roundi(float(valores.get("BONUS_DEFESA", 0.0)) * f * 100), roundi(float(valores.get("BONUS_VITALIDADE", 0.0)) * f * 100)], COR_DICA_DETALHE))
	return linhas

static func linha_dica(texto: String, cor: Color) -> Label:
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
	# Todo item arrasta (armas, armaduras, aljava, ferramentas e sementes): quem recebe é que decide (mochila aceita qualquer um;
	# os slots de equipamento só a categoria deles, e o modelo recusa o que não pode, como a aljava com o arco em uso)
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

# Usados pelo slot da bigorna (codigo/logica/slot.gd)
func obter_tipo_item() -> String:
	return dados.tipo if dados != null else ""

func obter_cor_raridade() -> Color:
	return dados.cor_raridade() if dados != null else Color.WHITE

## O item está numa casa da mochila (não equipado)
func esta_na_mochila() -> bool:
	return dados != null and EventosJogo.inventario_de(self).indice_de(dados) != -1

func obter_raridade() -> String:
	return dados.raridade if dados != null else "comum"

func obter_textura_icone() -> Texture2D:
	return icone.texture

func definir_em_uso(valor: bool) -> void:
	em_uso = valor
	icone.modulate = COR_EM_USO if valor else Color.WHITE

func _mostrar_qualidade(item: DadosItem) -> void:
	if _estrela_qualidade != null: _estrela_qualidade.hide()
	if item.categoria != "peixe" or item.qualidade == 0: return
	if _estrela_qualidade == null:
		_estrela_qualidade = TextureRect.new()
		_estrela_qualidade.name = "QualidadePeixe"
		var textura := AtlasTexture.new()
		textura.atlas = preload("res://assets/pesca/qualidade/estrela.png")
		textura.region = Rect2(2,1,11,11)
		_estrela_qualidade.texture = textura
		_estrela_qualidade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_estrela_qualidade.texture_filter = TEXTURE_FILTER_NEAREST
		_estrela_qualidade.mouse_filter = MOUSE_FILTER_IGNORE
		_estrela_qualidade.position = Vector2(12,0)
		_estrela_qualidade.size = Vector2(8,8)
		var material_estrela := ShaderMaterial.new()
		material_estrela.shader = preload("res://codigo/pesca/cor_vara.gdshader")
		_estrela_qualidade.material = material_estrela
		add_child(_estrela_qualidade)
	_estrela_qualidade.material.set_shader_parameter("cor_nivel",preload("res://codigo/pesca/qualidade_peixe.gd").CORES[item.qualidade])
	_estrela_qualidade.show()
