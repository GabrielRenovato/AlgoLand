extends SceneTree

const FONTES := "res://arte/fontes/personagens/exemplo_alta_qualidade/idle_transicao/"
const SAIDA := "res://assets/personagens/prototipos/exemplo_alta_qualidade/"
const REGISTRO := preload("res://ferramentas/personagem/registro_sprite_gerado.gd")

func _initialize() -> void:
	for direcao: String in ["lado", "baixo", "cima"]:
		var caminho := FONTES + "idle_" + direcao + "_fonte.png"
		if not FileAccess.file_exists(caminho):
			push_error("Falta a fonte de idle: " + direcao)
			quit(1)
			return
		_preparar(direcao, Image.load_from_file(caminho))
	quit()

func _preparar(direcao: String, fonte: Image) -> void:
	var referencia := Image.load_from_file(FONTES + "referencia_" + direcao + ".png")
	var largura_cabeca := REGISTRO.largura_cabeca(referencia)
	var quadros: Array[Image] = []
	var larguras: Array[int] = []
	for i in 4:
		var inicio := Vector2i(roundi(float(i % 2) * fonte.get_width() / 2), roundi(float(i / 2) * fonte.get_height() / 2))
		var fim := Vector2i(roundi(float(i % 2 + 1) * fonte.get_width() / 2), roundi(float(i / 2 + 1) * fonte.get_height() / 2))
		var quadro := fonte.get_region(Rect2i(inicio, fim - inicio))
		REGISTRO.limpar(quadro)
		quadros.append(quadro)
		larguras.append(REGISTRO.largura_cabeca(quadro))
	larguras.sort()
	# Uma única escala por direção: respiração e flexão não alteram a cabeça.
	var escala := float(largura_cabeca) / larguras[2]
	var atlas := Image.create(2048, 2048, false, Image.FORMAT_RGBA8)
	for i in 4:
		var cabeca_x := 32.0
		if direcao == "lado" and i >= 2:
			cabeca_x = 34.0 if i == 2 else 36.0
		var tela := REGISTRO.registrar(quadros[i], escala, cabeca_x, 44.0)
		atlas.blit_rect(tela, Rect2i(0, 0, 1024, 1024), Vector2i(i % 2, i / 2) * 1024)
	atlas.save_png(SAIDA + "idle_" + direcao + ".png")
	print("IDLE ", direcao, ": respiração (0/1), preparação (2) e impulso (3), atlas 2x2.")
