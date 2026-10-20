extends SceneTree
## Regressão: cabeça canônica idêntica, olhos legíveis, corpo e lâmina preservados.
const ShaderBento := preload("res://codigo/jogador/olhos_contorno_base_vila.gdshader")
func _initialize() -> void:
	rodar.call_deferred()
func metal_perto(fonte: Image, p: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var cor := fonte.get_pixel(clampi(p.x + dx, 0, fonte.get_width() - 1), clampi(p.y + dy, 0, fonte.get_height() - 1))
			if cor.a > 0.5 and cor.b > cor.r * 1.08 and cor.b > 0.35:
				return true
	return false

func rodar() -> void:
	assert(str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"))
	assert(DisplayServer.get_name() != "headless")
	var dados: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/personagens/base_vila_npc/olhos_bento.json"))
	var vista := SubViewport.new()
	vista.size = Vector2i(80, 80)
	vista.transparent_bg = true
	vista.world_2d = World2D.new()
	vista.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vista)
	var ator := Sprite2D.new()
	ator.centered = false
	ator.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var acabamento := ShaderMaterial.new()
	acabamento.shader = ShaderBento
	acabamento.set_shader_parameter("modelo", load("res://assets/personagens/base_vila_npc/parado.png"))
	acabamento.set_shader_parameter("acabamento_modelo", load("res://assets/personagens/base_vila_npc/parado_acabamento.png"))
	ator.material = acabamento
	vista.add_child(ator)
	var quadros := 0
	var pupilas := 0
	var referencias := {}
	var pixels_canonicos := 0
	for acao in ["parado", "corrida", "espada"]:
		ator.texture = load("res://assets/personagens/base_vila_npc/" + acao + ".png")
		acabamento.set_shader_parameter("acabamento", load("res://assets/personagens/base_vila_npc/" + acao + "_acabamento.png"))
		var fonte := ator.texture.get_image()
		var retoques := Image.load_from_file("res://assets/personagens/base_vila_npc/" + acao + "_acabamento.png")
		ator.hframes = 4 if acao == "parado" else 8
		ator.vframes = 1 if acao == "parado" else 4
		for d in 4:
			for f in (1 if acao == "parado" else 8):
				ator.frame = d if acao == "parado" else d * 8 + f
				var guia: Array = dados.cabecas[acao][d][f]
				var destino := Vector2i(roundi(float(guia[0]) + float(guia[2]) / 2.0 - 6.5), int(guia[1]))
				acabamento.set_shader_parameter("cabeca_original", Vector4(guia[0], guia[1], guia[2], guia[3]))
				acabamento.set_shader_parameter("cabeca_destino", Vector2(destino))
				acabamento.set_shader_parameter("direcao", float(d))
				await process_frame
				await RenderingServer.frame_post_draw
				var imagem := vista.get_texture().get_image()
				var origem := Vector2i(d * 80, 0) if acao == "parado" else Vector2i(f * 80, d * 80)
				for y in 80:
					for x in 80:
						var original := fonte.get_pixelv(origem + Vector2i(x, y))
						var atual := imagem.get_pixel(x, y)
						var ponto := Vector2i(x, y)
						var area_cabeca := Rect2i(destino, Vector2i(14, 10)).has_point(ponto) or Rect2i(int(guia[0]) - 1, int(guia[1]), int(guia[2]) + 3, 10).has_point(ponto)
						var gola := Rect2i(destino + Vector2i(3, 10), Vector2i(8, 2)).has_point(ponto)
						if area_cabeca:
							continue
						assert(absf(original.a - atual.a) < 0.01, "Corpo alterado fora da cabeça.")
						if original.a > 0.5 and not original.is_equal_approx(atual):
							assert(gola or retoques.get_pixelv(origem + Vector2i(x, y)).a > 0.5 or original.to_html(false) in ["302327", "49332b"], "Alteração fora do acabamento.")
				if acao == "parado":
					referencias[d] = imagem.get_region(Rect2i(destino, Vector2i(14, 10)))
				else:
					for hy in 10:
						for hx in 14:
							var ponto := destino + Vector2i(hx, hy)
							if metal_perto(fonte, origem + ponto):
								continue
							var esperado: Color = referencias[d].get_pixel(hx, hy)
							var recebido := imagem.get_pixelv(ponto)
							assert(absf(esperado.a - recebido.a) < 0.01 and (esperado.a < 0.5 or esperado.is_equal_approx(recebido)), "Cabeça variou: %s/%d/%d/%s" % [acao, d, f, ponto])
							pixels_canonicos += 1
				var olhos: Array = dados.parado[d][0]
				for i in [0, 2]:
					if int(olhos[i]) < 0:
						continue
					var p := destino + Vector2i(int(olhos[i]) - 34, int(olhos[i + 1]) - 21)
					if metal_perto(fonte, origem + p):
						continue
					for dy in 2:
						assert(imagem.get_pixelv(p + Vector2i(0, dy)).get_luminance() < 0.15, "Pupila ausente: %s/%d/%d" % [acao, d, f])
						for dx in [-1, 1]:
							assert(imagem.get_pixelv(p + Vector2i(dx, dy)).get_luminance() > 0.45, "Olho grudado ao contorno.")
					pupilas += 1
				quadros += 1
	assert(quadros == 68 and pupilas >= 60 and pixels_canonicos > 8000)
	print("CABECA_ESTAVEL_OK: 68 quadros; %d pixels canônicos idênticos; %d pupilas; corpo e arma preservados." % [pixels_canonicos, pupilas])
	quit()
