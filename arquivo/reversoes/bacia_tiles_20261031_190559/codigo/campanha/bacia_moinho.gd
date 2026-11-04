extends "res://codigo/campanha/clareiras_chegada.gd"
class_name TerrenoBaciaMoinho

## Região modular da Bacia: o canal, os caminhos e os marcos usam peças do jogo.
const TAMANHO_MAPA := Vector2(1536, 1024)
const CENTRO_MAPA := Vector2(-768, -512)
const BRILHOS := [
	"res://assets/cenario/Seasonal Forest/seasonal water animations/spring water sparkles B.png",
	"res://assets/cenario/Seasonal Forest/seasonal water animations/summer water sparkles B 16x16.png",
	"res://assets/cenario/Seasonal Forest/seasonal water animations/autumn water sparkles B 16x16.png",
	"res://assets/cenario/Seasonal Forest/seasonal water animations/winter water sparkles B 16x16.png",
]
const CANAIS := [
	[Vector2(-770, -340), Vector2(-540, -340), Vector2(-390, -270), Vector2(-215, -270), Vector2(-170, -190), Vector2(-210, -100), Vector2(-75, -150), Vector2(150, -190), Vector2(340, -150), Vector2(500, -210), Vector2(770, -250)],
	[Vector2(-770, 205), Vector2(-570, 155), Vector2(-420, 180), Vector2(-340, 300), Vector2(-270, 450), Vector2(-215, 520)],
	[Vector2(770, 95), Vector2(590, 95), Vector2(470, 170), Vector2(390, 300), Vector2(350, 520)],
]
const LARGURAS_CANAIS := [52.0, 42.0, 46.0]
const CAMINHOS := [
	[Vector2(-765, 410), Vector2(-590, 325), Vector2(-430, 250), Vector2(-250, 155), Vector2(-110, 105), Vector2(0, 18)],
	[Vector2(-485, 235), Vector2(-525, 165), Vector2(-560, 88)],
	[Vector2(0, 18), Vector2(-120, -40), Vector2(-200, -125), Vector2(-280, -195), Vector2(-370, -245), Vector2(-470, -300), Vector2(-455, -365)],
	[Vector2(0, 18), Vector2(165, 48), Vector2(345, 55), Vector2(425, 110), Vector2(470, 170), Vector2(560, 200), Vector2(650, 90), Vector2(765, -125)],
	[Vector2(25, 70), Vector2(70, 215), Vector2(30, 375), Vector2(-130, 510)],
]
const LARGURAS_CAMINHOS := [46.0, 26.0, 34.0, 38.0, 32.0]
const PRACA_DUNGEON := Vector2(0, 0)

var _fontes_agua: Array[SpriteFrames] = []
var _reflexos: Array[AnimatedSprite2D] = []
var _pontes: Array[Dictionary] = []
var _marco_dungeon: Area2D
var _roda_moinho: Node2D
var _comporta: Node2D

func _ready() -> void:
	regiao = "moinho"
	dados = JSON.parse_string(FileAccess.get_file_as_string("res://codigo/campanha/bacia_moinho.json")).duplicate(true)
	limites = Rect2(CENTRO_MAPA, TAMANHO_MAPA)
	margem_obstaculos_navegacao = 0.0
	raio_agente_navegacao = 6.0
	_fichas = JSON.parse_string(FileAccess.get_file_as_string(CAMINHO_PECAS))
	_ficha_bau = JSON.parse_string(FileAccess.get_file_as_string(BAU_ANIMADO))
	_fichas.merge(JSON.parse_string(FileAccess.get_file_as_string("res://assets/cenario/campanha/bacia_moinho/pecas.json")))
	_estacoes = preload("res://codigo/campanha/estacoes_campanha.gd").new()
	_estacoes.name = "Estacoes"
	add_child(_estacoes)
	_preparar_frames_agua()
	_montar_tiles()
	_bordas()
	_colisoes_agua()
	_montar_marcos()
	_montar_floresta()
	_montar_reflexos()
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
	for ponte in _pontes:
		var a: Vector2 = ponte.a
		var b: Vector2 = ponte.b
		if p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)) < float(ponte.largura):
			return true
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
	# Duas travessias curtas ligam a rota principal ao moinho e às margens leste.
	_montar_ponte("ponte_moinho", Vector2(-200, -125), 0.42, Vector2(-223, -146), Vector2(-177, -104), 36.0)
	_montar_ponte("ponte_leste", Vector2(470, 170), 0.95, Vector2(450, 145), Vector2(490, 195), 34.0)
	_montar_moinho()
	_montar_entrada_dungeon()
	_no_mundo("marco_entrada", "poste_resgate", Vector2(-690, 420), 32.0, Vector2(12, 9))
	_no_mundo("marco_margem", "estela", Vector2(-515, 70), 56.0, Vector2(34, 12))
	_no_mundo("marco_ruina_leste", "pilar", Vector2(615, -35), 42.0, Vector2(20, 12))
	# Margens rochosas em grupos baixos, sem fechar corredores ou pontes.
	for i in 18:
		var a := Vector2(-580 + i * 19, -350 + sin(i * 0.55) * 17)
		_no_mundo("pedra_margem_norte_%02d" % i, "pedras", a, 24.0, Vector2(0, 0))
	for i in 12:
		var a := Vector2(-570 + i * 22, 170 + sin(i * 0.62) * 18)
		_no_mundo("pedra_margem_sul_%02d" % i, "pedras", a, 22.0, Vector2(0, 0))

func _montar_ponte(id: String, centro: Vector2, angulo: float, a: Vector2, b: Vector2, largura: float) -> void:
	var raiz := Node2D.new()
	raiz.name = id
	raiz.position = centro
	raiz.rotation = angulo
	raiz.z_as_relative = false
	raiz.z_index = Profundidade.z_de(centro.y)
	add_child(raiz)
	for parte in ["apoios", "piso", "corrimao"]:
		var sprite := Sprite2D.new()
		sprite.name = parte
		sprite.centered = true
		sprite.position = Vector2(0, -7 if parte != "apoios" else 1)
		sprite.scale = Vector2.ONE * 0.25
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		sprite.texture = load("res://assets/cenario/cidade/ponte_detalhada/%s/%s.png" % [NOMES[estacao_atual if estacao_atual >= 0 else 0], parte])
		if parte == "corrimao": sprite.position.y = -18
		raiz.add_child(sprite)
	_pontes.append({"id": id, "raiz": raiz, "a": a, "b": b, "largura": largura})

func _montar_moinho() -> void:
	# Prédio do moinho no pátio de pedra, ao norte do canal; o topo fica dentro do mapa.
	_no_mundo("moinho", "moinho", Vector2(-455, -372), 205.0, Vector2(150, 22))
	_roda_moinho = preload("res://codigo/campanha/roda_moinho.gd").new()
	_roda_moinho.name = "RodaDagua"
	_roda_moinho.textura = load("res://assets/ui/campanha/regiao_camadas/roda.png")
	_roda_moinho.position = Vector2(-510, -345) - Vector2(799, 617)
	_roda_moinho.z_as_relative = false
	_roda_moinho.z_index = Profundidade.z_de(-345)
	_roda_moinho.set_process(false)
	add_child(_roda_moinho)
	_comporta = Node2D.new()
	_comporta.name = "ComportaDeMadeira"
	_comporta.position = Vector2(-390, -270)
	_comporta.z_index = Profundidade.z_de(-268)
	_comporta.z_as_relative = false
	add_child(_comporta)
	for x in [-8.0, 0.0, 8.0]:
		var tabua := Line2D.new()
		tabua.points = PackedVector2Array([Vector2(x, -25), Vector2(x, 25)])
		tabua.width = 5.0
		tabua.default_color = Color("83532b")
		_comporta.add_child(tabua)
	var travessa := Line2D.new()
	travessa.points = PackedVector2Array([Vector2(-13, -19), Vector2(13, -19)])
	travessa.width = 4.0
	travessa.default_color = Color("c18a45")
	_comporta.add_child(travessa)

func _montar_entrada_dungeon() -> void:
	var pos := PRACA_DUNGEON
	var sombra := Polygon2D.new()
	sombra.name = "SombraEscadariaDungeon"
	sombra.position = pos + Vector2(0, -44)
	sombra.polygon = PackedVector2Array([Vector2(-25, -12), Vector2(25, -12), Vector2(31, 27), Vector2(-31, 27)])
	sombra.color = Color("172522")
	sombra.z_as_relative = false
	sombra.z_index = Profundidade.z_de(pos.y - 3)
	add_child(sombra)
	for i in 4:
		var degrau := Line2D.new()
		degrau.name = "DegrauDungeon_%d" % i
		var y := -53 + i * 9
		degrau.points = PackedVector2Array([Vector2(-18 + i * 2, y), Vector2(18 - i * 2, y)])
		degrau.width = 2.0
		degrau.default_color = Color("8b8063")
		degrau.z_as_relative = false
		degrau.z_index = Profundidade.z_de(pos.y - 2 + i)
		add_child(degrau)
	_no_mundo("arco_entrada_dungeon", "arco", pos, 142.0, Vector2(0, 0))
	for i in 3:
		_no_mundo("ruina_dungeon_%d" % i, "muro", Vector2(-115 + i * 112, 92), 54.0, Vector2(40, 11))
	_marco_dungeon = Area2D.new()
	_marco_dungeon.name = "EntradaDungeon"
	_marco_dungeon.position = pos + Vector2(0, 14)
	_marco_dungeon.collision_layer = 0
	_marco_dungeon.collision_mask = 0
	var forma := CollisionShape2D.new()
	var circulo := CircleShape2D.new()
	circulo.radius = 28.0
	forma.shape = circulo
	_marco_dungeon.add_child(forma)
	_marco_dungeon.set_meta("destino", "tuneis")
	add_child(_marco_dungeon)

func _no_mundo(id: String, tipo: String, ponto: Vector2, largura: float, base: Vector2) -> void:
	_objeto(id, tipo, ponto - limites.position, largura, base)

func _preparar_frames_agua() -> void:
	_fontes_agua.clear()
	for caminho in BRILHOS:
		var atlas := load(caminho) as Texture2D
		var frames := SpriteFrames.new()
		frames.add_animation("brilho")
		frames.set_animation_speed("brilho", 8.0)
		frames.set_animation_loop("brilho", true)
		for y in 3:
			for x in 4:
				var quadro := AtlasTexture.new()
				quadro.atlas = atlas
				quadro.region = Rect2(x * 16, y * 16, 16, 16)
				frames.add_frame("brilho", quadro)
		_fontes_agua.append(frames)

func _montar_reflexos() -> void:
	_reflexos.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 417203
	var pontos: Array[Vector2] = []
	var tentativas := 0
	while pontos.size() < 30 and tentativas < 1200:
		tentativas += 1
		var p := Vector2(rng.randf_range(-748, 748), rng.randf_range(-492, 492))
		if peso_agua(p) < 0.52 or _sobre_ponte(p): continue
		if pontos.any(func(outro: Vector2) -> bool: return outro.distance_to(p) < 55.0): continue
		pontos.append(p)
	for i in pontos.size():
		var brilho := AnimatedSprite2D.new()
		brilho.name = "ReflexoAgua_%02d" % i
		brilho.sprite_frames = _fontes_agua[0]
		brilho.animation = "brilho"
		brilho.frame = rng.randi_range(0, 11)
		brilho.speed_scale = rng.randf_range(0.65, 1.15)
		brilho.position = pontos[i]
		brilho.scale = Vector2.ONE * rng.randf_range(1.1, 1.55)
		brilho.modulate = Color(0.72, 0.94, 1.0, 0.82)
		brilho.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		brilho.z_as_relative = false
		brilho.z_index = Profundidade.Z_CHAO + 1
		add_child(brilho)
		brilho.play("brilho")
		_reflexos.append(brilho)

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
				if mundo.distance_to(Geometry2D.get_closest_point_to_segment(mundo, pontos_rota[j], pontos_rota[j + 1])) < 72.0:
					perto = true
		for i in CANAIS.size():
			var canal: Array = CANAIS[i]
			for j in canal.size() - 1:
				if mundo.distance_to(Geometry2D.get_closest_point_to_segment(mundo, canal[j], canal[j + 1])) < LARGURAS_CANAIS[i] + 24.0:
					perto = true
		for ponte in _pontes:
			if mundo.distance_to(Geometry2D.get_closest_point_to_segment(mundo, ponte.a, ponte.b)) < 80.0:
				perto = true
		if mundo.length() < 168.0 or mundo.distance_to(Vector2(-455, -315)) < 145.0:
			perto = true
		if perto: continue
		pontos.append(imagem)
		var tipo := "pinheiro" if rng.randf() < 0.22 else ("jovem" if rng.randf() < 0.26 else "carvalho")
		_objeto("arvore_bacia_%03d" % pontos.size(), tipo, imagem, rng.randf_range(82, 108), Vector2(18, 20))
	for i in 26:
		var p := Vector2(rng.randf_range(20, 1510), rng.randf_range(24, 1000))
		if _tipo_canto(Vector2i((_da_imagem(p) / 16).floor())) != GRAMA: continue
		if p.distance_to(Vector2(768, 512)) < 180.0: continue
		_objeto("arbusto_bacia_%02d" % i, "arbustos", p, rng.randf_range(24, 36), Vector2.ZERO)

func _criar_inimigos() -> void:
	for entrada in [
		["res://cenas/inimigos/arraia_junco.tscn", Vector2(-590, 95)],
		["res://cenas/inimigos/besouro_barranco.tscn", Vector2(480, 40)],
		["res://cenas/inimigos/valvula_errante.tscn", Vector2(-260, -315)],
	]:
		var inimigo := load(entrada[0]).instantiate() as Node2D
		inimigo.position = entrada[1]
		inimigo.set_meta("encontro_bacia", true)
		add_child(inimigo)

func aplicar_descobertas(cumpridos: Array) -> void:
	if is_instance_valid(_comporta):
		_comporta.rotation = -0.48 if "comporta" in cumpridos else 0.0
	if is_instance_valid(_roda_moinho):
		_roda_moinho.set_process("eixo" in cumpridos)
	if is_instance_valid(_marco_dungeon):
		_marco_dungeon.set_meta("descoberta", "dungeon" in cumpridos)

func definir_estacao(indice: int) -> void:
	super(indice)
	if _fontes_agua.is_empty(): return
	var fonte: SpriteFrames = _fontes_agua[estacao_atual]
	for brilho in _reflexos:
		if is_instance_valid(brilho): brilho.sprite_frames = fonte
	for ponte in _pontes:
		for parte in ponte.raiz.get_children():
			parte.texture = load("res://assets/cenario/cidade/ponte_detalhada/%s/%s.png" % [NOMES[estacao_atual], parte.name])
