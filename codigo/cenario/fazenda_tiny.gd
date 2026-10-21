extends Node

## Comparação visual local da fazenda: troca recursos no lugar, sem recriar mapa nem alterar o save.
const PASTA := "res://assets/cenario/fazenda/tiny/"
const NOMES := ["primavera", "verao", "outono", "inverno"]

var ativo := false
var _terreno: Node2D
var _originais: Dictionary = {}
var _folhas: Array[Texture2D] = []
var _casa_obstaculo: CollisionPolygon2D
var _poligono_casa: PackedVector2Array
var _area_casa: Rect2
var _detalhe_casa: Node
var _processo_detalhe := true

func _ready() -> void:
	_terreno = get_parent().get_node("Terrains")
	for nome in NOMES:
		_folhas.append(load(PASTA + nome + "/terreno.png"))
	for sprite in _terreno.get_node("Objetos3D").get_children():
		if sprite is Sprite2D:
			_guardar(sprite)
	var casa := _terreno.get_node("Objetos3D/Casa")
	_guardar(casa.get_node("Fachada"))
	_area_casa = casa._area_visual
	_detalhe_casa = casa.get_node_or_null("DetalheAmbiente")
	if _detalhe_casa != null:
		_processo_detalhe = _detalhe_casa.is_processing()
	_casa_obstaculo = _terreno.get_node("Obstaculos/Obstaculo1")
	_poligono_casa = _casa_obstaculo.polygon
	_terreno.get_node("Estacoes").estacao_mudou.connect(_ao_estacao)

func _guardar(sprite: Sprite2D) -> void:
	_originais[sprite] = {"texture": sprite.texture, "offset": sprite.offset,
		"scale": sprite.scale, "texture_filter": sprite.texture_filter, "hframes": sprite.hframes, "vframes": sprite.vframes, "frame": sprite.frame}

func alternar() -> void:
	definir_ativo(not ativo)

func definir_ativo(valor: bool) -> void:
	ativo = valor
	_terreno.set_meta("visual_tiny", ativo)
	var chao_detalhado := _terreno.get_node_or_null("ChaoFazenda")
	if chao_detalhado != null:
		chao_detalhado.sincronizar()
	if _detalhe_casa != null:
		_detalhe_casa.set_process(false if ativo else _processo_detalhe)
	var estacoes := _terreno.get_node("Estacoes")
	if ativo:
		estacoes.folhas_personalizadas = _folhas
	else:
		estacoes.folhas_personalizadas = [] as Array[Texture2D]
	# Reaplica inclusive quando o índice da estação continua igual.
	estacoes.definir_estacao(estacoes.estacao_atual, true)
	if ativo:
		_aplicar(estacoes.estacao_atual)
	else:
		for sprite in _originais:
			if is_instance_valid(sprite):
				sprite.texture = _originais[sprite]["texture"]
				sprite.scale = _originais[sprite]["scale"]
				sprite.texture_filter = _originais[sprite]["texture_filter"]
				sprite.offset = _originais[sprite]["offset"]
				sprite.hframes = _originais[sprite]["hframes"]
				sprite.vframes = _originais[sprite]["vframes"]
				sprite.frame = _originais[sprite]["frame"]
		_casa_obstaculo.polygon = _poligono_casa
		_terreno.get_node("Objetos3D/Casa")._area_visual = _area_casa
		if _detalhe_casa != null:
			_detalhe_casa.estacao = -1
			_detalhe_casa._atualizar_estacao()
	_terreno.get_node("CercaSazonal")._aplicar(estacoes.estacao_atual)
	_atualizar_dinamicos(estacoes.estacao_atual)
	var natureza := _terreno.get_node_or_null("NaturezaFazenda")
	if natureza != null: natureza.aplicar(estacoes.estacao_atual)

func _ao_estacao(indice: int) -> void:
	if ativo:
		_aplicar(indice)

func _aplicar(indice: int) -> void:
	var pasta: String = PASTA + NOMES[clampi(indice, 0, 3)] + "/"
	for sprite in _originais:
		if not is_instance_valid(sprite):
			continue
		var peca := ""
		if sprite.has_meta("peca"):
			peca = String(sprite.get_meta("peca"))
		elif sprite.name.begins_with("Abeto"):
			peca = "abeto"
		elif sprite.name.begins_with("Carvalho"):
			peca = "carvalho"
		elif _originais[sprite]["texture"] is AtlasTexture:
			var original: AtlasTexture = _originais[sprite]["texture"]
			peca = "arbusto_g" if original.region.size.x == 32 else "arbusto_m"
		elif sprite.name == "Fachada":
			peca = "casa"
		if not peca.is_empty():
			sprite.texture = load(pasta + peca + ".png")
			if peca == "casa":
				sprite.hframes = 1
				sprite.vframes = 1
				sprite.frame = 0
				sprite.offset = Vector2(-44, -100)
				sprite.scale = Vector2.ONE
				sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var casa := _terreno.get_node("Objetos3D/Casa")
	casa._area_visual = Rect2(-44, -100, 128, 112)
	var p: Vector2 = casa.position
	_casa_obstaculo.polygon = PackedVector2Array([
		p + Vector2(-36, -22), p + Vector2(78, -22), p + Vector2(78, -2), p + Vector2(-36, -2)])
	_atualizar_dinamicos(indice)

func _atualizar_dinamicos(indice: int) -> void:
	_terreno.get_node("Lago")._aplicar_estacao(indice)
	_terreno.get_node("Extracao")._trocar_estacao()
	_terreno.get_node("Plantio").queue_redraw()

static func pasta_do_terreno(terreno: Node, indice: int) -> String:
	return PASTA + NOMES[clampi(indice, 0, 3)] + "/" if terreno.get_meta("visual_tiny", false) else ""
