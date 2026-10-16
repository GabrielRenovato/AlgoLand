extends Node2D

## Ocupação da cama da casa (cozy furnishings sampler.png do Mana Seed, 32x58). O desenho da cama em si são faixas
## horizontais de Sprite2D ("Cama_f0"...) irmãs deste nó, cada uma com a própria profundidade (gerar_fazenda.py), para o
## jogador poder encostar de lado sem ser cortado. Este nó fica na base-centro da cama e cuida do sono: na hora de dormir o jogador some (o Character Base não
## tem pose deitada) e a cama fica "ocupada": a CABEÇA do personagem aparece no travesseiro (recortada do quadro parado de
## frente, com o corpo, a roupa e o cabelo que ele está usando, nas cores dele), o cobertor sobe e desce, respirando, e
## uns "Z" sobem do travesseiro.
## Transicao.dormir chama deitar() antes do fade e levantar() quando o jogador reaparece ao lado da cama.
## Medidas por pixel na folha da cama: travesseiro nas linhas 10..18 e cobertor azul nas linhas 25..43.

const FONTE := preload("res://assets/ui/Planes_ValMore.ttf")
const Profundidade := preload("res://codigo/globais/profundidade.gd")

## A folha de móveis e a região da cama nela (o gerador preenche `folha`); o canto de cima à esquerda do desenho em relação
## ao nó (base-centro) é ORIGEM
@export var folha: Texture2D
@export var regiao := Rect2(208, 6, 32, 58)
const ORIGEM := Vector2(-16, -58)
## A cabeça e o cobertor acompanham a profundidade da cama mesmo quando a planta muda.
var _z_sobre_a_cama: int

## Cabeça: recorte em unidades de 64 px do quadro 0 (parado de frente). Cada camada converte para sua resolução nativa; a cabeça fica nas linhas 15..26
## e nas colunas 26..37). O recorte pega o cabelo e a gola e é posto com o topo na linha TOPO_CABECA do sprite da cama.
const RECORTE_CABECA := Rect2(22, 8, 20, 20)
const TOPO_CABECA := 4.0
## Olhos no quadro 0 (linhas 23..24; colunas 29..30 e 33..34): dormindo ficam fechados (pele por cima e uma pálpebra)
const OLHOS_X := [29, 33]
const OLHO_LINHA := 23
const COR_PELE_CLARA := Color("f8d8b8")
const COR_PALPEBRA := Color("885848")
## Região do cobertor (x, y_linha, largura, altura) relativa ao sprite da cama
const LINHA_COBERTOR := 25
const ALTURA_COBERTOR := 19
## Respiração: quanto o cobertor sobe (escala em y) e o tempo de cada subida/descida (s)
const SUBIDA := 1.09
const TEMPO_RESPIRO := 0.9
## Intervalo entre os Z e quanto cada um dura/sobe
const INTERVALO_Z := 0.6
const DURACAO_Z := 1.5
const ALTURA_Z := 22.0

var deitado := false

var _cabeca: Node2D
var _cobertor: Sprite2D
var _respiro: Tween
var _jogador: Node2D
var _relogio_z: Timer

func _ready() -> void:
	_z_sobre_a_cama = Profundidade.z_de(global_position.y) + 1
	add_to_group("cama")

## O jogador se deita: some e a cama passa a respirar
func deitar(quem: Node2D = null) -> void:
	if deitado:
		return
	deitado = true
	_jogador = quem if quem != null else EventosJogo.dono(self)
	if _jogador != null:
		_jogador.visible = false
	_montar_cabeca()
	if folha != null:
		# Cobertor por cima das faixas da cama, preso na base (sobe para cima ao respirar)
		var parte := AtlasTexture.new()
		parte.atlas = folha
		parte.region = Rect2(regiao.position.x, regiao.position.y + LINHA_COBERTOR, regiao.size.x, ALTURA_COBERTOR)
		_cobertor = Sprite2D.new()
		_cobertor.name = "Cobertor"
		_cobertor.texture = parte
		_cobertor.centered = false
		_cobertor.offset = Vector2(ORIGEM.x, -ALTURA_COBERTOR)
		_cobertor.position = Vector2(0, ORIGEM.y + LINHA_COBERTOR + ALTURA_COBERTOR)
		_cobertor.z_as_relative = false
		_cobertor.z_index = _z_sobre_a_cama + 1
		add_child(_cobertor)
		_respiro = create_tween().set_loops()
		_respiro.tween_property(_cobertor, "scale:y", SUBIDA, TEMPO_RESPIRO).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_respiro.tween_property(_cobertor, "scale:y", 1.0, TEMPO_RESPIRO).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_relogio_z = Timer.new()
	_relogio_z.wait_time = INTERVALO_Z
	_relogio_z.timeout.connect(_soltar_z)
	add_child(_relogio_z)
	_relogio_z.start()
	_soltar_z()

# A cabeça do jogador no travesseiro: as mesmas camadas dele (corpo, roupa e cabelo), recortadas no quadro 0. Vem antes do
# cobertor na ordem de desenho, então o cobertor cobre o pescoço
func _montar_cabeca() -> void:
	if _jogador == null:
		return
	_cabeca = Node2D.new()
	_cabeca.name = "Cabeca"
	_cabeca.position = Vector2(ORIGEM.x + regiao.size.x / 2.0 - RECORTE_CABECA.size.x / 2.0, ORIGEM.y + TOPO_CABECA)
	_cabeca.z_as_relative = false
	_cabeca.z_index = _z_sobre_a_cama
	add_child(_cabeca)
	for camada in ["sprite_corpo", "sprite_roupa", "sprite_cabelo"]:
		var origem := _jogador.get(camada) as Sprite2D
		if origem == null or origem.texture == null:
			continue
		var parte := Sprite2D.new()
		parte.name = camada
		parte.texture = origem.texture
		parte.centered = false
		parte.region_enabled = true
		var fator := origem.texture.get_size() / Vector2(origem.hframes, origem.vframes) / 64.0
		parte.region_rect = Rect2(RECORTE_CABECA.position * fator, RECORTE_CABECA.size * fator)
		parte.scale = Vector2.ONE / fator
		parte.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		parte.modulate = origem.modulate
		parte.self_modulate = origem.self_modulate
		parte.material = origem.material
		_cabeca.add_child(parte)
	_fechar_olhos()

# Cobre os olhos abertos do corpo (na cor de pele do jogador) e desenha as pálpebras fechadas
func _fechar_olhos() -> void:
	var corpo := _jogador.get("sprite_corpo") as Sprite2D
	var tom := corpo.modulate * corpo.self_modulate if corpo != null else Color.WHITE
	for x in OLHOS_X:
		for linha in 2:
			var pixel := ColorRect.new()
			pixel.name = "Olho_%d_%d" % [x, linha]
			pixel.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pixel.color = COR_PELE_CLARA if linha == 0 else COR_PALPEBRA
			pixel.modulate = tom
			pixel.position = Vector2(x - RECORTE_CABECA.position.x, OLHO_LINHA + linha - RECORTE_CABECA.position.y)
			pixel.size = Vector2(2, 1)
			_cabeca.add_child(pixel)

## Acordou: o jogador volta e a cama fica como era
func levantar() -> void:
	if not deitado:
		return
	deitado = false
	if _respiro != null and _respiro.is_valid():
		_respiro.kill()
	if is_instance_valid(_cobertor):
		_cobertor.queue_free()
	if is_instance_valid(_cabeca):
		_cabeca.queue_free()
	if is_instance_valid(_relogio_z):
		_relogio_z.queue_free()
	for z in get_children():
		if z.is_in_group("z_dormindo"):
			z.queue_free()
	if is_instance_valid(_jogador):
		_jogador.visible = true
	_jogador = null

# Um "Z" que sobe do travesseiro, cresce um pouco e some
func _soltar_z() -> void:
	var z := Label.new()
	z.text = "Z"
	z.add_to_group("z_dormindo")
	z.add_theme_font_override("font", FONTE)
	z.add_theme_font_size_override("font_size", 8)
	z.add_theme_color_override("font_color", Color(0.95, 0.96, 1))
	z.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.25))
	z.add_theme_constant_override("outline_size", 3)
	z.z_as_relative = false
	z.z_index = Profundidade.Z_TOPO - 40
	z.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Do travesseiro (linha ~14 do sprite), um pouco para a direita da cabeça
	var origem := Vector2(ORIGEM.x + 20.0 + randf_range(-2.0, 2.0), ORIGEM.y + 12.0)
	z.position = origem
	add_child(z)
	var tween := z.create_tween().set_parallel(true)
	tween.tween_property(z, "position", origem + Vector2(randf_range(4.0, 9.0), -ALTURA_Z), DURACAO_Z).set_trans(Tween.TRANS_SINE)
	tween.tween_property(z, "scale", Vector2(1.5, 1.5), DURACAO_Z)
	tween.tween_property(z, "modulate:a", 0.0, DURACAO_Z).set_delay(DURACAO_Z * 0.5)
	tween.chain().tween_callback(z.queue_free)
