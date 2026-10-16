extends SceneTree

# Cena mínima para conferir F3, troca de onda e cancelamento de spawns sem carregar os saves da partida.
var _falhas := 0

class JogadorTeste extends Node2D:
	var estaMorto := false
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
	var cena := Node2D.new()
	cena.name = "cenario"
	root.add_child(cena)
	current_scene = cena
	var jogador := JogadorTeste.new()
	jogador.name = "Jogador"
	jogador.position = Vector2(1000, 1000)
	cena.add_child(jogador)
	var mercador := Node2D.new()
	mercador.name = "Merchant"
	cena.add_child(mercador)
	var spawner: Node = load("res://codigo/logica/slime_spawner.gd").new()
	spawner.name = "enemySpawner"
	spawner.atraso_spawn = 1.0
	var ponto := Marker2D.new()
	spawner.add_child(ponto)
	var gerenciador: Node = load("res://codigo/logica/gerenciador_de_ondas.gd").new()
	gerenciador.name = "GerenciadorOndas"
	gerenciador.chance_onda_bonus = 0.0
	gerenciador.chance_evento = 0.0
	spawner.add_child(gerenciador)
	cena.add_child(spawner)
	for i in 3:
		await process_frame
	await create_timer(0.1).timeout
	var progresso := root.get_node("Progresso")
	var dados := root.get_node("DadosJogo")
	var ouro_antes: int = dados.moedas
	var painel: Node = root.get_node("PainelDebug")
	var evento := InputEventKey.new()
	evento.keycode = KEY_F3
	evento.pressed = true
	painel._unhandled_key_input(evento)
	_verificar("F3 abre o debugger", painel._painel.visible)
	_verificar("F3 compacto não usa rolagem", painel._painel.get_child(0).get_children().all(func(no): return not no is ScrollContainer))
	var indice_categoria: int = painel._opcoes.keys().find("ONDAS")
	painel._categoria.select(indice_categoria)
	painel._categoria.item_selected.emit(indice_categoria)
	_verificar("dropdown oferece os dois avanços", painel._acao.item_count == 2 and painel._acao.get_item_text(0) == "AVANCAR 1" and painel._acao.get_item_text(1) == "AVANCAR 10")
	_verificar("conjuntos têm as três opções de equipar completas", painel._opcoes["CONJUNTOS"].slice(0, 3).all(func(opcao): return String(opcao[0]).contains("EQUIPAR")))
	# Cancela a primeira leva ainda dentro do await que conclui o spawn do primeiro inimigo.
	gerenciador.iniciar_onda()
	painel._executar_selecao()
	painel._executar_selecao()
	await create_timer(0.3).timeout
	_verificar("AVANCAR 1 começa a onda 2 e ignora clique duplicado durante a troca", gerenciador.onda_atual == 2 and gerenciador.onda_em_andamento)
	_verificar("primeiro inimigo da onda descartada foi removido", get_nodes_in_group("enemy").size() == 1)
	await create_timer(1.15).timeout
	_verificar("leva antiga não retoma depois do timer", get_nodes_in_group("enemy").size() == 2)
	_verificar("pular não registra abates, vitórias ou ouro", progresso.abates == 0 and progresso.ondas_concluidas == 0 and dados.moedas == ouro_antes)
	painel._acao.select(1)
	painel._executar_selecao()
	await create_timer(0.3).timeout
	_verificar("AVANCAR 10 começa a onda 12", gerenciador.onda_atual == 12 and gerenciador.onda_em_andamento)
	painel._atualizar_estado()
	_verificar("painel mostra a onda atual", "ONDA 12" in painel._rotulo_estado.text)
	gerenciador.parar_ondas()
	gerenciador.onda_atual = 20
	progresso.onda_comecou = false
	progresso.onda_inicial = 5
	await gerenciador.avancar_onda_debug()
	_verificar("checkpoint não substitui a onda escolhida no debug", gerenciador.onda_atual == 21)
	paused = true
	await gerenciador.avancar_onda_debug()
	_verificar("avanço não acontece durante pausa", gerenciador.onda_atual == 21)
	paused = false
	jogador.estaMorto = true
	await gerenciador.avancar_onda_debug()
	_verificar("avanço não revive o jogador", gerenciador.onda_atual == 21 and jogador.estaMorto)
	jogador.estaMorto = false
	gerenciador.parar_ondas()
	await create_timer(1.2).timeout
	_verificar("parar ondas cancela todos os spawns restantes", get_nodes_in_group("enemy").is_empty())
	gerenciador.onda_atual = 9
	await gerenciador.avancar_onda_debug()
	await create_timer(1.3).timeout
	var chefes := get_nodes_in_group("enemy")
	_verificar("onda 10 usa somente o minotauro, sem mistura de escolta", gerenciador.escolta_chefe == 0 and gerenciador.total_inimigos_onda == 1 and chefes.size() == 1 and chefes[0].scene_file_path == "res://cenas/inimigos/minotauro.tscn")
	gerenciador.parar_ondas()
	await process_frame
	print("Falhas: ", _falhas)
	painel._ao_onda_dragao()
	await create_timer(0.4).timeout
	var dragoes := get_nodes_in_group("boss_dragao")
	_verificar("F3 chama somente o dragão na onda 50", gerenciador.onda_atual == 50 and dragoes.size() == 1 and get_nodes_in_group("enemy").size() == 1)
	if dragoes.size() == 1:
		painel._ao_ataque_dragao("cauda")
		_verificar("F3 inicia varrida com aviso", dragoes[0].ataque_atual == "cauda" and dragoes[0]._area_golpe != null)
	gerenciador.parar_ondas()
	await process_frame
	_verificar("trocar onda remove dragão e aviso pendente", get_nodes_in_group("boss_dragao").is_empty())
	print("Falhas finais: ", _falhas)
	quit(_falhas)
