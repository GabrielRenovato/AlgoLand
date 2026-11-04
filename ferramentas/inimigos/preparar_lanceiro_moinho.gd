extends SceneTree
## Empacota as poses preservando o registro anatômico documentado, sem recentrar por silhueta.
const FONTES := "res://arte/fontes/inimigos/goblins_moinho/lanceiro/"
const DESTINO := "res://assets/inimigos/goblins_moinho/lanceiro/"

func _initialize() -> void:
	var fichas: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FONTES + "registro.json"))
	DirAccess.make_dir_recursive_absolute(DESTINO)
	var recursos := "[gd_resource type=\"SpriteFrames\" load_steps=%d format=3]\n\n" % (1 + fichas.size() * 7)
	for nome in fichas:
		recursos += '[ext_resource type="Texture2D" path="%s%s.png" id="%s"]\n' % [DESTINO, nome, nome]
	recursos += "\n"
	var animacoes: Array[String] = []
	for nome in fichas:
		var ficha: Dictionary = fichas[nome]
		var fonte := Image.load_from_file(FONTES + ficha.fonte)
		var atlas := Image.create(1536, 256, false, Image.FORMAT_RGBA8)
		for q in 6:
			var origem: Array = ficha.quadros[q].origem
			var posicao: Array = ficha.quadros[q].destino
			var celula := Image.create(1024, 1024, false, Image.FORMAT_RGBA8)
			# Faixas da própria figura preservam a lança sem copiar pedaços do vizinho.
			for faixa in ficha.quadros[q].faixas_visiveis:
				celula.blit_rect(fonte, Rect2i(faixa[1], faixa[0], faixa[2], 1), Vector2i(posicao[0] + faixa[1] - origem[0], posicao[1] + faixa[0] - origem[1]))
			celula.resize(256, 256, Image.INTERPOLATE_LANCZOS)
			atlas.blit_rect(celula, Rect2i(0, 0, 256, 256), Vector2i(q * 256, 0))
			recursos += '[sub_resource type="AtlasTexture" id="%s_%d"]\natlas = ExtResource("%s")\nregion = Rect2(%d, 0, 256, 256)\n\n' % [nome, q, nome, q * 256]
		atlas.save_png(DESTINO + nome + ".png")
		var quadros: Array[String] = []
		for q in 6:
			quadros.append('{"duration": %s, "texture": SubResource("%s_%d")}' % [str(ficha.duracoes_ms[q] / 10.0), nome, q])
		animacoes.append('{"frames": [%s], "loop": %s, "name": &"%s", "speed": 100.0}' % [", ".join(quadros), "true" if nome.begins_with("andar") else "false", nome])
		print("LANCEIRO_ATLAS ", nome)
	recursos += "[resource]\nanimations = [%s]\n" % ",\n".join(animacoes)
	FileAccess.open(DESTINO + "animacoes.tres", FileAccess.WRITE).store_string(recursos)
	var registro_visual: Dictionary = {}
	for nome in fichas:
		registro_visual[nome] = {"escala": fichas[nome].escala, "pivo": [128, 224], "celula": [256, 256], "duracoes_ms": fichas[nome].duracoes_ms}
	FileAccess.open(DESTINO + "registro.json", FileAccess.WRITE).store_string(JSON.stringify(registro_visual, "\t"))
	quit()
