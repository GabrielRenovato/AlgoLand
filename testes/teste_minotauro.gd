extends SceneTree

var falhas := 0

class JogadorTeste extends Node2D:
	var estaMorto := false
	var invulneravel := false
	var golpes := 0
	func receber_dano(_dano: int, _forca: Vector2) -> void:
		golpes += 1

class MobTeste extends Node2D:
	var vida := 5
	var esta_morto := false
	var eh_chefe := false
	func receber_dano_efeito(valor: int, _cor: Color) -> void:
		vida -= valor
		esta_morto = vida <= 0

func _initialize() -> void:
	_rodar()

func verificar(nome: String, condicao: bool) -> void:
	print("OK " if condicao else "FALHA ", nome)
	if not condicao:
		falhas += 1

func _rodar() -> void:
	await process_frame
	if not OS.get_user_data_dir().ends_with("AlgoLand testes Carrasco"):
		push_error("Use saves isolados para o teste.")
		quit(1)
		return
	var cena := Node2D.new()
	root.add_child(cena)
	current_scene = cena
	var jogador := JogadorTeste.new()
	jogador.name = "Jogador"
	jogador.position = Vector2(110, 0)
	cena.add_child(jogador)
	var chefe = load("res://cenas/inimigos/minotauro.tscn").instantiate()
	cena.add_child(chefe)
	chefe.set_physics_process(false)
	verificar("minotauro persegue com velocidade 72", chefe.velocidade == 72)
	verificar("minotauro é chefe sem dano de contato", chefe.eh_chefe and chefe.collision_layer == 0)
	chefe.aplicar_dano_contato()
	verificar("proximidade não causa dano", jogador.golpes == 0)
	chefe._distancia_passos = 0
	for i in 6:
		chefe._animar_deslocamento(Vector2(8, 0))
		verificar("caminhada avança pelo deslocamento %d" % i, chefe.sprite.hframes == 6 and chefe.sprite.frame % 6 == (i + 1) % 6)
	chefe._animar_deslocamento(Vector2.ZERO)
	verificar("parado não caminha no lugar", chefe.sprite.texture == chefe._folhas["movimento"] and chefe._distancia_passos == 0)
	var mob := MobTeste.new()
	mob.position = Vector2(50, 0)
	mob.add_to_group("enemy")
	cena.add_child(mob)
	verificar("investida inicia aviso", chefe.iniciar_ataque("investida", jogador.position))
	var direcao: Vector2 = chefe._direcao
	jogador.position.y = 100
	chefe._physics_process(0.95)
	verificar("investida não persegue depois do aviso", chefe._direcao == direcao and jogador.golpes == 0)
	jogador.position = Vector2(110, 0)
	for i in 55:
		await physics_frame
		chefe._physics_process(1.0 / 60)
	verificar("investida anda em linha reta e acerta o caminho", chefe.position.x > 200 and absf(chefe.position.y) < 0.01 and jogador.golpes == 1)
	verificar("investida derruba mobs pequenos sem bloquear", mob.esta_morto)
	chefe._physics_process(1.0)
	for tipo in ["pisao", "machado"]:
		chefe.global_position = Vector2.ZERO
		jogador.position = Vector2(50, 0)
		var antes: int = jogador.golpes
		verificar(tipo + " prepara sem dano", chefe.iniciar_ataque(tipo, jogador.position) and jogador.golpes == antes)
		if tipo == "machado":
			verificar("arco do machado acompanha a lâmina acima do chefe", chefe._impacto.z_as_relative and chefe._impacto.z_index > chefe.sprite.z_index)
		chefe._physics_process(1.0)
		chefe._physics_process(0.15)
		verificar(tipo + " acerta no impacto", jogador.golpes == antes + 1)
		verificar(tipo + " usa efeito próprio no impacto", chefe._impacto.visible and chefe._impacto.texture.resource_path == "res://Efeitos/minotauro/" + tipo + ".png")
		if tipo == "machado":
			for linha in 4:
				chefe._linha = linha
				for pose in [3, 4]:
					chefe._tocar("machado", pose)
					for quadro in 6:
						chefe._impacto.frame = quadro
						chefe._alinhar_arco_machado()
						var borda: Vector2 = chefe._impacto.position + (chefe._bordas_arco[quadro] * chefe._impacto.scale).rotated(chefe._impacto.rotation)
						var ponta: Vector2 = chefe._pontas_machado[chefe.sprite.frame]
						var esperado := Vector2(-8, 0) if linha == 3 else Vector2(8, 0)
						verificar("arco à frente da lâmina %d/%d/%d" % [linha, pose, quadro], (borda - ponta).distance_to(esperado) < 0.01)
		chefe._physics_process(0.1)
		verificar(tipo + " causa somente um golpe", jogador.golpes == antes + 1)
		chefe._physics_process(1.0)
		chefe._physics_process(1.0)
	chefe.iniciar_ataque("pisao", jogador.position)
	chefe.aplicar_congelamento(1.0)
	var tempo: float = chefe._tempo
	var quadro_efeito: int = chefe._impacto.frame
	chefe._physics_process(0.5)
	verificar("gelo pausa ataque e animação", chefe._tempo == tempo and chefe.velocity == Vector2.ZERO and chefe._impacto.frame == quadro_efeito)
	chefe._physics_process(1.0)
	chefe._limpar_efeitos()
	chefe.estado = chefe.Estado.LIVRE
	chefe.vida = roundi(chefe.vida_maxima * 0.4)
	chefe._physics_process(0.01)
	verificar("especial de 40% começa com rugido", chefe._furia_usada and chefe.estado == chefe.Estado.RUGINDO)
	chefe._physics_process(1.0)
	verificar("especial inicia primeira investida", chefe.ataque_atual == "investida" and chefe._fila_furia.size() == 3)
	chefe._limpar_efeitos()
	chefe._executar_furia()
	chefe._limpar_efeitos()
	chefe._executar_furia()
	chefe._limpar_efeitos()
	chefe._executar_furia()
	verificar("especial tem três investidas e pisão maior", chefe.ataque_atual == "pisao_furia" and chefe.RAIOS["pisao_furia"] > chefe.RAIOS["pisao"] and chefe._fila_furia.is_empty())
	verificar("especial usa onda de choque própria", chefe._impacto.texture.resource_path == "res://Efeitos/minotauro/furia.png")
	chefe._limpar_efeitos()
	chefe._executar_furia()
	verificar("especial termina sem repetir a mesma marca", not chefe._furia_ativa and chefe._furia_usada)
	var valido := true
	for pagina in ["movimento", "caminhada", "investida", "pisao", "machado", "furia"]:
		for linha in 4:
			chefe._linha = linha
			for quadro in 6:
				chefe._tocar(pagina, quadro)
				valido = valido and chefe._area_dano._contorno.size() >= 3
	verificar("área de acerto acompanha os 144 quadros", valido)
	var gerenciador = load("res://Codigos/Logicas/Gerenciador-de-ondas.gd").new()
	verificar("minotauro aparece nas ondas 10 e 60; dragão continua na 50", gerenciador.chefe_da_onda(10).id == "minotauro" and gerenciador.chefe_da_onda(60).id == "minotauro" and gerenciador.chefe_da_onda(50).id == "dragao_vermelho")
	gerenciador.free()
	var ouro: int = root.get_node("DadosJogo").moedas
	chefe.morrer()
	chefe.morrer()
	verificar("morte cancela efeito e premia uma vez", chefe.esta_morto and chefe._aviso == null and root.get_node("DadosJogo").moedas == ouro + 250)
	await create_timer(0.8).timeout
	verificar("morte remove o chefe", not is_instance_valid(chefe))
	cena.queue_free()
	await process_frame
	print("Falhas: ", falhas)
	quit(falhas)
