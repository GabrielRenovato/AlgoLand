extends Node2D

## Apoios sob as faces inferiores; a máscara impede invadir qualquer célula caminhável do cais.
var _estacao := 0

func aplicar_estacao(estacao: int) -> void:
	_estacao = estacao
	queue_redraw()
var _celulas: Dictionary = {}
var _costa_base := 300.0
var _curvas := Vector4(16, 0.011, 8, 0.027)

func configurar(layout: Dictionary) -> void:
	name = "EstruturaCais"
	z_as_relative = false
	z_index = -1000
	texture_filter = TEXTURE_FILTER_NEAREST
	_costa_base = layout["costa_base"]
	var curvas: Array = layout["curvas_costa"]
	_curvas = Vector4(curvas[0], curvas[1], curvas[2], curvas[3])
	_celulas.clear()
	var tamanho := Vector2i.ONE
	for area: Array in layout["cais"]:
		for y in range(int(area[1]) / 16, (int(area[1]) + int(area[3])) / 16):
			for x in range(int(area[0]) / 16, (int(area[0]) + int(area[2])) / 16):
				_celulas[Vector2i(x, y)] = true
				tamanho.x = maxi(tamanho.x, x + 1)
				tamanho.y = maxi(tamanho.y, y + 1)
	var mascara := Image.create(tamanho.x, tamanho.y, false, Image.FORMAT_RGBA8)
	mascara.fill(Color.BLACK)
	for celula: Vector2i in _celulas:
		mascara.set_pixelv(celula, Color.WHITE)
	var recorte := ShaderMaterial.new()
	recorte.shader = preload("res://codigo/pesca/recorte_estrutura_cais.gdshader")
	recorte.set_shader_parameter("mascara_piso", ImageTexture.create_from_image(mascara))
	recorte.set_shader_parameter("tamanho_mascara", Vector2(tamanho))
	material = recorte
	queue_redraw()

func _sobre_agua(p: Vector2) -> bool:
	var costa := _costa_base + _curvas.x * sin(p.x * _curvas.y) + _curvas.z * sin(p.x * _curvas.w)
	return p.y > costa + 6

func _draw() -> void:
	var frentes := {}
	for celula: Vector2i in _celulas:
		var frente := Vector2(celula * 16) + Vector2(0, 16)
		if _celulas.has(celula + Vector2i.DOWN) or not _sobre_agua(frente + Vector2(8, 0)):
			continue
		if not frentes.has(int(frente.y)):
			frentes[int(frente.y)] = []
		frentes[int(frente.y)].append(int(frente.x))
	for y: int in frentes:
		var xs: Array = frentes[y]
		xs.sort()
		var inicio: int = xs[0]
		var fim := inicio + 16
		for x: int in xs.slice(1):
			if x == fim:
				fim += 16
			else:
				_frente(inicio, fim, y)
				inicio = x
				fim = x + 16
		_frente(inicio, fim, y)

func _frente(inicio: int, fim: int, y: int) -> void:
	var apoios: Array[int] = [inicio + 6]
	for x in range(inicio + 54, fim - 24, 48):
		apoios.append(x)
	if fim - 6 - apoios[-1] >= 16:
		apoios.append(fim - 6)
	for x in apoios:
		_estaca(Vector2(x, y + 2))
	# A viga cobre o topo dos apoios, sempre a partir da borda inferior do piso.
	draw_rect(Rect2(inicio, y, fim - inicio, 4), Color("795437"))
	draw_line(Vector2(inicio, y), Vector2(fim, y), Color("b7824c"), 1)
	draw_line(Vector2(inicio, y + 4), Vector2(fim, y + 4), Color("493529"), 1)

func _estaca(ponto: Vector2) -> void:
	var canto := ponto - Vector2(3, 0)
	var altura := 18.0
	draw_rect(Rect2(canto - Vector2(1, 0), Vector2(8, altura)), Color("49382b"))
	var madeira: Color = [Color("976b3e"),Color("a67946"),Color("83603e"),Color("75644d")][_estacao]
	draw_rect(Rect2(canto, Vector2(6, altura)), madeira)
	draw_line(canto+Vector2(1,1), canto+Vector2(1,altura-4), madeira.lightened(0.14))
	draw_line(canto+Vector2(4,4), canto+Vector2(4,altura-2), madeira.darkened(0.23))
	draw_rect(Rect2(canto + Vector2(0, altura - 5), Vector2(6, 5)), Color(0.08, 0.25, 0.23, 0.48))
	var agua := ponto + Vector2(0, altura)
	draw_polyline(PackedVector2Array([agua + Vector2(-5, -1), agua + Vector2(-3, 1),
		agua + Vector2(3, 1), agua + Vector2(5, -1)]), Color(0.45, 0.70, 0.68, 0.38), 1)
