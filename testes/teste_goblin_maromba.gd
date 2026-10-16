extends SceneTree

var falhas := 0
class AlvoTeste extends Node2D:
	var estaMorto := false
	var golpes := 0
	var fatais := 0
	func receber_dano(_dano: int, _forca: Vector2) -> void:
		golpes += 1
	func receber_hitkill_chefe() -> void:
		fatais += 1

func verificar(nome: String, certo: bool) -> void:
	print("OK " if certo else "FALHA ", nome)
	if not certo:
		falhas += 1

func _initialize() -> void:
	_rodar()

func _rodar() -> void:
	await process_frame
	if not OS.get_user_data_dir().ends_with("AlgoLand testes Carrasco"):
		push_error("Use a cópia de testes com saves isolados.")
		quit(1)
		return
	var ondas: Node = load("res://codigo/logica/gerenciador_de_ondas.gd").new()
	verificar("Goblin nas ondas 30 e 80", ondas.chefe_da_onda(30).id == "goblin_maromba" and ondas.chefe_da_onda(80).id == "goblin_maromba")
	verificar("Medusa e dragão preservados", ondas.chefe_da_onda(20).id == "medusa" and ondas.chefe_da_onda(50).id == "dragao_vermelho")
	ondas.free()
	var cena := Node2D.new()
	root.add_child(cena)
	current_scene = cena
	var alvo := AlvoTeste.new()
	alvo.name = "Jogador"
	cena.add_child(alvo)
	var chefe: Node = load("res://cenas/inimigos/goblin_maromba.tscn").instantiate()
	cena.add_child(chefe)
	chefe.set_physics_process(false)
	chefe._definir_linha(Vector2.RIGHT)
	chefe._tocar("movimento", 11)
	verificar("Ciclo lateral direito completo e atingível", chefe.sprite.hframes == 12 and chefe.sprite.frame == 35 and not chefe._area_dano._contorno.is_empty())
	chefe._definir_linha(Vector2.LEFT)
	chefe._tocar("movimento", 11)
	verificar("Ciclo lateral esquerdo completo e atingível", chefe.sprite.frame == 47 and not chefe._area_dano._contorno.is_empty())
	chefe._tocar("porretada", 5)
	verificar("Trocar caminhada por ataque mantém a grade correta", chefe.sprite.hframes == 6 and chefe.sprite.frame == 23)
	chefe._tocar("movimento", 0)
	verificar("Sem dano de contato", chefe.collision_layer == 0 and chefe.eh_chefe)
	chefe.aplicar_dano_contato()
	verificar("Contato não acerta", alvo.golpes == 0)
	verificar("Longe escolhe salto", chefe._escolher_ataque(Vector2(250, 0)) == "salto")
	verificar("Perto escolhe porretada", chefe._escolher_ataque(Vector2(40, 0)) == "porretada")
	verificar("Distância média escolhe varrida", chefe._escolher_ataque(Vector2(80, 0)) == "varrida")
	for tipo in ["porretada", "varrida", "salto", "furia", "execucao"]:
		chefe.position = Vector2.ZERO
		alvo.position = Vector2(40, 0)
		chefe.estado = chefe.Estado.LIVRE
		verificar("Inicia " + tipo, chefe.iniciar_ataque(tipo, alvo.position))
		var golpes: int = alvo.golpes
		chefe._physics_process(0.1)
		verificar("Aviso sem dano: " + tipo, alvo.golpes == golpes and alvo.fatais == 0)
		chefe._recuperar()
	chefe.estado = chefe.Estado.LIVRE
	chefe.iniciar_ataque("porretada", Vector2(40, 0))
	alvo.position = Vector2(-40, 0)
	chefe._atingir_area()
	verificar("Porretada não acerta pelas costas", alvo.golpes == 0)
	chefe._recuperar()
	chefe.estado = chefe.Estado.LIVRE
	alvo.position = Vector2(40, 0)
	chefe.iniciar_ataque("porretada", alvo.position)
	chefe._atingir_area()
	chefe._atingir_area()
	verificar("Um acerto por golpe", alvo.golpes == 1)
	chefe._recuperar()
	chefe.estado = chefe.Estado.LIVRE
	chefe.iniciar_ataque("furia", alvo.position)
	chefe._physics_process(0.7)
	for i in 18:
		chefe._physics_process(0.1)
	verificar("Fúria tem três golpes", alvo.golpes == 4)
	chefe._recuperar()
	chefe.estado = chefe.Estado.LIVRE
	chefe.iniciar_ataque("execucao", alvo.position)
	var marca: Vector2 = chefe._centro_execucao
	alvo.position = Vector2(400, 0)
	chefe._physics_process(0.1)
	verificar("Marca fatal fica fixa", chefe._centro_execucao == marca)
	chefe._atingir_area()
	verificar("Sair do círculo evita hit kill", alvo.fatais == 0)
	chefe._acertou = false
	alvo.position = marca - Vector2(0, 9)
	chefe._atingir_area()
	chefe._atingir_area()
	verificar("Hit kill dentro da área, uma vez", alvo.fatais == 1)
	chefe._recuperar()
	chefe.estado = chefe.Estado.LIVRE
	chefe.vida = roundi(chefe.vida_maxima * 0.49)
	chefe._physics_process(0.01)
	verificar("Execução aos 50%", chefe.ataque_atual == "execucao" and chefe._proxima_execucao == 1)
	chefe._recuperar()
	chefe.estado = chefe.Estado.LIVRE
	chefe.vida = roundi(chefe.vida_maxima * 0.09)
	chefe._physics_process(0.01)
	verificar("Execução aos 10%", chefe._proxima_execucao == 2)
	chefe._recuperar()
	chefe._physics_process(1.1)
	verificar("Recuperação termina", chefe.estado == chefe.Estado.LIVRE)
	chefe._recuperar()
	cena.queue_free()
	await process_frame
	print("Falhas: ", falhas)
	quit(1 if falhas > 0 else 0)
