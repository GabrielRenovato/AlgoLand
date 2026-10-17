extends SceneTree

# Rodar: godot --headless --path . --script res://testes/teste_transicoes.gd
# Percorre arena -> cidade -> fazenda -> casa -> dormir -> casa -> fazenda -> cidade -> arena com a cena de jogo de verdade (Transicao) e confere
# que ouro, inventario, vida, estamina, totens e a partida (Progresso, onda atual, checkpoint) atravessam as trocas sem
# virar morte nem reiniciar a partida; as zonas de passagem (caverna, porta, saida, cama), a caverna fechada durante a
# onda, o fade, a data e o sono (dia seguinte, cura, salvamento, acordar ao lado da cama).
# Execute apenas na cópia de testes com saves isolados.

const CAMINHO_PROGRESSO := "user://teste_transicoes_progresso.json"
const CAMINHO_CALENDARIO := "user://teste_transicoes_calendario.json"
const CAMINHO_FAZENDA := "user://teste_transicoes_fazenda.json"

var _falhas: int = 0
var _progresso: Node
var _calendario: Node
var _dados_jogo: Node
var _inventario: Node
var _transicao: Node
var _mortes := 0

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

# Espera um sinal (com ou sem argumentos) por ate `tempo` segundos; devolve se ele veio
func _esperar(sinal: Signal, tempo := 10.0) -> bool:
	var marca := {"ok": false}
	sinal.connect(func(_a = null): marca["ok"] = true, CONNECT_ONE_SHOT)
	var t := 0.0
	while not marca["ok"] and t < tempo:
		await process_frame
		t += 0.016
	return marca["ok"]

func _jogador() -> Node:
	return current_scene.get_node("Jogador")

# Leva o jogador ao centro da zona e espera a fisica notar a sobreposicao
func _ir_para_zona(zona: Node) -> void:
	_jogador().global_position = zona.global_position + Vector2(0, -9)
	await _fisica(4)

func _rodar() -> void:
	if ProjectSettings.get_setting("application/config/name") != "AlgoLand testes Carrasco":
		push_error("Execute em copia de testes com saves isolados.")
		quit(1)
		return
	await process_frame
	_progresso = root.get_node("Progresso")
	_calendario = root.get_node("Calendario")
	_dados_jogo = root.get_node("DadosJogo")
	_inventario = root.get_node("InventarioJogador")
	_transicao = root.get_node("Transicao")
	var caminho_progresso: String = _progresso.caminho_save
	var caminho_calendario: String = _calendario.caminho_save
	var fazenda_dados: Node = root.get_node("Fazenda")
	var caminho_fazenda: String = fazenda_dados.caminho_save
	fazenda_dados.caminho_save = CAMINHO_FAZENDA
	fazenda_dados.apagar()
	_progresso.caminho_save = CAMINHO_PROGRESSO
	_calendario.caminho_save = CAMINHO_CALENDARIO
	_progresso.apagar()
	_calendario.apagar()
	_transicao.limpar()
	_inventario.limpar()
	_inventario.criar_itens_iniciais()
	_dados_jogo.moedas = 0

	var arena: Node = load("res://cenas/cenario.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	await _quadros(10)
	await create_timer(0.3).timeout
	var jogador: Node = _jogador()
	jogador.jogador_morreu.connect(func(): _mortes += 1)
	var gerenciador: Node = arena.get_node("enemySpawner/GerenciadorOndas")

	# ---- estado da arena antes de sair: partida em andamento, ouro, vida, estamina, totem, checkpoint
	_progresso.registrar_onda_iniciada(3)
	_progresso.registrar_onda_concluida(2, false, false)
	_progresso.registrar_abate()
	_progresso.registrar_abate()
	_progresso.checkpoint_max = 10
	_progresso.brasas = 7
	_dados_jogo.moedas = 123
	gerenciador.onda_atual = 3
	var forca_antes: int = jogador.estatisticas.forca
	var totem := {"nome": "TOTEM DE TESTE", "efeitos": {"forca": 3}}
	jogador.aplicar_efeitos_item(totem)
	jogador.itens_comprados.append(totem.duplicate(true))
	jogador.hp_atual = 77
	jogador.stamina = 20.0
	var mochila_antes: int = _inventario.mochila.size()
	var equipados_antes: Array = _equipados()
	_verificar("arena: partida ativa com a onda 3 e 2 abates", _progresso.partida_ativa and _progresso.abates == 2 and gerenciador.onda_atual == 3, "")
	_verificar("totem somou forca (+3)", jogador.estatisticas.forca == forca_antes + 3, "")

	# O portal atual abre o menu da arena; a volta pede confirmação.
	var interface_arena: Node = root.get_node("EventosJogo").interface_p1()
	interface_arena._abrir_tela("mercante")
	await _quadros(4)
	var loja_arena: Node = interface_arena._telas["mercante"]
	_verificar("portal oferece menu da arena", loja_arena._modo_arena and loja_arena._botao_cidade.visible, "")
	loja_arena._ao_voltar_para_cidade()
	_verificar("voltar à cidade pede confirmação", loja_arena._confirmacao.visible and not _transicao.ocupada, "")
	interface_arena._fechar_tela("mercante")
	# Exercita também a viagem que preserva o estado (usada pelo fluxo de introdução).
	_transicao.sair_da_arena()

	_verificar("ao abrir, a Transicao fica ocupada e o jogador travado", _transicao.ocupada, "")
	_verificar("fade para preto", await _esperar_escuro(), "")
	_verificar("cidade carregada ao sair da arena", await _esperar(_transicao.troca_concluida) and current_scene.name == "cidade")
	await _quadros(4)
	current_scene.get_node("TrilhaFazenda").abrir_tela()
	_verificar("fazenda carregada", await _esperar(_transicao.troca_concluida) and current_scene.name == "fazenda", "cena=%s" % current_scene.name)
	await _quadros(4)
	var fazenda: Node = current_scene
	jogador = _jogador()
	jogador.jogador_morreu.connect(func(): _mortes += 1)
	_verificar("fazenda: chega pela trilha a leste", jogador.global_position.distance_to(fazenda.get_node("Terrains/Chegada_cidade").global_position) < 2.0, str(jogador.global_position))
	_verificar("fazenda: chegada fora da zona de retorno", not fazenda.get_node("Terrains/PassagemCidade").jogador_perto)
	_conferir_estado("fazenda", jogador, forca_antes + 3, mochila_antes, equipados_antes, true)
	_verificar("fazenda: partida do Progresso segue ativa, com os abates e o checkpoint", _progresso.partida_ativa and _progresso.abates == 2 and _progresso.checkpoint_max == 10 and _progresso.brasas == 7, "")
	_verificar("fazenda: sem gerenciador de ondas e sem inimigos", get_nodes_in_group("gerenciador_ondas").is_empty() and get_nodes_in_group("enemy").is_empty(), "")
	_verificar("fazenda: nao conta como morte", _mortes == 0 and _progresso.ultimo_resultado.is_empty() and not jogador.estaMorto, "")
	_verificar("fazenda: estacao do calendario (primavera)", fazenda.get_node("Terrains/Estacoes").estacao_atual == 0, "")
	var hud: Node = get_nodes_in_group("hud")[0]
	await _quadros(3)
	_verificar("fazenda: HUD com a data e o titulo", hud.rotulo_data.text == "SEG  PRIMAVERA - DIA 1" and hud.rotulo_onda.text == "FAZENDA", "%s / %s" % [hud.rotulo_data.text, hud.rotulo_onda.text])
	_verificar("fazenda: camera presa ao mapa", jogador.camera.limit_right == 1152 and jogador.camera.limit_bottom == 768 and jogador.camera.limit_left == 0, "")
	# jogador nao morre fora da arena
	jogador.invulneravel = false
	jogador.receber_dano(99999)
	await _quadros(2)
	_verificar("fazenda: dano fatal nao mata (vida minima 1, sem tela de fim)", jogador.hp_atual == 1 and not jogador.estaMorto and _mortes == 0, "hp=%d" % jogador.hp_atual)
	jogador.hp_atual = 77
	jogador.invulneravel = false

	# ---- colisoes da fazenda: a base da casa bloqueia, o telhado nao
	await _testar_colisoes_fazenda(fazenda, jogador)

	# ---- fazenda -> casa pela porta
	var porta: Node = fazenda.get_node("Terrains/PortaCasa")
	await _ir_para_zona(porta)
	_verificar("porta: jogador na frente ativa a zona", porta.jogador_perto and porta.disponivel_para_interacao(), "")
	porta.abrir_tela()
	_verificar("casa carregada", await _esperar(_transicao.troca_concluida) and current_scene.name == "casa", "cena=%s" % current_scene.name)
	await _quadros(4)
	var casa: Node = current_scene
	jogador = _jogador()
	_verificar("casa: jogador entra pela porta (marcador Chegada_entrada)", jogador.global_position.distance_to(casa.get_node("Chegada_entrada").global_position) < 2.0, "")
	_conferir_estado("casa", jogador, forca_antes + 3, mochila_antes, equipados_antes)
	await _quadros(3)
	hud = get_nodes_in_group("hud")[0]
	_verificar("casa: HUD com a data e o titulo CASA", hud.rotulo_data.text == "SEG  PRIMAVERA - DIA 1" and hud.rotulo_onda.text == "CASA", hud.rotulo_onda.text)
	await _testar_colisoes_casa(casa, jogador)

	# ---- cama: confirmacao, NAO fecha sem dormir
	var cama: Node = casa.get_node("Cama")
	await _ir_para_zona(cama)
	_verificar("cama: jogador perto ativa a zona", cama.jogador_perto and cama.disponivel_para_interacao(), "")
	var interface: Node = casa.get_node("Interface")
	var tela: Control = casa.get_node("Interface/TelaDormir")
	_verificar("tela DORMIR? comeca fechada", not tela.visible, "")
	cama.abrir_tela()
	await _quadros(3)
	_verificar("interagir com a cama abre DORMIR?", tela.visible, "")
	_verificar("DORMIR? mostra o dia seguinte", tela.get_node("%Detalhe").text == "AMANHA: PRIMAVERA - DIA 2", tela.get_node("%Detalhe").text)
	# Controle: o foco comeca em SIM e NAO esta ao alcance (esquerda/direita ou baixo/cima), B/Esc fecha sem dormir
	tela.get_node("%BotaoNao").grab_focus()
	tela.focar_inicio()
	await _quadros(2)
	var botao_sim: Button = tela.get_node("%BotaoSim")
	var botao_nao: Button = tela.get_node("%BotaoNao")
	_verificar("DORMIR? controle: o foco comeca em SIM", root.gui_get_focus_owner() == botao_sim, str(root.gui_get_focus_owner()))
	var alcance := false
	for lado in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		if botao_sim.find_valid_focus_neighbor(lado) == botao_nao:
			alcance = true
	_verificar("DORMIR? controle: NAO e alcancavel a partir de SIM", alcance, "")
	_verificar("DORMIR? controle: os dois botoes recebem foco", botao_sim.focus_mode == Control.FOCUS_ALL and botao_nao.focus_mode == Control.FOCUS_ALL, "")
	var fechar := InputEventAction.new()
	fechar.action = "close_menu"
	fechar.pressed = true
	Input.parse_input_event(fechar)
	await _quadros(3)
	_verificar("DORMIR? controle: B/Esc fecha sem dormir", not tela.visible and _calendario.dia == 1 and not _transicao.ocupada, "dia=%d visivel=%s" % [_calendario.dia, tela.visible])
	cama.abrir_tela()
	await _quadros(3)
	_verificar("DORMIR? reabre depois do B/Esc", tela.visible, "")
	tela.get_node("%BotaoNao").pressed.emit()
	await _quadros(3)
	_verificar("NAO fecha a tela e nao passa o dia", not tela.visible and _calendario.dia == 1 and not _transicao.ocupada, "dia=%d" % _calendario.dia)
	_verificar("jogador volta a se mover depois de fechar", jogador.movimento_habilitado, "")

	# ---- dormir de verdade: dia 30 (vira a estacao), cura total, salvamento, acorda ao lado da cama
	_calendario.dia = 30
	jogador.hp_atual = 33
	jogador.stamina = 5.0
	_progresso.salvar()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CAMINHO_PROGRESSO))
	cama.abrir_tela()
	await _quadros(3)
	tela.get_node("%BotaoSim").pressed.emit()
	await _quadros(2)
	_verificar("SIM fecha a tela e comeca o sono (Transicao ocupada)", not tela.visible and _transicao.ocupada, "")
	# a cama fica ocupada: o jogador some (o Character Base nao tem pose deitada), o cobertor respira e os Z sobem
	var cama_sprite: Node = casa.get_node("Objetos3D/CamaDormindo")
	await _quadros(5)
	_verificar("cama ocupada: jogador some, cobertor e Z na cama", cama_sprite.deitado and not jogador.visible and cama_sprite.get_node_or_null("Cobertor") != null
			and get_nodes_in_group("z_dormindo").size() >= 1 and not _transicao.esta_escuro(), "deitado=%s visivel=%s" % [cama_sprite.deitado, jogador.visible])
	var cabeca: Node = cama_sprite.get_node_or_null("Cabeca")
	_verificar("a cabeca do jogador aparece no travesseiro (corpo, roupa e cabelo dele recortados) com os olhos fechados",
			cabeca != null and cabeca.get_node_or_null("sprite_corpo") != null and cabeca.get_node_or_null("sprite_cabelo") != null
			and cabeca.get_node("sprite_cabelo").texture == jogador.sprite_cabelo.texture and cabeca.get_node("sprite_corpo").region_enabled
			and cabeca.get_child_count() >= 3 + 4 and cabeca.get_index() < cama_sprite.get_node("Cobertor").get_index(), "")
	var escala_min := 9.0
	var escala_max := 0.0
	for i in 70:
		await process_frame
		if is_instance_valid(cama_sprite.get_node_or_null("Cobertor")):
			var e: float = cama_sprite.get_node("Cobertor").scale.y
			escala_min = minf(escala_min, e)
			escala_max = maxf(escala_max, e)
	_verificar("o cobertor respira (a escala em y sobe e desce)", escala_max - escala_min > 0.02, "%.3f..%.3f" % [escala_min, escala_max])
	_verificar("dormiu (sinal)", await _esperar(_transicao.dormiu, 12.0), "")
	_verificar("acordou: jogador de volta, cama normal (sem cabeca, cobertor nem Z)", jogador.visible and not cama_sprite.deitado and cama_sprite.get_node_or_null("Cobertor") == null
			and not is_instance_valid(cabeca)
			and get_nodes_in_group("z_dormindo").is_empty(), "")
	_verificar("dormir: dia 31, verao (a estacao virou)", _calendario.dia == 31 and _calendario.estacao() == 1, "dia=%d" % _calendario.dia)
	_verificar("dormir: cura total e estamina cheia", jogador.hp_atual == jogador.estatisticas.hp_maximo and is_equal_approx(jogador.stamina, jogador.stamina_maxima), "hp=%d stamina=%.1f" % [jogador.hp_atual, jogador.stamina])
	_verificar("dormir: calendario salvo (dia 31)", int(JSON.parse_string(FileAccess.get_file_as_string(CAMINHO_CALENDARIO)).get("dia", 0)) == 31, "")
	_verificar("dormir: progresso salvo", FileAccess.file_exists(CAMINHO_PROGRESSO), "")
	_verificar("dormir: acorda ao lado da cama", jogador.global_position.distance_to(casa.get_node("Chegada_cama").global_position) < 2.0, str(jogador.global_position))
	_verificar("dormir: jogador liberado e Transicao livre", jogador.movimento_habilitado and not _transicao.ocupada and not _transicao.esta_escuro(), "")
	_verificar("dormir: nao e morte (partida, abates e onda intactos)", _progresso.partida_ativa and _progresso.abates == 2 and _mortes == 0 and _progresso.ultimo_resultado.is_empty(), "")
	_verificar("dormir: ouro, forca e inventario intactos", _dados_jogo.moedas == 123 and jogador.estatisticas.forca == forca_antes + 3 and _inventario.mochila.size() == mochila_antes, "")
	_verificar("dormir: HUD com a nova data (VERAO - DIA 1)", hud.rotulo_data.text == "QUA  VERAO - DIA 1", hud.rotulo_data.text)
	_verificar("dormir: manha seguinte", is_equal_approx(_transicao.hora_salva, 6.0), "hora=%.2f" % _transicao.hora_salva)
	hud.faixa_banner.hide()

	# ---- casa -> fazenda pela saida (o vao da parede sul)
	jogador.hp_atual = 61
	var saida: Node = casa.get_node("SaidaCasa")
	await _ir_para_zona(saida)
	_verificar("saida: jogador no vao ativa a zona", saida.jogador_perto, "")
	saida.abrir_tela()
	_verificar("de volta a fazenda", await _esperar(_transicao.troca_concluida) and current_scene.name == "fazenda", "cena=%s" % current_scene.name)
	await _quadros(4)
	fazenda = current_scene
	jogador = _jogador()
	_verificar("sair da casa: jogador na frente da porta", jogador.global_position.distance_to(fazenda.get_node("Terrains/Chegada_porta").global_position) < 2.0, "")
	_verificar("fazenda no dia 31: verao", fazenda.get_node("Terrains/Estacoes").estacao_atual == 1, "")
	_verificar("fazenda: vida atravessou a porta (61)", jogador.hp_atual == 61, "hp=%d" % jogador.hp_atual)
	_verificar("fazenda: o mesmo horario (manha) e a data nova no HUD", get_nodes_in_group("hud")[0].rotulo_data.text == "QUA  VERAO - DIA 1", "")
	var luz: Node = get_nodes_in_group("iluminacao")[0]
	_verificar("fazenda: hora do dia segue de onde estava (6h)", absf(luz.hora - 6.0) < 0.2, "hora=%.2f" % luz.hora)

	# ---- fazenda -> cidade pela trilha a leste -> arena
	var caverna_fazenda: Node = fazenda.get_node("Terrains/PassagemCidade")
	await _ir_para_zona(caverna_fazenda)
	_verificar("trilha da cidade: zona ativa", caverna_fazenda.jogador_perto and caverna_fazenda.disponivel_para_interacao(), "")
	caverna_fazenda.abrir_tela()
	_verificar("cidade carregada ao sair da fazenda", await _esperar(_transicao.troca_concluida) and current_scene.name == "cidade")
	await _quadros(4)
	_transicao.entrar_na_arena()
	_verificar("de volta a arena", await _esperar(_transicao.troca_concluida) and current_scene.name == "cenario", "cena=%s" % current_scene.name)
	await _quadros(4)
	await create_timer(0.3).timeout
	arena = current_scene
	jogador = _jogador()
	gerenciador = arena.get_node("enemySpawner/GerenciadorOndas")
	_verificar("arena: jogador na frente da caverna", jogador.global_position.distance_to(arena.get_node("Terrains/Chegada_portal").global_position) < 2.0, str(jogador.global_position))
	_verificar("arena: a partida continua (onda 3, nao reiniciou)", gerenciador.onda_atual == 3 and _progresso.partida_ativa, "onda=%d" % gerenciador.onda_atual)
	_verificar("arena: abates, onda maxima e ondas concluidas da partida intactos", _progresso.abates == 2 and _progresso.onda_maxima == 3 and _progresso.ondas_concluidas == 1, "abates=%d onda_max=%d" % [_progresso.abates, _progresso.onda_maxima])
	_verificar("arena: checkpoint e brasas intactos", _progresso.checkpoint_max == 10 and _progresso.brasas == 7, "")
	_verificar("arena: ouro (123) nao voltou ao inicial", _dados_jogo.moedas == 123, "ouro=%d" % _dados_jogo.moedas)
	_verificar("arena: vida (61), totem, mochila e equipamento intactos", jogador.hp_atual == 61 and jogador.estatisticas.forca == forca_antes + 3 and _inventario.mochila.size() == mochila_antes and _equipados() == equipados_antes, "hp=%d" % jogador.hp_atual)
	_verificar("arena: sem morte, sem fim de partida", _mortes == 0 and _progresso.ultimo_resultado.is_empty() and not jogador.estaMorto, "")
	_verificar("arena: estacao do calendario (verao, dia 31)", arena.get_node("Terrains/Estacoes").estacao_atual == 1, "")
	_verificar("arena: HUD mostra ONDA 3 e a data", get_nodes_in_group("hud")[0].rotulo_onda.text == "ONDA 3" and get_nodes_in_group("hud")[0].rotulo_data.text == "QUA  VERAO - DIA 1", get_nodes_in_group("hud")[0].rotulo_onda.text)
	_verificar("arena: Transicao livre (sem fade preso)", not _transicao.ocupada and not _transicao.esta_escuro() and not _transicao.retornando, "")
	# A onda 3 ainda comeca normalmente e o evento nao quebra
	gerenciador.iniciar_onda()
	await _quadros(5)
	_verificar("arena: iniciar a onda 3 funciona e continua a partida", gerenciador.onda_em_andamento and gerenciador.onda_atual == 3 and _progresso.onda_comecou, "")
	var caverna_arena: Node = arena.get_node("PortalDaArena/InteracaoPortal")
	await _ir_para_zona(caverna_arena)
	_verificar("arena: caverna fechada durante a onda", not caverna_arena.disponivel_para_interacao(), "")

	# ---- morte de verdade na arena depois da viagem: o calendario nao volta
	var dia_antes: int = _calendario.dia
	gerenciador.parar_ondas()
	await _quadros(2)
	_verificar("parar ondas (morte) nao volta o calendario", _calendario.dia == dia_antes, "dia=%d" % _calendario.dia)

	arena.queue_free()
	await _quadros(3)
	_progresso.apagar()
	_calendario.apagar()
	_transicao.limpar()
	_progresso.caminho_save = caminho_progresso
	_calendario.caminho_save = caminho_calendario
	await _quadros(2)
	fazenda_dados.apagar()
	if FileAccess.file_exists(CAMINHO_FAZENDA):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CAMINHO_FAZENDA))
	fazenda_dados.caminho_save = caminho_fazenda
	print("FALHAS: ", _falhas)
	quit(_falhas)

func _esperar_escuro() -> bool:
	var t := 0.0
	while not _transicao.esta_escuro() and t < 3.0:
		await process_frame
		t += 0.016
	return _transicao.esta_escuro()

func _equipados() -> Array:
	var lista := []
	for slot in _inventario.equipados:
		var item = _inventario.equipados[slot]
		lista.append("%s:%s" % [slot, item.tipo if item != null else "-"])
	lista.sort()
	return lista

# A estamina regenera sozinha (30/s): so a primeira chegada, logo depois da saida da arena, ainda a mostra abaixo do maximo
func _conferir_estado(onde: String, jogador: Node, forca_esperada: int, mochila: int, equipados: Array, conferir_estamina := false) -> void:
	_verificar("%s: ouro 123 intacto" % onde, _dados_jogo.moedas == 123, "ouro=%d" % _dados_jogo.moedas)
	_verificar("%s: vida 77 atravessou" % onde, jogador.hp_atual == 77, "hp=%d" % jogador.hp_atual)
	if conferir_estamina:
		_verificar("%s: estamina atravessou (nao voltou a 100)" % onde, jogador.stamina < jogador.stamina_maxima - 1.0, "stamina=%.1f" % jogador.stamina)
	_verificar("%s: totem comprado reaplicado (forca)" % onde, jogador.estatisticas.forca == forca_esperada and jogador.itens_comprados.size() == 1, "forca=%d itens=%d" % [jogador.estatisticas.forca, jogador.itens_comprados.size()])
	_verificar("%s: mochila e equipamento intactos" % onde, _inventario.mochila.size() == mochila and _equipados() == equipados, "")
	_verificar("%s: HUD com a vida certa" % onde, get_nodes_in_group("hud")[0].rotulo_vida.text == "77/%d" % jogador.estatisticas.hp_maximo, get_nodes_in_group("hud")[0].rotulo_vida.text)

# Consulta fisica direta: a base da casa bloqueia, a area do telhado nao
func _testar_colisoes_fazenda(fazenda: Node, jogador: Node) -> void:
	var casa: Node2D = fazenda.get_node("Terrains/Objetos3D/Casa")
	var espaco: PhysicsDirectSpaceState2D = root.get_world_2d().direct_space_state
	var base: Vector2 = casa.global_position
	var parede: bool = _ponto_bloqueado(espaco, base + Vector2(-20, -12))
	var telhado: bool = _ponto_bloqueado(espaco, base + Vector2(-20, -70))
	var frente: bool = _ponto_bloqueado(espaco, base + Vector2(-20, 14))
	_verificar("casa: a parede (base) bloqueia", parede, "")
	_verificar("casa: o telhado nao bloqueia (colisao so na base)", not telhado, "")
	_verificar("casa: a frente da porta e livre", not frente, "")
	# profundidade: atras do telhado o desenho fica translucido, na frente continua opaco
	var grupo: Node = fazenda.get_node("Terrains/Objetos3D")
	jogador.global_position = base + Vector2(0, -60)
	await _quadros(40)
	_verificar("jogador atras do telhado: casa translucida (alfa %.2f)" % casa.modulate.a, casa.modulate.a < 0.75, "")
	jogador.global_position = base + Vector2(0, 40)
	await _quadros(40)
	_verificar("jogador na frente da casa: opaca (alfa %.2f)" % casa.modulate.a, casa.modulate.a > 0.95, "")
	_verificar("casa tem z pela base (profundidade_grupo)", casa.z_index == preload("res://codigo/globais/profundidade.gd").z_de(base.y), "")
	_verificar("borda do mapa e a caverna da fazenda bloqueiam", _ponto_bloqueado(espaco, Vector2(4, 300)) and _ponto_bloqueado(espaco, Vector2(500, 668)), "")

func _testar_colisoes_casa(casa: Node, _jogador_no: Node) -> void:
	var espaco: PhysicsDirectSpaceState2D = root.get_world_2d().direct_space_state
	var ok_paredes: bool = _ponto_bloqueado(espaco, Vector2(96, -20)) and _ponto_bloqueado(espaco, Vector2(-20, 50)) and _ponto_bloqueado(espaco, Vector2(210, 50)) and _ponto_bloqueado(espaco, Vector2(20, 120))
	_verificar("casa: paredes (norte, lados, sul) bloqueiam", ok_paredes, "")
	_verificar("casa: o vao da porta e o centro do piso estao livres", not _ponto_bloqueado(espaco, Vector2(128, 198)) and not _ponto_bloqueado(espaco, Vector2(160, 150)), "")
	_verificar("casa: cama, bau, estante e mesa bloqueiam", _ponto_bloqueado(espaco, Vector2(216, 95)) and _ponto_bloqueado(espaco, Vector2(40, 73)) and _ponto_bloqueado(espaco, Vector2(104, 60)) and _ponto_bloqueado(espaco, Vector2(88, 133)), "")
	_verificar("casa: a chegada ao acordar (Chegada_cama) esta livre", not _ponto_bloqueado(espaco, casa.get_node("Chegada_cama").global_position + Vector2(0, 9)), "")
	# A colisao da cama tem a largura exata do desenho (200..232): o jogador encosta de lado, sem folga artificial
	# (so o circulo de 5 px de raio dos pes: um ponto a 5 px da borda ainda toca, a 6 px ja esta livre).
	# A cama fica encostada na parede leste, entao so o lado oeste e acessivel.
	_verificar("casa: a colisao da cama e exata (encosta de lado, sem alargar)", _ponto_bloqueado(espaco, Vector2(196, 95)) and not _ponto_bloqueado(espaco, Vector2(194, 95)), "")
	# A cama e fatiada em faixas de profundidade (alinhadas a grade de 8 px): o jogador do lado fica NA FRENTE das faixas da
	# altura dele e atras so das que estao abaixo dos pes dele (uma cama inteira com z pela base cortava o jogador encostado)
	var Prof := preload("res://codigo/globais/profundidade.gd")
	var faixas: Array = []
	for filho in casa.get_node("Objetos3D").get_children():
		if filho.name.begins_with("Cama_f"):
			faixas.append(filho)
	_verificar("casa: a cama e feita de faixas horizontais (uma por faixa de 8 px da profundidade)", faixas.size() >= 7 and faixas.size() <= 9, "faixas=%d" % faixas.size())
	var soma_alturas := 0.0
	var contiguas := true
	var anterior_base := -1.0
	for f in faixas:
		var h: float = f.texture.get_size().y
		soma_alturas += h
		var topo: float = f.position.y + f.offset.y
		contiguas = contiguas and (anterior_base < 0.0 or absf(topo - anterior_base) < 0.01)
		anterior_base = topo + h
	_verificar("casa: as faixas somam os 58 px da cama, sem buracos nem sobreposicao", is_equal_approx(soma_alturas, 58.0) and contiguas, "soma=%.1f" % soma_alturas)
	var z_do_jogador_ao_lado: int = Prof.z_de(94.0)   # pes do jogador no meio da cama
	var atras_do_jogador := 0
	var na_frente := 0
	for f in faixas:
		if f.z_index <= z_do_jogador_ao_lado:
			atras_do_jogador += 1
		else:
			na_frente += 1
	_verificar("casa: jogador ao lado (pes y=36): as faixas da altura dele ficam atras e so as de baixo na frente", atras_do_jogador >= 3 and na_frente >= 3, "atras=%d frente=%d" % [atras_do_jogador, na_frente])
	var z_pes_abaixo: int = Prof.z_de(124.0)
	_verificar("casa: jogador no pe da cama (y>=60): na frente de todas as faixas", faixas.all(func(f): return f.z_index <= z_pes_abaixo), "")

# Ponto do chao (onde fica o circulo de colisao dos pes do jogador: raio 5) toca algum corpo da camada "mundo" (64)?
func _ponto_bloqueado(espaco: PhysicsDirectSpaceState2D, ponto: Vector2) -> bool:
	var forma := CircleShape2D.new()
	forma.radius = 5.0
	var consulta := PhysicsShapeQueryParameters2D.new()
	consulta.shape = forma
	consulta.transform = Transform2D(0.0, ponto)
	consulta.collision_mask = 64
	return not espaco.intersect_shape(consulta, 1).is_empty()
