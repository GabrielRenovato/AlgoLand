extends Node2D

## Fachada de uma casa da vila: uma imagem inteira gerada no PixelLab (assets/cenario/cidade/casas/exterior/<id>.png). As medidas de cada
## uma ficam em exteriores.json, em pixels da imagem ou relativas à âncora: a âncora é o centro da porta na base e vira a origem deste nó.
##   usado: retângulo da imagem com pixels (a zona em que a casa fica meio transparente quando o jogador passa atrás dela)
##   colisoes: retângulos (x0, y0, x1, y1) no chão, na camada dos obstáculos da cidade
##   chamine: boca da chaminé (de onde sobe a fumaça); null se não tem
##   janelas: onde há vidro (ganham uma luz quente à noite, no mesmo horário dos lampiões)
##   placa: posiciona a placa ilustrada quando há poste, sem nomes flutuantes no chão.
## Fica à frente ou atrás do jogador pela profundidade da base, como as construções modulares que substituiu.
const Profundidade := preload("res://codigo/globais/profundidade.gd")
const SombraCidade := preload("res://codigo/cidade/sombra_cidade.gd")
const DetalheAmbiente := preload("res://codigo/cidade/detalhe_ambiente.gd")
const MEDIDAS := "res://assets/cenario/cidade/casas/exteriores.json"
const RAIZ_IMAGENS := "res://assets/cenario/cidade/casas/exterior/"
const RAIZ_PLACAS := "res://assets/cenario/cidade/casas/placa/"
const COR_LUZ := Color(1.0, 0.72, 0.38)
const ENERGIA_NOITE := 0.75
const INTERVALO_HORA := 0.5
## Mesma camada dos obstáculos da cidade (cenas/cidade.tscn, Obstaculos)
const CAMADA_OBSTACULOS := 64

static var _textura_luz: GradientTexture2D

@export var id := ""

var _area_visual := Rect2()
var _luzes: Array[PointLight2D] = []
var _noite := false
var _tempo := 0.0

func _ready() -> void:
	var todas = JSON.parse_string(FileAccess.get_file_as_string(MEDIDAS))
	if not todas is Dictionary or not todas.has(id):
		push_error("Casa sem medidas em exteriores.json: " + id)
		return
	var medidas: Dictionary = todas[id].duplicate(true)
	var detalhes := preload("res://codigo/cidade/fachadas_detalhadas.gd").dados(id)
	if detalhes.has("chamine"): medidas.chamine = detalhes.chamine
	if detalhes.has("janelas"): medidas.janelas = detalhes.janelas
	var ancora := _ponto(medidas["ancora"])
	var usado: Array = medidas["usado"]
	_area_visual = Rect2(Vector2(usado[0], usado[1]) - ancora, Vector2(usado[2], usado[3]))
	z_as_relative = false
	z_index = Profundidade.z_de(global_position.y)
	_montar_sprite(ancora)
	SombraCidade.projetar(self, "casas/" + id, float(usado[2]) * 0.92, float(usado[3]) * 0.70)
	_montar_colisoes(medidas["colisoes"])
	for janela in medidas["janelas"]:
		_montar_luz(_ponto(janela))
	if medidas.has("placa"):
		_montar_placa(medidas["placa"])
	if medidas["chamine"] != null:
		_montar_fumaca(_ponto(medidas["chamine"]))

func _ponto(par: Array) -> Vector2:
	return Vector2(par[0], par[1])

func _montar_sprite(ancora: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.name = "Fachada"
	sprite.texture = load(RAIZ_IMAGENS + id + ".png")
	sprite.centered = false
	sprite.offset = -ancora
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	var ambientes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/cenario/cidade/ambientes/manifesto.json"))
	DetalheAmbiente.instalar(self, sprite, ambientes.get("fachada/" + id, {}))

func _montar_colisoes(retangulos: Array) -> void:
	var corpo := StaticBody2D.new()
	corpo.name = "Colisao"
	corpo.collision_layer = CAMADA_OBSTACULOS
	corpo.collision_mask = 0
	for r in retangulos:
		var forma := CollisionShape2D.new()
		var retangulo := RectangleShape2D.new()
		retangulo.size = Vector2(r[2] - r[0], r[3] - r[1])
		forma.shape = retangulo
		forma.position = Vector2((r[0] + r[2]) / 2.0, (r[1] + r[3]) / 2.0)
		corpo.add_child(forma)
	add_child(corpo)

## Placa ilustrada de madeira, com o poste na posição dada.
func _montar_placa(dados: Dictionary) -> void:
	if not dados.get("poste", true):
		return
	var base := _ponto(dados["base"])
	var raiz := Node2D.new()
	raiz.name = "Placa"
	raiz.position = _ponto(dados["pos"])
	raiz.z_as_relative = false
	raiz.z_index = Profundidade.z_de(global_position.y + raiz.position.y)
	var sprite := Sprite2D.new()
	sprite.texture = load(RAIZ_PLACAS + id + ".png")
	sprite.centered = false
	sprite.offset = -base
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	raiz.add_child(sprite)
	var corpo := StaticBody2D.new()
	corpo.collision_layer = CAMADA_OBSTACULOS
	corpo.collision_mask = 0
	var forma := CollisionShape2D.new()
	var caixa := RectangleShape2D.new()
	caixa.size = Vector2(10, 5)
	forma.shape = caixa
	forma.position = Vector2(0, -2.5)
	corpo.add_child(forma)
	raiz.add_child(corpo)
	add_child(raiz)

## Poça de luz quente na janela. Começa apagada: _atualizar_noite acende à noite
func _montar_luz(posicao: Vector2) -> void:
	var luz := PointLight2D.new()
	luz.name = "LuzJanela%d" % _luzes.size()
	luz.texture = _luz_radial()
	luz.color = COR_LUZ
	luz.energy = 0.0
	luz.visible = false
	luz.texture_scale = 0.45
	luz.position = posicao
	add_child(luz)
	_luzes.append(luz)

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

## Fumaça subindo devagar da chaminé: quadradinhos cinza claros que crescem e somem
func _montar_fumaca(posicao: Vector2) -> void:
	var fumaca := CPUParticles2D.new()
	fumaca.name = "Fumaca"
	fumaca.position = posicao
	fumaca.local_coords = false
	fumaca.amount = 7
	fumaca.lifetime = 3.4
	fumaca.preprocess = 3.4
	fumaca.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fumaca.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	fumaca.emission_sphere_radius = 1.5
	fumaca.direction = Vector2(0.3, -1.0)
	fumaca.spread = 14.0
	fumaca.gravity = Vector2.ZERO
	fumaca.initial_velocity_min = 5.0
	fumaca.initial_velocity_max = 9.0
	fumaca.scale_amount_min = 2.0
	fumaca.scale_amount_max = 3.0
	var crescimento := Curve.new()
	crescimento.add_point(Vector2(0, 0.7))
	crescimento.add_point(Vector2(1, 1.8))
	fumaca.scale_amount_curve = crescimento
	var rampa := Gradient.new()
	rampa.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	rampa.colors = PackedColorArray([Color(0.86, 0.86, 0.9, 0.0), Color(0.86, 0.86, 0.9, 0.6), Color(0.78, 0.78, 0.84, 0.0)])
	fumaca.color_ramp = rampa
	add_child(fumaca)

func _process(delta: float) -> void:
	_tempo += delta
	if _tempo >= INTERVALO_HORA:
		_tempo = 0.0
		var luz := get_tree().get_first_node_in_group("iluminacao")
		_noite = luz != null and "hora" in luz and (luz.hora >= 18.0 or luz.hora < 6.0)
	for janela in _luzes:
		janela.energy = move_toward(janela.energy, ENERGIA_NOITE if _noite else 0.0, delta * 1.2)
		# Luz apagada sai da renderização: no Compatibility cada luz ativa redesenha os itens ao redor.
		janela.visible = janela.energy > 0.0
	# Meio transparente quando o jogador passa atrás da casa, para ele não sumir
	var jogador := Cooperativo.jogador_no_ambiente(self)
	if jogador == null:
		return
	var ponto := to_local(jogador.global_position + Vector2(0, 11))
	var atras := ponto.y < 0 and _area_visual.has_point(ponto)
	modulate.a = move_toward(modulate.a, 0.5 if atras else 1.0, delta * 6.0)
