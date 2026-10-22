extends Node2D

## Interior da vila: sala ortogonal com materiais pintados4× e móveis
## postos pelo layout de interiores.json. A origem é o canto superior esquerdo do
## recorte da sala, que é o espaço em que a cena, os moradores e a câmera trabalham. Cada móvel é ancorado pela base-centro
## do retângulo com pixels e tem colisão só no pé dele, na camada dos obstáculos; a profundidade vem da base, como no resto
## do jogo, então o jogador passa atrás ou à frente. Luzes de fogo, vela, cristal e poção ficam acesas o tempo todo.
const Profundidade := preload("res://codigo/globais/profundidade.gd")
const DetalheAmbiente := preload("res://codigo/cidade/detalhe_ambiente.gd")
const SalaTopdown := preload("res://codigo/cidade/sala_topdown.gd")
const InterioresDetalhados := preload("res://codigo/cidade/interiores_detalhados.gd")
const LAYOUT := "res://assets/cenario/cidade/interiores/interiores.json"
const RAIZ_IMAGENS := "res://assets/cenario/cidade/interiores/"
## Mesma camada dos obstáculos da cidade (cenas/cidade.tscn, Obstaculos)
const CAMADA_OBSTACULOS := 64
const Z_SALA := -999
const Z_TAPETE := -990
## Espessura das paredes de colisão, fora da sala
const ESPESSURA := 40.0
const SHADER_VARIANTE := preload("res://codigo/cidade/variante_movel.gdshader")
## Variações dos móveis repetidos (opção "variante" no layout): tom da madeira e cor dos tecidos (variante_movel.gdshader)
const VARIANTES := {
	"nogueira": {"madeira_matiz": -0.01, "madeira_saturacao": 1.1, "madeira_brilho": 0.72, "tecido_matiz": 0.0},
	"pinho": {"madeira_matiz": 0.015, "madeira_saturacao": 0.85, "madeira_brilho": 1.18, "tecido_matiz": 0.33},
	"cerejeira": {"madeira_matiz": -0.035, "madeira_saturacao": 1.2, "madeira_brilho": 0.92, "tecido_matiz": 0.6},
	"gasta": {"madeira_matiz": 0.0, "madeira_saturacao": 0.4, "madeira_brilho": 0.95, "tecido_matiz": -0.15},
}
static var _materiais: Dictionary = {}

static var _textura_luz: GradientTexture2D
static var _cache: Dictionary = {}

@export var id := ""

## Plantas das casas, cada uma com a própria geometria, lidas uma vez
static func dados() -> Dictionary:
	if _cache.is_empty():
		_cache = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT))
	return _cache

## Ponto nomeado de uma casa (trabalho, passeio, cama...), em coordenadas da sala; Vector2.ZERO se não existe
static func ponto(casa: String, chave: String) -> Vector2:
	var pontos: Dictionary = dados()["casas"][casa]["pontos"]
	if not pontos.has(chave):
		return Vector2.ZERO
	return Vector2(pontos[chave][0], pontos[chave][1])

## Onde fica a interação do quadro de pedidos na sede
static func mural() -> Vector2:
	var lugar: Array = dados()["casas"]["sede"]["mural"]
	return Vector2(lugar[0], lugar[1])

## Lugar de quem se aquece na pousada no inverno (índice do morador)
static func ponto_inverno(indice: int) -> Vector2:
	var lugares: Array = dados()["casas"]["pousada"]["inverno"]
	var lugar: Array = lugares[indice % lugares.size()]
	return Vector2(lugar[0], lugar[1])

const Cadeira := preload("res://codigo/logica/cadeira.gd")
const ASSENTOS := ["cadeira", "banco_reuniao", "banqueta", "poltrona"]

func _ready() -> void:
	var todos := dados()
	if not todos["casas"].has(id):
		push_error("Casa sem layout em interiores.json: " + id)
		return
	# Cada sala traz a própria geometria (paredes e porta em lugares diferentes)
	var geometria: Dictionary = todos["casas"][id]["geometria"]
	var corpo := StaticBody2D.new()
	corpo.name = "Obstaculos"
	corpo.collision_layer = CAMADA_OBSTACULOS
	corpo.collision_mask = 0
	add_child(corpo)
	_montar_sala(geometria)
	_montar_paredes(corpo, geometria)
	_itens_da_casa = todos["casas"][id]["itens"]
	for item in _itens_da_casa:
		_montar_item(corpo, item)
	load("res://codigo/cidade/atendimento_cidade.gd").montar(self,id)
	if id == "casa_jogador":
		var mobilia := preload("res://codigo/cidade/mobilia_casa_detalhada.gd").new()
		mobilia.name = "MobiliaDetalhada"
		add_child(mobilia)

func _montar_sala(geometria: Dictionary) -> void:
	var sala := SalaTopdown.new()
	sala.name = "Sala"
	sala.configurar(geometria, id)
	add_child(sala)

## Tudo o que não é chão bloqueia (paredes, faces e o lado de fora), mais uma moldura em volta da casa.
## Embaixo da porta de saída, a moldura fica além do gatilho, que leva o jogador antes de ele chegar lá.
func _montar_paredes(corpo: StaticBody2D, geometria: Dictionary) -> void:
	var largura: float = geometria["recorte"][2]
	var altura: float = geometria["recorte"][3]
	for area in SalaTopdown.solidos(geometria):
		_retangulo(corpo, "Parede", area)
	_retangulo(corpo, "Norte", Rect2(-ESPESSURA, -ESPESSURA, largura + 2 * ESPESSURA, ESPESSURA))
	_retangulo(corpo, "Oeste", Rect2(-ESPESSURA, 0, ESPESSURA, altura + ESPESSURA))
	_retangulo(corpo, "Leste", Rect2(largura, 0, ESPESSURA, altura + ESPESSURA))
	_retangulo(corpo, "Soleira", Rect2(-ESPESSURA, altura + 6, largura + 2 * ESPESSURA, ESPESSURA))

func _retangulo(corpo: StaticBody2D, nome: String, area: Rect2) -> void:
	var forma := CollisionShape2D.new()
	forma.name = nome
	var retangulo := RectangleShape2D.new()
	retangulo.size = area.size
	forma.shape = retangulo
	forma.position = area.get_center()
	corpo.add_child(forma)

func _montar_item(corpo: StaticBody2D, item: Dictionary) -> void:
	item = InterioresDetalhados.preparar(item)
	var base := Vector2(item["x"], item["y"])
	var usado: Array = item["usado"]
	var no := Node2D.new()
	no.name = String(item.get("id", item["p"])).capitalize().replace(" ", "")
	no.position = base
	no.z_as_relative = false
	no.z_index = Z_TAPETE if item["chao"] else Profundidade.z_de(base.y)
	var sprite := Sprite2D.new()
	sprite.name = "Imagem"
	sprite.texture = load(item["texturas"][0] if item.has("texturas") else RAIZ_IMAGENS + id + "/props/" + item["p"] + ".png")
	sprite.centered = false
	sprite.offset = Vector2(-(usado[0] + usado[2] / 2.0), -(usado[1] + usado[3]))
	sprite.flip_h = item.get("espelhar", false)
	if VARIANTES.has(item.get("variante", "")):
		sprite.material = _material_variante(item["variante"])
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	no.add_child(sprite)
	add_child(no)
	if not item["chao"]:
		var col: Array = item["col"]
		_retangulo(corpo, no.name, Rect2(base.x - col[0] / 2.0, base.y - col[1], col[0], col[1]))
	for luz in item.get("luzes", []):
		if String(item["p"]) in ["mesa", "mesa_reuniao"] and luz[2] == "#ffc46b" and usado[3] >= 28:
			luz = luz.duplicate()
			# Atrás da área reservada às travessas, com chama e luz alinhadas.
			luz[1] = -usado[3] - 10
		_montar_luz(no, luz)
		if String(item["p"]) in SUPERFICIES and luz[2] in ["#ffc46b", "#ffd488"]:
			_montar_vela(no, luz)
	if item.get("fumaca") != null:
		_montar_vapor(no, Vector2(item["fumaca"][0], item["fumaca"][1]), item["p"])
	DetalheAmbiente.instalar(no, sprite, item)
	if String(item["p"]) in ASSENTOS:
		_montar_assento(no, item, _itens_da_casa)

var _itens_da_casa: Array = []
const SUPERFICIES := ["mesa", "mesa_reuniao", "mesa_cristal", "mesa_frutas", "balcao", "bancada"]

func _montar_vela(no: Node2D, luz: Array) -> void:
	var item := InterioresDetalhados.dados("acessorios/vela")
	if item.is_empty():
		return
	var suporte := Node2D.new()
	suporte.name = "Candelabro"
	# A chama fica junto da luz já existente. O pé está dentro do tampo;
	# posição e colisão da mesa não mudam.
	suporte.position = Vector2(luz[0], luz[1] + 11)
	suporte.z_index = 1
	var imagem := Sprite2D.new()
	imagem.name = "Imagem"
	imagem.centered = false
	imagem.offset = Vector2(-3, -12)
	imagem.texture = load(item.texturas[0])
	suporte.add_child(imagem)
	DetalheAmbiente.instalar(suporte, imagem, item)
	no.add_child(suporte)

## A mesa (ou balcão) mais próxima do assento, até 48 px; vazio se não tem
func _mesa_perto(assento: Dictionary, itens: Array) -> Dictionary:
	var melhor := {}
	var menor := 48.0
	for outro in itens:
		if not String(outro["p"]) in SUPERFICIES:
			continue
		var distancia := Vector2(outro["x"], outro["y"]).distance_to(Vector2(assento["x"], assento["y"]))
		if distancia < menor:
			menor = distancia
			melhor = outro
	return melhor

## Cadeiras, bancos, banquetas e poltronas: F/Y senta (cadeira.gd, a mesma da casa da fazenda), virado para a mesa (ou
## balcão) mais próxima: banco com a mesa logo abaixo senta de frente, com a mesa logo acima senta de costas, e cadeira
## ao lado dela senta de lado olhando para ela. Ao levantar, o jogador fica do lado oposto ao da mesa.
## Cadeira e poltrona são desenhadas de frente (encosto atrás, assento virado para baixo): sempre de frente, mesmo com
## a mesa ao lado (de lado, o corpo ficava atravessado no desenho)
const ASSENTOS_DE_FRENTE := ["cadeira", "poltrona"]
## A pose de costas tem o quadril mais baixo no quadro: sobe até o tampo do banco (conferido nas banquetas e bancos)
const ASSENTO_COSTAS := Vector2(0, -11)

func _montar_assento(objeto: Node2D, item: Dictionary, itens: Array) -> void:
	var cadeira := Cadeira.new()
	cadeira.name = "Assento"
	cadeira.so_entre_ondas = false
	cadeira.position = Vector2(0, -6)
	cadeira.assento = Vector2(0, -8)
	cadeira.saida = Vector2(0, 20)
	cadeira.lado = -1 if item.get("espelhar", false) else 1
	var mesa := _mesa_perto(item, itens)
	if String(item["p"]) in ASSENTOS_DE_FRENTE:
		cadeira.frente = 1
		var abaixo: bool = not mesa.is_empty() and float(mesa["y"]) > float(item["y"]) \
				and absf(float(mesa["x"]) - float(item["x"])) < float(mesa["usado"][2]) / 2.0 + 6.0
		cadeira.saida = Vector2(0, -16) if abaixo else Vector2(0, 16)
	elif not mesa.is_empty():
		var dx: float = float(mesa["x"]) - float(item["x"])
		var dy: float = float(mesa["y"]) - float(item["y"])
		var metade: float = float(mesa["usado"][2]) / 2.0 + 6.0
		if absf(dx) < metade and dy > 0.0:
			cadeira.frente = 1
			cadeira.saida = Vector2(0, -16)
		elif absf(dx) < metade and dy < 0.0:
			cadeira.frente = -1
			cadeira.assento = ASSENTO_COSTAS
			cadeira.saida = Vector2(0, 20)
		else:
			cadeira.lado = 1 if dx > 0.0 else -1
			cadeira.saida = Vector2(-signf(dx) * 16.0, 6)
	cadeira.deslocamento_aviso = Vector2(0, -30)
	var forma := CollisionShape2D.new()
	var circulo := CircleShape2D.new()
	circulo.radius = 14.0
	forma.shape = circulo
	cadeira.add_child(forma)
	objeto.add_child(cadeira)

## Um material por variante, compartilhado por todos os móveis dela
static func _material_variante(nome: String) -> ShaderMaterial:
	if not _materiais.has(nome):
		var material := ShaderMaterial.new()
		material.shader = SHADER_VARIANTE
		for parametro in VARIANTES[nome]:
			material.set_shader_parameter(parametro, VARIANTES[nome][parametro])
		_materiais[nome] = material
	return _materiais[nome]

## luz = [dx, dy, cor, escala, energia, tipo]
func _montar_luz(pai: Node2D, luz: Array) -> void:
	var ponto_luz := PointLight2D.new()
	ponto_luz.name = "Luz%d" % pai.get_child_count()
	ponto_luz.texture = _luz_radial()
	ponto_luz.color = Color(luz[2])
	ponto_luz.texture_scale = luz[3]
	ponto_luz.energy = luz[4]
	ponto_luz.position = Vector2(luz[0], luz[1])
	pai.add_child(ponto_luz)
	var energia: float = luz[4]
	match luz[5]:
		"fogo":
			var tremor := ponto_luz.create_tween().set_loops()
			for passo in 6:
				tremor.tween_property(ponto_luz, "energy", energia * randf_range(0.72, 1.12), randf_range(0.08, 0.2))
		"pulso":
			var pulso := ponto_luz.create_tween().set_loops()
			pulso.tween_property(ponto_luz, "energy", energia * 1.35, 1.4).set_trans(Tween.TRANS_SINE)
			pulso.tween_property(ponto_luz, "energy", energia * 0.65, 1.4).set_trans(Tween.TRANS_SINE)

static func _luz_radial() -> GradientTexture2D:
	if _textura_luz == null:
		var gradiente := Gradient.new()
		gradiente.colors = PackedColorArray([Color(1, 1, 1, 0.9), Color(1, 1, 1, 0)])
		_textura_luz = GradientTexture2D.new()
		_textura_luz.gradient = gradiente
		_textura_luz.width = 128
		_textura_luz.height = 128
		_textura_luz.fill = GradientTexture2D.FILL_RADIAL
		_textura_luz.fill_from = Vector2(0.5, 0.5)
		_textura_luz.fill_to = Vector2(1, 0.5)
	return _textura_luz

## Vapor subindo do caldeirão: quadradinhos que crescem e somem
func _montar_vapor(pai: Node2D, posicao: Vector2, prop: String) -> void:
	var vapor := CPUParticles2D.new()
	vapor.name = "Vapor"
	vapor.position = posicao
	vapor.local_coords = false
	vapor.amount = 9
	vapor.lifetime = 2.6
	vapor.preprocess = 2.6
	vapor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	vapor.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	vapor.emission_sphere_radius = 3.0
	vapor.direction = Vector2(0.15, -1.0)
	vapor.spread = 16.0
	vapor.gravity = Vector2.ZERO
	vapor.initial_velocity_min = 6.0
	vapor.initial_velocity_max = 11.0
	vapor.scale_amount_min = 1.5
	vapor.scale_amount_max = 2.5
	var crescimento := Curve.new()
	crescimento.add_point(Vector2(0, 0.7))
	crescimento.add_point(Vector2(1, 1.7))
	vapor.scale_amount_curve = crescimento
	var cor := Color(0.55, 1.0, 0.7) if prop == "caldeirao" else Color(0.86, 0.86, 0.9)
	var rampa := Gradient.new()
	rampa.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	rampa.colors = PackedColorArray([Color(cor, 0.0), Color(cor, 0.6), Color(cor, 0.0)])
	vapor.color_ramp = rampa
	pai.add_child(vapor)
