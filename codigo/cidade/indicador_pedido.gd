extends Node2D

## Estado dos pedidos do morador; acompanha o ator em todos os mapas da rotina.
const Dados := preload("res://codigo/cidade/dados_cidade.gd")
const Jornada := preload("res://codigo/cidade/jornada_limiar.gd")
var principal := false
var pronto := false
var _rotulo: Label
var _espera := 0.0
var _sprite: Sprite2D

func _ready() -> void:
	name = "IndicadorPedido"
	position = Vector2(10,-44)
	z_as_relative = false
	z_index = 900
	_sprite = Sprite2D.new()
	_sprite.texture = preload("res://assets/ui/baloes/pedido_cinza.png")
	_sprite.centered = false
	add_child(_sprite)
	_rotulo = Label.new()
	_rotulo.text = "?"
	_rotulo.visible = false
	_rotulo.position = Vector2(1,-1)
	_rotulo.size = Vector2(10,14)
	_rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rotulo.add_theme_font_override("font",preload("res://assets/ui/Planes_ValMore.ttf"))
	_rotulo.add_theme_font_size_override("font_size",12)
	_rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rotulo)
	Cidade.alterado.connect(_atualizar)
	Fazenda.bolsas_alteradas.connect(_atualizar)
	Progresso.checkpoint_alterado.connect(_atualizar)
	_atualizar()

func _process(delta: float) -> void:
	var fala: Label = get_parent()._balao
	var transformacao: Transform2D = get_parent().get_global_transform_with_canvas()
	var escala := maxf(transformacao.get_scale().x,0.01)
	var tela := get_viewport_rect().size/escala
	var origem := transformacao.origin/escala
	# Centrado em cima da cabeça (o desenho tem 16 px de largura). Com balão de fala (o do próprio morador ou o do vizinho
	# que está conversando com ele), o ícone sai do caminho: lado do balão, depois outros pontos em volta da cabeça.
	var candidatos: Array[Vector2] = []
	if fala.visible:
		candidatos.append(Vector2(fala.position.x+fala.size.x+3,fala.position.y+fala.size.y-16))
		candidatos.append(Vector2(fala.position.x-19,fala.position.y+fala.size.y-16))
		candidatos.append(Vector2(fala.position.x+fala.size.x-16,fala.position.y+fala.size.y+4))
	candidatos.append_array([Vector2(-8,-44),Vector2(-28,-30),Vector2(12,-30),Vector2(-8,-76),Vector2(-28,-52),Vector2(12,-52)])
	var baloes := _baloes_visiveis()
	position = candidatos[0]
	for candidato in candidatos:
		var ponto := Vector2(clampf(candidato.x,4-origem.x,tela.x-origem.x-20),clampf(candidato.y,4-origem.y,tela.y-origem.y-20))
		var retangulo := Rect2(get_parent().global_position+ponto,Vector2(16,16)).grow(2)
		if not baloes.any(func(balao: Rect2) -> bool: return balao.intersects(retangulo)):
			position = ponto
			break
	position.x = clampf(position.x,4-origem.x,tela.x-origem.x-20)
	position.y = clampf(position.y,4-origem.y,tela.y-origem.y-20)
	_espera -= delta
	if _espera<=0:
		_espera = 0.5
		_atualizar()

## Retângulos (em coordenadas do mundo) dos balões de fala na tela agora, de qualquer morador
func _baloes_visiveis() -> Array[Rect2]:
	var lista: Array[Rect2] = []
	for morador in get_tree().get_nodes_in_group("moradores_cidade"):
		var balao = morador.get("_balao")
		if balao is Label and balao.visible and morador.visible and morador.get_world_2d() == get_parent().get_world_2d():
			lista.append(Rect2(morador.global_position+balao.position,balao.size))
	return lista

func _atualizar(_valor: Variant = null) -> void:
	var ativo := false
	pronto = false
	var id: String = get_parent().id
	for missao in Cidade.missoes:
		if not Dados.MISSOES.has(missao) or Dados.MISSOES[missao]["dono"]!=id or Cidade.missoes[missao]["estado"]!="aceita": continue
		ativo = true
		var progresso := Cidade.progresso_missao(missao)
		if progresso.x>=progresso.y: pronto = true
		# Pedidos são compartilhados; qualquer parceiro com os itens pode entregar a parte dele.
		var p2 := Cooperativo.jogador2()
		if p2 != null:
			progresso = Cidade.progresso_missao(missao,p2)
			if progresso.x>=progresso.y: pronto = true
	visible = ativo
	_rotulo.add_theme_color_override("font_color",Color("ffe07a") if pronto else Color("a3a7af"))
	_sprite.texture = preload("res://assets/ui/baloes/pedido_amarelo.png") if pronto else preload("res://assets/ui/baloes/pedido_cinza.png")
	var objetivo := Jornada.rastreio(Cidade)
	principal = objetivo.dono == id and not Introducao.ativa()
	if principal:
		visible = true
		_sprite.texture = preload("res://assets/ui/baloes/pedido_amarelo.png") if objetivo.fase == "aceitar" or pronto else preload("res://assets/ui/baloes/pedido_cinza.png")
	_rotulo.visible = false
	_sprite.visible = true
