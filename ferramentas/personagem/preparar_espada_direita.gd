extends "res://ferramentas/personagem/preparar_espada_gerada.gd"

## Registra desenhos completos de corpo, mão e arma, sem separar os membros.
func _initialize() -> void:
	var fonte := Image.load_from_file(FONTES + "espada_direita_fonte.png")
	if fonte == null:
		push_error("Falta a fonte do ataque para a direita.")
		quit(1)
		return
	var referencia := Image.load_from_file(FONTES + "referencia_lado.png")
	var largura_cabeca: int = _medir(referencia).cabeca.size.x
	var atlas := Image.create(2048, 5120, false, Image.FORMAT_RGBA8)
	for i in 9:
		# A fonte tem margens verticais irregulares; os cortes preservam pés inteiros.
		var linhas := [0, 375, 695, 1024]
		var inicio := Vector2i(roundi(float(i % 3) * fonte.get_width() / 3), linhas[i / 3])
		var fim := Vector2i(roundi(float(i % 3 + 1) * fonte.get_width() / 3), linhas[i / 3 + 1])
		var pose := fonte.get_region(Rect2i(inicio, fim - inicio))
		var correcao := FONTES + "espada_direita_pose_%d.png" % i
		if FileAccess.file_exists(correcao):
			pose = Image.load_from_file(correcao)
		REGISTRO.limpar(pose)
		var medida := _medir(pose)
		var cabeca: Rect2i = medida.cabeca
		var escala := float(largura_cabeca) / maxi(1, cabeca.size.x)
		var centro_x: float = 512.0 + [0, 0, 24, 24, 24, 24, 16, 8, 0][i]
		var posicao := Vector2i(roundi(centro_x - cabeca.get_center().x * escala), roundi(704 - (medida.pe + 2) * escala))
		var limites := pose.get_used_rect()
		var minimo := posicao + Vector2i(Vector2(limites.position) * escala)
		var maximo := posicao + Vector2i(Vector2(limites.end) * escala)
		if minimo.x < 0 or minimo.y < 0 or maximo.x > 1024 or maximo.y > 1024:
			push_error("Ataque direita fora da tela na pose %d: %s a %s" % [i, minimo, maximo])
			quit(1)
			return
		pose.resize(roundi(pose.get_width() * escala), roundi(pose.get_height() * escala), Image.INTERPOLATE_NEAREST)
		var tela := Image.create(1024, 1024, false, Image.FORMAT_RGBA8)
		tela.blit_rect(pose, Rect2i(Vector2i.ZERO, pose.get_size()), posicao)
		atlas.blit_rect(tela, Rect2i(0, 0, 1024, 1024), Vector2i(i % 2, i / 2) * 1024)
	atlas.save_png(SAIDA + "espada_direita.png")
	print("ATAQUE DIREITA: nove desenhos completos, cabeça na escala do personagem e pés no pivô existente.")
	quit()
