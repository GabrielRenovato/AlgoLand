extends SceneTree

## --script ferramentas/armaduras/validar_conjunto.gd -- res://caminho/manifesto.json
const Padrao := preload("res://codigo/dados/padrao_armadura.gd")
const Aparencia := preload("res://codigo/dados/aparencia.gd")
const Acabamento := preload("res://codigo/dados/acabamento_refinado.gd")
var _falhas := 0

func _verificar(nome: String, condicao: bool) -> void:
	print("OK " if condicao else "FALHA ", nome)
	if not condicao:
		_falhas += 1

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var caminho: String = args[0] if not args.is_empty() else "res://ferramentas/armaduras/modelos/carrasco.json"
	var config := Padrao.carregar(caminho)
	var erros := Padrao.validar(config)
	if not erros.is_empty():
		for erro in erros:
			push_error(erro)
		quit(1)
		return
	var raiz: String = config["destino"]
	var cores := {}
	for html in config["paleta"]:
		cores[String(html).to_lower()] = true
	var paginas := Padrao.CORPOS.duplicate()
	if "--pesca" in args:
		paginas = {"pesca": "Pesca/corpo.png"}
	for pagina in paginas:
		var imagens: Array[Image] = []
		var completa := _ler(raiz + pagina + ".png")
		for peca in Padrao.PECAS:
			imagens.append(_ler(raiz + peca + "/" + pagina + ".png"))
		if completa == null or imagens.has(null):
			continue
		var corpo: Image = load("res://assets/personagens/" + paginas[pagina]).get_image()
		var corpo_original := corpo
		var cobertura_exigida := corpo.duplicate()
		if config.get("modo_visual", "armadura") == "tecido":
			# A face exposta continua no corpo original. Validar a vestimenta abaixo dela.
			var cabelo_tecido := Aparencia.cabelo(1, pagina).get_image()
			for linha in 8:
				for coluna in 8:
					var regiao := Rect2i(coluna * 64, linha * 64, 64, 64)
					var cabeca := cabelo_tecido.get_region(regiao).get_used_rect()
					if cabeca.size != Vector2i.ZERO:
						# Na esquiva de costas, a testa nativa sobe um pixel acima do cabelo.
						cobertura_exigida.fill_rect(Rect2i(regiao.position + cabeca.position - Vector2i(0, 1), Vector2i(cabeca.size.x, 14)), Color.TRANSPARENT)
		if bool(config.get("substituir_cabeca", false)):
			corpo = _ler(raiz + "corpo_sem_cabeca/" + pagina + ".png")
			if corpo == null:
				continue
			var esperado: Image = corpo_original.duplicate()
			var cabelos := Aparencia.cabelo(0, pagina).get_image()
			for linha in 8:
				for coluna in 8:
					var regiao := Rect2i(coluna * 64, linha * 64, 64, 64)
					var cabeca := cabelos.get_region(regiao).get_used_rect()
					if cabeca.size != Vector2i.ZERO:
						esperado.fill_rect(Rect2i(regiao.position + cabeca.position, Vector2i(cabeca.size.x, mini(13, 64 - cabeca.position.y))), Color.TRANSPARENT)
			var correto := true
			for y in 512:
				for x in 512:
					var a := corpo.get_pixel(x, y)
					var b := esperado.get_pixel(x, y)
					if a.a != b.a or (a.a > 0.0 and a != b):
						correto = false
			_verificar(pagina + ": corpo preservado, somente a cabeça substituída", correto)
			cobertura_exigida = corpo
		var cobertura := true
		var exclusivas := true
		var recomposta := true
		var nitida := true
		var sem_poses_fantasmas := true
		var cartolas_inteiras := true
		for y in 512:
			for x in 512:
				var cor := completa.get_pixel(x, y)
				if cobertura_exigida.get_pixel(x, y).a > 0.5 and cor.a < 0.5:
					cobertura = false
				var quantidade := 0
				var encontrada := Color.TRANSPARENT
				for imagem in imagens:
					var pixel := imagem.get_pixel(x, y)
					if pixel.a > 0.5:
						quantidade += 1
						encontrada = pixel
					if pixel.a != 0.0 and pixel.a != 1.0:
						nitida = false
				if quantidade > 1:
					exclusivas = false
				if cor.a != encontrada.a or (cor.a > 0.5 and cor != encontrada):
					recomposta = false
				if (cor.a != 0.0 and cor.a != 1.0) or (cor.a > 0.5 and not cores.has(cor.to_html(false))):
					nitida = false
		for linha in 8:
			for coluna in 8:
				var regiao := Rect2i(coluna * 64, linha * 64, 64, 64)
				if corpo_original.get_region(regiao).is_invisible() and not completa.get_region(regiao).is_invisible():
					sem_poses_fantasmas = false
				if config.get("modo_visual", "armadura") == "tecido" and not corpo_original.get_region(regiao).is_invisible():
					var cartola := imagens[0].get_region(regiao).get_used_rect()
					if cartola.size.y != int(config["recortes"]["altura_elmo"]):
						cartolas_inteiras = false
		_verificar(pagina + ": cobre o corpo em todas as poses", cobertura)
		_verificar(pagina + ": cada pixel pertence a uma peça", exclusivas)
		_verificar(pagina + ": quatro peças recompõem o conjunto", recomposta)
		_verificar(pagina + ": paleta nativa e alfa sem suavização", nitida)
		_verificar(pagina + ": não inventa poses nas células vazias", sem_poses_fantasmas)
		if config.get("modo_visual", "armadura") == "tecido":
			_verificar(pagina + ": copa e aba inteiras, sem corte na borda do quadro", cartolas_inteiras)
	var cabelo := _ler(raiz + "cabelo_oculto.png")
	_verificar("camada para ocultar cabelo é transparente", cabelo != null and cabelo.is_invisible())
	var cadastro: String = raiz + "definicao.gd"
	_verificar("cadastro gerado existe", FileAccess.file_exists(cadastro))
	if FileAccess.file_exists(cadastro):
		var definicao = load(cadastro)
		_verificar("cadastro gerado compila", definicao is GDScript and definicao.can_instantiate())
		if definicao is GDScript and definicao.can_instantiate():
			_verificar("cadastro contém as quatro peças", definicao.TIPOS.size() == 4)
			_verificar("cadastro corresponde ao manifesto", definicao.ID == config["id"] and definicao.RARIDADE == config["raridade"] and definicao.ONDA_MINIMA == int(config["onda_minima"]))
	if "--acabamento" in args:
		var erros_acabamento := Acabamento.validar_conjunto(config)
		for erro in erros_acabamento:
			_verificar(erro,false)
		_verificar("11 páginas refinadas: cobertura, peças independentes e recomposição exata",erros_acabamento.is_empty())
	print("Falhas: ", _falhas)
	quit(_falhas)

func _ler(caminho: String) -> Image:
	if not FileAccess.file_exists(caminho):
		_verificar("arquivo existe: " + caminho, false)
		return null
	var imagem := Image.load_from_file(caminho)
	var valido := imagem != null and imagem.get_size() == Padrao.TAMANHO_FOLHA
	_verificar("grade 512x512: " + caminho, valido)
	return imagem if valido else null
