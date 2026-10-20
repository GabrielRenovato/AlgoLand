extends SceneTree
## Reempacota as poses aprovadas sem escala, recortes anatômicos ou repintura.
const NOMES := ["frente", "direita", "costas", "esquerda"]
const SAIDA := "res://assets/personagens/base_vila_nativa/"
const FONTES := "res://arte/fontes/personagens/base_vila_estudo/"

static func fonte_quadro(acao: String, d: int, f: int) -> Image:
	if acao == "espada":
		# Recupera a célula64 da mesma prévia aprovada, pelo recorte/escala comuns.
		var ampliada := Image.load_from_file("res://arte/previas/personagens/base_vila_estudo/espada_quatro_direcoes/%s_%d.png" % [NOMES[d], f])
		var quadro := ampliada.get_region(Rect2i(32, 58, 192, 192))
		quadro.resize(64, 64, Image.INTERPOLATE_NEAREST)
		return quadro
	var folha := Image.load_from_file(FONTES + acao + "-v1-64.png")
	return folha.get_region(Rect2i(d * 64 if acao == "parado" else f * 64, 0 if acao == "parado" else d * 64, 64, 64))

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(SAIDA)
	var copia := "res://arte/fontes/personagens/base_vila_npc/v4_geometria_nativa/"
	DirAccess.make_dir_recursive_absolute(copia)
	for acao in ["parado", "corrida", "espada"]:
		var folha := Image.create(320 if acao == "parado" else 640, 80 if acao == "parado" else 320, false, Image.FORMAT_RGBA8)
		for d in 4:
			for f in (1 if acao == "parado" else 8):
				var quadro := fonte_quadro(acao, d, f)
				var origem := Vector2i(d * 80, 0) if acao == "parado" else Vector2i(f * 80, d * 80)
				folha.blit_rect(quadro, Rect2i(0, 0, 64, 64), origem + Vector2i(8, 8))
		assert(folha.save_png(SAIDA + acao + ".png") == OK)
		assert(folha.save_png(copia + acao + ".png") == OK)
	print("GEOMETRIA_NATIVA: 68 poses preservadas integralmente; somente margem8px, pivô40/52.")
	quit()
