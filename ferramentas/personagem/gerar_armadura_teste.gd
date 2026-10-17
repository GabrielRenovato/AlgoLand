extends SceneTree

# Usa o encaixe das poses nativas, mas redesenha o tórax como placas rígidas, sem suspensórios.
const Aparencia := preload("res://codigo/dados/aparencia.gd")
const DESTINO := "res://assets/personagens/prototipos/armadura_teste/"
const ACO := {"425865": "3c485c", "8aafac": "8497b0", "c7e5dc": "d4dfec", "383050": "3c485c", "5068a0": "8497b0", "88b0e8": "d4dfec", "364a3f": "3c485c", "5b7f6a": "8497b0", "a8c898": "d4dfec"}
const COURO := {"7f4935": "372c27", "b47f54": "67472f", "dab988": "9b6c41", "815c21": "372c27", "b29149": "67472f", "e0d28e": "9b6c41"}
var _placas: Array[Image] = []

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DESTINO))
	_carregar_placas()
	var paginas := ["pesca"] if "--pesca" in OS.get_cmdline_user_args() else Aparencia.PAGINAS_ANDAR + Aparencia.PAGINAS_COMBATE
	for pagina in paginas:
		var textura := Aparencia.roupa(2, pagina)
		var original := textura.get_image()
		var imagem: Image = original.duplicate()
		var alterados := 0
		for linha in 8:
			for coluna in 8:
				var inicio := Vector2i(coluna * 64, linha * 64)
				var limite_pes := -1
				var inicio_peitoral := 64
				for y in 64:
					for x in 64:
						var pixel := imagem.get_pixelv(inicio + Vector2i(x, y))
						if pixel.a > 0.5 and (COURO.has(pixel.to_html(false)) or ACO.has(pixel.to_html(false))):
							limite_pes = maxi(limite_pes, y)
						if pixel.a > 0.5 and ACO.has(pixel.to_html(false)):
							inicio_peitoral = mini(inicio_peitoral, y)
				for y in 64:
					for x in 64:
						var ponto := inicio + Vector2i(x, y)
						var pixel := imagem.get_pixelv(ponto)
						if pixel.a == 0.0:
							continue
						var chave := pixel.to_html(false)
						if y >= limite_pes - 3 and (ACO.has(chave) or COURO.has(chave)):
							var brilho := (pixel.r + pixel.g + pixel.b) / 3.0
							imagem.set_pixelv(ponto, Color.html("372c27" if brilho < 0.4 else ("67472f" if brilho < 0.65 else "9b6c41")))
							alterados += 1
				alterados += _desenhar_peitoral(imagem, original, inicio, inicio_peitoral, limite_pes, linha % 4)
		if imagem.save_png(DESTINO + pagina + ".png") != OK or alterados == 0:
			push_error("Não foi possível preparar a armadura: " + pagina)
			quit(1)
			return
		print("Armadura: ", pagina, ", pixels adaptados: ", alterados)
	quit()

func _carregar_placas() -> void:
	# A folha preparada permite gerar páginas adicionais sem depender do conceito de trabalho.
	if "--pesca" in OS.get_cmdline_user_args():
		var atlas := Image.load_from_file(DESTINO + "placas_pixel.png")
		for i in 4:
			_placas.append(atlas.get_region(Rect2i(i * 14, 0, 14, 12)))
		return
	var fonte := Image.load_from_file(DESTINO + "conceitos/peitoral_placas_v3.png")
	var paleta: Array[Color] = []
	for cor in ["151622", "292b42", "40415c", "595c78", "777e99", "9ba5bb", "c8d0df", "eff0e8", "543b1e", "92642d", "cd9b45", "f1cf83", "321923", "602c35", "a04d44", "bc7762"]:
		paleta.append(Color.html(cor))
	for i in 4:
		var inicio := roundi(i * fonte.get_width() / 4.0)
		var fim := roundi((i + 1) * fonte.get_width() / 4.0)
		var placa := fonte.get_region(Rect2i(inicio, 0, fim - inicio, fonte.get_height()))
		for y in placa.get_height():
			for x in placa.get_width():
				if placa.get_pixel(x, y).a < 0.5:
					placa.set_pixel(x, y, Color.TRANSPARENT)
		placa = placa.get_region(placa.get_used_rect())
		placa.resize(14, 12, Image.INTERPOLATE_NEAREST)
		for y in placa.get_height():
			for x in placa.get_width():
				var pixel := placa.get_pixel(x, y)
				if pixel.a < 0.5:
					placa.set_pixel(x, y, Color.TRANSPARENT)
					continue
				var melhor := paleta[0]
				var distancia := INF
				for cor in paleta:
					var delta := Vector3(pixel.r - cor.r, pixel.g - cor.g, pixel.b - cor.b).length_squared()
					if delta < distancia:
						distancia = delta
						melhor = cor
				placa.set_pixel(x, y, melhor)
		_placas.append(placa)
	var atlas := Image.create(56, 12, false, Image.FORMAT_RGBA8)
	for i in 4:
		atlas.blit_rect(_placas[i], Rect2i(0, 0, 14, 12), Vector2i(i * 14, 0))
	atlas.save_png(DESTINO + "placas_pixel.png")

## Preenche o tórax sem transferir os vazios do recorte conceitual para o corpo.
## As mãos continuam visíveis nas linhas inferiores, conforme a roupa nativa.
func _desenhar_peitoral(imagem: Image, original: Image, inicio: Vector2i, primeiro_aco: int, pes: int, vista: int) -> int:
	if primeiro_aco == 64:
		return 0
	var topo := maxi(primeiro_aco - 3, 0)
	var fundo := maxi(topo + 3, mini(primeiro_aco + 6, pes - 4))
	var esquerda_pose := 64
	var direita_pose := 0
	for y in range(topo, fundo + 1):
		for x in 64:
			var cor := original.get_pixelv(inicio + Vector2i(x, y))
			if cor.a > 0.5 and (ACO.has(cor.to_html(false)) or COURO.has(cor.to_html(false))):
				esquerda_pose = mini(esquerda_pose, x)
				direita_pose = maxi(direita_pose, x)
	var placa := _placas[vista]
	var alterados := 0
	for y in range(topo, fundo + 1):
		var xs: Array[int] = []
		for x in 64:
			var cor := original.get_pixelv(inicio + Vector2i(x, y))
			if cor.a > 0.5 and (ACO.has(cor.to_html(false)) or COURO.has(cor.to_html(false)) or cor.to_html(false) == "181818"):
				xs.append(x)
		if xs.is_empty():
			continue
		# Fecha os vãos dos suspensórios abaixo da gola, sem ampliar a silhueta.
		if y >= topo + 1 and y < primeiro_aco:
			for x in range(xs.front(), xs.back() + 1):
				if not xs.has(x):
					xs.append(x)
		for x in xs:
			var u := clampi(roundi((x - esquerda_pose) * 13.0 / maxf(direita_pose - esquerda_pose, 1)), 0, 13)
			var v := clampi(roundi((y - topo) * 11.0 / maxf(fundo - topo, 1)), 0, 11)
			imagem.set_pixelv(inicio + Vector2i(x, y), _cor_solida(placa, u, v))
			alterados += 1
	return alterados

## O fundo transparente do conceito descreve a silhueta da peça, não buracos na chapa.
func _cor_solida(placa: Image, u: int, v: int) -> Color:
	var pixel := placa.get_pixel(u, v)
	if pixel.a > 0.5:
		return pixel
	var distancia := INF
	var cor := Color.html("40415c")
	for y in placa.get_height():
		for x in placa.get_width():
			var candidato := placa.get_pixel(x, y)
			var delta := Vector2(x - u, y - v).length_squared()
			if candidato.a > 0.5 and delta < distancia:
				distancia = delta
				cor = candidato
	return cor
