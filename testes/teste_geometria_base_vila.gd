extends SceneTree
## Compara cada pixel do recurso ativo com as poses anteriores à adaptação anatômica.
const NOMES := ["frente", "direita", "costas", "esquerda"]
func _initialize() -> void:
	var conferidos := 0
	for acao in ["parado", "corrida", "espada"]:
		var ativa := Image.load_from_file("res://assets/personagens/base_vila_nativa/%s.png" % acao)
		var original: Image
		if acao != "espada":
			original = Image.load_from_file("res://arte/fontes/personagens/base_vila_estudo/%s-v1-64.png" % acao)
		for d in 4:
			for f in (1 if acao == "parado" else 8):
				var origem := Vector2i(d * 80, 0) if acao == "parado" else Vector2i(f * 80, d * 80)
				var ampliada: Image
				if acao == "espada":
					ampliada = Image.load_from_file("res://arte/previas/personagens/base_vila_estudo/espada_quatro_direcoes/%s_%d.png" % [NOMES[d], f])
				for y in 80:
					for x in 80:
						var atual := ativa.get_pixelv(origem + Vector2i(x, y))
						if x < 8 or x >= 72 or y < 8 or y >= 72:
							assert(atual.a == 0.0, "Margem invadida.")
							continue
						var esperado: Color
						if acao == "espada":
							esperado = ampliada.get_pixel(33 + (x - 8) * 3, 59 + (y - 8) * 3)
						else:
							esperado = original.get_pixel((d if acao == "parado" else f) * 64 + x - 8, (0 if acao == "parado" else d * 64) + y - 8)
						assert(atual == esperado, "Pose alterada: %s/%d/%d/%d,%d" % [acao, d, f, x, y])
				conferidos += 1
	assert(conferidos == 68)
	print("GEOMETRIA_NATIVA_OK: 68 poses e278528 pixels originais preservados; sem escala desigual ou recorte anatômico.")
	quit()
