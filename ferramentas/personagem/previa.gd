extends SceneTree
# Folha de contato de aparências (análise): cada célula é o quadro 0 (parado de frente) da página dada, com corpo + roupa + cabelo.
# Precisa de janela. Uso:
#   godot --path . --script res://ferramentas/personagem/previa.gd -- <saida.png> <escala> <quadro> <corpo.png> <lista>
# <lista>: itens separados por ';', cada um "roupa.png|cabelo.png|#cor" (qualquer parte pode ficar vazia). <quadro> = índice 0..63 na folha 8x8 de 64 px.

class Folha extends Node2D:
	var celulas: Array = []
	var corpo: Texture2D
	var quadro := 0
	var escala := 2
	var colunas := 10
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 8000, 8000), Color(0.28, 0.28, 0.34))
		var origem := Vector2((quadro % 8) * 64, (quadro / 8) * 64)
		for i in celulas.size():
			var c: Dictionary = celulas[i]
			var pos := Vector2((i % colunas) * 64 * escala, (i / colunas) * 64 * escala)
			var dst := Rect2(pos, Vector2(64 * escala, 64 * escala))
			var src := Rect2(origem, Vector2(64, 64))
			draw_texture_rect_region(corpo, dst, src)
			if c["roupa"] != null:
				draw_texture_rect_region(c["roupa"], dst, src)
			if c["cabelo"] != null:
				draw_texture_rect_region(c["cabelo"], dst, src, c["cor"])
			draw_string(ThemeDB.fallback_font, pos + Vector2(2, 10), str(i), HORIZONTAL_ALIGNMENT_LEFT, -1, 10)

func _initialize() -> void:
	_rodar()

func _rodar() -> void:
	var a := OS.get_cmdline_user_args()
	var f := Folha.new()
	f.escala = int(a[1])
	f.quadro = int(a[2])
	f.corpo = load(a[3])
	for item in a[4].split(";", false):
		var partes := item.split("|")
		var roupa = load(partes[0]) if partes.size() > 0 and partes[0] != "" else null
		var cabelo = load(partes[1]) if partes.size() > 1 and partes[1] != "" else null
		var cor := Color.WHITE
		if partes.size() > 2 and partes[2] != "":
			cor = Color(partes[2])
		f.celulas.append({"roupa": roupa, "cabelo": cabelo, "cor": cor})
	f.colunas = mini(10, f.celulas.size())
	var vp := SubViewport.new()
	vp.size = Vector2i(f.colunas * 64 * f.escala, ((f.celulas.size() + f.colunas - 1) / f.colunas) * 64 * f.escala)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.add_child(f)
	root.add_child(vp)
	for i in 6:
		await process_frame
	vp.get_texture().get_image().save_png(a[0])
	print("salvo ", a[0])
	quit()
