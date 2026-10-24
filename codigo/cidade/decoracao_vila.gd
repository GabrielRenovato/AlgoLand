extends Node2D

## Decoração da vila (cercas, canteiros, postes de luz, carrinho, feno, fonte...): imagens soltas geradas no PixelLab no padrão
## Mana Seed, em assets/cenario/cidade/decoracao/<categoria>/<nome>.png (vegetacao, mobiliario, construcoes), postas pelo layout de decoracao.json (ferramentas/cidade/layout_decoracao.py).
## Cada peça é ancorada pela base-centro do retângulo com pixels, tem colisão só no pé (camada dos obstáculos da cidade) e
## profundidade pela base. Peças com "animacao" usam uma folha de quadros lado a lado; peças com "luz" acendem à noite, no mesmo
## horário dos lampiões e das janelas das casas. Peças "sazonais" têm uma imagem por estação (<nome>_primavera, _verao, _outono,
## _inverno), trocada quando o calendário muda; "estacoes" lista em quais estações a peça aparece (as flores somem no inverno).
const Profundidade := preload("res://codigo/globais/profundidade.gd")
const SombraCidade := preload("res://codigo/cidade/sombra_cidade.gd")
const DetalheAmbiente := preload("res://codigo/cidade/detalhe_ambiente.gd")
const Cadeira := preload("res://codigo/logica/cadeira.gd")
const LAYOUT := "res://assets/cenario/cidade/decoracao/decoracao.json"
const RAIZ := "res://assets/cenario/cidade/decoracao/"
const CAMADA_OBSTACULOS := 64
const INTERVALO_HORA := 0.5
const MASCARAS_SOMBRA := {"coreto": "coreto", "fonte": "fonte", "feira_a": "feira", "feira_b": "feira",
	"banco": "banco", "poste_luz": "poste", "cerca": "cerca", "horta": "horta", "galinheiro": "galinheiro",
	"arvore": "arvore", "arbusto": "arbusto", "feno": "feno", "mesa_ar_livre": "mesa", "mesa_piquenique": "mesa",
	"banco_piquenique_esquerdo": "banco", "banco_piquenique_direito": "banco",
	"mural": "feira", "placa_encruzilhada": "poste", "correio": "poste", "canteiro": "horta"}

static var _textura_luz: GradientTexture2D

const ESTACOES := ["primavera", "verao", "outono", "inverno"]

var _luzes: Array[Dictionary] = []
var _sazonais: Array[Dictionary] = []
var _por_estacao: Array[Dictionary] = []
var _estacao := -1
var _noite := false
var _tempo := 0.0

func _ready() -> void:
	var itens = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT))
	if not itens is Array:
		push_error("decoracao.json inválido")
		return
	var corpo := StaticBody2D.new()
	corpo.name = "Obstaculos"
	corpo.collision_layer = CAMADA_OBSTACULOS
	corpo.collision_mask = 0
	add_child(corpo)
	for item in itens:
		_montar_item(corpo, item)

func _montar_item(corpo: StaticBody2D, item: Dictionary) -> void:
	if item["p"] == "construcoes/ponte":
		var ponte := preload("res://codigo/cidade/ponte_cidade.gd").new()
		ponte.name = "ponte_%d_%d" % [int(item["x"]), int(item["y"])]
		ponte.position = Vector2(item["x"], item["y"])
		add_child(ponte)
		return
	var detalhado := preload("res://codigo/cidade/enfeites_detalhados.gd").dados(item["p"])
	if not detalhado.is_empty():
		item = item.duplicate(true)
		item.merge(detalhado, true)
		# A fonte usa a mesma sequência no controlador sazonal de Sprite2D.
		item.erase("animacao")
		item.erase("sazonal")
	var especie_arvore := ""
	if item["p"] == "vegetacao/arvore":
		item = item.duplicate(true)
		# Mesma arte4× da fazenda, com raiz no pivô64,127.
		item["usado"] = [0,-1,128,128]
		especie_arvore = "pinheiro" if (floori(float(item["x"])/16.0)+floori(float(item["y"])/16.0))%3 == 0 else "folhosa"
		item["resolucao"] = 4
		item["quadros"] = 1
		item["fps"] = 0
		item.erase("animacao")
		item.erase("sazonal")
		item["texturas"] = []
		for e in ESTACOES:
			item["texturas"].append("res://assets/cenario/fazenda/natureza_detalhada/%s/%s.png" % [e,"carvalho" if especie_arvore == "folhosa" else "pinheiro"])
	var base := Vector2(item["x"], item["y"])
	var usado: Array = item["usado"]
	var no := Node2D.new()
	no.name = "%s_%d_%d" % [String(item["p"]).get_file(), int(base.x), int(base.y)]
	no.position = base
	no.z_as_relative = false
	no.z_index = int(item["z_fixo"]) if item.has("z_fixo") else Profundidade.z_de(base.y) + int(item.get("z_extra", 0))
	var nome_imagem: String = item["p"] + "_primavera" if item.get("sazonal", false) else item["p"]
	var deslocamento := Vector2(-(usado[0] + usado[2] / 2.0), -(usado[1] + usado[3]))
	var textura: Texture2D = load(item["texturas"][0] if item.has("texturas") else RAIZ + nome_imagem + ".png")
	if item.has("animacao"):
		var anim: Dictionary = item["animacao"]
		var quadros := SpriteFrames.new()
		quadros.add_animation("loop")
		quadros.set_animation_speed("loop", anim["fps"])
		quadros.set_animation_loop("loop", true)
		for i in int(anim["quadros"]):
			var atlas := AtlasTexture.new()
			atlas.atlas = textura
			atlas.region = Rect2(i * anim["largura"], 0, anim["largura"], anim["altura"])
			quadros.add_frame("loop", atlas)
		var animado := AnimatedSprite2D.new()
		animado.name = "Imagem"
		animado.sprite_frames = quadros
		animado.centered = false
		animado.offset = deslocamento
		animado.flip_h = item.get("espelhar", false)
		animado.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		no.add_child(animado)
		animado.play("loop")
		# Quadros diferentes entre peças iguais: cada uma começa em um ponto do ciclo
		animado.frame = randi() % int(anim["quadros"])
	else:
		var sprite := Sprite2D.new()
		sprite.name = "Imagem"
		sprite.texture = textura
		sprite.centered = false
		sprite.offset = deslocamento
		sprite.flip_h = item.get("espelhar", false)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		no.add_child(sprite)
		DetalheAmbiente.instalar(no, sprite, item)
		if item.get("simulacao_agua",false):
			var agua_fonte:=preload("res://codigo/cidade/agua_fonte.gd").new()
			agua_fonte.name="AguaFonte"
			agua_fonte.imagem=sprite
			no.add_child(agua_fonte)
		if item.get("sazonal", false):
			_sazonais.append({"sprite": sprite, "p": item["p"]})
	if item.has("estacoes"):
		var permitidas: Array[int] = []
		for numero in item["estacoes"]:
			permitidas.append(int(numero))
		_por_estacao.append({"no": no, "estacoes": permitidas})
	add_child(no)
	# Só elementos elevados recebem sombra solar; ponte, água e detalhes de chão ficam de fora.
	var nome_peca := String(item["p"]).get_file().replace("_anim", "")
	if MASCARAS_SOMBRA.has(nome_peca):
		var largura_sombra := float(usado[2]) * 0.85
		var altura_sombra := float(usado[3]) * 0.65
		if nome_peca in ["poste_luz", "placa_encruzilhada", "correio"]:
			largura_sombra *= 0.45
			altura_sombra = float(usado[3])
		var mascara: String = "arvore_"+especie_arvore if not especie_arvore.is_empty() else MASCARAS_SOMBRA[nome_peca]
		var sombras_sazonais: Array[Texture2D] = []
		if not especie_arvore.is_empty():
			for caminho in item["texturas"]:
				sombras_sazonais.append(load(caminho))
		SombraCidade.projetar(no, "objetos/" + mascara, largura_sombra, altura_sombra, sombras_sazonais)
	if item.has("col"):
		var col: Array = item["col"]
		var forma := CollisionShape2D.new()
		forma.name = no.name
		var retangulo := RectangleShape2D.new()
		retangulo.size = Vector2(col[0], col[1])
		forma.shape = retangulo
		forma.position = Vector2(base.x + float(item.get("col_dx", 0)), base.y - col[1] / 2.0)
		corpo.add_child(forma)
		if item.has("estacoes"):
			_por_estacao.back()["forma"] = forma
	if item.has("luz"):
		_montar_luz(no, item["luz"])
	if item.get("assento", false):
		_montar_assento(no, nome_peca, item)
	if nome_peca == "mesa_piquenique":
		var vapor := CPUParticles2D.new()
		vapor.name = "VaporCha"
		vapor.position = Vector2(10, -23)
		vapor.amount = 3
		vapor.lifetime = 1.3
		vapor.preprocess = 1.3
		vapor.direction = Vector2.UP
		vapor.spread = 12.0
		vapor.gravity = Vector2.ZERO
		vapor.initial_velocity_min = 3.0
		vapor.initial_velocity_max = 5.0
		vapor.color = Color(0.9, 0.88, 0.8, 0.35)
		vapor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		no.add_child(vapor)

func _montar_assento(objeto: Node2D, nome: String, item: Dictionary) -> void:
	var cadeira := Cadeira.new()
	cadeira.name = "Assento"
	cadeira.so_entre_ondas = false
	cadeira.position = Vector2(0, -5)
	cadeira.assento = Vector2(0, -8)
	cadeira.saida = Vector2(0, -24) if nome.begins_with("banco_piquenique_") else Vector2(-24, 12)
	cadeira.lado = int(item.get("lado_assento", 1))
	# O banco da praça é desenhado de frente: senta de frente, não de lado
	if not item.has("lado_assento"):
		cadeira.frente = 1
	var forma := CollisionShape2D.new()
	var circulo := CircleShape2D.new()
	circulo.radius = 20.0
	forma.shape = circulo
	cadeira.add_child(forma)
	objeto.add_child(cadeira)
	if item.has("estacoes"):
		_por_estacao.back()["assento"] = cadeira

## luz = [dx, dy, cor, escala, energia]: só à noite
func _montar_luz(pai: Node2D, luz: Array) -> void:
	var ponto := PointLight2D.new()
	ponto.name = "Luz"
	ponto.texture = _luz_radial()
	ponto.color = Color(luz[2])
	ponto.texture_scale = luz[3]
	ponto.energy = 0.0
	ponto.visible = false
	ponto.position = Vector2(luz[0], luz[1])
	pai.add_child(ponto)
	_luzes.append({"luz": ponto, "energia": float(luz[4])})

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

## Mesma regra do terreno: o nó Estacoes manda (ele também obedece ao painel F3); sem ele, o calendário
func _estacao_atual() -> int:
	var estacoes := get_node_or_null("../Terrains/Estacoes")
	if estacoes != null and "estacao_atual" in estacoes and int(estacoes.estacao_atual) >= 0:
		return int(estacoes.estacao_atual)
	return Calendario.estacao()

func _aplicar_estacao(estacao: int) -> void:
	_estacao = estacao
	for entrada in _sazonais:
		entrada["sprite"].texture = load(RAIZ + "%s_%s.png" % [entrada["p"], ESTACOES[estacao]])
	for entrada in _por_estacao:
		var aparece: bool = estacao in entrada["estacoes"]
		entrada["no"].visible = aparece
		if entrada.has("forma"):
			entrada["forma"].set_deferred("disabled", not aparece)
		if entrada.has("assento"):
			var cadeira: Area2D = entrada["assento"]
			if not aparece and cadeira.ocupada:
				cadeira._levantar()
			cadeira.set_process(aparece)
			cadeira.set_deferred("monitoring", aparece)
			if not aparece:
				cadeira.jogador_perto = false
	# Obstáculos que somem não deixam bloqueios invisíveis nas rotas dos moradores.
	get_parent().call_deferred("_montar_navegacao")

func _process(delta: float) -> void:
	var estacao := _estacao_atual()
	if estacao != _estacao:
		_aplicar_estacao(estacao)
	if _luzes.is_empty():
		return
	_tempo += delta
	if _tempo >= INTERVALO_HORA:
		_tempo = 0.0
		var luz := get_tree().get_first_node_in_group("iluminacao")
		_noite = luz != null and "hora" in luz and (luz.hora >= 18.0 or luz.hora < 6.0)
	for entrada in _luzes:
		var ponto: PointLight2D = entrada["luz"]
		ponto.energy = move_toward(ponto.energy, entrada["energia"] if _noite else 0.0, delta * 1.2)
		ponto.visible = ponto.energy > 0.0
