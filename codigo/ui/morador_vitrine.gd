extends Node2D

## Ator exclusivamente visual do menu: nao participa de agendas, missoes, colisao ou saves.
const Dados := preload("res://codigo/cidade/dados_cidade.gd")
var id := "lia"
var caminho := PackedVector2Array()
var velocidade := 18.0
var sprite: Sprite2D
var _tempo := 0.0
var _linha := 0
var _colunas := 7
var _quadros := 6

func _ready() -> void:
	texture_filter = TEXTURE_FILTER_NEAREST
	var geometria := Dados.geometria_sprite(id)
	_colunas = int(geometria["grade"][0])
	_quadros = int(geometria["quadros_andar"])
	var sombra := Polygon2D.new()
	var pontos := PackedVector2Array()
	for i in 12:
		var angulo := TAU*i/12.0
		pontos.append(Vector2(cos(angulo)*7,9+sin(angulo)*2))
	sombra.polygon = pontos
	sombra.color = Color(0.08,0.07,0.04,0.24)
	add_child(sombra)
	sprite = Sprite2D.new()
	sprite.texture = load(Dados.caminho_sprite(id))
	sprite.hframes = _colunas
	sprite.vframes = int(geometria["grade"][1])
	sprite.scale = Vector2.ONE*float(geometria["escala_mapa"])
	sprite.position.y = 9-(float(geometria["pes_y"])-32)*sprite.scale.y
	add_child(sprite)

func _process(delta: float) -> void:
	_tempo += delta
	var andando := false
	if not caminho.is_empty():
		var diferenca := caminho[0]-position
		if diferenca.length() < 0.8:
			caminho.remove_at(0)
		else:
			_olhar(diferenca)
			position += diferenca.normalized()*minf(velocidade*delta,diferenca.length())
			andando = true
	sprite.frame = _linha*_colunas+(1+int(_tempo*7)%_quadros if andando else 0)

func _olhar(direcao: Vector2) -> void:
	_linha = (1 if direcao.x > 0 else 3) if absf(direcao.x) > absf(direcao.y) else (0 if direcao.y >= 0 else 2)

