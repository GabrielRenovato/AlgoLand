extends SceneTree

# Rodar: godot --headless --path . --script res://testes/teste_cadeira.gd
# Cadeiras da casa (codigo/logica/cadeira.gd): F senta o jogador (pose de sentar da pagina 4, com a roupa dele, olhando para a
# mesa) e ele fica sentado; F/B/andar levanta de volta atras da cadeira. As xicaras de cafe so enfeitam a mesa.
# Usa arquivos de teste para Progresso e Fazenda (nao toca nos saves reais).

const CAMINHO_PROGRESSO := "user://teste_cadeira_progresso.json"
const CAMINHO_FAZENDA := "user://teste_cadeira_fazenda.json"

var _falhas: int = 0

func _initialize() -> void:
	_rodar()

func _verificar(nome: String, condicao: bool, detalhe: String = "") -> void:
	if condicao:
		print("OK ", nome)
	else:
		_falhas += 1
		print("FALHA ", nome, ": ", detalhe)

func _quadros(n: int) -> void:
	for i in n:
		await process_frame

func _fisica(n: int) -> void:
	for i in n:
		await physics_frame

func _esperar(condicao: Callable, limite: float) -> bool:
	var fim := Time.get_ticks_msec() + int(limite * 1000.0)
	while Time.get_ticks_msec() < fim:
		if condicao.call():
			return true
		await process_frame
	return condicao.call()

func _rodar() -> void:
	await process_frame
	var progresso = root.get_node("Progresso")
	var fazenda = root.get_node("Fazenda")
	progresso.caminho_save = CAMINHO_PROGRESSO
	fazenda.caminho_save = CAMINHO_FAZENDA
	progresso.apagar()
	fazenda.apagar()

	var casa: Node = load("res://cenas/casa.tscn").instantiate()
	root.add_child(casa)
	current_scene = casa
	await _quadros(10)
	var jogador: Node = casa.get_node("Jogador")
	var mesa: Node = casa.get_node("Objetos3D/Mesa")

	# --- montagem da cena
	var zonas := {"E": casa.get_node("ZonaCadeiraE"), "D": casa.get_node("ZonaCadeiraD")}
	_verificar("duas zonas de cadeira, uma olha para a direita e a outra para a esquerda (as duas para a mesa)",
			zonas["E"].lado == 1 and zonas["D"].lado == -1 and zonas["E"].global_position.x < mesa.global_position.x and zonas["D"].global_position.x > mesa.global_position.x, "")
	var Prof := preload("res://codigo/globais/profundidade.gd")
	var cafe := {"E": mesa.get_node_or_null("Cafe_E"), "D": mesa.get_node_or_null("Cafe_D")}
	_verificar("duas xicaras de cafe em cima da mesa (filhas da mesa, visiveis, com fumacinha)", cafe["E"] != null and cafe["D"] != null and cafe["E"].visible and cafe["D"].visible
			and cafe["E"].get_node_or_null("Vapor") != null and cafe["E"].texture.region == Rect2(177, 68, 10, 8), "")
	var tampo_y: float = mesa.global_position.y - 42.0
	_verificar("as xicaras ficam em cima do tampo (entre y 64 e 94)", cafe["E"].global_position.y > tampo_y and cafe["E"].global_position.y < mesa.global_position.y - 8.0, "")

	var todas_existem := true
	for i in range(1, 13):
		todas_existem = todas_existem and ResourceLoader.exists("res://assets/personagens/Sentado/roupa_%d.png" % i)
	_verificar("as 12 roupas de sentar (pagina 4) existem, uma para cada roupa de andar", todas_existem, "")
	jogador.roupa_atual = 6
	# de pe na frente da mesa (pes abaixo da base dela) ele continua na frente dela; atras dela, fica escondido
	_verificar("de pe na frente da mesa o jogador desenha por cima dela; de pe atras, por baixo",
			Prof.z_de(mesa.global_position.y + 16.0) >= mesa.z_index and Prof.z_de(mesa.global_position.y - 40.0) < mesa.z_index, "mesa=%d frente=%d atras=%d" % [mesa.z_index, Prof.z_de(mesa.global_position.y + 16.0), Prof.z_de(mesa.global_position.y - 40.0)])
	for chave in ["E", "D"]:
		var zona: Node = zonas[chave]
		var lado: int = zona.lado
		jogador.global_position = zona.global_position + Vector2(0, 8)
		await _fisica(8)
		_verificar("%s: jogador perto, livre e de pe: pode sentar (aviso F)" % chave, zona.jogador_perto and zona.disponivel_para_interacao() and not jogador.esta_sentado, "")
		var movimento_antes: bool = jogador.movimento_habilitado
		zona.abrir_tela()
		await _quadros(3)
		_verificar("%s: sentou (esta_sentado, nos da forja visiveis, corpo normal escondido)" % chave, jogador.esta_sentado and jogador.no_forja.visible
				and not jogador.get_node("CompositeSprites/BaseSprites").visible and not jogador.movimento_habilitado, "")
		await _fisica(6)
		_verificar("%s: a arvore de animacao nao reescreve o quadro (ficava na pose de martelar): segue sentado" % chave,
				not jogador._arvore_animacao.active and jogador.sprite_corpo_forja.frame == (51 if lado > 0 else 59), "frame=%d ativa=%s" % [jogador.sprite_corpo_forja.frame, jogador._arvore_animacao.active])
		_verificar("%s: sentado no assento, olhando para a mesa (quadro da pagina 4 coluna 3: %d)" % [chave, 51 if lado > 0 else 59],
				jogador.global_position.is_equal_approx(zona.global_position + zona.assento) and jogador.sprite_corpo_forja.frame == (51 if lado > 0 else 59)
				and jogador.sprite_cabelo_forja.frame == jogador.sprite_corpo_forja.frame and jogador.sprite_roupa_forja.frame == jogador.sprite_corpo_forja.frame, "frame=%d" % jogador.sprite_corpo_forja.frame)
		_verificar("%s: veste a roupa dele (versao da pagina 4 da mesma roupa), nao o avental de ferreiro da forja" % chave,
				jogador.sprite_roupa_forja.texture == preload("res://codigo/dados/aparencia.gd").roupa_refinada(jogador.roupa_atual, "sentado")
				and jogador.sprite_roupa_forja.scale == Vector2(0.5, 0.5)
				and not jogador.sprite_roupa_forja.texture.resource_path.contains("body_smithing"), str(jogador.sprite_roupa_forja.texture.resource_path))
		_verificar("%s: desenhado na frente do encosto da cadeira (z acima do da cadeira)" % chave, jogador.z_index > preload("res://codigo/globais/profundidade.gd").z_de(zona.global_position.y + 8.0), "z=%d" % jogador.z_index)
		_verificar("%s: as pernas passam por BAIXO da mesa: z da cadeira < z do jogador sentado < z da mesa" % chave,
				zona.z_da_cadeira() < jogador.z_index and jogador.z_index + 6 < mesa.z_index, "cadeira=%d jogador=%d mesa=%d" % [zona.z_da_cadeira(), jogador.z_index, mesa.z_index])
		_verificar("%s: a cadeira fica ocupada e a outra tambem nao deixa (ele ja esta sentado)" % chave, zona.ocupada and not zonas["E" if chave == "D" else "D"].pode_interagir(), "")
		# --- fica sentado (sem beber: o Character Base nao tem essa animacao) e a xicara continua na mesa
		await create_timer(2.0).timeout
		_verificar("%s: a cadeira e a mesa seguem opacas (o fade de 'jogador atras' nao vale para quem esta sentado)" % chave,
				is_equal_approx(casa.get_node("Objetos3D/Cadeira" + chave).modulate.a, 1.0) and is_equal_approx(mesa.modulate.a, 1.0),
				"cadeira=%.2f mesa=%.2f" % [casa.get_node("Objetos3D/Cadeira" + chave).modulate.a, mesa.modulate.a])
		_verificar("%s: segue sentado, no mesmo quadro, e a xicara fica na mesa (nao e usada)" % chave, jogador.esta_sentado and zona.ocupada
				and jogador.sprite_corpo_forja.frame == (51 if lado > 0 else 59) and cafe[chave].visible, "frame=%d" % jogador.sprite_corpo_forja.frame)
		# --- levantar: F/Y (aqui o sinal que o jogador emite)
		Input.action_press("open_menu")
		await _quadros(3)
		Input.action_release("open_menu")
		await _esperar(func(): return not jogador.esta_sentado, 2.0)
		_verificar("%s: F levanta: de pe ao lado da cadeira, corpo normal de volta, solto" % chave, not jogador.esta_sentado and not jogador.no_forja.visible
				and jogador.get_node("CompositeSprites/BaseSprites").visible and jogador.movimento_habilitado and not zona.ocupada
				and jogador.global_position.is_equal_approx(zona.global_position + zona.saida) and not jogador.ataques_bloqueados, "pos=%s" % jogador.global_position)
		_verificar("%s: a animacao normal volta (arvore ativa) e o jogador anda de novo" % chave, jogador._arvore_animacao.active and jogador.get_node("CompositeSprites/Forja/Arm").visible, "")
		Input.action_press("move_down")
		await _fisica(6)
		Input.action_release("move_down")
		_verificar("%s: depois de levantar ele se move (nao ficou travado)" % chave, jogador.velocity.length() > 1.0 or jogador.global_position.y > (zona.global_position + zona.saida).y + 0.2, "vel=%s" % jogador.velocity)
		_verificar("%s: a xicara de cafe segue na mesa" % chave, cafe[chave].visible, "")

	# --- o ponto onde levanta esta livre (nada de parede ou movel empurrando o jogador)
	var espaco: PhysicsDirectSpaceState2D = root.get_world_2d().direct_space_state
	for chave in ["E", "D"]:
		var ponto: Vector2 = zonas[chave].global_position + zonas[chave].saida
		# a colisao real do jogador: circulo de 5 px nos pes (a 9 px da origem)
		var forma: Shape2D = jogador.get_node("CollisionShape2D").shape
		var consulta := PhysicsShapeQueryParameters2D.new()
		consulta.shape = forma
		consulta.transform = Transform2D(0.0, ponto + jogador.get_node("CollisionShape2D").position)
		consulta.collision_mask = 64
		_verificar("%s: o ponto onde levanta esta livre (sem parede nem movel por perto)" % chave, espaco.intersect_shape(consulta, 1).is_empty(), str(ponto))

	var zona_e: Node = zonas["E"]
	# --- F logo ao sentar nao levanta na hora (o mesmo F que sentou)
	jogador.global_position = zona_e.global_position + Vector2(0, 8)
	await _fisica(8)
	zona_e.abrir_tela()
	await _quadros(2)
	Input.action_press("open_menu")
	await _quadros(3)
	Input.action_release("open_menu")
	_verificar("o F de sentar nao levanta na hora (tempo minimo sentado)", jogador.esta_sentado, "")
	jogador.pediu_levantar.emit()
	await _quadros(3)

	# --- sem tela: sentar nao abre menu nem trava a Interface
	_verificar("sentar nao abre nenhuma tela", casa.get_node("Interface")._telas_abertas.is_empty(), "")

	casa.queue_free()
	await _quadros(3)
	progresso.apagar()
	fazenda.apagar()
	for caminho in [CAMINHO_PROGRESSO, CAMINHO_FAZENDA]:
		if FileAccess.file_exists(caminho):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho))
	print("FALHAS: ", _falhas)
	quit(_falhas)
