extends SceneTree

var falhas := 0

class Alvo extends Node2D:
	var estaMorto := false
	var invulneravel := false
	func receber_dano(_dano: int, _forca: Vector2) -> void:
		pass

class ChefeSimples extends Node2D:
	var esta_morto := false
	var sprite := Sprite2D.new()
	func esta_congelado() -> bool:
		return false
	func obter_jogador() -> Node2D:
		return get_tree().current_scene.get_node("Jogador")
	func definir_direcao_animacao(_direcao: Vector2) -> void:
		pass

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
	var cena := Node2D.new()
	root.add_child(cena)
	current_scene = cena
	var alvo := Alvo.new()
	alvo.name = "Jogador"
	cena.add_child(alvo)
	var minotauro = load("res://cenas/inimigos/minotauro.tscn").instantiate()
	cena.add_child(minotauro)
	minotauro.set_physics_process(false)
	for sequencia in 6:
		minotauro._golpes_normais = sequencia
		verificar("minotauro distante escolhe investida, sequência %d" % sequencia, minotauro._escolher_ataque(Vector2(200, 0)) == "investida")
	verificar("minotauro só usa pisão dentro de 90", minotauro._escolher_ataque(Vector2(80, 0)) == "pisao" and minotauro._escolher_ataque(Vector2(100, 0)) == "investida")
	minotauro._golpes_normais = 0
	verificar("machado próximo", minotauro._escolher_ataque(Vector2(40, 0)) == "machado")
	minotauro._golpes_normais = 2
	verificar("pisão alterna somente próximo", minotauro._escolher_ataque(Vector2(40, 0)) == "pisao")
	verificar("muito longe usa investida para aproximar", minotauro._escolher_ataque(Vector2(400, 0)) == "investida")
	alvo.position = Vector2(200, 0)
	minotauro._recarga = 0
	minotauro._physics_process(0.016)
	verificar("IA real inicia investida no antigo terceiro pisão", minotauro.estado == minotauro.Estado.PREPARANDO and minotauro.ataque_atual == "investida")
	minotauro._limpar_efeitos()
	minotauro.position = Vector2.ZERO
	minotauro._furia_ativa = true
	minotauro._fila_furia.assign(["pisao_furia"])
	minotauro._executar_furia()
	verificar("especial aproxima antes do pisão final", minotauro.estado == minotauro.Estado.LIVRE and minotauro._fila_furia.size() == 1)
	alvo.position = Vector2(100, 0)
	minotauro._executar_furia()
	verificar("especial executa pisão quando alcança", minotauro.estado == minotauro.Estado.PREPARANDO and minotauro.ataque_atual == "pisao_furia")
	minotauro._limpar_efeitos()
	minotauro._furia_ativa = false
	minotauro.estado = minotauro.Estado.LIVRE
	var dragao = load("res://cenas/inimigos/dragao_vermelho.tscn").instantiate()
	cena.add_child(dragao)
	dragao.set_physics_process(false)
	dragao._linha = 0
	for sequencia in 3:
		dragao._proximo_ataque = sequencia
		verificar("dragão ignora cauda e asas fora do alcance %d" % sequencia, dragao._escolher_ataque(Vector2(0, 120)) == "sopro")
	dragao._proximo_ataque = 1
	verificar("cauda próxima", dragao._escolher_ataque(Vector2(0, 70)) == "cauda")
	verificar("asas no alcance intermediário", dragao._escolher_ataque(Vector2(0, 100)) == "asas")
	verificar("sopro mede alcance a partir da boca", dragao._escolher_ataque(Vector2(0, 140)).is_empty())
	var parede := StaticBody2D.new()
	parede.collision_layer = 64
	parede.position = Vector2(100, 0)
	var colisor := CollisionShape2D.new()
	var forma := RectangleShape2D.new()
	forma.size = Vector2(10, 100)
	colisor.shape = forma
	parede.add_child(colisor)
	cena.add_child(parede)
	await physics_frame
	await physics_frame
	verificar("chefes não lançam golpes contra parede", not minotauro._caminho_livre(Vector2(200, 0)) and not dragao._caminho_livre(Vector2(200, 0)))
	alvo.position = Vector2(200, 0)
	minotauro._recarga = 0
	minotauro._physics_process(0.016)
	verificar("bloqueado mantém perseguição sem gastar ataque", minotauro.estado == minotauro.Estado.LIVRE and minotauro._recarga == 0)
	var simples := ChefeSimples.new()
	cena.add_child(simples)
	var habilidade = load("res://codigo/inimigos/habilidade_chefe.gd").new()
	habilidade.tipo = "cogumelo"
	simples.add_child(habilidade)
	habilidade.set_physics_process(false)
	habilidade._tempo_invocacao = 1000
	habilidade._tempo_restante = 0
	alvo.position = Vector2(100, 0)
	habilidade._processar_cogumelo(0.016)
	verificar("cogumelo não explode fora dos esporos", habilidade.estado == habilidade.Estado.LIVRE)
	alvo.position = Vector2(70, 0)
	habilidade._processar_cogumelo(0.016)
	verificar("cogumelo prepara esporos próximo", habilidade.estado == habilidade.Estado.AVISO)
	habilidade.queue_free()
	await process_frame
	habilidade = load("res://codigo/inimigos/habilidade_chefe.gd").new()
	habilidade.tipo = "caranguejo"
	simples.add_child(habilidade)
	habilidade.set_physics_process(false)
	habilidade._tempo_restante = 0
	alvo.position = Vector2(240, 0)
	habilidade._processar_caranguejo(0.016)
	verificar("caranguejo respeita distância de ativação", habilidade.estado == habilidade.Estado.LIVRE)
	alvo.position = Vector2(100, 0)
	habilidade._processar_caranguejo(0.016)
	verificar("caranguejo mantém investida para aproximar", habilidade.estado == habilidade.Estado.AVISO)
	simples.sprite.free()
	cena.queue_free()
	await process_frame
	print("Falhas: ", falhas)
	quit(falhas)
