extends SceneTree

# Cena mínima para conferir a caminhada real e a mordida, sem carregar a partida.
var _falhas := 0

class JogadorTeste extends Node2D:
	var invulneravel := true
	var estaMorto := false
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
	var cena: PackedScene = load("res://cenas/inimigos/gremlin.tscn")
	for mutante in [false, true]:
		var inimigo: Node2D = cena.instantiate()
		if mutante:
			inimigo.tornar_mutante()
		arena.add_child(inimigo)
		var prefixo := "mutante" if mutante else "normal"
		# A folha original reserva as quatro primeiras colunas para idle e as quatro últimas para andar.
		for caso in [[Vector2.DOWN, 4], [Vector2.UP, 12], [Vector2.RIGHT, 20], [Vector2.LEFT, 20]]:
			inimigo.position = Vector2.ZERO
			inimigo.velocity = Vector2.ZERO
			inimigo._quadro = 0.0
			jogador.position = caso[0] * 400.0
			var distancia_inicial: float = inimigo.position.distance_to(jogador.position)
			var vistos := {}
			var quadros_corretos := true
			var sprite: Sprite2D = inimigo.get_node("Texture")
			for i in 50:
				await physics_frame
				vistos[sprite.frame] = true
				quadros_corretos = quadros_corretos and sprite.frame >= caso[1] and sprite.frame <= caso[1] + 3
			_verificar(prefixo + " persegue em " + str(caso[0]), inimigo.position.distance_to(jogador.position) < distancia_inicial - 20.0)
			_verificar(prefixo + " anima caminhada em " + str(caso[0]), quadros_corretos and vistos.size() == 4)
			if caso[0].x != 0:
				_verificar(prefixo + " espelha o lado corretamente", sprite.flip_h == (caso[0].x < 0))
		# Deixa a animação avançar enquanto a física de perseguição está desativada.
		inimigo.set_physics_process(false)
		for caso in [[Vector2.DOWN, 28], [Vector2.UP, 36], [Vector2.RIGHT, 44]]:
			inimigo.pode_atacar = true
			inimigo._iniciar_ataque(caso[0])
			var quadros_corretos := true
			for i in 3:
				inimigo._animar(1.0 / inimigo.fps_ataque)
				quadros_corretos = quadros_corretos and inimigo.sprite.frame == caso[1] + mini(i + 1, 2)
			_verificar(prefixo + " usa mordida da direção " + str(caso[0]), quadros_corretos)
			await create_timer(0.4).timeout
		inimigo.free()
	print("Falhas: ", _falhas)
	quit(_falhas)
