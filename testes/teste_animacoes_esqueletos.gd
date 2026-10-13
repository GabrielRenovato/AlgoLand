extends SceneTree

# Cena mínima para validar as três folhas novas, movimento, ataque e morte, sem carregar a partida.
var _falhas := 0

class JogadorTeste extends Node2D:
	var invulneravel := true
	func receber_dano(_dano: int, _forca: Vector2) -> void:
		pass

func _initialize() -> void:
	_rodar()

func _verificar(nome: String, condicao: bool) -> void:
	print("OK " if condicao else "FALHA ", nome)
	if not condicao:
		_falhas += 1

func _rodar() -> void:
	await process_frame
	var arena := Node2D.new()
	root.add_child(arena)
	current_scene = arena
	var jogador := JogadorTeste.new()
	jogador.name = "Jogador"
	arena.add_child(jogador)
	for caso_tipo in [["guerreiro", false], ["arqueiro", false], ["mago", false], ["guerreiro", true], ["arqueiro", true], ["mago", true]]:
		var cena: PackedScene = load("res://cenas/inimigos/esqueleto_%s.tscn" % caso_tipo[0])
		var mutante: bool = caso_tipo[1]
		var inimigo: Node2D = cena.instantiate()
		if mutante:
			inimigo.tornar_mutante()
		arena.add_child(inimigo)
		var prefixo: String = caso_tipo[0] + (" mutante" if mutante else " normal")
		var imagem: Image = inimigo.get_node("Texture").texture.get_image()
		var quadros_validos := imagem.get_size() == Vector2i(384, 448) and imagem.get_pixel(0, 0).a == 0.0
		for quadro in 42:
			var recorte := imagem.get_region(Rect2i((quadro % 6) * 64, (quadro / 6) * 64, 64, 64))
			quadros_validos = quadros_validos and not recorte.is_invisible()
		_verificar(prefixo + " tem grid de 42 células de 64px com transparência", quadros_validos)
		for caso in [[Vector2.DOWN, 0], [Vector2.UP, 6], [Vector2.RIGHT, 12], [Vector2.LEFT, 12]]:
			inimigo.position = Vector2.ZERO
			inimigo.velocity = Vector2.ZERO
			inimigo._quadro = 0.0
			jogador.position = caso[0] * 400.0
			var distancia_inicial: float = inimigo.position.distance_to(jogador.position)
			var vistos := {}
			var quadros_corretos := true
			var sprite: Sprite2D = inimigo.get_node("Texture")
			for i in 110:
				await physics_frame
				vistos[sprite.frame] = true
				quadros_corretos = quadros_corretos and sprite.frame >= caso[1] and sprite.frame <= caso[1] + 5
			_verificar(prefixo + " persegue em " + str(caso[0]), inimigo.position.distance_to(jogador.position) < distancia_inicial - 20.0)
			_verificar(prefixo + " anima caminhada em " + str(caso[0]), quadros_corretos and vistos.size() == 6)
			if caso[0].x != 0:
				_verificar(prefixo + " espelha o lado corretamente", sprite.flip_h == (caso[0].x < 0))
		# Deixa a animação avançar enquanto a física de perseguição está desativada.
		inimigo.set_physics_process(false)
		for caso in [[Vector2.DOWN, 18], [Vector2.UP, 24], [Vector2.RIGHT, 30]]:
			inimigo.pode_atacar = true
			inimigo._iniciar_ataque(caso[0])
			var quadros_corretos := true
			for i in 4:
				inimigo._animar(1.0 / inimigo.fps_ataque)
				quadros_corretos = quadros_corretos and inimigo.sprite.frame == caso[1] + mini(i + 1, 3)
			_verificar(prefixo + " anima ataque na direção " + str(caso[0]), quadros_corretos)
			await create_timer(0.75).timeout
		inimigo.set_physics_process(true)
		var mortes := [0]
		inimigo.inimigo_morreu.connect(func(): mortes[0] += 1)
		inimigo.morrer()
		await create_timer(0.7).timeout
		_verificar(prefixo + " chega ao último quadro da queda", is_instance_valid(inimigo) and inimigo.sprite.frame == 39)
		await create_timer(0.2).timeout
		_verificar(prefixo + " conclui a morte e sinaliza a onda uma vez", not is_instance_valid(inimigo) and mortes[0] == 1)
	print("Falhas: ", _falhas)
	quit(_falhas)
