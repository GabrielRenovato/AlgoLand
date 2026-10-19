extends SceneTree

var falhas := 0

func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ", nome)
	if not ok:
		falhas += 1

func _initialize() -> void:
	var dados: GDScript = load("res://codigo/cidade/dados_cidade.gd")
	var imagens := {}
	for id in dados.MORADORES:
		var caminho: String = dados.caminho_sprite(id)
		var geometria: Dictionary = dados.geometria_sprite(id) if id != "nilo" else {"grade": [4, 1], "quadro": [64, 64], "pes_y": 46}
		var grade := Vector2i(geometria["grade"][0], geometria["grade"][1])
		var imagem := Image.load_from_file(caminho)
		verificar("folha segue grade nativa: " + id, imagem != null and imagem.get_size() == grade * 64)
		if imagem == null:
			continue
		var assinatura := FileAccess.get_sha256(caminho)
		verificar("identidade visual exclusiva: " + id, not imagens.has(assinatura))
		imagens[assinatura] = id
		for linha in range(grade.y):
			for coluna in range(grade.x):
				var quadro := imagem.get_region(Rect2i(coluna*64,linha*64,64,64))
				var area := quadro.get_used_rect()
				verificar("quadro inteiro e pes alinhados %s/%d/%d" % [id,linha,coluna], area.size != Vector2i.ZERO and area.position.x > 0 and area.end.x < 64 and area.position.y > 0 and absi(area.end.y - int(geometria["pes_y"])) <= 3)
				var binaria := true
				for y in range(64):
					for x in range(64):
						var alfa := quadro.get_pixel(x,y).a
						binaria = binaria and (alfa == 0.0 or alfa == 1.0)
				verificar("transparencia sem halo %s/%d/%d" % [id,linha,coluna], binaria)
	print("FALHAS: ", falhas)
	quit(falhas)
