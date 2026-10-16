extends SceneTree

var falhas := 0

class AlvoTeste extends Node2D:
	var estaMorto := false
	var invulneravel := false
	var golpes := 0
	var pedras := 0
	var fatais := 0
	var mira := Vector2.LEFT
	func receber_dano(_dano: int, _forca: Vector2) -> void:
		golpes += 1
	func direcao_apontada() -> Vector2:
		return mira
	func aplicar_petrificacao(_duracao: float) -> bool:
		pedras += 1
		return true
	func aplicar_petrificacao_fatal() -> bool:
		fatais += 1
		return true

func _initialize() -> void:
	_rodar()

func verificar(nome: String, certo: bool) -> void:
	print("OK " if certo else "FALHA ", nome)
	if not certo:
		falhas += 1

func _rodar() -> void:
	await process_frame
	if not OS.get_user_data_dir().ends_with("AlgoLand testes Carrasco"):
		push_error("Execute com saves isolados.")
		quit(1)
		return
	var gerenciador: Node = load("res://codigo/logica/gerenciador_de_ondas.gd").new()
	verificar("Medusa na onda 20 e 70", gerenciador.chefe_da_onda(20).id == "medusa" and gerenciador.chefe_da_onda(70).id == "medusa")
	verificar("Outros chefes mantêm suas ondas", gerenciador.chefe_da_onda(10).id == "minotauro" and gerenciador.chefe_da_onda(50).id == "dragao_vermelho")
	gerenciador.free()
	var cena := Node2D.new()
	root.add_child(cena)
	current_scene = cena
	var alvo := AlvoTeste.new()
	alvo.name = "Jogador"
	cena.add_child(alvo)
	var medusa: Node = load("res://cenas/inimigos/medusa.tscn").instantiate()
	cena.add_child(medusa)
	medusa.set_physics_process(false)
	verificar("Chefe sem dano de contato", medusa.eh_chefe and medusa.collision_layer == 0)
	medusa.aplicar_dano_contato()
	verificar("Encostar não causa dano", alvo.golpes == 0)
	verificar("Alvo longe provoca bote", medusa._escolher_ataque(Vector2(300, 0)) == "bote")
	verificar("Alvo perto provoca garras", medusa._escolher_ataque(Vector2(40, 0)) == "garras")
	verificar("Distância média provoca cauda", medusa._escolher_ataque(Vector2(80, 0)) == "cauda")
	alvo.position = Vector2(40, 0)
	verificar("Preparação inicia", medusa.iniciar_ataque("garras", alvo.position))
	medusa._physics_process(0.2)
	verificar("Aviso não causa dano", alvo.golpes == 0 and medusa.estado == medusa.Estado.AVISANDO)
	medusa._atingir_area()
	medusa._atingir_area()
	verificar("Garras atingem dentro do cone uma vez", alvo.golpes == 1)
	medusa._recuperar()
	medusa.estado = medusa.Estado.LIVRE
	medusa.iniciar_ataque("garras", Vector2(60, 0))
	alvo.position = Vector2(-40, 0)
	var golpes := alvo.golpes
	medusa._atingir_area()
	verificar("Garras não acertam atrás", alvo.golpes == golpes)
	medusa._recuperar()
	medusa.estado = medusa.Estado.LIVRE
	alvo.position = Vector2(85, 0)
	medusa.iniciar_ataque("cauda", alvo.position)
	medusa._atingir_area()
	verificar("Cauda atinge dentro do círculo", alvo.golpes == golpes + 1)
	medusa._recuperar()
	medusa.estado = medusa.Estado.LIVRE
	alvo.position = Vector2(100, 0)
	medusa.iniciar_ataque("bote", alvo.position)
	golpes = alvo.golpes
	medusa._atingir_bote(Vector2(0, 0), Vector2(180, 0))
	medusa._atingir_bote(Vector2(0, 0), Vector2(180, 0))
	verificar("Bote varre o caminho sem atravessar o alvo nem duplicar dano", alvo.golpes == golpes + 1)
	medusa._recuperar()
	medusa.estado = medusa.Estado.LIVRE
	medusa.iniciar_ataque("olhar", alvo.position)
	alvo.mira = Vector2.RIGHT
	medusa._atingir_area()
	verificar("Virar de costas evita petrificação", alvo.pedras == 0)
	alvo.mira = Vector2.LEFT
	medusa._acertou = false
	medusa._atingir_area()
	verificar("Olhar para Medusa dentro do cone petrifica", alvo.pedras == 1)
	alvo.position = Vector2(0, 200)
	medusa._acertou = false
	medusa._atingir_area()
	verificar("Sair do cone evita petrificação", alvo.pedras == 1)
	medusa._recuperar()
	medusa.estado = medusa.Estado.LIVRE
	medusa._recarga = 0
	medusa._physics_process(0.01)
	verificar("Após recuperar, volta a agir", medusa.estado == medusa.Estado.AVISANDO)
	medusa._recuperar()
	medusa.estado = medusa.Estado.LIVRE
	medusa.vida = roundi(medusa.vida_maxima * 0.5)
	medusa._physics_process(0.01)
	verificar("50% dispara especial fatal uma vez", medusa.ataque_atual == "ruina" and medusa._proxima_ruina == 1)
	verificar("Invocação tem círculo que nasce nos olhos", is_instance_valid(medusa._luz_olhos) and is_instance_valid(medusa._luz_circulo) and medusa._efeito.visible and medusa._efeito.position.distance_to(medusa._origem_olhos()) < 1)
	var centro: Vector2 = medusa._centro_ruina
	verificar("Área grande fica no local anunciado", centro == alvo.global_position + Vector2(0, 9))
	medusa._physics_process(2.5)
	verificar("Aviso fatal não mata antes do impacto", alvo.fatais == 0)
	medusa._physics_process(0.25)
	verificar("Permanecer dentro da área aplica pedra fatal", alvo.fatais == 1)
	medusa._recuperar()
	medusa.estado = medusa.Estado.LIVRE
	medusa._physics_process(0.01)
	verificar("Limiar de 50% não repete", medusa._proxima_ruina == 1 and medusa.ataque_atual != "ruina")
	medusa._recuperar()
	medusa.estado = medusa.Estado.LIVRE
	medusa.vida = roundi(medusa.vida_maxima * 0.1)
	medusa._physics_process(0.01)
	verificar("10% dispara segundo especial fatal", medusa.ataque_atual == "ruina" and medusa._proxima_ruina == 2)
	alvo.global_position = medusa._centro_ruina + Vector2(medusa.RAIO_RUINA + 1, -9)
	medusa._atingir_area()
	verificar("Sair da área evita morte fatal", alvo.fatais == 1)
	cena.queue_free()
	await process_frame
	await process_frame
	var arena: Node = load("res://cenas/cenario.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	await process_frame
	arena.get_node("enemySpawner/GerenciadorOndas").parar_ondas()
	var jogador: Node = arena.get_node("Jogador")
	jogador.set_physics_process(false)
	var slots: Dictionary = root.get_node("InventarioJogador").equipados.duplicate()
	var material_antigo: Material = jogador.sprite_corpo.material
	jogador.esta_em_dash = true
	verificar("Esquiva evita petrificação", not jogador.aplicar_petrificacao(2.25))
	jogador.esta_em_dash = false
	verificar("Jogador real vira pedra", jogador.aplicar_petrificacao(2.25) and jogador.esta_petrificado())
	verificar("Visual de pedra e animação parados", jogador.sprite_corpo.material is ShaderMaterial and not jogador._arvore_animacao.active)
	var posicao: Vector2 = jogador.position
	Input.action_press("move_right")
	jogador._physics_process(0.5)
	Input.action_release("move_right")
	verificar("Pedra bloqueia movimento e ataque", jogador.position == posicao and jogador.velocity == Vector2.ZERO and not jogador._esta_atacando)
	jogador.petrificacao.atualizar(2)
	verificar("Pedra termina e restaura aparência", not jogador.esta_petrificado() and jogador.sprite_corpo.material == material_antigo and jogador._arvore_animacao.active)
	verificar("Proteção contra petrificação em sequência", not jogador.aplicar_petrificacao(2.25))
	jogador.petrificacao.atualizar(4.1)
	verificar("Pode petrificar novamente após imunidade", jogador.aplicar_petrificacao(0.2))
	jogador.petrificacao.atualizar(0.3)
	verificar("Equipamentos preservados", root.get_node("InventarioJogador").equipados == slots)
	jogador.invulneravel = true
	jogador.temporizador_invul = 99
	jogador.esta_em_dash = true
	verificar("Especial fatal ignora invulnerabilidade e proteção da pedra normal", jogador.aplicar_petrificacao_fatal())
	jogador.petrificacao.atualizar(0.7)
	verificar("Jogador petrificado começa a virar cascalho", jogador.petrificacao._esfarelando and not jogador.get_node("CompositeSprites").visible)
	jogador.petrificacao.atualizar(0.6)
	verificar("Cascalho causa hit kill sem reviver", jogador.hp_atual == 0 and jogador.estaMorto)
	jogador.reiniciar_para_nova_partida()
	verificar("Nova partida restaura corpo e limpa cascalho", jogador.get_node("CompositeSprites").visible and jogador.petrificacao == null and not jogador.estaMorto)
	arena.queue_free()
	await process_frame
	print("Falhas: ", falhas)
	quit(falhas)
