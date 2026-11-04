extends "res://codigo/campanha/clareiras_chegada.gd"
class_name TerrenoBaciaMoinho

## Região modular da Bacia: o canal, os caminhos e os marcos usam peças do jogo.
const TAMANHO_MAPA := Vector2(1536, 1024)
const CENTRO_MAPA := Vector2(-768, -512)
const CANAIS := [
	[Vector2(-800, -224), Vector2(-560, -224), Vector2(-240, -224), Vector2(80, -224), Vector2(432, -224), Vector2(800, -224)],
	[Vector2(432, -224), Vector2(432, 0), Vector2(432, 240), Vector2(480, 540)],
	[Vector2(-592, -224), Vector2(-592, -304)],
]
const LARGURAS_CANAIS := [36.0, 36.0, 22.0]
const CAMINHOS := [
	[Vector2(-765, 410), Vector2(-560, 320), Vector2(-400, 192), Vector2(-144, 96), Vector2(0, 80)],
	[Vector2(-400, 192), Vector2(-540, 80)],
	[Vector2(0, 80), Vector2(-240, -32), Vector2(-240, -320), Vector2(-464, -288)],
	[Vector2(0, 80), Vector2(240, 96), Vector2(600, 96), Vector2(768, 96)],
	[Vector2(-240, -128), Vector2(-352, -144)],
]
const LARGURAS_CAMINHOS := [28.0, 22.0, 28.0, 28.0, 24.0]
const PRACA_DUNGEON := Vector2(0, 0)

var _pontes: Array[Dictionary] = []
var _marco_dungeon: Area2D
var _roda_moinho: Node2D
var _comporta: Node2D
var _construcoes: Node2D
var _travessias: Array[Rect2] = []
var _atlas_agua: Array[Texture2D] = []
var _campo_corrente: Image
var _textura_corrente: ImageTexture
var roteiro: Node
var _vazao_canais := Vector3(1.0,1.0,0.0)
var _fase_corrente := Vector3.ZERO

func _ready() -> void:
	regiao = "moinho"
	dados = JSON.parse_string(FileAccess.get_file_as_string("res://codigo/campanha/bacia_moinho.json")).duplicate(true)
	limites = Rect2(CENTRO_MAPA, TAMANHO_MAPA)
	margem_obstaculos_navegacao = 0.0
	raio_agente_navegacao = 6.0
	_fichas = JSON.parse_string(FileAccess.get_file_as_string(CAMINHO_PECAS))
	_ficha_bau = JSON.parse_string(FileAccess.get_file_as_string(BAU_ANIMADO))
	_estacoes = preload("res://codigo/campanha/estacoes_campanha.gd").new()
	_estacoes.name = "Estacoes"
	add_child(_estacoes)
	_preparar_superficie_agua()
	_montar_tiles()
	_material.shader = preload("res://codigo/campanha/terreno_bacia.gdshader")
	_material.set_shader_parameter("campo_corrente", _textura_corrente)
	_bordas()
	_montar_marcos()
	_colisoes_agua()
	_montar_floresta()
	var espuma := preload("res://codigo/campanha/espuma_canais_bacia.gd").new()
	espuma.name = "EspumaDosCanais"
	espuma.terreno = self
	add_child(espuma)
	_montar_navegacao()
	var calendario := get_node_or_null("/root/Calendario")
	var estacao_inicial := int(calendario.call("estacao")) if calendario != null else 0
	definir_estacao(estacao_inicial)
	if calendario != null and calendario.has_signal("estacao_mudou"):
		calendario.connect("estacao_mudou", definir_estacao)
	_criar_inimigos.call_deferred()

func _tipo_base(canto: Vector2i) -> int:
	var p := Vector2(canto * 16)
	if p.distance_to(Vector2(-455, -420)) < 62.0:
		return PEDRA
	for i in CANAIS.size():
		var pontos: Array = CANAIS[i]
		for j in pontos.size() - 1:
			if p.distance_to(Geometry2D.get_closest_point_to_segment(p, pontos[j], pontos[j + 1])) < LARGURAS_CANAIS[i]:
				return AGUA
	for i in CAMINHOS.size():
		var pontos: Array = CAMINHOS[i]
		for j in pontos.size() - 1:
			if p.distance_to(Geometry2D.get_closest_point_to_segment(p, pontos[j], pontos[j + 1])) < LARGURAS_CAMINHOS[i]:
				return TERRA
	if p.distance_to(PRACA_DUNGEON) < 105.0:
		return PEDRA
	# Pátio de trabalho do moinho: pedra firme, separado da passagem molhada.
	if p.distance_to(Vector2(-455, -315)) < 76.0:
		return PEDRA
	return GRAMA

func _preparar_superficie_agua() -> void:
	for nome in NOMES:
		_atlas_agua.append(load("res://assets/cenario/campanha/agua_bacia/%s.png" % nome) as Texture2D)
	_campo_corrente = Image.create(192, 128, false, Image.FORMAT_RGBA8)
	for y in 128:
		for x in 192:
			var p := limites.position + Vector2(x * 8 + 4, y * 8 + 4)
			var direcao := Vector2.ZERO
			var profundidade := 0.0
			for i in CANAIS.size():
				var pontos: Array = CANAIS[i]
				for j in pontos.size() - 1:
					var a: Vector2 = pontos[j]
					var b: Vector2 = pontos[j + 1]
					var d := p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))
					var influencia := pow(maxf(1.0 - d / (LARGURAS_CANAIS[i] + 16.0), 0.0), 3.0)
					var fluxo := (b - a).normalized() * (-1.0 if i == 2 else 1.0)
					direcao += fluxo * influencia
					profundidade = maxf(profundidade, 1.0 - d / LARGURAS_CANAIS[i])
			if direcao.length_squared() < 0.001:
				direcao = Vector2.RIGHT
			direcao = direcao.normalized()
			_campo_corrente.set_pixel(x, y, Color(direcao.x * 0.5 + 0.5, direcao.y * 0.5 + 0.5, clampf(profundidade, 0.0, 1.0), 1.0))
	_textura_corrente = ImageTexture.create_from_image(_campo_corrente)

func corrente_em(ponto: Vector2) -> Vector2:
	var uv := (ponto - limites.position) / 8.0
	var cor := _campo_corrente.get_pixel(clampi(int(uv.x), 0, 191), clampi(int(uv.y), 0, 127))
	return Vector2(cor.r * 2.0 - 1.0, cor.g * 2.0 - 1.0).normalized()

func velocidade_corrente(ponto: Vector2) -> float:
	if ponto.x < -520.0 and ponto.y < -244.0: return _vazao_canais.z
	if ponto.x > 380.0 and ponto.y > -196.0: return _vazao_canais.y
	return _vazao_canais.x

func atualizar_fluxo_puzzle(posicoes: Array, comporta_aberta: bool) -> void:
	var entrada := float(posicoes[0])*.5
	var desvio := float(posicoes[1])*.5
	var retorno := float(posicoes[2])*.5
	var pressao := entrada*(1.0-desvio)*retorno
	_vazao_canais = Vector3(1.0,desvio,pressao if comporta_aberta else 0.0)
	if is_instance_valid(_roda_moinho):
		_roda_moinho.definir_vazao(_vazao_canais.z)

func _process(delta: float) -> void:
	super(delta)
	_fase_corrente += _vazao_canais*delta
	if _material:
		_material.set_shader_parameter("fase_corrente",_fase_corrente)

func _campo_raizes() -> ImageTexture:
	var imagem := Image.create(96, 64, false, Image.FORMAT_L8)
	imagem.fill(Color.BLACK)
	return ImageTexture.create_from_image(imagem)

func _montar_navegacao() -> void:
	# Captura de arte não precisa assar a malha; no jogo a navegação completa
	# continua sendo criada normalmente a partir das colisões do cenário.
	if get_meta("captura_visual", false): return
	super._montar_navegacao()

func _sobre_ponte(p: Vector2) -> bool:
	for travessia in _travessias:
		if travessia.has_point(p): return true
	return false

func _colisoes_agua() -> void:
	# A grade de 8px preserva as margens do canal e reduz milhares de
	# retângulos em poucas faixas contínuas para a navegação.
	for registro in _corpos_agua:
		obstaculos.erase(registro.ret)
		if is_instance_valid(registro.corpo): registro.corpo.queue_free()
	_corpos_agua.clear()
	var faixas_ativas: Dictionary = {}
	for y in range(-64, 64):
		var faixas_linha: Array[Vector2i] = []
		var inicio := 999
		for x in range(-96, 96):
			var ponto := Vector2(x * 8 + 4, y * 8 + 4)
			var fechado := peso_agua(ponto) >= 0.4 and not _sobre_ponte(ponto)
			if fechado and inicio == 999: inicio = x
			if not fechado and inicio != 999:
				faixas_linha.append(Vector2i(inicio, x))
				inicio = 999
		if inicio != 999: faixas_linha.append(Vector2i(inicio, 96))
		var presentes: Dictionary = {}
		for faixa in faixas_linha:
			presentes[faixa] = true
			if faixas_ativas.has(faixa):
				faixas_ativas[faixa].altura += 8.0
			else:
				faixas_ativas[faixa] = {"y": y * 8.0, "altura": 8.0}
		for faixa in faixas_ativas.keys():
			if presentes.has(faixa): continue
			var faixa_y: Dictionary = faixas_ativas[faixa]
			var ret := Rect2(faixa.x * 8.0, faixa_y.y, (faixa.y - faixa.x) * 8.0, faixa_y.altura)
			_colisao(ret)
			_corpos_agua.append({"ret": ret, "corpo": get_child(-1)})
			faixas_ativas.erase(faixa)
	for faixa in faixas_ativas:
		var faixa_y: Dictionary = faixas_ativas[faixa]
		var ret := Rect2(faixa.x * 8.0, faixa_y.y, (faixa.y - faixa.x) * 8.0, faixa_y.altura)
		_colisao(ret)
		_corpos_agua.append({"ret": ret, "corpo": get_child(-1)})

func _montar_marcos() -> void:
	_construcoes = preload("res://codigo/campanha/construcao_bacia.gd").new()
	_construcoes.name = "ConstrucoesModulares"
	_construcoes.terreno = self
	add_child(_construcoes)
	_montar_moinho_3d()
	_construcoes.ruina(Vector2i(-6, -4))
	_travessias.append(_construcoes.ponte(Vector2i(-17, -19), Vector2i(4, 10), true))
	_travessias.append(_construcoes.ponte(Vector2i(22, 4), Vector2i(10, 4), false))
	_comporta = _construcoes.comporta(Vector2i(-25, -15))
	_no_mundo("marco_entrada", "poste_resgate", Vector2(-690, 420), 32.0, Vector2(12, 9))
	_no_mundo("marco_margem", "estela", Vector2(-575, 70), 45.0, Vector2(24, 12))
	_marco_dungeon = Area2D.new()
	_marco_dungeon.name = "EntradaDungeon"
	_marco_dungeon.position = Vector2(0, 32)
	_marco_dungeon.set_meta("destino", "tuneis")
	add_child(_marco_dungeon)

func _montar_moinho_3d() -> void:
	_roda_moinho = preload("res://codigo/campanha/moinho_3d_no_mapa.gd").new()
	_roda_moinho.name = "MoinhoLowPolyPixelArt"
	_roda_moinho.position = Vector2(-464, -304)
	add_child(_roda_moinho)
	_colisao_poligono(_roda_moinho.poligono_base())
	_colisao_poligono(_roda_moinho.poligono_roda())

func _no_mundo(id: String, tipo: String, ponto: Vector2, largura: float, base: Vector2) -> void:
	_objeto(id, tipo, ponto - limites.position, largura, base)

func _montar_floresta() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 840417
	var pontos: Array[Vector2] = []
	for tentativa in 5000:
		if pontos.size() >= 70: break
		var imagem := Vector2(rng.randf_range(64, 1472), rng.randf_range(150, 1000))
		var mundo := _da_imagem(imagem)
		if _tipo_canto(Vector2i((mundo / 16).floor())) != GRAMA: continue
		if pontos.any(func(outro: Vector2) -> bool: return outro.distance_to(imagem) < 98.0): continue
		var perto := false
		for pontos_rota in CAMINHOS:
			for j in pontos_rota.size() - 1:
				if mundo.distance_to(Geometry2D.get_closest_point_to_segment(mundo, pontos_rota[j], pontos_rota[j + 1])) < 96.0:
					perto = true
		for i in CANAIS.size():
			var canal: Array = CANAIS[i]
			for j in canal.size() - 1:
				if mundo.distance_to(Geometry2D.get_closest_point_to_segment(mundo, canal[j], canal[j + 1])) < LARGURAS_CANAIS[i] + 24.0:
					perto = true
		for ponte in _pontes:
			if mundo.distance_to(Geometry2D.get_closest_point_to_segment(mundo, ponte.a, ponte.b)) < 80.0:
				perto = true
		if mundo.length() < 168.0 or mundo.distance_to(Vector2(-464, -400)) < 230.0:
			perto = true
		if perto: continue
		pontos.append(imagem)
		var tipo := "pinheiro" if rng.randf() < 0.22 else ("jovem" if rng.randf() < 0.26 else "carvalho")
		_objeto("arvore_bacia_%03d" % pontos.size(), tipo, imagem, rng.randf_range(82, 108), Vector2(18, 20))
	for i in 26:
		var p := Vector2(rng.randf_range(20, 1510), rng.randf_range(24, 1000))
		if _da_imagem(p).distance_to(Vector2(-520, -380)) < 180.0: continue
		if _tipo_canto(Vector2i((_da_imagem(p) / 16).floor())) != GRAMA: continue
		if p.distance_to(Vector2(768, 512)) < 180.0: continue
		_objeto("arbusto_bacia_%02d" % i, "arbustos", p, rng.randf_range(24, 36), Vector2.ZERO)

func _criar_inimigos() -> void:
	for entrada in [
		["res://cenas/inimigos/arraia_junco.tscn", Vector2(-490, 96)],
		["res://cenas/inimigos/besouro_barranco.tscn", Vector2(576, 160)],
		["res://cenas/inimigos/valvula_errante.tscn", Vector2(-320, -350)],
	]:
		var inimigo := load(entrada[0]).instantiate() as Node2D
		inimigo.position = entrada[1]
		inimigo.set_meta("encontro_bacia", true)
		add_child(inimigo)
		if is_instance_valid(roteiro) and "valvula" in str(entrada[0]): roteiro.guardioes.append(inimigo)

func aplicar_descobertas(cumpridos: Array) -> void:
	if is_instance_valid(_comporta):
		_comporta.definir_aberta("comporta" in cumpridos)
	if is_instance_valid(_roda_moinho):
		_roda_moinho.definir_ligado("comporta" in cumpridos or "eixo" in cumpridos)
	if is_instance_valid(_marco_dungeon):
		_marco_dungeon.set_meta("descoberta", "dungeon" in cumpridos)

func definir_estacao(indice: int) -> void:
	super(indice)
	if not _atlas_agua.is_empty(): _material.set_shader_parameter("agua_quadros", _atlas_agua[estacao_atual])
	if is_instance_valid(_construcoes): _construcoes.definir_estacao(indice)
	if is_instance_valid(_roda_moinho): _roda_moinho.definir_estacao(estacao_atual)
	for ponte in _pontes:
		for parte in ponte.raiz.get_children():
			parte.texture = load("res://assets/cenario/cidade/ponte_detalhada/%s/%s.png" % [NOMES[estacao_atual], parte.name])
