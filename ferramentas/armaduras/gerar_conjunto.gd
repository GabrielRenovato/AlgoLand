extends SceneTree

## Compila o conceito nas poses nativas: o corpo determina a silhueta e o movimento,
## o cabelo nativo localiza a cabeça, e as placas fornecem a superfície da armadura.
const Aparencia := preload("res://codigo/dados/aparencia.gd")
const Padrao := preload("res://codigo/dados/padrao_armadura.gd")
const CORPOS := Padrao.CORPOS
const Acabamento := preload("res://codigo/dados/acabamento_refinado.gd")
var _config: Dictionary = {}
var _destino := ""
var _paleta: Array = []

var _elmos: Array[Image] = []
var _peitorais: Array[Image] = []
var _grevas: Array[Image] = []
var _ancoras_elmo: Array[int] = []
var _deslocamentos_cabeca: Array[int] = []
var _elmos_rigidos: Array[Image] = []
var _ancoras_cartola: Array[int] = []
var _deslocamentos_cranio: Array[int] = []

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var manifesto := args[0] if not args.is_empty() else "res://ferramentas/armaduras/modelos/carrasco.json"
	_config = Padrao.carregar(manifesto)
	var erros := Padrao.validar(_config)
	if not erros.is_empty():
		for erro in erros:
			push_error(erro)
		quit(1)
		return
	_destino = String(_config["destino"])
	_paleta = _config["paleta"]
	if "--somente-acabamento" in args:
		quit(0 if Acabamento.compilar_conjunto(_config) else 1)
		return
	if "--somente-dados" in args:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_destino))
		quit(0 if _gravar_definicao() else 1)
		return
	if not FileAccess.file_exists(_config["arte"]):
		push_error("Conceito não encontrado: " + String(_config["arte"]))
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_destino))
	if not _preparar_pecas():
		quit(1)
		return
	Image.create(512, 512, false, Image.FORMAT_RGBA8).save_png(_destino + "cabelo_oculto.png")
	for pagina in CORPOS:
		var corpo: Image = load("res://assets/personagens/" + CORPOS[pagina]).get_image()
		var corpo_visivel := corpo.duplicate()
		var cabelo: Image = Aparencia.cabelo(0, pagina).get_image()
		var roupa: Image = Aparencia.roupa(2, pagina).get_image()
		var folha := Image.create(512, 512, false, Image.FORMAT_RGBA8)
		var folhas_pecas := {}
		for peca in ["elmo", "peitoral", "luvas", "botas"]:
			folhas_pecas[peca] = Image.create(512, 512, false, Image.FORMAT_RGBA8)
		var poses := 0
		for linha in 8:
			for coluna in 8:
				var regiao := Rect2i(coluna * 64, linha * 64, 64, 64)
				var base := corpo.get_region(regiao)
				var cabeca := cabelo.get_region(regiao).get_used_rect()
				if base.is_invisible() or cabeca.size == Vector2i.ZERO:
					continue
				var vestimenta := roupa.get_region(regiao)
				if bool(_config.get("substituir_cabeca", false)):
					var area := Rect2i(regiao.position + cabeca.position, Vector2i(cabeca.size.x, mini(13, 64 - cabeca.position.y)))
					corpo_visivel.fill_rect(area, Color.TRANSPARENT)
				var partes := _vestir_tecido(base, vestimenta, cabeca, linha % 4) if _config.get("modo_visual", "armadura") == "tecido" else _vestir(base, vestimenta, cabeca, linha % 4)
				var quadro := Image.create(64, 64, false, Image.FORMAT_RGBA8)
				for peca in ["peitoral", "botas", "luvas", "elmo"]:
					quadro.blend_rect(partes[peca], Rect2i(0, 0, 64, 64), Vector2i.ZERO)
					folhas_pecas[peca].blit_rect(partes[peca], Rect2i(0, 0, 64, 64), regiao.position)
				folha.blit_rect(quadro, Rect2i(0, 0, 64, 64), regiao.position)
				poses += 1
		if folha.save_png(_destino + pagina + ".png") != OK:
			quit(1)
			return
		if bool(_config.get("substituir_cabeca", false)):
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_destino + "corpo_sem_cabeca/"))
			corpo_visivel.save_png(_destino + "corpo_sem_cabeca/" + pagina + ".png")
		for peca in folhas_pecas:
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_destino + peca))
			folhas_pecas[peca].save_png(_destino + peca + "/" + pagina + ".png")
		print("Conjunto ", _config["id"], ": ", pagina, ", poses: ", poses)
	quit(0 if _gravar_definicao() and Acabamento.compilar_conjunto(_config) else 1)

func _gravar_definicao() -> bool:
	var cadastro := FileAccess.open(_destino + "definicao.gd", FileAccess.WRITE)
	if cadastro == null:
		push_error("Não foi possível gravar a definição do conjunto.")
		return false
	cadastro.store_string(Padrao.roteiro_definicao(_config))
	return true

func _preparar_pecas() -> bool:
	var fonte := Image.load_from_file(_config["arte"])
	if fonte == null or fonte.is_empty() or fonte.get_width() < 4:
		push_error("Conceito inválido: forneça as quatro vistas em uma linha.")
		return false
	var fonte_elmos: Image = null
	if _config.has("arte_elmo"):
		fonte_elmos = Image.load_from_file(_config["arte_elmo"])
		if fonte_elmos == null or fonte_elmos.is_empty():
			push_error("Folha de elmos inválida.")
			return false
	for i in 4:
		var x := roundi(i * fonte.get_width() / 4.0)
		var fim := roundi((i + 1) * fonte.get_width() / 4.0)
		var vista := fonte.get_region(Rect2i(x, 0, fim - x, fonte.get_height()))
		for y in vista.get_height():
			for u in vista.get_width():
				if vista.get_pixel(u, y).a < 0.5:
					vista.set_pixel(u, y, Color.TRANSPARENT)
		if vista.is_invisible():
			push_error("Vista vazia no conceito: " + str(i))
			return false
		vista = vista.get_region(vista.get_used_rect())
		var h := vista.get_height()
		var fim_elmo: float = _config["recortes"]["fim_elmo"]
		var fim_peitoral: float = _config["recortes"]["fim_peitoral"]
		var elmo := vista.get_region(Rect2i(0, 0, vista.get_width(), roundi(h * fim_elmo)))
		# Exclui ombreiras que entram na faixa vertical da cabeça em conceitos compactos.
		var largura_recorte := roundi(elmo.get_width() * float(_config["recortes"].get("fracao_largura_elmo", 1.0)))
		if largura_recorte < elmo.get_width():
			elmo = elmo.get_region(Rect2i((elmo.get_width() - largura_recorte) / 2, 0, largura_recorte, elmo.get_height()))
		# Chifres usam a largura superior; na gola retira pontas das ombreiras do conceito.
		var fracao_gola := float(_config["recortes"].get("fracao_gola_elmo", 1.0))
		var meia_gola := roundi(elmo.get_width() * fracao_gola * 0.5)
		for y in range(roundi(elmo.get_height() * 0.7), elmo.get_height()):
			for u in elmo.get_width():
				if absi(u - elmo.get_width() / 2) > meia_gola:
					elmo.set_pixel(u, y, Color.TRANSPARENT)
		if elmo.is_invisible():
			push_error("Recorte de elmo vazio na vista: " + str(i))
			return false
		elmo = elmo.get_region(elmo.get_used_rect())
		if _config.get("modo_visual", "armadura") == "tecido":
			# Cartola aberta: o recorte termina na aba, sem incorporar a face do conceito.
			elmo = vista.get_region(Rect2i(0, 0, vista.get_width(), roundi(h * float(_config["recortes"]["fim_cartola"]))))
			elmo = elmo.get_region(elmo.get_used_rect())
		if fonte_elmos != null:
			var inicio_elmo := roundi(i * fonte_elmos.get_width() / 4.0)
			var final_elmo := roundi((i + 1) * fonte_elmos.get_width() / 4.0)
			elmo = fonte_elmos.get_region(Rect2i(inicio_elmo, 0, final_elmo - inicio_elmo, fonte_elmos.get_height()))
			for v in elmo.get_height():
				for u in elmo.get_width():
					if elmo.get_pixel(u, v).a < 0.5:
						elmo.set_pixel(u, v, Color.TRANSPARENT)
			if elmo.is_invisible():
				push_error("Vista de elmo vazia: " + str(i))
				return false
			elmo = elmo.get_region(elmo.get_used_rect())
		elmo.resize(int(_config["recortes"].get("largura_elmo", 14)), int(_config["recortes"].get("altura_elmo", 17)), Image.INTERPOLATE_NEAREST)
		_quantizar(elmo)
		_elmos.append(elmo)
		var metade := elmo.get_height() / 2
		var chapa := elmo.get_region(Rect2i(0, metade, elmo.get_width(), elmo.get_height() - metade)).get_used_rect()
		_ancoras_elmo.append(chapa.get_center().x)
		var regiao_idle := Rect2i(0, i * 64, 64, 64)
		var cabelo_idle := Aparencia.cabelo(0, "andar").get_image().get_region(regiao_idle).get_used_rect()
		var corpo_idle: Image = load("res://assets/personagens/" + CORPOS["andar"]).get_image().get_region(regiao_idle)
		var face_idle := corpo_idle.get_region(Rect2i(cabelo_idle.position, Vector2i(cabelo_idle.size.x, 13))).get_used_rect()
		_deslocamentos_cabeca.append(face_idle.get_center().x - cabelo_idle.size.x / 2)
		# Chapéus se apoiam no crânio. Nariz e queixo não deslocam a copa nos perfis.
		var cranio := corpo_idle.get_region(Rect2i(cabelo_idle.position, Vector2i(cabelo_idle.size.x, 7))).get_used_rect()
		_deslocamentos_cranio.append(cranio.get_center().x - cabelo_idle.size.x / 2)
		var copa := elmo.get_region(Rect2i(0, 0, elmo.get_width(), maxi(1, roundi(elmo.get_height() * 0.6)))).get_used_rect()
		_ancoras_cartola.append(copa.get_center().x)
		var peito := vista.get_region(Rect2i(0, roundi(h * fim_elmo), vista.get_width(), roundi(h * (fim_peitoral - fim_elmo))))
		peito.resize(16, 11, Image.INTERPOLATE_NEAREST)
		_quantizar(peito)
		_peitorais.append(peito)
		var pernas := vista.get_region(Rect2i(0, roundi(h * fim_peitoral), vista.get_width(), h - roundi(h * fim_peitoral)))
		pernas.resize(14, 9, Image.INTERPOLATE_NEAREST)
		_quantizar(pernas)
		_grevas.append(pernas)
	if bool(_config["recortes"].get("elmo_rigido", false)):
		_preparar_elmos_rigidos()
	return true

## O suporte é calculado uma vez para todas as poses. O visor original fica por
## cima dele e nunca é esticado conforme braços ou corpo mudam de quadro.
func _preparar_elmos_rigidos() -> void:
	for d in 4:
		var fonte := _elmos[d]
		var imagem := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		var deslocamentos: Array = _config["recortes"].get("deslocamento_vertical_elmo", [0, 0, 0, 0])
		var posicao := Vector2i(32 + _deslocamentos_cabeca[d] - _ancoras_elmo[d], 33 - fonte.get_height() + int(deslocamentos[d]))
		if int(_config["recortes"].get("borda_calota", 0)) == 1:
			# Espessura do contorno das chapas, calculada uma vez. Não altera o visor.
			for y in range(fonte.get_height() / 3, fonte.get_height()):
				for x in fonte.get_width():
					if fonte.get_pixel(x, y).a > 0.5:
						for dy in range(-1, 2):
							for dx in range(-1, 2):
								imagem.set_pixel(posicao.x + x + dx, posicao.y + y + dy, Color.html(_paleta[0]))
		imagem.blend_rect(fonte, Rect2i(Vector2i.ZERO, fonte.get_size()), posicao)
		_elmos_rigidos.append(imagem)

func _quantizar(imagem: Image) -> void:
	for y in imagem.get_height():
		for x in imagem.get_width():
			var pixel := imagem.get_pixel(x, y)
			if pixel.a < 0.5:
				imagem.set_pixel(x, y, Color.TRANSPARENT)
				continue
			var menor := INF
			var melhor := Color.BLACK
			for html in _paleta:
				var cor := Color.html(html)
				var distancia := Vector3(pixel.r - cor.r, pixel.g - cor.g, pixel.b - cor.b).length_squared()
				if distancia < menor:
					menor = distancia
					melhor = cor
			imagem.set_pixel(x, y, melhor)

## O traje usa a silhueta animada da roupa nativa. Face e pescoço continuam
## na camada de corpo; a cartola acompanha a cabeça sem esticar seus pixels.
func _vestir_tecido(corpo: Image, roupa: Image, cabeca: Rect2i, direcao: int) -> Dictionary:
	var partes := {}
	for peca in Padrao.PECAS:
		partes[peca] = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var centro := cabeca.get_center().x
	var topo := cabeca.position.y + 13
	var fundo := topo + 10
	var peito := _peitorais[direcao]
	for y in 64:
		for x in 64:
			var original := roupa.get_pixel(x, y)
			var pele := corpo.get_pixel(x, y)
			var na_cabeca := y < topo and x >= cabeca.position.x and x < cabeca.end.x
			# Não recolorir a face nem inserir a face do modelo gerado.
			if original.a < 0.5 and (pele.a < 0.5 or na_cabeca):
				continue
			var brilho := (original.r + original.g + original.b) / 3.0
			var tom := 0 if brilho < 0.18 else (1 if brilho < 0.4 else (2 if brilho < 0.65 else 3))
			var peca := "peitoral"
			var cor := Color.html(_paleta[tom])
			if y >= fundo:
				peca = "botas"
				if y >= corpo.get_used_rect().end.y - 4:
					cor = Color.html(_paleta[6 if brilho < 0.4 else (7 if brilho < 0.7 else 8)])
			elif original.a < 0.5:
				peca = "luvas"
				# O molde de camponês tem braços descobertos. Estender as mangas do
				# casaco perto do tecido; só a extremidade recebe a luva clara.
				var perto_manga := false
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var vizinho := Vector2i(x + dx, y + dy)
						if Rect2i(0, 0, 64, 64).has_point(vizinho) and roupa.get_pixelv(vizinho).a > 0.5:
							perto_manga = true
				cor = Color.html(_paleta[2 if perto_manga else 5])
			elif y >= topo + 3 and abs(x - centro) > 4:
				peca = "luvas"
			elif y >= topo and y < fundo and abs(x - centro) <= 4:
				var amostra := peito.get_pixel(clampi(x - centro + 8, 0, 15), clampi(y - topo, 0, 10))
				if amostra.a > 0.5:
					cor = amostra
			partes[peca].set_pixel(x, y, cor)
	var cartola := _elmos[direcao]
	var encaixe := int(_config["recortes"].get("encaixe_cartola", 4))
	var posicao := Vector2i(centro + _deslocamentos_cranio[direcao] - _ancoras_cartola[direcao], cabeca.position.y + encaixe - cartola.get_height())
	partes["elmo"].blend_rect(cartola, Rect2i(Vector2i.ZERO, cartola.get_size()), posicao)
	for y in 64:
		for x in 64:
			if partes["elmo"].get_pixel(x, y).a > 0.5:
				for peca in ["peitoral", "luvas", "botas"]:
					partes[peca].set_pixel(x, y, Color.TRANSPARENT)
	return partes

func _vestir(corpo: Image, roupa: Image, cabeca: Rect2i, direcao: int) -> Dictionary:
	var partes := {}
	for peca in ["elmo", "peitoral", "luvas", "botas"]:
		partes[peca] = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var centro := cabeca.position.x + cabeca.size.x / 2
	var topo := cabeca.position.y + 13
	var fundo := topo + 10
	var peito := _peitorais[direcao]
	var pernas := _grevas[direcao]
	var base_pes := corpo.get_used_rect().end.y - 1
	# As extremidades seguem exatamente os pixels de cada pose, inclusive os punhos.
	for y in 64:
		for x in 64:
			var pele := corpo.get_pixel(x, y)
			var tecido := roupa.get_pixel(x, y)
			if pele.a < 0.5 and tecido.a < 0.5:
				continue
			var original := tecido if tecido.a > 0.5 else pele
			var brilho := (original.r + original.g + original.b) / 3.0
			var tom := 0 if brilho < 0.15 else (2 if brilho < 0.4 else (3 if brilho < 0.6 else (4 if brilho < 0.8 else 5)))
			var cor := Color.html(_paleta[tom])
			if y >= topo and y <= fundo and abs(x - centro) <= 7 and brilho >= 0.15:
				var amostra := peito.get_pixel(clampi(x - centro + 8, 0, 15), clampi(y - topo, 0, 10))
				if amostra.a > 0.5:
					cor = amostra
			# Couro entre a placa abdominal e as grevas, sem tingir os pés de marrom.
			elif y > fundo and y <= fundo + 2:
				cor = Color.html(_paleta[9 if brilho < 0.6 else 10])
			elif y > fundo + 2 and brilho >= 0.15:
				var v := clampi(roundi((y - fundo - 3) * 8.0 / maxf(base_pes - fundo - 3, 1)), 0, 8)
				var amostra := pernas.get_pixel(clampi(x - centro + 7, 0, 13), v)
				if amostra.a > 0.5:
					cor = amostra
			var peca := "peitoral"
			var dentro_cabeca := y >= cabeca.position.y and y < topo and x >= cabeca.position.x and x < cabeca.end.x
			if dentro_cabeca and bool(_config["recortes"].get("elmo_rigido", false)):
				# Mãos e braços que passam perto da face continuam pertencendo às luvas.
				dentro_cabeca = _elmos_rigidos[direcao].get_pixel(x - centro + 32, y - topo + 32).a > 0.5
			if dentro_cabeca:
				if bool(_config.get("substituir_cabeca", false)):
					continue
				peca = "elmo"
			elif pele.a > 0.5 and tecido.a < 0.5 and y < fundo + 2:
				peca = "luvas"
			elif y >= fundo + 2:
				peca = "botas"
			elif y >= topo + 4 and abs(x - centro) > 4:
				peca = "luvas"
			partes[peca].set_pixel(x, y, cor)
	# O elmo acompanha o deslocamento da cabeça (inclusive o balanço da corrida).
	var elmo: Image = _elmos[direcao].duplicate()
	var posicao := Vector2i(centro - elmo.get_width() / 2, topo + 1 - elmo.get_height())
	# Chifres assimétricos deslocam o centro do recorte nos perfis. Alinha pela
	# calota na metade inferior, não pela largura total dos enfeites.
	var rigido := bool(_config["recortes"].get("elmo_rigido", false))
	if rigido:
		posicao.x = centro + _deslocamentos_cabeca[direcao] - _ancoras_elmo[direcao]
	elif bool(_config["recortes"].get("alinhar_calota", false)):
		var inicio := elmo.get_height() / 2
		var calota := elmo.get_region(Rect2i(0, inicio, elmo.get_width(), elmo.get_height() - inicio)).get_used_rect()
		var regiao_cabeca := Rect2i(cabeca.position, Vector2i(cabeca.size.x, mini(cabeca.size.y, topo - cabeca.position.y)))
		var cabeca_real := corpo.get_region(regiao_cabeca).get_used_rect()
		if calota.size.x > 0 and cabeca_real.size.x > 0:
			posicao.x = regiao_cabeca.position.x + cabeca_real.get_center().x - calota.get_center().x
	var silhueta := corpo.get_used_rect()
	if not rigido and silhueta.size.x > silhueta.size.y * 1.35:
		elmo.rotate_90(CLOCKWISE if direcao == 2 else COUNTERCLOCKWISE)
		posicao = cabeca.get_center() - elmo.get_size() / 2
	# A cabeça fica coberta por uma base opaca mesmo onde o recorte do elmo é vazio.
	if not rigido:
		for y in range(maxi(cabeca.position.y, 0), mini(topo, 64)):
			for x in range(maxi(cabeca.position.x, 0), mini(cabeca.end.x, 64)):
				if corpo.get_pixel(x, y).a > 0.5:
					partes["elmo"].set_pixel(x, y, Color.html(_paleta[2]))
	if rigido:
		partes["elmo"].fill(Color.TRANSPARENT)
		partes["elmo"].blit_rect(_elmos_rigidos[direcao], Rect2i(0, 0, 64, 64), Vector2i(centro - 32, topo - 32))
	elif bool(_config["recortes"].get("ajustar_calota_corpo", false)):
		var ajustado := _ajustar_calota(elmo, corpo, cabeca, posicao, topo)
		partes["elmo"].blend_rect(ajustado, Rect2i(0, 0, 64, 64), Vector2i.ZERO)
	else:
		partes["elmo"].blend_rect(elmo, Rect2i(Vector2i.ZERO, elmo.get_size()), posicao)
	# Cada pixel pertence a uma única peça, inclusive nos cruzamentos da gola.
	for y in 64:
		for x in 64:
			if partes["elmo"].get_pixel(x, y).a > 0.5:
				for peca in ["peitoral", "luvas", "botas"]:
					partes[peca].set_pixel(x, y, Color.TRANSPARENT)
	return partes

## Mantém os chifres acima da cabeça e ajusta as chapas à silhueta nativa.
## A cabeça não pode depender de um preenchimento cinza plano fora do desenho.
func _ajustar_calota(elmo: Image, corpo: Image, cabeca: Rect2i, posicao: Vector2i, topo: int) -> Image:
	var resultado := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	resultado.blit_rect(elmo, Rect2i(Vector2i.ZERO, elmo.get_size()), posicao)
	var original := resultado.duplicate()
	for y in range(maxi(cabeca.position.y, 0), mini(topo, 64)):
		var esquerda := 64
		var direita := -1
		for x in range(maxi(cabeca.position.x, 0), mini(cabeca.end.x, 64)):
			if corpo.get_pixel(x, y).a > 0.5:
				esquerda = mini(esquerda, x)
				direita = maxi(direita, x)
		if direita < esquerda:
			continue
		var faixa := _faixa_calota(original, y)
		var linha_fonte := y
		if faixa.y <= 0:
			for distancia in range(1, 64):
				for candidata in [y - distancia, y + distancia]:
					if candidata < 0 or candidata >= 64:
						continue
					faixa = _faixa_calota(original, candidata)
					if faixa.y > 0:
						linha_fonte = candidata
						break
				if faixa.y > 0:
					break
			if faixa.y <= 0:
				continue
		# Contorno de um pixel ao redor da cabeça, com os tons reais da chapa.
		esquerda = maxi(esquerda - 1, 0)
		direita = mini(direita + 1, 63)
		# Preserva os chifres e suas conexões fora da região da cabeça.
		for x in range(esquerda, direita + 1):
			var u := mini(faixa.y - 1, int((x - esquerda) * faixa.y / float(direita - esquerda + 1)))
			resultado.set_pixel(x, y, original.get_pixel(faixa.x + u, linha_fonte))
	return resultado

## A maior faixa opaca é a chapa; pontas isoladas não deslocam seu centro.
func _faixa_calota(imagem: Image, y: int) -> Vector2i:
	var melhor := Vector2i.ZERO
	var inicio := -1
	for x in 65:
		var opaco := x < 64 and imagem.get_pixel(x, y).a > 0.5
		if opaco and inicio < 0:
			inicio = x
		elif not opaco and inicio >= 0:
			if x - inicio > melhor.y:
				melhor = Vector2i(inicio, x - inicio)
			inicio = -1
	return melhor
