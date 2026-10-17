extends Node2D

## Mesma arte e mesmo relógio de quadros para o cenário, a viagem e as duas interfaces do coop.
const ESTACOES := ["primavera", "verao", "outono", "inverno"]
const QUADROS := 8
const SEGUNDOS_QUADRO := 0.08
const PIXELS_CAVALO_POR_UNIDADE := 22.0
const ESCALA_CAVALO := 1.3
const PIXELS_CARROCA_POR_UNIDADE := 19.0
var sprite: Sprite2D
var cavalo: Sprite2D
var andando := false
var quadro := 0
var _tempo := 0.0
var _estacao := 0
var passageiros: Node2D
var redeas: Line2D
var lateral_frente: Sprite2D

func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite = Sprite2D.new()
	sprite.centered = false
	sprite.scale = Vector2.ONE / PIXELS_CARROCA_POR_UNIDADE
	sprite.offset = Vector2(-48, -58) * PIXELS_CARROCA_POR_UNIDADE
	add_child(sprite)
	_varal(PackedVector2Array([Vector2(25, -24), Vector2(92, -35)]))
	cavalo = Sprite2D.new()
	cavalo.name = "Cavalo"
	cavalo.centered = false
	# Conservar a imagem escolhida em resolução alta; canvas_items rasteriza na tela final.
	cavalo.scale = Vector2.ONE * ESCALA_CAVALO / PIXELS_CAVALO_POR_UNIDADE
	# Ampliar a partir da base física, mantendo os cascos na mesma linha do chão.
	cavalo.position = Vector2(80, 0) * (1.0 - ESCALA_CAVALO)
	cavalo.offset = Vector2(24, -55) * PIXELS_CAVALO_POR_UNIDADE
	var pelagem := ShaderMaterial.new()
	pelagem.shader = preload("res://codigo/comercio/pelagem_cavalo.gdshader")
	cavalo.material = pelagem
	add_child(cavalo)
	_varal(PackedVector2Array([Vector2(40, -14), Vector2(78, -18), Vector2(96, -31)]))

	passageiros = Node2D.new()
	passageiros.name = "Passageiros"
	add_child(passageiros)
	lateral_frente = Sprite2D.new()
	lateral_frente.name = "LateralFrente"
	lateral_frente.centered = false
	lateral_frente.scale = sprite.scale
	lateral_frente.offset = sprite.offset
	var recorte := ShaderMaterial.new()
	var shader_recorte := Shader.new()
	# A lateral começa na linha 33 do quadro de 64 pixels, à frente dos ocupantes.
	shader_recorte.code = "shader_type canvas_item; uniform float linhas_quadros = 1.0; void fragment() { if (fract(UV.y * linhas_quadros) < 0.515625) { discard; } }"
	recorte.shader = shader_recorte
	lateral_frente.material = recorte
	add_child(lateral_frente)
	redeas = Line2D.new()
	redeas.width = 1
	redeas.default_color = Color("392b2a")
	redeas.points = PackedVector2Array([Vector2(22, -29), Vector2(53, -25), Vector2(110, -46)])
	redeas.visible = false
	add_child(redeas)

func definir_ocupantes(ocupantes: Array) -> void:
	for passageiro in passageiros.get_children():
		passageiros.remove_child(passageiro)
		passageiro.queue_free()
	# O passageiro distante fica atrás do condutor, ambos apoiados na borda dianteira.
	for i in range(ocupantes.size() - 1, -1, -1):
		if not is_instance_valid(ocupantes[i]):
			continue
		var passageiro := preload("res://codigo/comercio/passageiro_carroca.gd").new()
		passageiro.position = Vector2(16, -31) if i == 0 else Vector2(2, -36)
		passageiro.configurar(ocupantes[i])
		passageiros.add_child(passageiro)
	redeas.visible = passageiros.get_child_count() > 0

func embarcar_jogadores() -> void:
	var ocupantes: Array = []
	for jogador in [Cooperativo._jogador1(), Cooperativo.jogador2()]:
		if is_instance_valid(jogador):
			ocupantes.append(jogador)
	definir_ocupantes(ocupantes)

func _ready() -> void:
	atualizar_estacao(Calendario.estacao())
	atualizar_pelagem()
	set_process(andando)

func _varal(pontos: PackedVector2Array) -> void:
	for contorno in [true, false]:
		var varal := Line2D.new()
		varal.points = pontos
		varal.width = 3 if contorno else 1
		varal.default_color = Color("3d2d32") if contorno else Color("aa8052")
		add_child(varal)

func atualizar_pelagem() -> void:
	(cavalo.material as ShaderMaterial).set_shader_parameter("pelagem", Comercio.pelagem)

func atualizar_estacao(estacao: int) -> void:
	_estacao = clampi(estacao, 0, 3)
	_aplicar_texturas()

func definir_movimento(mover: bool) -> void:
	if andando == mover:
		return
	andando = mover
	_tempo = 0.0
	quadro = 0
	_aplicar_texturas()
	set_process(andando)

func _aplicar_texturas() -> void:
	sprite.hframes = 2 if andando else 1
	sprite.vframes = 4 if andando else 1
	# Duas colunas mantêm ambos os eixos abaixo de 8192 pixels.
	cavalo.hframes = 2 if andando else 1
	cavalo.vframes = 4 if andando else 1
	lateral_frente.hframes = sprite.hframes
	lateral_frente.vframes = sprite.vframes
	(lateral_frente.material as ShaderMaterial).set_shader_parameter("linhas_quadros", float(sprite.vframes))
	var sufixo := "andando_" if andando else ""
	sprite.texture = load("res://assets/cenario/comercio/carroca_%s%s.png" % [sufixo, ESTACOES[_estacao]])
	cavalo.texture = load("res://assets/cenario/comercio/cavalo_%s%s.png" % [sufixo, ESTACOES[_estacao]])
	lateral_frente.texture = sprite.texture
	definir_quadro(quadro)

func definir_quadro(indice: int) -> void:
	quadro = posmod(indice, QUADROS) if andando else 0
	sprite.frame = quadro
	cavalo.frame = quadro
	lateral_frente.frame = quadro

func _process(delta: float) -> void:
	_tempo += delta
	definir_quadro(floori(_tempo / SEGUNDOS_QUADRO))
