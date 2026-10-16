extends SceneTree

## Apaga o "chãozinho" que o PixelLab desenha embaixo de alguns objetos (grama ou terra em volta da base), que ficava como um
## remendo de outra grama em cima do chão da cidade. Preenche a partir dos pixels transparentes, só na parte de baixo do desenho,
## apagando pixels de chão: verdes (grama) e, se pedido, terra (marrom pouco saturado e escuro). Os originais ficam em
## arte/fontes/cenario/aconchego/; a saída sobrescreve o arquivo em assets.
## Uso: godot --headless --path . --script ferramentas/cidade/limpar_chao_props.gd -- <arquivo.png> [terra]
## Grama verde ou grama seca amarelo-esverdeada (o feno dourado fica de fora: matiz abaixo de 0,14)
func _verde(c: Color) -> bool:
	if c.g > c.r * 1.05 and c.g > c.b * 1.1:
		return true
	return c.h > 0.14 and c.h < 0.3 and c.s > 0.3

func _terra(c: Color) -> bool:
	var h := c.h
	return c.s > 0.15 and c.s < 0.6 and c.v < 0.75 and h > 0.04 and h < 0.13

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var com_terra := a.size() > 1 and a[1] == "terra"
	var img := Image.load_from_file(a[0])
	img.convert(Image.FORMAT_RGBA8)
	var usado := img.get_used_rect()
	var limite_y := usado.position.y + int(usado.size.y * 0.55)
	var fila: Array[Vector2i] = []
	var visto := {}
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a < 0.5:
				fila.append(Vector2i(x, y))
				visto[Vector2i(x, y)] = true
	var apagados := 0
	while not fila.is_empty():
		var p: Vector2i = fila.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = p + d
			if q.x < 0 or q.y < 0 or q.x >= img.get_width() or q.y >= img.get_height() or visto.has(q):
				continue
			if q.y < limite_y:
				continue
			var c := img.get_pixel(q.x, q.y)
			if c.a < 0.5 or _verde(c) or (com_terra and _terra(c)):
				visto[q] = true
				if c.a >= 0.5:
					img.set_pixel(q.x, q.y, Color(0, 0, 0, 0))
					apagados += 1
				fila.append(q)
	img.save_png(a[0])
	print("ok ", a[0].get_file(), " ", apagados)
	quit()
