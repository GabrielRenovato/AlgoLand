extends Node2D
## Articulação de recortes pintados em 2D. Nenhum modelo ou câmera 3D.
const PASTA := "res://arte/fontes/inimigos/goblins_moinho/lanceiro/rig_2d/"
const ALTURA_CABECA_QUADRIL := 244.0
const COMPRIMENTO_LANCA := 500.0
var vista := "direita"
var _fichas: Dictionary
var _sprites: Dictionary = {}
var _texturas: Dictionary = {}
var _frente_lanca: Sprite2D
var _material: ShaderMaterial
var juntas: Dictionary = {}

func montar(direcao: String) -> void:
	vista = direcao
	var registro: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PASTA + "juntas.json"))
	_fichas = registro[vista].pecas.duplicate(true)
	# Uma única lança física em todas as vistas e poses.
	_fichas.lanca = registro.direita.pecas.lanca.duplicate(true)
	_material = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; render_mode unshaded; void fragment(){vec4 c=texture(TEXTURE,UV);if(c.a<0.94){discard;}COLOR=c;}"
	_material.shader = shader
	for nome in _fichas:
		var pasta_fonte: String = registro.direita.fonte if nome == "lanca" else registro[vista].fonte
		if not _texturas.has(pasta_fonte):
			_texturas[pasta_fonte] = ImageTexture.create_from_image(Image.load_from_file(PASTA + pasta_fonte))
		var ficha: Dictionary = _fichas[nome]
		var ret: Array = ficha.ret
		var atlas := AtlasTexture.new()
		atlas.atlas = _texturas[pasta_fonte]
		atlas.region = Rect2(ret[0], ret[1], ret[2], ret[3])
		var sprite := Sprite2D.new()
		sprite.texture = atlas
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		sprite.material = _material
		sprite.flip_h = bool(ficha.espelhar)
		add_child(sprite)
		_sprites[nome] = sprite
		if sprite.flip_h:
			ficha.a[0] = float(ret[2]) - float(ficha.a[0])
			ficha.b[0] = float(ret[2]) - float(ficha.b[0])
	var ret: Array = _fichas.lanca.ret
	var recuo := int(float(ret[2]) * .34)
	var atlas := AtlasTexture.new()
	atlas.atlas = (_sprites.lanca.texture as AtlasTexture).atlas
	atlas.region = Rect2(int(ret[0]) + recuo, ret[1], int(ret[2]) - recuo, ret[3])
	_frente_lanca = Sprite2D.new()
	_frente_lanca.texture = atlas
	_frente_lanca.material = _material
	_frente_lanca.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_frente_lanca.offset = Vector2(float(ret[2]) * .5 - recuo, float(ret[3]) * .5) * -1.0 + atlas.get_size() * .5
	add_child(_frente_lanca)

func _ponto(nome: String, chave: String) -> Vector2:
	var p: Array = _fichas[nome][chave]
	return Vector2(float(p[0]), float(p[1]))

func _fixar(nome: String, origem: Vector2, fim: Vector2, camada: int) -> void:
	var sprite: Sprite2D = _sprites[nome]
	var a := _ponto(nome, "a")
	var b := _ponto(nome, "b")
	var fator := origem.distance_to(fim) / maxf(a.distance_to(b), 1.0)
	sprite.offset = sprite.texture.get_size() * .5 - a
	sprite.position = origem
	sprite.scale = Vector2.ONE * fator
	sprite.rotation = (fim - origem).angle() - (b - a).angle()
	sprite.z_index = camada
	sprite.show()

func _ik(raiz: Vector2, alvo: Vector2, comprimento_a: float, comprimento_b: float, preferencia: Vector2) -> Vector2:
	var delta := alvo - raiz
	var distancia := clampf(delta.length(), 1.0, comprimento_a + comprimento_b - .01)
	var rumo := delta.normalized()
	var ao_longo := (comprimento_a * comprimento_a - comprimento_b * comprimento_b + distancia * distancia) / (2.0 * distancia)
	var altura := sqrt(maxf(0.0, comprimento_a * comprimento_a - ao_longo * ao_longo))
	var p := raiz + rumo * ao_longo
	var lado := rumo.orthogonal() * altura
	return p + lado if lado.dot(preferencia) >= 0.0 else p - lado

func _bota(lado: String, tornozelo: Vector2, levantado: bool, angulo: float, camada: int) -> void:
	var nome := ("sola_" if levantado and vista == "cima" else "bota_") + lado
	var sprite: Sprite2D = _sprites[nome]
	var a := _ponto(nome, "a")
	var b := _ponto(nome, "b")
	var fator := 22.0 / maxf(b.y - a.y, 1.0)
	sprite.position = tornozelo
	sprite.offset = sprite.texture.get_size() * .5 - a
	sprite.scale = Vector2.ONE * fator
	sprite.rotation = angulo
	sprite.z_index = camada
	sprite.show()

func _perna(lado: String, quadril: Vector2, tornozelo: Vector2, levantado: bool, giro_pe: float, camada: int) -> void:
	var preferencia := Vector2.RIGHT if vista == "direita" else Vector2.LEFT if vista == "esquerda" else Vector2.RIGHT if lado == "d" else Vector2.LEFT
	var joelho := _ik(quadril, tornozelo, 78.0, 74.0, preferencia)
	_fixar("coxa_" + lado, quadril, joelho, camada)
	_fixar("canela_" + lado, joelho, tornozelo, camada + 1)
	_bota(lado, tornozelo, levantado, giro_pe, camada + 2)
	juntas["quadril_" + lado] = [quadril.x, quadril.y]
	juntas["joelho_" + lado] = [joelho.x, joelho.y]
	juntas["pe_" + lado] = [tornozelo.x, tornozelo.y]

func _braco(lado: String, ombro: Vector2, pega: Vector2, camada: int) -> void:
	var frontal := vista == "baixo" or vista == "cima"
	var sentido := Vector2.RIGHT if vista == "direita" else Vector2.LEFT
	var preferencia := Vector2(-signf(ombro.x), 0.0) if frontal else (-sentido if lado == "d" else Vector2.DOWN)
	# O último segmento inclui a mão: o centro da pega permanece na haste.
	var cotovelo := _ik(ombro, pega, 88.0, 108.0, preferencia)
	var rumo := (pega - cotovelo).normalized()
	var pulso := pega - rumo * 20.0
	_fixar("braco_" + lado, ombro, cotovelo, camada)
	_fixar("antebraco_" + lado, cotovelo, pulso, camada + 1)
	_fixar("mao_" + lado, pulso, pega, 12)
	juntas["pega_" + lado] = [pega.x, pega.y]
	juntas["cotovelo_" + lado] = [cotovelo.x, cotovelo.y]

func aplicar_pose(acao: String, quadro: int) -> void:
	juntas.clear()
	for sprite in _sprites.values(): sprite.hide()
	var lateral := vista == "direita" or vista == "esquerda"
	var sentido := Vector2.RIGHT if vista == "direita" else Vector2.LEFT if vista == "esquerda" else Vector2.DOWN if vista == "baixo" else Vector2.UP
	var quadril := Vector2(0, -142)
	var angulo_corpo := 0.0
	var centro_lanca := Vector2.ZERO
	var angulo_lanca := sentido.angle()
	var fase := float(quadro) / 6.0 * TAU
	var extensoes := [0.0, -.20, .72, 1.0, .24, 0.0]
	var extensao: float = extensoes[quadro]
	var perto := "d" if vista == "direita" else "e"
	if acao == "andar":
		quadril.y += sin(fase * 2.0) * 3.0
		if lateral:
			centro_lanca = Vector2(sentido.x * 40.0, -185.0 + sin(fase * 2.0) * 3.0)
			angulo_lanca = -.95 if vista == "direita" else -PI + .95
		else:
			centro_lanca = Vector2(44, -193 + sin(fase * 2.0) * 3.0)
			angulo_lanca = -1.02
	else:
		quadril += sentido * extensao * (30.0 if lateral else 18.0)
		if lateral:
			angulo_corpo = sentido.x * extensao * .065
			centro_lanca = Vector2(sentido.x * (80.0 + extensao * 105.0), -178)
		elif vista == "baixo":
			# A ponta continua voltada para baixo durante toda a estocada.
			centro_lanca = Vector2(6, -150.0 + extensao * 65.0)
		else:
			centro_lanca = Vector2(12, -200.0 - extensao * 65.0)
	for lado in ["d", "e"]:
		var fase_pe := fposmod(fase + (0.0 if lado == perto else PI), TAU)
		var apoio := fase_pe <= PI
		var passo := 1.0 - 2.0 * fase_pe / PI if apoio else -1.0 + 2.0 * (fase_pe - PI) / PI
		var sobe := 0.0 if apoio else sin(fase_pe - PI)
		var x_quadril: float = (10.0 if lado == perto else -10.0) if lateral else (31.0 if (lado == "d") == (vista == "cima") else -31.0)
		var raiz_perna := quadril + Vector2(x_quadril, 0)
		var tornozelo := Vector2.ZERO
		if lateral:
			tornozelo = Vector2(sentido.x * passo * 65.0, -22.0 - sobe * 34.0)
		else:
			tornozelo = Vector2(x_quadril, -22.0 + sentido.y * passo * 22.0 - sobe * 10.0)
		if acao == "ataque":
			var dianteiro: bool = lado == "e"
			if lateral:
				tornozelo = Vector2(sentido.x * (55.0 + maxf(extensao, 0.0) * 18.0) if dianteiro else -sentido.x * 55.0, -22)
			else:
				tornozelo = Vector2(x_quadril, -22.0 + sentido.y * (22.0 + maxf(extensao, 0.0) * 12.0) * (1.0 if dianteiro else -1.0))
			sobe = 0.0
		var camada := 3 if lado == perto else 0
		_perna(lado, raiz_perna, tornozelo, sobe > .55, sentido.x * sobe * -.12 if lateral else 0.0, camada)
	var corpo: Sprite2D = _sprites.corpo
	var a := _ponto("corpo", "a")
	corpo.position = quadril
	corpo.offset = corpo.texture.get_size() * .5 - a
	corpo.scale = Vector2.ONE * ALTURA_CABECA_QUADRIL / a.y
	corpo.rotation = angulo_corpo
	corpo.z_index = 6
	corpo.show()
	var lanca: Sprite2D = _sprites.lanca
	var fator := COMPRIMENTO_LANCA / lanca.texture.get_width()
	lanca.offset = Vector2.ZERO
	lanca.position = centro_lanca
	lanca.scale = Vector2.ONE * fator
	lanca.rotation = angulo_lanca
	lanca.z_index = 4
	lanca.show()
	_frente_lanca.position = centro_lanca
	_frente_lanca.scale = Vector2.ONE * fator
	_frente_lanca.rotation = angulo_lanca
	_frente_lanca.z_index = 10
	var pega_d := centro_lanca + Vector2(-80, 0).rotated(angulo_lanca)
	var pega_e := centro_lanca + Vector2(20, 0).rotated(angulo_lanca)
	for lado in ["d", "e"]:
		var x_ombro: float = (18.0 if lado == perto else -13.0) if lateral else (40.0 if (lado == "d") == (vista == "cima") else -40.0)
		var ombro := quadril + Vector2(x_ombro, -103).rotated(angulo_corpo)
		_braco(lado, ombro, pega_d if lado == "d" else pega_e, 7 if lado == perto else 3)
	var ponta := centro_lanca + Vector2(COMPRIMENTO_LANCA * .5, 0).rotated(angulo_lanca)
	var cabeca := quadril + Vector2(0, -ALTURA_CABECA_QUADRIL).rotated(angulo_corpo)
	juntas.ponta = [ponta.x, ponta.y]
	juntas.cabeca = [cabeca.x, cabeca.y]
	juntas.quadril = [quadril.x, quadril.y]
