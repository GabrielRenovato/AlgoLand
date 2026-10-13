extends SceneTree

class Alvo extends Node2D:
	var estaMorto := false
	var invulneravel := true
	func receber_dano(_dano: int, _forca: Vector2) -> void:
		pass

var falhas := 0

func _initialize() -> void:
	_rodar()

func verificar(nome: String, condicao: bool) -> void:
	print("OK " if condicao else "FALHA ", nome)
	if not condicao:
		falhas += 1

func _rodar() -> void:
	await process_frame
	if not OS.get_user_data_dir().ends_with("AlgoLand testes Carrasco"):
		quit(1)
		return
	var palco := Node2D.new()
	root.add_child(palco)
	current_scene = palco
	var alvo := Alvo.new()
	alvo.name = "Jogador"
	alvo.position = Vector2(45, 0)
	palco.add_child(alvo)
	var parede := StaticBody2D.new()
	parede.collision_layer = 64
	parede.position = Vector2(24, 0)
	var colisor := CollisionShape2D.new()
	var forma := RectangleShape2D.new()
	forma.size = Vector2(8, 40)
	colisor.shape = forma
	parede.add_child(colisor)
	palco.add_child(parede)
	var geometria := NavigationMeshSourceGeometryData2D.new()
	geometria.add_traversable_outline(PackedVector2Array([Vector2(-200, -200), Vector2(200, -200), Vector2(200, 200), Vector2(-200, 200)]))
	geometria.add_obstruction_outline(PackedVector2Array([Vector2(20, -20), Vector2(28, -20), Vector2(28, 20), Vector2(20, 20)]))
	var malha := NavigationPolygon.new()
	malha.agent_radius = 21
	NavigationServer2D.bake_from_source_geometry_data(malha, geometria)
	var regiao := NavigationRegion2D.new()
	regiao.navigation_layers = 3
	regiao.navigation_polygon = malha
	palco.add_child(regiao)
	for tipo in ["minotauro", "dragao_vermelho"]:
		var chefe = load("res://cenas/inimigos/" + tipo + ".tscn").instantiate()
		palco.add_child(chefe)
		chefe.set_physics_process(false)
		chefe._recarga = 0
		var raio: float = chefe.raio_parada
		await physics_frame
		await physics_frame
		verificar(tipo + " reproduz perto com parede bloqueando", chefe.global_position.distance_to(alvo.global_position) < raio and not chefe._caminho_livre(alvo.global_position))
		var atacou := false
		var maior_deslocamento := 0.0
		for quadro in 360:
			await physics_frame
			chefe._physics_process(1.0 / 60)
			maior_deslocamento = maxf(maior_deslocamento, chefe.position.length())
			if chefe.estado != chefe.Estado.LIVRE:
				atacou = true
				break
		verificar(tipo + " contorna obstáculo e retoma ataque", atacou and maior_deslocamento > 10)
		verificar(tipo + " preserva raio normal de parada", chefe.raio_parada == raio)
		if tipo == "minotauro":
			chefe._limpar_efeitos()
			chefe.global_position = Vector2.ZERO
			chefe._furia_usada = true
			chefe._furia_ativa = true
			chefe._fila_furia.assign(["pisao_furia"])
			chefe._executar_furia()
			verificar("pisão pendente volta para perseguir", chefe.estado == chefe.Estado.LIVRE and chefe._fila_furia.size() == 1 and not chefe.esta_atacando)
			var terminou_aproximacao := false
			for quadro in 360:
				await physics_frame
				chefe._physics_process(1.0 / 60)
				if chefe.estado == chefe.Estado.PREPARANDO:
					terminou_aproximacao = chefe.ataque_atual == "pisao_furia"
					break
			verificar("pisão pendente não prende chefe na parede", terminou_aproximacao)
		chefe.queue_free()
		await process_frame
	palco.queue_free()
	await process_frame
	print("Falhas: ", falhas)
	quit(falhas)
