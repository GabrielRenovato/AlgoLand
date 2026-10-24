extends Control

## Caldeirão da fazenda: transforma a bolsa de colheita em poções (receitas sazonais de codigo/dados/pocoes.gd).
## Mesmo visual da mochila e da loja do mercante (tema_sidebar.tres, moldura do TileMap.png, título escuro no alto e o
## X de fechar), na lateral direita (desliza da borda). Inspirado na mesa de poções do Hogwarts Legacy:
##  - a grade de frascos (casas BotaoSlot como os itens da loja; a escolhida fica com a moldura dourada; frasco apagado =
##    falta ingrediente; no canto, quantas o jogador tem);
##  - embaixo, a poção escolhida: nome, texto, efeito, quantas tem, os ingredientes ("tem / precisa", verde quando dá e
##    vermelho quando falta) e o botão FAZER.
## Escolher: passar o mouse ou mover o foco (controle/setas). Fazer: clicar/apertar A no frasco escolhido ou no FAZER.

const IconesFazenda := preload("res://codigo/ui/icones_fazenda.gd")
const Pocoes := preload("res://codigo/dados/pocoes.gd")
const Peixes := preload("res://codigo/pesca/peixes.gd")

const COR_TEXTO := Color(0.93, 0.9, 0.85)
const COR_TEM := Color(0.6, 1, 0.5)
const COR_FALTA := Color(1, 0.45, 0.45)
const COR_FEITO := Color(0.6, 1, 0.5)
const COR_APAGADO := Color(0.45, 0.45, 0.5, 0.8)
## Mesmas medidas dos itens da loja (tela_mercante.gd)
const LADO_CASA := 30
const RECUO_ICONE := 5
const LADO_INGREDIENTE := 22

@onready var _grade: GridContainer = %Grade
@onready var _nome: Label = %Nome
@onready var _texto: Label = %Texto
@onready var _efeito: Label = %Efeito
@onready var _info: Label = %Info
@onready var _ingredientes: VBoxContainer = %Ingredientes
@onready var aviso: Label = %Aviso
@onready var botao_fazer: Button = %BotaoFazer
@onready var botao_fechar: Button = %BotaoFechar

var selecionada: String = ""
## id da poção -> Button da casa na grade
var casas: Dictionary = {}

func _ready() -> void:
	botao_fechar.pressed.connect(EventosJogo.fechar_tela_de.bind(self, "caldeirao"))
	botao_fazer.set_meta(Sons.META_SOM_PROPRIO, true)
	botao_fazer.pressed.connect(fazer)
	for id in Pocoes.ORDEM:
		_grade.add_child(_nova_casa(id))
	visibility_changed.connect(_ao_visibilidade_alterada)

func _ao_visibilidade_alterada() -> void:
	if visible:
		_avisar("", COR_FEITO)
		if selecionada == "":
			selecionada = _primeira_da_estacao()
		_atualizar()

## Chamado pela Interface ao abrir a tela: o foco vai para o frasco escolhido (o primeiro que dá para fazer)
func focar_inicio(preferida := "") -> void:
	var id := preferida
	if not casas.has(id):
		id = _primeira_da_estacao()
		for outra in Pocoes.ORDEM:
			if Fazenda.motivo_para_nao_fazer(outra,EventosJogo.dono(self)) == "":
				id = outra
				break
	selecionar(id)
	Controle.focar(casas[id])

## Cura é acessível em qualquer estação; o foco prioriza o que já pode ser preparado.
func _primeira_da_estacao() -> String:
	return Pocoes.ORDEM[0]

func selecionar(id: String) -> void:
	if not Pocoes.POCOES.has(id):
		return
	selecionada = id
	_atualizar()

## Faz a poção escolhida (A no frasco, clique no frasco ou no FAZER)
func fazer(id := "") -> void:
	if id != "":
		selecionada = id
	var motivo := Fazenda.fazer_pocao(selecionada,EventosJogo.dono(self))
	if motivo != "":
		_avisar(motivo, COR_FALTA)
		Sons.tocar("erro", 0.0)
		_atualizar()
		return
	_avisar("+1 %s" % String(Pocoes.dados(selecionada)["nome"]), COR_FEITO)
	Sons.tocar("caldeirao", 0.0)
	get_tree().call_group("caldeirao", "ferver")
	_atualizar()

# O aviso só ocupa espaço quando tem texto
func _avisar(texto: String, cor: Color) -> void:
	aviso.text = texto
	aviso.add_theme_color_override("font_color", cor)
	aviso.visible = texto != ""

# Casa da grade igual aos itens da loja: BotaoSlot com o ícone recuado (o icon do Button cobriria a moldura)
func _nova_casa(id: String) -> Button:
	var casa := Button.new()
	casa.name = "Casa_" + id
	casa.theme_type_variation = &"BotaoSlot"
	casa.custom_minimum_size = Vector2(LADO_CASA, LADO_CASA)
	casa.set_meta(Sons.META_SOM_PROPRIO, true)
	casa.tooltip_text = String(Pocoes.dados(id)["nome"])
	var icone := TextureRect.new()
	icone.name = "Icone"
	icone.texture = Pocoes.icone(id)
	icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icone.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icone.offset_left = RECUO_ICONE
	icone.offset_top = RECUO_ICONE
	icone.offset_right = -RECUO_ICONE
	icone.offset_bottom = -RECUO_ICONE
	casa.add_child(icone)
	var quantidade := Label.new()
	quantidade.name = "Quantidade"
	quantidade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quantidade.add_theme_font_size_override("font_size", 8)
	quantidade.add_theme_color_override("font_color", COR_TEXTO)
	quantidade.add_theme_color_override("font_outline_color", Color(0.13, 0.12, 0.18))
	quantidade.add_theme_constant_override("outline_size", 3)
	quantidade.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	quantidade.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	quantidade.grow_vertical = Control.GROW_DIRECTION_BEGIN
	quantidade.offset_right = -3
	quantidade.offset_bottom = 1
	casa.add_child(quantidade)
	casa.focus_entered.connect(selecionar.bind(id))
	casa.mouse_entered.connect(selecionar.bind(id))
	casa.pressed.connect(fazer.bind(id))
	casas[id] = casa
	return casa

func _atualizar() -> void:
	# A escolhida usa a moldura dourada do BotaoSlot (a mesma do mouse em cima) mesmo sem o mouse
	var dourada := get_theme_stylebox("hover", &"BotaoSlot")
	var normal := get_theme_stylebox("normal", &"BotaoSlot")
	for id: String in casas:
		var casa: Button = casas[id]
		casa.add_theme_stylebox_override("normal", dourada if id == selecionada else normal)
		var pode := Fazenda.motivo_para_nao_fazer(id,EventosJogo.dono(self)) == ""
		(casa.get_node("Icone") as TextureRect).modulate = Color.WHITE if pode else COR_APAGADO
		var tem := Fazenda.quantidade_pocoes(id,EventosJogo.dono(self))
		(casa.get_node("Quantidade") as Label).text = str(tem) if tem > 0 else ""
	_atualizar_detalhe()

func _atualizar_detalhe() -> void:
	if not Pocoes.POCOES.has(selecionada):
		return
	var dados := Pocoes.dados(selecionada)
	_nome.text = String(dados["nome"])
	var estacao := Calendario.estacao()
	var formula := Pocoes.receita_da_estacao(selecionada,estacao)
	_texto.text = "CALDO DE PEIXES DA ESTACAO, PREPARADO NO CALDEIRAO." if estacao == 3 else "PREPARADA COM A COLHEITA DA ESTACAO."
	_efeito.text = Pocoes.texto_efeito(selecionada) + ("" if float(dados["duracao"]) > 0.0 else " NA HORA")
	_info.text = "TEM %d | %s" % [Fazenda.quantidade_pocoes(selecionada,EventosJogo.dono(self)), Calendario.NOMES[estacao]]
	for filho in _ingredientes.get_children():
		_ingredientes.remove_child(filho)
		filho.queue_free()
	var receita: Dictionary = formula["receita"]
	for planta in receita:
		_ingredientes.add_child(_linha_ingrediente(planta, int(receita[planta])))
	var peixes: Dictionary = formula["peixes"]
	for peixe in peixes:
		_ingredientes.add_child(_linha_peixe(peixe, int(peixes[peixe])))
	botao_fazer.disabled = Fazenda.motivo_para_nao_fazer(selecionada,EventosJogo.dono(self)) != ""

## Ícone da planta numa casinha (a mesma moldura de slot), o nome e "tem / precisa" (verde quando dá, vermelho quando falta)
func _linha_ingrediente(planta: String, precisa: int) -> Control:
	return _linha("Ingrediente_" + planta, IconesFazenda.item_colhido(planta), String(Fazenda.PLANTAS[planta]["nome"]),
		Fazenda.quantidade_colhida(planta,EventosJogo.dono(self)), precisa)

## O peixe do inverno: mesmo desenho do ingrediente de planta
func _linha_peixe(peixe: String, precisa: int) -> Control:
	return _linha("Ingrediente_" + peixe, Peixes.icone(peixe), Peixes.nome(peixe), Fazenda.quantidade_peixes(peixe,EventosJogo.dono(self)), precisa)

func _linha(nome_no: String, textura: Texture2D, titulo: String, tem: int, precisa: int) -> Control:
	var linha := HBoxContainer.new()
	linha.name = nome_no
	linha.add_theme_constant_override("separation", 4)
	var casinha := PanelContainer.new()
	casinha.custom_minimum_size = Vector2(LADO_INGREDIENTE, LADO_INGREDIENTE)
	casinha.add_theme_stylebox_override("panel", get_theme_stylebox("normal", &"BotaoSlot"))
	var icone := TextureRect.new()
	icone.texture = textura
	icone.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	casinha.add_child(icone)
	linha.add_child(casinha)
	var nome := Label.new()
	nome.text = titulo
	nome.custom_minimum_size = Vector2(76, 0)
	nome.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	linha.add_child(nome)
	var contagem := Label.new()
	contagem.name = "Contagem"
	contagem.text = "%d / %d" % [tem, precisa]
	contagem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	contagem.add_theme_color_override("font_color", COR_TEM if tem >= precisa else COR_FALTA)
	linha.add_child(contagem)
	return linha
