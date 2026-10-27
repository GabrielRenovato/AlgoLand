extends Node2D
## Encaixa a arma gerada nos punhos sem redesenhar os corpos aprovados.
var corpo: AnimatedSprite2D
var direcao: String
var dados: Dictionary
var espada: Sprite2D
var mao_frente: Sprite2D
var rastro: Polygon2D

static func escala_arma(config: Dictionary) -> Vector2:
	return Vector2(float(config.get("largura_relativa",1.0)),1.0)*float(config.escala)

func configurar(ator: AnimatedSprite2D, vista: String, golpe: int = 1):
	corpo = ator
	direcao = vista
	var arquivo = "pegadas_espada_golpe2.json" if golpe == 2 else "pegadas_espada_base.json"
	dados = JSON.parse_string(FileAccess.get_file_as_string("res://assets/personagens/raven_cartoon/"+arquivo))
	rastro = load("res://codigo/jogador/rastro_espada_cartoon.gd").new()
	add_child(rastro)
	rastro.configurar(corpo, direcao, golpe)
	espada = Sprite2D.new()
	espada.texture = load(dados.textura)
	espada.centered = false
	espada.offset = -Vector2(dados.pivo[0], dados.pivo[1])
	espada.scale = escala_arma(dados)
	espada.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(espada)
	mao_frente = Sprite2D.new()
	mao_frente.centered = false
	mao_frente.z_index = 2
	mao_frente.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(mao_frente)
	corpo.frame_changed.connect(atualizar)
	atualizar()

func definir_direcao(vista: String):
	direcao = vista
	rastro.forma = rastro.direcoes[vista]
	rastro.atualizar()
	atualizar()

func atualizar():
	var pegada = dados.direcoes[direcao][corpo.frame]
	var ponto = Vector2(pegada.mao[0], pegada.mao[1])
	espada.position = corpo.offset + ponto
	espada.rotation = deg_to_rad(float(pegada.angulo_graus))
	espada.z_index = int(pegada.camada)
	# A própria textura do punho cobre o centro do cabo na passagem à frente.
	# O recorte acompanha a mesma região e transformação do corpo, sem alterar pixels.
	var quadro: AtlasTexture = corpo.sprite_frames.get_frame_texture(corpo.animation, corpo.frame)
	if corpo.has_meta("luvas_armadura"):
		quadro = corpo.get_meta("luvas_armadura")
	var raio = float(pegada.raio_recorte_mao)
	var recorte = AtlasTexture.new()
	recorte.atlas = quadro.atlas
	recorte.region = Rect2(quadro.region.position+ponto-Vector2.ONE*raio, Vector2.ONE*raio*2)
	recorte.filter_clip = true
	mao_frente.texture = recorte
	mao_frente.position = corpo.offset+ponto-Vector2.ONE*raio
	mao_frente.visible = espada.z_index > 0
