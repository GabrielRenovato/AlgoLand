extends SceneTree

## Regressão do visor que deformava/piscava: compara pixels visíveis, descontando
## somente o deslocamento da cabeça. A importação pode alterar RGB com alfa zero.
const Aparencia := preload("res://codigo/dados/aparencia.gd")
const Padrao := preload("res://codigo/dados/padrao_armadura.gd")
var _falhas := 0

func _initialize() -> void:
	# Confere o molde legado; teste_corpo_original cobre a base nova no jogador.
	var args := OS.get_cmdline_user_args()
	var raiz := "res://assets/personagens/conjuntos/cavaleiro_rubro/"
	for argumento in args:
		if not argumento.begins_with("--"):
			raiz = argumento
			break
	var referencias: Array[Image] = []
	referencias.resize(4)
	var indice := -1
	for i in Aparencia.total_roupas():
		if Aparencia.roupas()[i]["id"] == "armadura_cavaleiro_rubro":
			indice = i
	if indice < 0:
		push_error("Traje Rubro ausente do cadastro.")
		quit(1)
		return
	for pagina in Padrao.CORPOS:
		var folha := Image.load_from_file(raiz + "elmo/" + pagina + ".png")
		if folha == null or folha.is_empty():
			print("FALHA ", pagina, ": folha do elmo ausente")
			_falhas += 1
			continue
		var corpo: Image = load("res://assets/personagens/" + Padrao.CORPOS[pagina]).get_image()
		var cabelos := Aparencia.cabelo(0, pagina).get_image()
		var corpo_usado := Aparencia.corpo(pagina, indice, 15).get_image()
		if not _mesmos_pixels(corpo, corpo_usado):
			print("FALHA ", pagina, ": cabeça original foi removida do corpo")
			_falhas += 1
		var alterados := 0
		var examinados := 0
		for linha in 8:
			for coluna in 8:
				var regiao := Rect2i(coluna * 64, linha * 64, 64, 64)
				var cabeca := cabelos.get_region(regiao).get_used_rect()
				if cabeca.size == Vector2i.ZERO or corpo.get_region(regiao).is_invisible():
					continue
				if pagina == "andar" and linha >= 4 and coluna < 6:
					var coberto := true
					for y in range(cabeca.position.y, cabeca.position.y + 13):
						for x in range(cabeca.position.x, cabeca.end.x):
							var ponto := regiao.position + Vector2i(x, y)
							if corpo.get_pixelv(ponto).a > 0.5 and folha.get_pixelv(ponto).a < 0.5:
								coberto = false
					if not coberto:
						print("FALHA caminhada ", linha % 4, "/", coluna, ": placa do elmo deixa rosto descoberto")
						_falhas += 1
				var ancora := Vector2i(cabeca.position.x + cabeca.size.x / 2, cabeca.position.y + 13)
				var quadro := Image.create(80, 80, false, Image.FORMAT_RGBA8)
				quadro.blit_rect(folha, regiao, Vector2i(40, 40) - ancora)
				var d := linha % 4
				if referencias[d] == null:
					referencias[d] = quadro
				elif not _mesmos_pixels(referencias[d], quadro):
					alterados += 1
				examinados += 1
		print("OK " if alterados == 0 else "FALHA ", pagina, ": ", examinados, " poses, ", alterados, " deformações do elmo")
		if alterados > 0:
			_falhas += 1
	print("Falhas: ", _falhas)
	quit(_falhas)

func _mesmos_pixels(a: Image, b: Image) -> bool:
	if a.get_size() != b.get_size():
		return false
	for y in a.get_height():
		for x in a.get_width():
			var cor_a := a.get_pixel(x, y)
			var cor_b := b.get_pixel(x, y)
			if cor_a.a != cor_b.a or (cor_a.a > 0.0 and cor_a != cor_b):
				return false
	return true
