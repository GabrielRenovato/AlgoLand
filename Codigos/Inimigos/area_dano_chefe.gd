extends Area2D

## Área atingível separada da navegação, reutilizável por chefes com folhas próprias.
var _cache := {}
var _imagens := {}
var _colisores: Array[CollisionShape2D] = []
var _chave_atual := ""
var _contorno := PackedVector2Array()
var _offset := Vector2.ZERO

func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	monitoring = false
	add_to_group("hurtbox_inimigo")

func acompanhar(sprite: Sprite2D) -> void:
	transform = sprite.transform
	_offset = sprite.get_rect().position
	var chave := str(sprite.texture.get_instance_id()) + ":" + str(sprite.frame)
	if chave == _chave_atual:
		return
	if not _cache.has(chave):
		var id := sprite.texture.get_instance_id()
		if not _imagens.has(id):
			_imagens[id] = sprite.texture.get_image()
		var imagem: Image = _imagens[id]
		var tamanho := Vector2i(imagem.get_width() / sprite.hframes, imagem.get_height() / sprite.vframes)
		var inicio := Vector2i(sprite.frame % sprite.hframes, sprite.frame / sprite.hframes) * tamanho
		var bitmap := BitMap.new()
		bitmap.create_from_image_alpha(imagem.get_region(Rect2i(inicio, tamanho)))
		var contornos := bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO, tamanho), 2.0)
		var maior := PackedVector2Array()
		var area := 0.0
		for contorno in contornos:
			var soma := 0.0
			for i in contorno.size():
				soma += contorno[i].cross(contorno[(i + 1) % contorno.size()])
			if absf(soma) > area:
				maior = contorno
				area = absf(soma)
		var indices := Geometry2D.triangulate_polygon(maior)
		if indices.is_empty():
			maior = Geometry2D.convex_hull(maior)
			indices = Geometry2D.triangulate_polygon(maior)
		var formas: Array[Shape2D] = []
		for i in range(0, indices.size(), 3):
			var forma := ConvexPolygonShape2D.new()
			forma.points = PackedVector2Array([maior[indices[i]], maior[indices[i + 1]], maior[indices[i + 2]]])
			formas.append(forma)
		_cache[chave] = {"contorno": maior, "formas": formas}
	_contorno = _cache[chave].contorno
	var formas: Array = _cache[chave].formas
	while _colisores.size() < formas.size():
		var colisor := CollisionShape2D.new()
		add_child(colisor)
		_colisores.append(colisor)
	for i in _colisores.size():
		_colisores[i].disabled = i >= formas.size()
		if i < formas.size():
			_colisores[i].shape = formas[i]
			_colisores[i].position = _offset
	_chave_atual = chave

func ponto_proximo(origem: Vector2) -> Vector2:
	var local := to_local(origem) - _offset
	if Geometry2D.is_point_in_polygon(local, _contorno):
		return origem
	var melhor := global_position
	var distancia := INF
	for i in _contorno.size():
		var ponto := Geometry2D.get_closest_point_to_segment(origem, to_global(_contorno[i] + _offset), to_global(_contorno[(i + 1) % _contorno.size()] + _offset))
		var atual := ponto.distance_squared_to(origem)
		if atual < distancia:
			distancia = atual
			melhor = ponto
	return melhor
