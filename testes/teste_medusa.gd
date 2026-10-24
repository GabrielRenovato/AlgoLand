extends SceneTree

var falhas := 0

class AlvoTeste extends Node2D:
	var estaMorto := false
	var invulneravel := false
	var golpes := 0
	var dano_total := 0
	var caido := false
	var esta_em_dash := false
	var pedras := 0
	var fatais := 0
	var mira := Vector2.LEFT
	func receber_dano(_dano: int, _forca: Vector2) -> void:
		if invulneravel or estaMorto:
			return
		golpes += 1
		dano_total += _dano
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
	root.get_node("Saves").trocar("solo")
	var gerenciador: Node = load("res://codigo/logica/gerenciador_de_ondas.gd").new()
	verificar("Medusa na onda 20 e 70", gerenciador.chefe_da_onda(20).id == "medusa" and gerenciador.chefe_da_onda(70).id == "medusa")
	verificar("Outros chefes mantêm suas ondas", gerenciador.chefe_da_onda(10).id == "minotauro" and gerenciador.chefe_da_onda(50).id == "dragao_vermelho")
	gerenciador.free()
	var encaixe_correto := true
	for pagina in ["movimento", "garras", "cauda", "bote", "olhar"]:
		var imagem: Image = load("res://assets/inimigos/medusa/" + pagina + ".png").get_image()
		encaixe_correto = encaixe_correto and imagem.get_size() == Vector2i(960, 640)
		for linha in 4:
			for coluna in 6:
				var limites := imagem.get_region(Rect2i(coluna * 160, linha * 160, 160, 160)).get_used_rect()
				encaixe_correto = encaixe_correto and limites.has_area() and limites.position.x > 0 and limites.position.y > 0 and limites.end.x < 160 and limites.end.y < 160
	verificar("120 poses completas, com margem para mãos, cauda e serpentes", encaixe_correto)
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
	medusa._recarga = 99
	medusa.vida = roundi(medusa.vida_maxima * 0.61)
	medusa._physics_process(0.01)
	verificar("Acima de60% mantém a primeira fase", medusa.fase == 1 and medusa._proxima_ruina == 0)
	medusa.vida = roundi(medusa.vida_maxima * 0.6)
	medusa._physics_process(0.01)
	verificar("Transição da fase2 dispara Ruína uma vez", medusa.ataque_atual == "ruina" and medusa._proxima_ruina == 1)
	verificar("Invocação tem círculo que nasce nos olhos", is_instance_valid(medusa._luz_olhos) and is_instance_valid(medusa._luz_circulo) and medusa._efeito.visible and medusa._efeito.position.distance_to(medusa._origem_olhos()) < 1)
	var centro: Vector2 = medusa._centro_ruina
	verificar("Área grande fica no local anunciado", centro == alvo.global_position + Vector2(0, 9))
	medusa._physics_process(2.5)
	verificar("Aviso de Ruína não atinge antes do impacto", alvo.fatais == 0)
	golpes = alvo.golpes
	medusa._physics_process(0.25)
	verificar("Ruína causa dano forte sem morte instantânea", alvo.golpes == golpes + 1 and alvo.fatais == 0 and medusa.fase == 2)
	medusa._recuperar()
	medusa.estado = medusa.Estado.LIVRE
	medusa._recarga = 0
	medusa._physics_process(0.01)
	verificar("Transição da fase2 não repete", medusa._proxima_ruina == 1 and medusa.ataque_atual != "ruina")
	medusa._recuperar()
	medusa.estado = medusa.Estado.LIVRE
	medusa._recarga = 99
	medusa.vida = roundi(medusa.vida_maxima * 0.26)
	medusa._physics_process(0.01)
	verificar("Acima de25% mantém a segunda fase", medusa.fase == 2 and medusa._proxima_ruina == 1)
	medusa.vida = roundi(medusa.vida_maxima * 0.25)
	medusa._physics_process(0.01)
	verificar("Transição da fase3 dispara segunda Ruína", medusa.ataque_atual == "ruina" and medusa._proxima_ruina == 2)
	alvo.global_position = medusa._centro_ruina + Vector2(medusa.RAIO_RUINA + 1, -9)
	golpes = alvo.golpes
	medusa._atingir_area()
	verificar("Sair da área evita Ruína", alvo.golpes == golpes and alvo.fatais == 0 and medusa.fase == 3)
	await _testar_combate(medusa, alvo, cena)
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
	var raven: Sprite2D = jogador.get_node("HeroiRaven")
	var chefe_real: Node2D = load("res://cenas/inimigos/medusa.tscn").instantiate()
	arena.add_child(chefe_real)
	chefe_real.set_physics_process(false)
	chefe_real.position = jogador.position + Vector2(100, 0)
	var hp_antes: int = jogador.hp_atual
	jogador.esta_em_dash = true
	jogador.invulneravel = false
	chefe_real.iniciar_ataque("ruina", jogador.global_position)
	chefe_real._atingir_area()
	verificar("Jogador real esquiva da Ruína sem perder vida", jogador.hp_atual == hp_antes and jogador.petrificacao == null)
	jogador.esta_em_dash = false
	chefe_real._recuperar()
	chefe_real.estado = chefe_real.Estado.LIVRE
	jogador.invulneravel = true
	chefe_real.iniciar_ataque("ruina", jogador.global_position)
	chefe_real._atingir_area()
	verificar("Invulnerabilidade real protege da Ruína", jogador.hp_atual == hp_antes)
	chefe_real._recuperar()
	chefe_real.estado = chefe_real.Estado.LIVRE
	jogador.invulneravel = false
	jogador.defesa.cancelar()
	chefe_real.iniciar_ataque("ruina", jogador.global_position)
	chefe_real._atingir_area()
	verificar("Ruína real causa dano sem petrificação fatal ou morte garantida", jogador.hp_atual < hp_antes and not jogador.estaMorto and jogador.petrificacao == null)
	var dano_sem_guarda: int = hp_antes - jogador.hp_atual
	jogador.hp_atual = hp_antes
	jogador.invulneravel = false
	jogador.stamina = jogador.stamina_maxima
	jogador.defesa.estado = jogador.defesa.Estado.GUARDA
	jogador.defesa._inicio_guarda_ms = Time.get_ticks_msec() - 1000
	jogador.defesa.direcao_guarda = Vector2.RIGHT
	chefe_real._recuperar()
	chefe_real.estado = chefe_real.Estado.LIVRE
	chefe_real.iniciar_ataque("ruina", jogador.global_position)
	chefe_real._atingir_area()
	verificar("Guarda real reduz Ruína e consome estamina", jogador.hp_atual < hp_antes and hp_antes - jogador.hp_atual < dano_sem_guarda and jogador.stamina < jogador.stamina_maxima)
	jogador.defesa.cancelar()
	jogador.hp_atual = hp_antes
	jogador.invulneravel = false
	chefe_real.queue_free()
	var slots: Dictionary = root.get_node("InventarioJogador").equipados.duplicate()
	var material_antigo: Material = jogador.sprite_corpo.material
	jogador.esta_em_dash = true
	verificar("Esquiva evita petrificação", not jogador.aplicar_petrificacao(2.25))
	jogador.esta_em_dash = false
	verificar("Jogador real vira pedra", jogador.aplicar_petrificacao(2.25) and jogador.esta_petrificado())
	verificar("Visual de pedra e animação parados", jogador.sprite_corpo.material is ShaderMaterial and not jogador._arvore_animacao.active)
	var quadro_pedra := raven.frame
	await create_timer(0.1).timeout
	verificar("Renderizador atual fica petrificado sem avançar poses", raven.material is ShaderMaterial and not raven.is_processing() and raven.frame == quadro_pedra)
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
	verificar("Mecânica fatal legada continua disponível a outros consumidores", jogador.aplicar_petrificacao_fatal())
	jogador.petrificacao.atualizar(0.7)
	await process_frame
	verificar("Jogador petrificado começa a virar cascalho", jogador.petrificacao._esfarelando and not raven.visible)
	jogador.petrificacao.atualizar(0.6)
	verificar("Cascalho causa hit kill sem reviver", jogador.hp_atual == 0 and jogador.estaMorto)
	await process_frame
	verificar("Corpo atual continua oculto após morte fatal", not raven.visible)
	jogador.reiniciar_para_nova_partida()
	await process_frame
	verificar("Nova partida restaura corpo e limpa cascalho", raven.visible and not jogador.get_node("CompositeSprites").visible and jogador.petrificacao == null and not jogador.estaMorto)
	arena.queue_free()
	await process_frame
	print("Falhas: ", falhas)
	quit(falhas)

func _preparar(medusa: Node, alvo: Node2D, fase_teste := 1) -> void:
	medusa._sequencia.clear()
	medusa._recuperar()
	medusa.estado = medusa.Estado.LIVRE
	medusa.fase = fase_teste
	medusa._proxima_ruina = 2
	medusa._ruina_pendente = false
	medusa.vida = medusa.vida_maxima
	medusa._padroes = 0
	medusa._direcao = Vector2.RIGHT
	medusa.position = Vector2.ZERO
	alvo.position = Vector2(40, 0)
	alvo.invulneravel = false

func _testar_combate(medusa: Node, alvo: Node2D, cena: Node) -> void:
	_preparar(medusa, alvo)
	medusa._padroes = 3
	verificar("Olhar participa da seleção normal", medusa._escolher_ataque(Vector2(80, 0)) == "olhar")
	medusa._padroes = 0
	verificar("Circular por trás provoca varrida", medusa._escolher_ataque(Vector2(-40, 0)) == "cauda")
	medusa._iniciar_padrao(alvo)
	verificar("Primeiro padrão apresenta golpe único", medusa._sequencia.is_empty())
	medusa._recuperar()
	verificar("Fim do padrão expõe a chefe", medusa.estado == medusa.Estado.RECUPERANDO and medusa._rotulo_exposta.visible)
	var vida_antes: int = medusa.vida
	medusa.receber_dano(20)
	verificar("Contra-ataque durante recuperação causa25% extra", vida_antes - medusa.vida == 25)
	medusa._physics_process(0.5)
	verificar("Janela de contra-ataque não é cancelada ao receber dano", medusa.estado == medusa.Estado.RECUPERANDO)
	await create_timer(0.21).timeout

	_preparar(medusa, alvo, 2)
	medusa._iniciar_padrao(alvo)
	verificar("Fase2 encadeia garras e cauda", medusa._sequencia == ["cauda"])
	vida_antes = medusa.vida
	medusa.receber_dano(20)
	verificar("Preparação recebe dano normal sem cancelar sequência", vida_antes - medusa.vida == 20 and medusa.estado == medusa.Estado.AVISANDO and not medusa._sequencia.is_empty())
	await create_timer(0.21).timeout
	medusa._physics_process(medusa._aviso_atual)
	medusa._physics_process(0.41)
	verificar("Golpe intermediário entra em pausa de combo", medusa.estado == medusa.Estado.ENTRE_GOLPES and not medusa._rotulo_exposta.visible)
	medusa._physics_process(medusa.intervalo_combo() + 0.01)
	verificar("Finalizador tem novo aviso e atraso legível", medusa.estado == medusa.Estado.AVISANDO and medusa.ataque_atual == "cauda" and medusa._aviso_atual == 0.95)
	medusa._physics_process(0.96)
	medusa._physics_process(0.51)
	verificar("Fim do combo garante recuperação longa", medusa.estado == medusa.Estado.RECUPERANDO)
	medusa._physics_process(1.0)
	verificar("Finalizador oferece mais de um segundo de abertura", medusa.estado == medusa.Estado.RECUPERANDO)

	_preparar(medusa, alvo, 3)
	medusa._iniciar_padrao(alvo)
	verificar("Fase3 tem três golpes, com limite explícito", medusa._sequencia == ["garras", "cauda"])
	medusa._recuperar()
	alvo.position = Vector2(200, 0)
	medusa._physics_process(medusa.intervalo_combo() + 0.01)
	verificar("Sair do alcance encerra combo sem golpe de alcance falso", medusa.estado == medusa.Estado.RECUPERANDO and medusa._sequencia.is_empty())

	_preparar(medusa, alvo, 3)
	medusa._iniciar_padrao(alvo)
	medusa.vida = 10
	medusa._proxima_ruina = 0
	medusa._physics_process(0.01)
	medusa._recuperar()
	verificar("Transição pendente encerra pressão, sem interromper golpe ativo", medusa.estado == medusa.Estado.RECUPERANDO and medusa._sequencia.is_empty())

	_preparar(medusa, alvo, 2)
	alvo.position = Vector2(180, 0)
	medusa._iniciar_padrao(alvo)
	verificar("Fase2 aproxima com bote antes das garras", medusa.ataque_atual == "bote" and medusa._sequencia == ["garras"])
	alvo.position = Vector2(140, 80)
	medusa._physics_process(0.15)
	verificar("Início do preparo acompanha posição observada", medusa._direcao.y > 0.1)
	var rumo: Vector2 = medusa._direcao
	var pontos: PackedVector2Array = medusa._aviso._superficie.polygon
	alvo.position = Vector2(140, -80)
	medusa._physics_process(0.4)
	verificar("Mira trava antes do impacto e mantém área anunciada", medusa._direcao == rumo and medusa._aviso._superficie.polygon == pontos)

	_preparar(medusa, alvo, 3)
	medusa._padroes = 3
	medusa._iniciar_padrao(alvo)
	verificar("Olhar não recebe combo que torne petrificação inevitável", medusa.ataque_atual == "olhar" and medusa._sequencia.is_empty())

	_preparar(medusa, alvo)
	medusa.iniciar_ataque("ruina", alvo.position)
	var golpes_antes: int = alvo.golpes
	alvo.invulneravel = true
	medusa._atingir_area()
	verificar("Ruína respeita invulnerabilidade, sem usar efeito fatal", alvo.golpes == golpes_antes and alvo.fatais == 0)
	alvo.invulneravel = false
	_preparar(medusa, alvo)
	medusa.iniciar_ataque("ruina", alvo.position)
	alvo.esta_em_dash = true
	golpes_antes = alvo.golpes
	medusa._atingir_area()
	verificar("Janela de esquiva evita Ruína mesmo sem petrificação fatal", alvo.golpes == golpes_antes)
	alvo.esta_em_dash = false

	var p2 := AlvoTeste.new()
	p2.position = Vector2(45, 0)
	cena.add_child(p2)
	alvo.add_to_group("jogadores")
	p2.add_to_group("jogadores")
	_preparar(medusa, alvo)
	medusa.iniciar_ataque("garras", alvo.position)
	golpes_antes = alvo.golpes
	medusa._atingir_area()
	medusa._atingir_area()
	verificar("Área atinge os dois jogadores uma vez cada", alvo.golpes == golpes_antes + 1 and p2.golpes == 1)
	_preparar(medusa, alvo)
	medusa.iniciar_ataque("bote", Vector2(180, 0))
	golpes_antes = alvo.golpes
	medusa._atingir_bote(Vector2.ZERO, Vector2(100, 0))
	medusa._atingir_bote(Vector2.ZERO, Vector2(100, 0))
	verificar("Bote não ignora P2 nem duplica acertos", alvo.golpes == golpes_antes + 1 and p2.golpes == 2)
	p2.caido = true
	_preparar(medusa, alvo)
	medusa.iniciar_ataque("cauda", alvo.position)
	medusa._atingir_area()
	verificar("Jogador caído não recebe golpes adicionais", p2.golpes == 2)
	var outro_ambiente := SubViewport.new()
	outro_ambiente.world_2d = World2D.new()
	root.add_child(outro_ambiente)
	var distante := AlvoTeste.new()
	outro_ambiente.add_child(distante)
	distante.position = alvo.position
	distante.add_to_group("jogadores")
	_preparar(medusa, alvo)
	medusa.iniciar_ataque("cauda", alvo.position)
	medusa._atingir_area()
	verificar("Golpes não atravessam mundos do cooperativo", distante.golpes == 0)
	alvo.caido = true
	verificar("Chefe não escolhe jogador em outro ambiente", medusa.obter_jogador() == null)
	alvo.caido = false
	outro_ambiente.queue_free()
	alvo.remove_from_group("jogadores")
	p2.queue_free()
