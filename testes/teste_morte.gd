extends SceneTree

# Rodar: godot --headless --path . --script res://testes/teste_morte.gd
# Carrega a cena de jogo de verdade, derruba o jogador e confere a tela de fim e o reset roguelite.
# ATENCAO: grava user://inventario.json (o reset salva o kit inicial); faça backup do user:// antes

const CAMINHO_PROGRESSO := "user://teste_morte_progresso.json"

var _falhas: int = 0
var _cena: Node
var _jogador: Node
var _progresso: Node
var _gerenciador: Node

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

func _rodar() -> void:
	# O _ready dos autoloads (Progresso.carregar) roda no primeiro quadro; espera para não sobrescrever o que o teste define
	await process_frame
	_progresso = root.get_node("Progresso")
	_progresso.caminho_save = CAMINHO_PROGRESSO
	# O clima do mundo fica no autoload Fazenda (as ondas o mudam): arquivo de teste, sem o save real
	var fazenda_isolada = root.get_node("Fazenda")
	fazenda_isolada.caminho_save = "user://teste_morte_fazenda.json"
	fazenda_isolada.apagar()
	# O _ready já carregou o progresso real do jogador (moradores, melhorias): começa do zero, só no arquivo do teste
	_progresso.apagar()
	var inventario = root.get_node("InventarioJogador")
	var dados_jogo = root.get_node("DadosJogo")
	inventario.limpar()
	inventario.criar_itens_iniciais()

	_cena = load("res://cenas/cenario.tscn").instantiate()
	root.add_child(_cena)
	# Como o jogo faz: os inimigos e efeitos procuram a cena atual
	current_scene = _cena
	await _quadros(10)
	await create_timer(0.2).timeout
	_jogador = _cena.get_node("Jogador")
	_gerenciador = _cena.get_node("enemySpawner/GerenciadorOndas")
	var interface = _cena.get_node("Interface")
	var tela_fim: Control = _cena.get_node("Interface/TelaFimPartida")
	var botao_voltar: Button = tela_fim.get_node("Centro/Painel/Linhas/BotaoVoltar")

	_verificar("partida iniciada ao carregar a cena", _progresso.partida_ativa, "")
	var posicao_inicial: Vector2 = _jogador.global_position
	var hp_inicial: int = _jogador.estatisticas.hp_maximo
	var defesa_inicial: int = _jogador.bonus_defesa
	var forca_inicial: int = _jogador.estatisticas.forca
	var sorte_inicial: int = _jogador.estatisticas.sorte
	_verificar("kit inicial: espada e escudo na mao", _jogador.usando_espada and _jogador.usando_escudo and not _jogador.usando_lanca, "")
	_verificar("kit inicial: armadura equipada", _jogador.usando_cabeca and _jogador.usando_corpo and _jogador.usando_luvas and _jogador.usando_botas, "")

	# --- equipa arma e escudo, compra um totem e junta ouro
	var espada = inventario.buscar_por_tipo("espada_basica")
	var escudo = inventario.buscar_por_tipo("escudo_basico")
	inventario.desequipar("arma")
	inventario.desequipar("escudo")
	await _quadros(5)
	var defesa_sem_escudo: int = _jogador.bonus_defesa
	inventario.equipar(espada)
	inventario.equipar(escudo)
	await _quadros(5)
	_verificar("espada e escudo equipados pelo modelo", _jogador.usando_espada and _jogador.usando_escudo, "espada=%s escudo=%s" % [_jogador.usando_espada, _jogador.usando_escudo])
	_verificar("escudo mudou a defesa/vida", _jogador.bonus_defesa > defesa_sem_escudo, "defesa=%d" % _jogador.bonus_defesa)
	var totem: Dictionary = root.get_node("DadosDosItems").obter_dados_item("item_1").duplicate()
	_jogador.aplicar_efeitos_item(totem)
	_jogador.itens_comprados.append(totem)
	_verificar("totem somou forca", _jogador.estatisticas.forca == forca_inicial + 3, "forca=%d" % _jogador.estatisticas.forca)
	dados_jogo.moedas = 500
	inventario.adicionar_arma_nova("machado")

	# --- morte sem curandeira: tela de fim
	_progresso.registrar_onda_iniciada(3)
	_progresso.registrar_onda_concluida(3, false, false)
	_progresso.brasas = 0
	_jogador.hp_atual = 1
	_jogador.receber_dano(999)
	await _quadros(5)
	_verificar("jogador morto", _jogador.estaMorto, "")
	_verificar("tela de fim de partida aberta", tela_fim.visible and interface._telas_abertas.has("fim_partida"), "")
	_verificar("partida encerrada e brasas creditadas", not _progresso.partida_ativa and _progresso.brasas == 2 and _progresso.ultimo_resultado["brasas"] == 2, "brasas=%d" % _progresso.brasas)
	_verificar("tela mostra a onda alcancada", tela_fim.get_node("%ValorOnda").text == "3" and tela_fim.get_node("%ValorBrasas").text == "+2 BRASAS", tela_fim.get_node("%ValorBrasas").text)
	_verificar("acoes do jogador desabilitadas", not _jogador.movimento_habilitado, "")
	_verificar("botao com foco (teclado e controle)", botao_voltar.has_focus(), "")
	var ev_fechar := InputEventAction.new()
	ev_fechar.action = "close_menu"
	ev_fechar.pressed = true
	interface._unhandled_input(ev_fechar)
	_verificar("B/Esc nao fecha a tela de fim", tela_fim.visible, "")
	_verificar("jogador nao toma dano morto", _jogador.estaMorto, "")

	# --- confirmar: volta ao acampamento com o kit inicial
	_jogador.reiniciar_para_nova_partida()
	interface._fechar_tela("fim_partida")
	await _quadros(5)
	_verificar("tela de fim fechada", not tela_fim.visible and not interface._telas_abertas.has("fim_partida"), "")
	_verificar("jogador vivo e livre", not _jogador.estaMorto and _jogador.movimento_habilitado, "")
	_verificar("volta para perto da fogueira", _jogador.global_position.distance_to(posicao_inicial) < 1.0, str(_jogador.global_position))
	_verificar("vida e estamina cheias", _jogador.hp_atual == _jogador.estatisticas.hp_maximo and is_equal_approx(_jogador.stamina, _jogador.stamina_maxima), "hp=%d" % _jogador.hp_atual)
	_verificar("de volta ao kit: espada e escudo na mao", _jogador.usando_espada and _jogador.usando_escudo and not _jogador.usando_lanca and not _jogador.usando_arco, "")
	_verificar("armadura continua equipada", _jogador.usando_cabeca and _jogador.usando_corpo and _jogador.usando_luvas and _jogador.usando_botas, "")
	_verificar("modelo: armadura, espada e escudo equipados; lanca e ferramentas na mochila",
			inventario.equipados["arma"] != null and inventario.equipados["arma"].tipo == "espada_basica" and inventario.equipados["escudo"] != null
			and inventario.equipados["corpo"] != null and inventario.indice_de(inventario.buscar_por_tipo("lanca_basica")) != -1
			and inventario.indice_de(inventario.buscar_por_tipo("enxada")) != -1 and inventario.buscar_por_tipo("machado") == null, str(inventario.equipados))
	_verificar("estatisticas voltaram ao inicio (vida, defesa, forca, sorte)",
			_jogador.estatisticas.hp_maximo == hp_inicial and _jogador.bonus_defesa == defesa_inicial
			and _jogador.estatisticas.forca == forca_inicial and _jogador.estatisticas.sorte == sorte_inicial and _jogador.itens_comprados.is_empty(),
			"hp=%d/%d defesa=%d/%d forca=%d/%d" % [_jogador.estatisticas.hp_maximo, hp_inicial, _jogador.bonus_defesa, defesa_inicial, _jogador.estatisticas.forca, forca_inicial])
	_verificar("ouro zerado (sem bolsa)", dados_jogo.moedas == 0, "moedas=%d" % dados_jogo.moedas)
	_verificar("nova partida em andamento com brasas guardadas", _progresso.partida_ativa and _progresso.abates == 0 and _progresso.brasas == 2, "")
	_verificar("gerenciador voltou para a onda 1", _gerenciador.onda_atual == 1 and not _gerenciador.onda_em_andamento, "onda=%d" % _gerenciador.onda_atual)
	var salvo = JSON.parse_string(FileAccess.get_file_as_string("user://inventario.json"))
	_verificar("inventario.json salvo com o kit inicial", salvo is Dictionary and salvo["equipados"]["arma"] != null and salvo["equipados"]["corpo"] != null, "")

	# --- equipar de novo depois do reset (a sincronia modelo <-> jogador continua valendo)
	inventario.equipar(inventario.buscar_por_tipo("espada_basica"))
	await _quadros(5)
	_verificar("depois do reset ainda da para equipar a espada", _jogador.usando_espada and _jogador.estatisticas.dano_arma > 0, "dano_arma=%d" % _jogador.estatisticas.dano_arma)
	inventario.desequipar("arma")
	await _quadros(3)

	# --- melhorias permanentes aplicadas
	var hp_sem: int = _jogador.estatisticas.hp_maximo
	var dano_sem: int = _jogador.estatisticas.dano_ataque
	var stamina_sem: float = _jogador.stamina_maxima
	_progresso.brasas = 500
	_progresso.comprar_melhoria("vigor")
	_progresso.comprar_melhoria("folego")
	_progresso.comprar_melhoria("couraca")
	await _quadros(2)
	_verificar("vigor sobe a vida maxima em 8%", _jogador.estatisticas.hp_maximo == roundi((40 + _jogador.estatisticas.vitalidade * 6) * 1.08) and _jogador.estatisticas.hp_maximo > hp_sem, "hp=%d (era %d)" % [_jogador.estatisticas.hp_maximo, hp_sem])
	_verificar("folego sobe a estamina maxima em 10%", is_equal_approx(_jogador.stamina_maxima, stamina_sem * 1.10), "stamina=%f" % _jogador.stamina_maxima)
	_verificar("couraca soma 4% na reducao de dano", is_equal_approx(_jogador.estatisticas.reducao_dano(), float(_jogador.estatisticas.defesa) / (_jogador.estatisticas.defesa + 50.0) + 0.04), "reducao=%f" % _jogador.estatisticas.reducao_dano())
	_progresso.comprar_melhoria("forca")
	_progresso.comprar_melhoria("bolsa")
	_verificar("forca soma 6% no dano", _jogador.estatisticas.dano_ataque >= dano_sem, "dano=%d" % _jogador.estatisticas.dano_ataque)
	_jogador.estatisticas.dano_arma = 20
	_jogador.estatisticas.calcular_estatisticas_derivadas()
	_verificar("dano = (arma + forca) x 1,06", _jogador.estatisticas.dano_ataque == roundi((20 + _jogador.estatisticas.forca) * 1.06), "dano=%d" % _jogador.estatisticas.dano_ataque)
	_jogador.atualizar_dano_arma()

	# --- Curandeira: reviver uma vez por partida; bolsa no reset
	_progresso.moradores = {"curandeira": true, "mistica": true}
	var maximo: int = _jogador.estatisticas.hp_maximo
	_jogador.hp_atual = 1
	_jogador.invulneravel = false
	_jogador.receber_dano(999)
	await _quadros(3)
	_verificar("curandeira revive o jogador", not _jogador.estaMorto and not tela_fim.visible, "")
	_verificar("reviveu com 50% da vida", _jogador.hp_atual == roundi(maximo * 0.5), "hp=%d de %d" % [_jogador.hp_atual, maximo])
	_verificar("2 s de invulnerabilidade (menos os quadros ja passados)", _jogador.invulneravel and _jogador.temporizador_invul > 1.5 and _jogador.temporizador_invul <= 2.0, "invul=%s t=%f" % [_jogador.invulneravel, _jogador.temporizador_invul])
	_jogador.invulneravel = false
	_jogador.hp_atual = 1
	_jogador.receber_dano(999)
	await _quadros(5)
	_verificar("segunda queda na mesma partida vai para a tela de fim", _jogador.estaMorto and tela_fim.visible, "")
	_jogador.reiniciar_para_nova_partida()
	interface._fechar_tela("fim_partida")
	await _quadros(3)
	_verificar("bolsa nivel 1 da 40 de ouro inicial", dados_jogo.moedas == 40, "moedas=%d" % dados_jogo.moedas)
	_verificar("nova partida libera outro reviver", _progresso.partida_ativa and not _progresso.reviveu_na_partida, "")

	# --- Mistica: checkpoint antes da primeira onda
	_progresso.checkpoint_max = 10
	var tela_mistica: Control = _cena.get_node("Interface/TelaMistica")
	root.get_node("EventosJogo").abrir_tela.emit("mistica")
	await _quadros(3)
	_verificar("tela da mistica abre", tela_mistica.visible, "")
	tela_mistica._ao_escolher(11)
	_verificar("checkpoint 11 escolhido: onda do gerenciador e ouro", _gerenciador.onda_atual == 11 and dados_jogo.moedas == 40 + 330, "onda=%d moedas=%d" % [_gerenciador.onda_atual, dados_jogo.moedas])
	root.get_node("EventosJogo").fechar_tela.emit("mistica")
	await _quadros(2)
	_gerenciador.iniciar_onda()
	await _quadros(2)
	_verificar("a partida comeca na onda do checkpoint", _gerenciador.onda_atual == 11 and _gerenciador.onda_em_andamento and _progresso.onda_comecou, "onda=%d" % _gerenciador.onda_atual)
	_verificar("com onda em andamento a mistica nao aceita mais", not _progresso.pode_escolher_checkpoint(), "")

	# --- Interagivel so entre ondas
	var interacao = _cena.get_node("PortalDaArena/InteracaoPortal")
	interacao.jogador_perto = true
	_verificar("passagem nao interage com onda em andamento", not interacao.pode_interagir(), "")
	_gerenciador.parar_ondas()
	_verificar("passagem interage entre as ondas", interacao.pode_interagir(), "")

	# O botão real agora leva à enfermaria, preservando o kit reiniciado.
	_jogador.receber_hitkill_chefe()
	await _quadros(4)
	_verificar("queda fatal abre confirmação", tela_fim.visible and _jogador.estaMorto, "")
	botao_voltar.pressed.emit()
	var transicao: Node = root.get_node("Transicao")
	for i in 600:
		await process_frame
		if not transicao.ocupada and current_scene.scene_file_path == "res://cenas/cidade/enfermaria.tscn":
			break
	_verificar("confirmar morte leva à enfermaria", current_scene.scene_file_path == "res://cenas/cidade/enfermaria.tscn" and not transicao.ocupada, "")
	var recuperado: Node = current_scene.get_node("Jogador")
	_verificar("recuperação cria jogador vivo e com vida", not recuperado.estaMorto and recuperado.hp_atual > 0, "")
	var atendimento: Node = root.get_node("EventosJogo").interface_p1()._telas["introducao"]
	for i in 120:
		await process_frame
		if atendimento.visible:
			break
	_verificar("Rosa inicia atendimento depois da chegada", atendimento.visible, "")
	while atendimento.visible:
		atendimento._espera = 0
		atendimento.avancar()
		await process_frame
	for i in 120:
		await process_frame
		if recuperado.movimento_habilitado:
			break
	_verificar("terminar atendimento devolve movimento", recuperado.movimento_habilitado and recuperado.visible, "")
	current_scene.queue_free()
	current_scene = null
	await _quadros(5)

	# limpeza
	if FileAccess.file_exists(CAMINHO_PROGRESSO):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CAMINHO_PROGRESSO))
	if FileAccess.file_exists("user://teste_morte_fazenda.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://teste_morte_fazenda.json"))
	quit(_falhas)
