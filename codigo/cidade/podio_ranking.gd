extends Node2D
## Monumento sazonal; jogadores são representações visuais, sem inventário, física ou participação nas rotinas.
const Dados := preload("res://codigo/cidade/dados_cidade.gd")
const Profundidade := preload("res://codigo/globais/profundidade.gd")
const Personagem := preload("res://codigo/jogador/personagem_ranking.gd")
const Visual := preload("res://codigo/dados/visual_ranking.gd")
const FONTE := preload("res://assets/ui/Planes_ValMore.ttf")
const ESTACOES := ["primavera","verao","outono","inverno"]
const PES := [Vector2(-36,-29),Vector2(0,-38),Vector2(37,-23)]
const ORDEM := [1,0,2]
var imagem: Sprite2D
var ocupantes: Node2D
var _estacao := -1
var _tempo := 0.0
var _consulta := 0.0
var _ultima_lista: Array = []

func _ready() -> void:
	name = "PodioRanking"
	position = Dados.ponto("podio_ranking")
	z_as_relative = false
	z_index = Profundidade.z_de(position.y)
	imagem = Sprite2D.new()
	imagem.name = "Monumento"
	imagem.centered = false
	imagem.position = Vector2(-64,-48)
	imagem.scale = Vector2.ONE/6.0
	imagem.texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(imagem)
	for i in 3:
		var numero := Sprite2D.new()
		numero.name = "Lugar%d" % (ORDEM[i]+1)
		numero.texture = load("res://assets/cenario/cidade/podio_ranking/numero_%d.png" % (ORDEM[i]+1))
		numero.scale = Vector2.ONE*0.25
		numero.self_modulate = Color("49331e")
		numero.texture_filter = TEXTURE_FILTER_NEAREST
		# Centros físicos dos medalhões na arte; textura recortada pela tinta do dígito.
		numero.position = [Vector2(-36,-13),Vector2(0,-18),Vector2(37,-11)][i]
		add_child(numero)
	var corpo := StaticBody2D.new()
	corpo.name = "BaseFisica"
	corpo.collision_layer = 64
	corpo.collision_mask = 0
	var forma := CollisionShape2D.new()
	var retangulo := RectangleShape2D.new()
	retangulo.size = Vector2(114,20)
	forma.shape = retangulo
	forma.position.y = -10
	corpo.add_child(forma)
	add_child(corpo)
	ocupantes = Node2D.new()
	ocupantes.name = "Colocados"
	add_child(ocupantes)
	var consulta := preload("res://codigo/logica/interagivel.gd").new()
	consulta.name = "ConsultarRanking"
	consulta.nome_tela = "ranking"
	consulta.so_entre_ondas = false
	consulta.position.y = 14
	# Indicador preso à lateral da base, fora do caminho dos pés e dos medalhões.
	consulta.deslocamento_aviso = Vector2(76,-22)
	var alcance := CollisionShape2D.new()
	var area := RectangleShape2D.new()
	area.size = Vector2(128,36)
	alcance.shape = area
	consulta.add_child(alcance)
	add_child(consulta)
	Ranking.lista_atualizada.connect(_atualizar_lista)
	_atualizar_lista(Ranking.lista_cache)
	_atualizar_estacao()
	Ranking.buscar()

func _rotulo(texto: String, largura: float, tamanho: int) -> Label:
	var rotulo := Label.new()
	rotulo.clip_text = true
	rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rotulo.add_theme_font_override("font",FONTE)
	rotulo.add_theme_font_size_override("font_size",tamanho)
	rotulo.add_theme_color_override("font_color",Color("fff4d9"))
	rotulo.add_theme_color_override("font_outline_color",Color("30251e"))
	rotulo.add_theme_constant_override("outline_size",2)
	rotulo.reset_size()
	rotulo.size = Vector2(largura,18)
	rotulo.text = texto
	return rotulo

func _atualizar_lista(lista: Array) -> void:
	var primeiros := lista.slice(0,3)
	if primeiros == _ultima_lista: return
	_ultima_lista = primeiros.duplicate(true)
	for filho in ocupantes.get_children():
		ocupantes.remove_child(filho)
		filho.queue_free()
	for i in 3:
		var lugar: int = ORDEM[i]
		if lugar >= primeiros.size(): continue
		var linha: Dictionary = primeiros[lugar]
		var ator := Node2D.new()
		ator.name = "Colocado%d" % (lugar+1)
		ator.position = PES[i]
		ocupantes.add_child(ator)
		var aparencia := Visual.normalizar(linha.get("aparencia"))
		if not aparencia.is_empty(): aparencia["arma_mais_usada"] = preload("res://codigo/dados/armas_ranking.gd").validar(linha.get("arma_mais_usada"))
		var topo := -35.0
		if not aparencia.is_empty():
			var personagem := Personagem.new()
			personagem.name = "Personagem"
			personagem.dados = aparencia
			ator.add_child(personagem)
			personagem.renderizado.connect(_encaixar_nomes)
			topo = personagem.topo_aparente()
		else:
			var pendente := _rotulo("VISUAL PENDENTE",76,6)
			pendente.position = Vector2(-38,-26)
			ator.add_child(pendente)
		var apelido := _rotulo(str(linha.get("apelido","")).left(16),48,6)
		apelido.name = "Nickname"
		# Mede o contorno renderizado do personagem; mantém nome fora da silhueta.
		apelido.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		apelido.clip_text = false
		apelido.add_theme_font_size_override("font_size",5 if FONTE.get_string_size(apelido.text,HORIZONTAL_ALIGNMENT_LEFT,-1,6).x > 44 else 6)
		apelido.size = Vector2(48,12)
		apelido.position = Vector2(-24,topo-24)
		apelido.z_as_relative = false
		apelido.z_index = 890
		ator.add_child(apelido)
	_encaixar_nomes.call_deferred()

## Recalcula depois do layout da fonte; apelidos longos usam duas linhas completas.
func _encaixar_nomes() -> void:
	var usados: Array[Rect2] = []
	for lugar in [1,2,3]:
		var ator := ocupantes.get_node_or_null("Colocado%d" % lugar)
		if ator == null: continue
		var nome: Label = ator.get_node("Nickname")
		nome.size = Vector2(48,12)
		var altura := maxf(12,nome.get_minimum_size().y)
		nome.size.y = altura
		var personagem := ator.get_node_or_null("Personagem")
		var topo: float = personagem.topo_aparente() if personagem != null else -35.0
		nome.position = Vector2(-24,topo-altura-5)
		var retangulo := Rect2(ator.position+nome.position,nome.size)
		while usados.any(func(outro: Rect2) -> bool: return outro.grow(2).intersects(retangulo)):
			nome.position.y -= 4
			retangulo.position.y -= 4
		usados.append(retangulo)

func _atualizar_estacao() -> void:
	var atual: int = get_parent().estacao_visual()
	if atual == _estacao: return
	_estacao = atual
	imagem.texture = load("res://assets/cenario/cidade/podio_ranking/%s.png" % ESTACOES[atual])

func _process(delta: float) -> void:
	_tempo += delta
	_consulta += delta
	if _tempo >= 2.0:
		_tempo = 0.0
		_atualizar_estacao()
		var jogador := Cooperativo._jogador1() as Node2D
		if jogador != null:
			var anterior: Dictionary = Ranking.visual_pendente
			Ranking.capturar_jogador(jogador)
			if Ranking.visual_pendente != anterior: Ranking.sincronizar_visual()
		var parceiro := Cooperativo.jogador2() as Node2D
		if parceiro != null:
			var perfil := Ranking.para_jogador(parceiro)
			var anterior: Dictionary = perfil.visual_pendente
			perfil.capturar_jogador(parceiro)
			if perfil.visual_pendente != anterior: perfil.sincronizar_visual()
	if _consulta >= 60.0:
		_consulta = 0.0
		Ranking.buscar()
