extends SceneTree

# Rodar: godot --headless --path . --script res://arquivo/tiny/testes/teste_inimigos_tiny.gd
# Cena mínima: não carrega a partida nem altera o inventário/saves do jogador.
const TIPOS := ["slime_grande", "miconide", "goblin_lanceiro", "goblin_arqueiro", "goblin_bombardeiro", "espinhento"]
var _falhas := 0
var _arena: Node2D
var _jogador: AlvoTeste

class AlvoTeste extends Node2D:
	var invulneravel := false
	var dano_recebido := 0
	func receber_dano(dano: int, _forca: Vector2) -> void:
		dano_recebido += dano

class GerenciadorTeste extends Node:
	var gerador: Node
	var onda_atual := 3
	var ondas_paradas := false
	var mortes := 0
	func inimigo_morreu() -> void:
		mortes += 1

func _initialize() -> void:
	_rodar()

func _verificar(nome: String, condicao: bool) -> void:
	print("OK " if condicao else "FALHA ", nome)
	if not condicao:
		_falhas += 1

func _rodar() -> void:
	await process_frame
	_arena = Node2D.new()
	_arena.name = "cenario"
	root.add_child(_arena)
	current_scene = _arena
	_jogador = AlvoTeste.new()
	_jogador.name = "Jogador"
	_jogador.position = Vector2(500, 500)
	_arena.add_child(_jogador)
	var area := Area2D.new()
	area.collision_layer = 2
	area.collision_mask = 0
	var colisao := CollisionShape2D.new()
	var forma := CircleShape2D.new()
	forma.radius = 8.0
	colisao.shape = forma
	area.add_child(colisao)
	_jogador.add_child(area)
	var spawner: Node = load("res://codigo/logica/slime_spawner.gd").new()
	var vistos := {}
	var pools_ok := true
	for onda in range(1, 121):
		var pool: Array = spawner.obter_pool_especies(onda)
		pools_ok = pools_ok and (pool.size() == 1 or (pool.size() == 3 and pool.all(func(c): return c.resource_path.get_file().begins_with("esqueleto_"))))
		for cena in pool:
			vistos[cena.resource_path.get_file().get_basename()] = true
	_verificar("ondas misturam somente as três classes de esqueleto", pools_ok)
	_verificar("flor venenosa imóvel fica fora das ondas e ciclos", not vistos.has("flor_venenosa"))
	_verificar("slimes pequenos e com broto ficam fora das ondas e ciclos", not vistos.has("slime_pequeno") and not vistos.has("slime_tiny") and not vistos.has("slime_broto"))
	for tipo in TIPOS:
		_verificar(tipo + " fica fora das ondas e ciclos", not vistos.has(tipo))
		var inimigo: Node2D = load("res://cenas/inimigos/" + tipo + ".tscn").instantiate()
		var vida_base: int = inimigo.vida
		inimigo.tornar_mutante()
		_verificar(tipo + " aceita variante mutante", inimigo.eh_mutante and inimigo.vida > vida_base)
		_arena.add_child(inimigo)
		inimigo.set_physics_process(false)
		var sprite: Sprite2D = inimigo.get_node("Texture")
		var quadros_ok := true
		for textura in inimigo.texturas:
			quadros_ok = quadros_ok and textura.get_width() / 8 == textura.get_height() / 12
		for direcao in [Vector2.DOWN, Vector2.UP, Vector2.RIGHT, Vector2.LEFT]:
			inimigo.definir_direcao_animacao(direcao)
			for estado in ["andar", "ataque", "morte"]:
				inimigo._estado = estado
				for quadro in range(12):
					inimigo._quadro = quadro
					inimigo._aplicar_quadro()
					var imagem := sprite.texture.get_image()
					var tamanho := imagem.get_width() / 8
					var recorte := imagem.get_region(Rect2i((sprite.frame % 8) * tamanho, (sprite.frame / 8) * tamanho, tamanho, tamanho))
					quadros_ok = quadros_ok and not recorte.is_invisible()
		_verificar(tipo + " anima todas as direções sem quadros vazios", quadros_ok)
		inimigo._estado = "andar"
		inimigo.set_physics_process(true)
		var mortes := [0]
		inimigo.inimigo_morreu.connect(func(): mortes[0] += 1)
		inimigo.receber_dano(99999)
		await create_timer(1.1).timeout
		_verificar(tipo + " morre, sinaliza a onda e sai da cena", mortes[0] == 1 and not is_instance_valid(inimigo))
	spawner.name = "enemySpawner"
	var gerenciador := GerenciadorTeste.new()
	gerenciador.name = "GerenciadorOndas"
	spawner.add_child(gerenciador)
	var ponto := Marker2D.new()
	spawner.add_child(ponto)
	_arena.add_child(spawner)
	await process_frame
	await process_frame
	var antes := gerenciador.mortes
	var criou: bool = await spawner.spawnar_inimigo_em(ponto, 2.0, 1.5, load("res://arquivo/tiny/cenas/slime_grande.tscn"))
	var criados := get_nodes_in_group("enemy")
	_verificar("spawner cria o Tiny com atributos da onda", criou and criados.size() == 1 and criados[0].vida == 120 and criados[0].dano == 22.5)
	if not criados.is_empty():
		var conexoes: Array = criados[0].get_signal_connection_list("inimigo_morreu")
		_verificar("spawner liga os drops de sementes e equipamento e a contagem da onda", conexoes.size() == 3)
		criados[0].receber_dano(99999)
		await create_timer(0.75).timeout
	_verificar("abate pelo spawner chega ao gerenciador", gerenciador.mortes == antes + 1)
	spawner.free()
	await _testar_disparos()
	print("Falhas: ", _falhas)
	quit(_falhas)

func _testar_disparos() -> void:
	var roteiro = load("res://arquivo/tiny/codigo/projetil_tiny.gd")
	_jogador.position = Vector2(100, 100)
	for tipo in ["flecha", "espinho", "bomba", "esporos"]:
		var antes := _jogador.dano_recebido
		var disparo: Node2D = roteiro.new()
		disparo.tipo = tipo
		disparo.dano = 7
		disparo.alvo = _jogador
		disparo.origem = Vector2(40, 100)
		disparo.destino = _jogador.position
		_arena.add_child(disparo)
		await create_timer(1.3).timeout
		_verificar(tipo + " causa dano uma vez e é removido", _jogador.dano_recebido == antes + 7 and not is_instance_valid(disparo))
	var antes := _jogador.dano_recebido
	var bomba: Node2D = roteiro.new()
	bomba.tipo = "bomba"
	bomba.dano = 7
	bomba.alvo = _jogador
	bomba.origem = Vector2(40, 100)
	bomba.destino = _jogador.position
	_arena.add_child(bomba)
	_jogador.position += Vector2(100, 0)
	await create_timer(1.3).timeout
	_verificar("sair do aviso evita o dano da bomba", _jogador.dano_recebido == antes)
	# Exercita a preparação da animação e a criação do projétil pelo inimigo real.
	for tipo in ["goblin_arqueiro", "goblin_bombardeiro", "espinhento", "flor_venenosa"]:
		var inimigo: Node2D = load("res://cenas/inimigos/" + tipo + ".tscn").instantiate()
		inimigo.position = _jogador.position - Vector2(30, 0)
		_arena.add_child(inimigo)
		inimigo.set_physics_process(false)
		var criados := [0]
		inimigo.child_entered_tree.connect(func(filho):
			if filho.get_script() == roteiro:
				criados[0] += 1
		)
		inimigo._iniciar_ataque(Vector2.RIGHT)
		await create_timer(0.45).timeout
		_verificar(tipo + " dispara durante a animação", criados[0] == 1)
		inimigo.free()
	var planta: Node2D = load("res://arquivo/tiny/cenas/espinhento.tscn").instantiate()
	_arena.add_child(planta)
	planta._atordoado = 0.15
	await create_timer(0.25).timeout
	_verificar("planta imóvel se recupera do atordoamento", not planta.esta_atordoado())
	planta.free()
	await physics_frame
