extends Node2D

## Estado dos pedidos do morador; acompanha o ator em todos os mapas da rotina.
const Dados := preload("res://codigo/cidade/dados_cidade.gd")
const Jornada := preload("res://codigo/cidade/jornada_limiar.gd")
var principal := false
var pronto := false
var _rotulo: Label
var _circulo: Panel
var _espera := 0.0

func _ready() -> void:
	name = "IndicadorPedido"
	position = _acima_da_cabeca()
	z_as_relative = false
	z_index = 900
	_circulo = Panel.new()
	_circulo.name = "CirculoPedido"
	_circulo.size = Vector2(18,18)
	_circulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color("30241b")
	estilo.border_color = Color("e4bd72")
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(9)
	_circulo.add_theme_stylebox_override("panel",estilo)
	add_child(_circulo)
	_rotulo = Label.new()
	_rotulo.text = "?"
	_rotulo.size = Vector2(18,18)
	_rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rotulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_rotulo.add_theme_font_override("font",preload("res://assets/ui/Planes_ValMore.ttf"))
	_rotulo.add_theme_font_size_override("font_size",9)
	_rotulo.add_theme_color_override("font_outline_color",Color("302016"))
	_rotulo.add_theme_constant_override("outline_size",1)
	_rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rotulo)
	Cidade.alterado.connect(_atualizar)
	Fazenda.bolsas_alteradas.connect(_atualizar)
	Progresso.checkpoint_alterado.connect(_atualizar)
	_atualizar()

func _process(delta: float) -> void:
	# O círculo pertence ao morador: não perseguir a borda do balão de fala
	# nem prender o marcador à tela quando a câmera se afasta.
	var baloes := _baloes_visiveis()
	position = _acima_da_cabeca()
	# Desvia apenas para cima: o centro permanece sobre a cabeça do morador.
	var para_local: Transform2D = get_parent().global_transform.affine_inverse()
	for tentativa in baloes.size() + 1:
		var mudou := false
		for balao in baloes:
			var area: Rect2 = para_local * balao
			if Rect2(position, Vector2(18,18)).grow(2).intersects(area):
				position.y = floorf(area.position.y - 22)
				mudou = true
		if not mudou:
			break
	_espera -= delta
	if _espera<=0:
		_espera = 0.5
		_atualizar()

func _acima_da_cabeca() -> Vector2:
	var altura: float = Dados.geometria_sprite(get_parent().id).get("altura_mapa",31)
	# Os pés dos moradores ficam em y=9; deixa 3px entre cabeça e círculo.
	return Vector2(-9, floorf(9 - altura - 3 - 18))

## Retângulos (em coordenadas do mundo) dos balões de fala na tela agora, de qualquer morador
func _baloes_visiveis() -> Array[Rect2]:
	var lista: Array[Rect2] = []
	for morador in get_tree().get_nodes_in_group("moradores_cidade"):
		var balao = morador.get("_balao")
		if balao is Label and balao.visible and morador.visible and morador.get_world_2d() == get_parent().get_world_2d():
			lista.append(balao.get_global_transform() * Rect2(Vector2.ZERO,balao.size))
	return lista

func _atualizar(_valor: Variant = null) -> void:
	var ativo := false
	var disponivel := false
	pronto = false
	var id: String = get_parent().id
	for missao in Dados.MISSOES:
		if Dados.MISSOES[missao]["dono"] != id: continue
		var estado: String = Cidade.missoes.get(missao,{}).get("estado","")
		if estado == "" and Dados.missao_na_estacao(missao,Calendario.estacao()):
			disponivel = true
		if estado != "aceita": continue
		ativo = true
		var progresso := Cidade.progresso_missao(missao)
		if progresso.x>=progresso.y: pronto = true
		# Pedidos são compartilhados; qualquer parceiro com os itens pode entregar a parte dele.
		var p2 := Cooperativo.jogador2()
		if p2 != null:
			progresso = Cidade.progresso_missao(missao,p2)
			if progresso.x>=progresso.y: pronto = true
	visible = ativo or disponivel
	# Entrega pronta tem prioridade, mesmo que o morador ofereça outro pedido.
	_rotulo.text = "?" if pronto or not disponivel else "!"
	_centralizar_simbolo()
	_rotulo.add_theme_color_override("font_color",Color("ffe07a") if pronto or disponivel else Color("a3a7af"))
	var objetivo := Jornada.rastreio(Cidade)
	principal = objetivo.dono == id and not Introducao.ativa()
	if principal:
		visible = true

func _centralizar_simbolo() -> void:
	# Plane's 9px: compensa o avanço lateral e a caixa de linha maior que o glifo.
	# Ajustes medidos na renderização; o desenho fica no centro do círculo de 18px.
	_rotulo.position = Vector2(2 if _rotulo.text == "?" else 1, -1)
