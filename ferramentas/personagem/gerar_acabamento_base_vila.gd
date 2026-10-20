extends SceneTree
## Atlas de retoques por quadro, sem alterar a silhueta nem os arquivos aprovados.
const RAIZ := "res://assets/personagens/base_vila_npc/"
const TECIDO := {"747362": "b3a58d", "9f9c83": "c8bea5", "c8c4a8": "ded5ba", "e5dfc3": "efe7ce"}

func _initialize() -> void:
	var dados: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RAIZ + "olhos_bento.json"))
	for acao in ["parado", "corrida", "espada"]:
		var fonte := Image.load_from_file(RAIZ + acao + ".png")
		var retoques := Image.create(fonte.get_width(), fonte.get_height(), false, Image.FORMAT_RGBA8)
		for d in 4:
			for f in (1 if acao == "parado" else 8):
				var origem := Vector2i(d * 80, 0) if acao == "parado" else Vector2i(f * 80, d * 80)
				var guia: Array = dados.cabecas[acao][d][f]
				var cabeca := Rect2i(int(guia[0]), int(guia[1]), int(guia[2]), int(guia[3]))
				# Somente a paleta do tecido, perto do torso; aço e brilhos brancos preservados.
				for y in range(cabeca.end.y, mini(65, cabeca.end.y + 14)):
					for x in range(maxi(0, cabeca.position.x - 8), mini(80, cabeca.end.x + 8)):
						var p := origem + Vector2i(x, y)
						var cor := fonte.get_pixelv(p)
						if cor.a > 0.5 and TECIDO.has(cor.to_html(false)):
							retoques.set_pixelv(p, Color(TECIDO[cor.to_html(false)]))
				if d == 2:
					continue
				var olhos: Array = dados[acao][d][f]
				# Remove vestígios de olhos antigos apenas na região interna do rosto.
				for y in range(int(olhos[1]) - 1, int(olhos[1]) + 3):
					for x in range(cabeca.position.x + 2, cabeca.end.x - 2):
						var p := origem + Vector2i(x, y)
						var interno := true
						for delta in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
							interno = interno and fonte.get_pixelv(p + delta).a > 0.5
						var cor := fonte.get_pixelv(p)
						if interno and cor.a > 0.5 and cor.to_html(false) in ["302327", "49332b", "674731", "747362", "9f9c83", "c8c4a8", "e5dfc3", "fff4d7"]:
							retoques.set_pixelv(p, Color("f2bc86"))
				for i in [0, 2]:
					if int(olhos[i]) < 0:
						continue
					var olho := Vector2i(int(olhos[i]), int(olhos[i + 1]))
					# Um pixel de pele separa a pupila do contorno em todos os quadros.
					for dy in range(-1, 3):
						for dx in range(-1, 2):
							var p := origem + olho + Vector2i(dx, dy)
							assert(fonte.get_pixelv(p).a > 0.5)
							retoques.set_pixelv(p, Color("f2bc86"))
					for dy in 2:
						retoques.set_pixelv(origem + olho + Vector2i(0, dy), Color("1c181a"))
		assert(retoques.save_png(RAIZ + acao + "_acabamento.png") == OK)
	print("ACABAMENTO: 68 quadros, olhos com margem e tecido creme; alfa fonte preservado.")
	quit()
