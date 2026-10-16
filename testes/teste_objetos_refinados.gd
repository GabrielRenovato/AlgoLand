extends SceneTree
const Objetos := preload("res://codigo/dados/objetos_refinados.gd")
const Equipamentos := preload("res://codigo/dados/equipamentos.gd")
const Flecha := preload("res://codigo/jogador/flecha.gd")
var falhas := 0
var verificacoes := 0

func _initialize() -> void:
	_rodar()

func _verificar(nome: String, condicao: bool) -> void:
	verificacoes += 1
	if not condicao:
		falhas += 1
		print("FALHA ",nome)

func _escala(sprite: Sprite2D) -> bool:
	return sprite.texture != null and sprite.scale == Vector2(0.5,0.5) and sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST

func _rodar() -> void:
	if ProjectSettings.get_setting("application/config/name") != "AlgoLand testes Carrasco":
		push_error("Execute com saves isolados.")
		quit(1)
		return
	await process_frame
	var manifesto: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Objetos.RAIZ+"manifesto.json"))
	for fonte in manifesto:
		var nativa: Texture2D = load(fonte)
		var sprite := Sprite2D.new()
		sprite.position = Vector2(7,-2)
		sprite.rotation = 0.8
		sprite.flip_h = true
		Objetos.aplicar(sprite,nativa)
		_verificar("resolução dupla",sprite.texture.get_size() == nativa.get_size()*2)
		_verificar("escala e filtro",_escala(sprite))
		_verificar("encaixe mantém transformação",sprite.position == Vector2(7,-2) and is_equal_approx(sprite.rotation,0.8) and sprite.flip_h)
		var textura := sprite.texture
		Objetos.aplicar(sprite,textura)
		_verificar("não duplica acabamento/escala",sprite.texture == textura and sprite.scale == Vector2(0.5,0.5))
		sprite.free()
		Objetos._cache.clear()
		Objetos._refinadas.clear()
	var arena: Node = load("res://cenas/cenario.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	await process_frame
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	var jogador: Node = arena.get_node("Jogador")
	for id in ["espada_basica","espada_gemea","machado","maca"]:
		jogador.id_arma_atual = id
		jogador.atualizar_texturas_espada()
		_verificar("arma de uma mão no jogador",_escala(jogador.sprite_espada) and _escala(jogador.braco_espada_ataque))
	jogador.atualizar_texturas_lanca()
	_verificar("lança no jogador",_escala(jogador.sprite_lanca) and _escala(jogador.braco_lanca_ataque))
	jogador.atualizar_texturas_escudo()
	_verificar("escudo no jogador",_escala(jogador.sprite_escudo) and _escala(jogador.escudo_ataque))
	for id in ["arco_curto","arco_curvo","arco_longo"]:
		jogador.id_arco_atual = id
		jogador.atualizar_texturas_arco()
		jogador.no_arco.disparar(Vector2.RIGHT,1)
		_verificar("arco e aljava no disparo",_escala(jogador.no_arco._arco) and _escala(jogador.no_arco._aljava) and _escala(jogador.sprite_escudo))
		jogador.no_arco.parar_disparo()
	for id in Equipamentos.FAMILIAS:
		if id == "escudo_basico": continue
		var familia: String = Equipamentos.FAMILIAS[id]
		if familia == "espada": familia = "um_mao"
		for nivel in range(1,6):
			for direcao in [Vector2.DOWN,Vector2.UP,Vector2.RIGHT,Vector2.LEFT]:
				jogador.no_reacao.tocar("aparar",direcao,familia,id,nivel,5 if familia == "um_mao" else 0)
				_verificar("pose mantém arma refinada",_escala(jogador.no_reacao._arma))
				if familia == "um_mao":
					_verificar("pose mantém escudo refinado",_escala(jogador.no_reacao._escudo))
				jogador.no_reacao.encerrar()
	for acao in jogador.no_fazenda.ACOES:
		for direcao in [Vector2.DOWN,Vector2.UP,Vector2.RIGHT,Vector2.LEFT]:
			jogador.no_fazenda.tocar(acao,direcao)
			_verificar("ferramenta usa resolução dupla",_escala(jogador.no_fazenda._ferramenta))
			for indice in jogador.no_fazenda._quadros.size():
				jogador.no_fazenda._indice = indice
				jogador.no_fazenda._aplicar_quadro()
				_verificar("ferramenta segue a pose",jogador.no_fazenda._ferramenta.frame == jogador.no_fazenda._corpo.frame)
			jogador.no_fazenda.parar()
	_verificar("marreta refinada",_escala(jogador.get_node("CompositeSprites/Forja/Arm")))
	var flecha := Flecha.new()
	var desenho: Sprite2D
	for filho in flecha.get_children():
		if filho is Sprite2D: desenho = filho
	_verificar("flecha conserva tamanho",desenho.texture.get_size()*desenho.scale == Flecha.TEXTURA.get_size())
	_verificar("flecha conserva colisão",flecha.get_child(0).shape.radius == 3)
	flecha.free()
	arena.queue_free()
	current_scene = null
	await process_frame
	print("Verificações: %d; falhas: %d" % [verificacoes,falhas])
	quit(falhas)
