extends SceneTree
# Ferramenta de analise: amplia uma folha de tiles com grade e numeracao de colunas/linhas.
# Uso (precisa de janela, nao headless):
#   godot --path . --script res://ferramentas/arena/ampliar_folha.gd -- <png> <saida.png> <escala> [col lin larg alt] [larg_tile [alt_tile]]
# col/lin/larg/alt em tiles. Cada celula recebe o rotulo "col,lin" no canto superior.

class Desenho extends Node2D:
	var tex: Texture2D
	var escala := 4
	var origem := Vector2i.ZERO
	var tam := Vector2i.ZERO
	var tile := 16
	var tile_h := 16
	var margem := 28

	func _draw() -> void:
		var fonte := ThemeDB.fallback_font
		draw_rect(Rect2(Vector2.ZERO, Vector2(Vector2i(tam.x * tile, tam.y * tile_h) * escala + Vector2i(margem, margem))), Color(0.18, 0.2, 0.22))
		# fundo xadrez para enxergar transparencia
		var area := Rect2(Vector2(margem, margem), Vector2(tam.x * tile * escala, tam.y * tile_h * escala))
		var passo := 8
		for yy in range(0, int(area.size.y), passo):
			for xx in range(0, int(area.size.x), passo):
				var c := Color(0.55, 0.0, 0.55) if ((xx / passo + yy / passo) % 2 == 0) else Color(0.45, 0.0, 0.45)
				draw_rect(Rect2(area.position + Vector2(xx, yy), Vector2(passo, passo)), c)
		var origem_px := Vector2(origem.x * tile, origem.y * tile_h)
		draw_texture_rect_region(tex, area, Rect2(origem_px, Vector2(tam.x * tile, tam.y * tile_h)))
		for i in range(tam.x + 1):
			var x := margem + i * tile * escala
			draw_line(Vector2(x, margem), Vector2(x, area.end.y), Color(1, 1, 0, 0.55), 1.0)
			if i < tam.x:
				draw_string(fonte, Vector2(x + 2, 18), str(origem.x + i), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
		for j in range(tam.y + 1):
			var y := margem + j * tile_h * escala
			draw_line(Vector2(margem, y), Vector2(area.end.x, y), Color(1, 1, 0, 0.55), 1.0)
			if j < tam.y:
				draw_string(fonte, Vector2(1, y + 16), str(origem.y + j), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)

var _quadros := 0
var _saida := ""
var _vp: SubViewport

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 3:
		push_error("uso: <png> <saida> <escala> [col lin larg alt] [tile]")
		quit(1)
		return
	var img := Image.load_from_file(args[0])
	var tex := ImageTexture.create_from_image(img)
	var tile := 16
	var tile_h := 16
	var origem := Vector2i.ZERO
	var tam := Vector2i(img.get_width() / tile, img.get_height() / tile)
	if args.size() >= 8:
		origem = Vector2i(int(args[3]), int(args[4]))
		tam = Vector2i(int(args[5]), int(args[6]))
		tile = int(args[7])
		tile_h = int(args[8]) if args.size() >= 9 else tile
	elif args.size() >= 7:
		origem = Vector2i(int(args[3]), int(args[4]))
		tam = Vector2i(int(args[5]), int(args[6]))
	var d := Desenho.new()
	d.tex = tex
	d.escala = int(args[2])
	d.origem = origem
	d.tam = tam
	d.tile = tile
	d.tile_h = tile_h
	_saida = args[1]
	_vp = SubViewport.new()
	_vp.size = Vector2i(tam.x * tile, tam.y * tile_h) * d.escala + Vector2i(d.margem, d.margem)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.transparent_bg = false
	root.add_child(_vp)
	_vp.add_child(d)

func _process(_delta: float) -> bool:
	_quadros += 1
	if _quadros == 4:
		_vp.get_texture().get_image().save_png(_saida)
		print("salvo: ", _saida)
		quit()
	return false
