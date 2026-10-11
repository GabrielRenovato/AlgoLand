extends Node2D

## Um raio da tempestade (criado por Codigos/Design/clima.gd): aviso circular no chão (indicador_ataque) por ~1 s,
## depois a queda — folhas "lightning" do pacote Weather Effects, clarão branco na tela, tremor de câmera, trovão —
## e dano em área em quem estiver dentro do círculo: inimigos E o jogador (que se livra correndo, ou com o dash).

const IndicadorAtaqueScript := preload("res://Codigos/Efeitos/indicador_ataque.gd")
const Profundidade := preload("res://Codigos/Globais/profundidade.gd")
const FOLHA_REPETIVEL := preload("res://Tiles/Weather Effects/weather effects, lightning repeatable 32x80.png")
const FOLHA_IMPACTO := preload("res://Tiles/Weather Effects/weather effects, lightning impact 32x48.png")
const TEXTURA_LUZ := preload("res://recursos/luz/luz_radial.tres")

## Raio da área de dano (px), igual ao do indicador no chão
const RAIO_AREA := 28.0
const LARGURA := 32
const ALTURA_REPETIVEL := 80
const ALTURA_IMPACTO := 48
## O clarão do impacto fica um pouco acima da base do sprite: a base desce alguns px para o centro cair no alvo
const AJUSTE_BASE := 3.0
## Dano base ao inimigo (vezes o multiplicador de vida da onda) e ao jogador (vezes o de dano): moderado, cresce com a onda
const DANO_INIMIGO_BASE := 20.0
const DANO_JOGADOR_BASE := 14.0
## Chefes levam só uma fração (o raio não deve resolver a luta)
const FRACAO_DANO_CHEFE := 0.25
const FORCA_EMPURRAO := 140.0
const ATRASO_TROVAO := 0.12
const DURACAO_RAIO := 0.7

# Texturas fatiadas uma vez só e compartilhadas por todos os raios
static var _repetiveis: Array[Texture2D] = []
static var _impactos: Array[Texture2D] = []

var raio_area := RAIO_AREA
var dano_inimigo := 0
var dano_jogador := 0
var caiu := false
## Quantos alvos o último raio atingiu (para testes e depuração)
var atingidos_inimigos := 0
var atingiu_jogador := false

var _jogador: Node
var _tempo_aviso := 1.0
var _tempo := 0.0
var _indicador: Node2D
var _alvo := Vector2.ZERO

## Dano do raio em função do multiplicador da onda (vida dos inimigos / dano dos inimigos)
static func dano_para_inimigo(mult_vida: float) -> int:
	return maxi(1, roundi(DANO_INIMIGO_BASE * mult_vida))

static func dano_para_jogador(mult_dano: float) -> int:
	return maxi(1, roundi(DANO_JOGADOR_BASE * mult_dano))

static func _preparar_texturas() -> void:
	if not _repetiveis.is_empty():
		return
	var rep := FOLHA_REPETIVEL.get_image()
	var imp := FOLHA_IMPACTO.get_image()
	for i in 2:
		_repetiveis.append(ImageTexture.create_from_image(rep.get_region(Rect2i(i * LARGURA, 0, LARGURA, ALTURA_REPETIVEL))))
		_impactos.append(ImageTexture.create_from_image(imp.get_region(Rect2i(i * LARGURA, 0, LARGURA, ALTURA_IMPACTO))))

func iniciar(ponto: Vector2, aviso: float, dano_a_inimigos: int, dano_ao_jogador: int, jogador: Node = null) -> void:
	_alvo = ponto
	_tempo_aviso = maxf(aviso, 0.0)
	dano_inimigo = dano_a_inimigos
	dano_jogador = dano_ao_jogador
	_jogador = jogador
	global_position = ponto
	add_to_group("raios_clima")
	_indicador = IndicadorAtaqueScript.new()
	add_child(_indicador)
	_indicador.configurar(ponto, raio_area)

func _process(delta: float) -> void:
	_tempo += delta
	if caiu:
		return
	if _tempo >= _tempo_aviso:
		cair()
	elif is_instance_valid(_indicador):
		_indicador.atualizar_progresso(_tempo / maxf(_tempo_aviso, 0.001))

## A queda: dano na hora (o aviso já foi a chance de fugir) e o espetáculo em volta
func cair() -> void:
	if caiu:
		return
	caiu = true
	if is_instance_valid(_indicador):
		_indicador.detonar_impacto()
	_causar_dano()
	_desenhar_raio()
	get_tree().call_group("clima", "piscar_raio", 0.8)
	_tremer_camera()
	get_tree().create_timer(ATRASO_TROVAO).timeout.connect(_tocar_trovao)
	# sem indicador/raio por mais tempo que o necessário
	get_tree().create_timer(DURACAO_RAIO).timeout.connect(queue_free)

func _causar_dano() -> void:
	atingidos_inimigos = 0
	for no in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(no) or not (no is Node2D) or not no.has_method("receber_dano"):
			continue
		if bool(no.get("esta_morto")):
			continue
		var inimigo := no as Node2D
		if inimigo.global_position.distance_to(_alvo) > raio_area:
			continue
		var dano := dano_inimigo
		if bool(inimigo.get("eh_chefe")):
			dano = maxi(1, roundi(dano * FRACAO_DANO_CHEFE))
		inimigo.call("receber_dano", dano, _direcao_empurrao(inimigo.global_position) * FORCA_EMPURRAO)
		atingidos_inimigos += 1
	atingiu_jogador = false
	if is_instance_valid(_jogador) and _jogador is Node2D and not bool(_jogador.get("estaMorto")):
		# a área é no chão: vale a distância até os pés do jogador
		var pes := (_jogador as Node2D).global_position + Vector2(0, Profundidade.PES_JOGADOR)
		if pes.distance_to(_alvo) <= raio_area:
			atingiu_jogador = true
			# receber_dano já respeita a invulnerabilidade (dash, depois de um golpe, reviver)
			_jogador.call("receber_dano", dano_jogador, _direcao_empurrao(pes) * FORCA_EMPURRAO)

func _direcao_empurrao(de: Vector2) -> Vector2:
	var direcao := de - _alvo
	return direcao.normalized() if direcao.length() > 1.0 else Vector2.ZERO

# O raio é desenhado "do céu": N trechos repetíveis empilhados + a base com o clarão do impacto, na posição do alvo.
# Duas variações alternam rápido (o "pisca" do pacote) antes de sumir
func _desenhar_raio() -> void:
	_preparar_texturas()
	var visivel := get_viewport().get_canvas_transform().affine_inverse() * Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	var topo_base := _alvo.y + AJUSTE_BASE - ALTURA_IMPACTO
	var trechos := clampi(ceili((topo_base - (visivel.position.y - 16.0)) / ALTURA_REPETIVEL), 1, 8)
	var visuais: Array[Node2D] = []
	for variacao in 2:
		var visual := Node2D.new()
		visual.top_level = true
		visual.z_as_relative = false
		visual.z_index = Profundidade.Z_TOPO + 2
		visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		visual.visible = false
		# sem a tintura da noite e somando luz ao que está atrás: o raio é a própria luz
		var material := CanvasItemMaterial.new()
		material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		visual.material = material
		var coluna := TextureRect.new()
		coluna.stretch_mode = TextureRect.STRETCH_TILE
		coluna.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		coluna.mouse_filter = Control.MOUSE_FILTER_IGNORE
		coluna.texture = _repetiveis[variacao]
		coluna.size = Vector2(LARGURA, trechos * ALTURA_REPETIVEL)
		coluna.position = Vector2(_alvo.x - LARGURA / 2.0, topo_base - trechos * ALTURA_REPETIVEL)
		coluna.use_parent_material = true
		visual.add_child(coluna)
		var base := Sprite2D.new()
		base.texture = _impactos[variacao]
		base.centered = false
		base.position = Vector2(_alvo.x - LARGURA / 2.0, topo_base)
		base.use_parent_material = true
		visual.add_child(base)
		add_child(visual)
		visuais.append(visual)
	# luz que ilumina o chão ao redor (de noite o raio clareia a cena)
	var luz := PointLight2D.new()
	luz.texture = TEXTURA_LUZ
	luz.color = Color(0.8, 0.85, 1.0)
	luz.energy = 1.6
	luz.texture_scale = 220.0 / 128.0
	luz.shadow_enabled = false
	add_child(luz)
	var tween_luz := luz.create_tween()
	tween_luz.tween_property(luz, "energy", 0.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# A, B, A, B e some
	var tween := create_tween()
	for i in 4:
		tween.tween_callback(_mostrar_so.bind(visuais, i % 2, 1.0 if i < 3 else 0.7))
		tween.tween_interval(0.06)
	tween.tween_callback(_mostrar_so.bind(visuais, 0, 0.35))
	tween.tween_interval(0.08)
	tween.tween_callback(_mostrar_so.bind(visuais, -1, 0.0))

func _mostrar_so(visuais: Array[Node2D], indice: int, alfa: float) -> void:
	for i in visuais.size():
		visuais[i].visible = i == indice
		visuais[i].modulate.a = alfa

func _tocar_trovao() -> void:
	# mais alto quanto mais perto do jogador
	var volume := -8.0
	if is_instance_valid(_jogador) and _jogador is Node2D and (_jogador as Node2D).global_position.distance_to(_alvo) < 120.0:
		volume = -2.0
	Sons.tocar("trovao", 0.08, volume)

# Mesmo tremor do Inimigo-base._tremer_camera, mais forte quanto mais perto
func _tremer_camera() -> void:
	if not is_instance_valid(_jogador):
		return
	var camera := _jogador.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return
	var perto := (_jogador as Node2D).global_position.distance_to(_alvo) < 120.0
	var intensidade := 4.0 if perto else 2.0
	var duracao := 0.35
	var passos := 6
	var tween := camera.create_tween()
	for i in passos:
		var forca := intensidade * (1.0 - float(i) / passos)
		tween.tween_property(camera, "offset", Vector2(randf_range(-forca, forca), randf_range(-forca, forca)), duracao / passos)
	tween.tween_property(camera, "offset", Vector2.ZERO, 0.03)
