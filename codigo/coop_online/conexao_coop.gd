extends Node
## Até quatro jogadores. Tudo passa pelo servidor de salas (relay): conexão direta entre aparelhos falhava em rede
## de celular e em muitos Wi-Fi, e a sala ficava parada em "conectando".
signal salas_recebidas(salas: Array)
signal mudou
signal erro(texto: String)
signal pacote(dados: Dictionary)
signal encerrou(motivo: String)
signal jogador_saiu(id: String)
signal prontos_mudaram
const Duelo := preload("res://codigo/duelo/conexao_duelo.gd")
const Catalogo := preload("res://codigo/fendas/catalogo_andares.gd")
const LIMITE_PACOTE := 262144
## Estados velhos não servem: com fila curta o envio descarta em vez de acumular segundos de atraso em upload fraco.
const LIMITE_FILA_ESTADOS := 16384
## Pacotes de um quadro seguem juntos numa mensagem; o servidor recusa mensagens acima de 64 KiB.
const LIMITE_LOTE := 48000
const MAX_JOGADORES := 4
## Reanimar um aliado: segurar a ação de interagir por este tempo; ele volta com pouca vida.
const TEMPO_REVIVER := 1.5
const FRACAO_REVIVER := 0.2
const ALCANCE_REVIVER := 36.0
## Um parceiro na sala. O anfitrião tem um por convidado (estrela); cada convidado tem só o do anfitrião.
class Par extends RefCounted:
	var id := ""
	var conectado := false
	var recebeu := 0
	var ping_ms := -1
var eu := ""
var codigo := ""
var dono := ""
var jogadores: Array = []
var ativo := false
var conectado := false
var andar := 1
var permitir_viagem := false
var ping_ms := -1
var _ws: WebSocketPeer
var _pares: Dictionary = {}
var _autenticou := false
var _jogador: Node2D
var _pedido: Dictionary = {}
var _relogio := 0.0
var _prazo := 0
var _cena: Node
var motivo_final := ""
var _fila: Array[Dictionary] = []
## Movimento não disputa as 256 vagas dos eventos e lotes do mundo.
var _movimentos: Dictionary = {}
var _encerrados: Array[Dictionary] = []
var _n_conectados := 0
## Pacotes do quadro aguardando o envio em lote: {"p": destino ("*" = todos), "e": 1 se estado, "m": pacote}.
var _saida: Array[Dictionary] = []
var _saida_bytes := 0
## Convidados que já se declararam prontos para o próximo andar (id -> bool). O anfitrião decide, os convidados só veem.
var prontos_avanco: Dictionary = {}

func retirar_pacotes(nivel: int) -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []
	var pendentes: Array[Dictionary] = []
	for chave in _movimentos.keys():
		var m: Dictionary = _movimentos[chave]
		var andar_pacote := int(m.get("andar", -1))
		if andar_pacote == nivel: resultado.append(m)
		if andar_pacote <= nivel: _movimentos.erase(chave)
	for m in _fila:
		if int(m.get("andar", -1)) == nivel: resultado.append(m)
		elif int(m.get("andar", -1)) > nivel: pendentes.append(m)
	_fila = pendentes
	return resultado

func _perfil(jogador: Node2D) -> Dictionary:
	var perfil := Duelo.perfil_do(jogador)
	perfil["dano_maximo"] = ceili(jogador.estatisticas.dano_ataque * maxf(3.0, jogador.estatisticas.dano_critico) * 2.0)
	return perfil

static func obter(arvore: SceneTree) -> Node:
	var no := arvore.root.get_node_or_null("CoopOnline")
	if no == null:
		no = load("res://codigo/coop_online/conexao_coop.gd").new()
		no.name = "CoopOnline"
		arvore.root.add_child(no)
	return no

static func da_arvore(arvore: SceneTree) -> Node:
	return arvore.root.get_node_or_null("CoopOnline")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 1000

func sou_host() -> bool:
	return not eu.is_empty() and dono == eu

## Quantos jogadores estão na partida (1 fora do coop online). Base do balanceamento por sala.
func jogadores_na_partida() -> int:
	return clampi(jogadores.size(), 1, MAX_JOGADORES) if ativo else 1

## Posição do jogador na sala (0 = anfitrião): define cor, vaga e ponto de chegada.
func vaga_de(id: String) -> int:
	for i in jogadores.size():
		if str(jogadores[i].get("id", "")) == id: return i
	return 0

# Balanceamento: cada jogador a mais traz mais inimigos, mais vida e um pouco mais de dano;
# o ouro por abate cai para o total por jogador não disparar com a horda maior.
static func mult_quantidade(n: int) -> float: return 1.0 + 0.35 * (clampi(n, 1, MAX_JOGADORES) - 1)
static func mult_vida(n: int) -> float: return 1.0 + 0.25 * (clampi(n, 1, MAX_JOGADORES) - 1)
static func mult_vida_chefe(n: int) -> float: return 1.0 + 0.3 * (clampi(n, 1, MAX_JOGADORES) - 1)
static func mult_dano(n: int) -> float: return 1.0 + 0.08 * (clampi(n, 1, MAX_JOGADORES) - 1)
static func mult_ouro(n: int) -> float: return 1.0 / (1.0 + (clampi(n, 1, MAX_JOGADORES) - 1) / 3.0)

func todos_prontos_para_avancar() -> bool:
	for id in outros():
		if not bool(prontos_avanco.get(id, false)): return false
	return true

func pendentes_para_avancar() -> Array[String]:
	var nomes: Array[String] = []
	for id in outros():
		if not bool(prontos_avanco.get(id, false)): nomes.append(str(perfil_de(id).get("apelido", "JOGADOR")))
	return nomes

## Convidado: marca ou desmarca "pronto para o próximo andar" e avisa o anfitrião.
func alternar_pronto() -> bool:
	if sou_host() or not ativo: return false
	var pronto := not bool(prontos_avanco.get(eu, false))
	prontos_avanco[eu] = pronto
	enviar({"t": "pronto_avanco", "pronto": pronto})
	prontos_mudaram.emit()
	return pronto

func _limpar_prontos() -> void:
	prontos_avanco.clear()
	if sou_host(): enviar({"t": "prontos", "lista": {}})
	prontos_mudaram.emit()

func perfil_de(id: String) -> Dictionary:
	for j in jogadores:
		if str(j.get("id", "")) == id:
			var perfil = j.get("perfil", {})
			return perfil if perfil is Dictionary else {}
	return {}

## Ids dos outros jogadores da sala, na ordem de entrada.
func outros() -> Array[String]:
	var ids: Array[String] = []
	for j in jogadores:
		if str(j.get("id", "")) != eu: ids.append(str(j.get("id", "")))
	return ids

## Vagas já ocupadas por um parceiro alcançável (para o saguão mostrar quem já está pronto).
func esta_conectado(id: String) -> bool:
	if id == eu: return true
	var par = _pares.get(id)
	return par != null and par.conectado

func todos_conectados() -> bool:
	if _pares.size() != jogadores.size() - 1: return false
	for par in _pares.values():
		if not par.conectado: return false
	return true

func abrir_tela(acao := "") -> void:
	if get_tree().root.has_node("TelaCoopOnline"): return
	var tela = load("res://codigo/coop_online/tela_coop.gd").new()
	tela.name = "TelaCoopOnline"
	tela.acao_inicial = acao
	get_tree().root.add_child(tela)

func criar(jogador: Node2D) -> void:
	_pedir(jogador, {"t": "coop_criar", "perfil": _perfil(jogador), "andar": maxi(1, Progresso.onda_inicial)})

func listar(jogador: Node2D) -> void:
	if not codigo.is_empty() or ativo: return
	if _ws != null and _autenticou and not eu.is_empty() and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.send_text('{"t":"coop_listar"}')
	else: _pedir(jogador, {"t": "coop_listar"})

func entrar(jogador: Node2D, sala: String) -> void:
	_pedir(jogador, {"t": "coop_entrar", "codigo": sala.strip_edges().to_upper(), "perfil": _perfil(jogador)})

func _pedir(jogador: Node2D, pedido: Dictionary) -> void:
	if Cooperativo.ativo:
		erro.emit("SAIA DO COOP LOCAL ANTES DE ENTRAR NO ONLINE")
		return
	if Introducao.ativa() and not permite_entrada_sem_tutorial():
		erro.emit("TERMINE O TUTORIAL ANTES DE ENTRAR NO COOP")
		return
	if not load("res://codigo/conta/cliente_conta.gd").obter(get_tree()).online_liberado():
		erro.emit("ENTRE NA CONTA PARA JOGAR ONLINE")
		return
	if not codigo.is_empty() or ativo:
		erro.emit("VOCE JA ESTA EM UMA SALA")
		return
	if _ws != null and _autenticou and not eu.is_empty() and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.send_text(JSON.stringify(pedido))
		return
	if _ws != null: _ws.close()
	eu = ""
	_jogador = jogador
	_pedido = pedido
	var url := Duelo.endereco()
	if url.is_empty():
		erro.emit("SERVIDOR DE SALAS INDISPONIVEL")
		return
	_ws = WebSocketPeer.new()
	_autenticou = false
	_prazo = Time.get_ticks_msec() + 20000
	if _ws.connect_to_url(url) != OK: _falhar("NAO FOI POSSIVEL CONECTAR AO SERVIDOR DE SALAS")

func _preparar_par(id: String) -> void:
	if _pares.has(id) or id == eu or id.is_empty(): return
	# O servidor só anuncia quem já está na sala, então o parceiro está alcançável desde já.
	var par := Par.new()
	par.id = id
	par.conectado = true
	par.recebeu = Time.get_ticks_msec()
	_pares[id] = par

func _remover_par(id: String) -> void:
	_pares.erase(id)

func _ws_aberto() -> bool:
	return _ws != null and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN

func _enfileirar(para: String, dados: Dictionary, estado: bool) -> bool:
	if not _ws_aberto(): return false
	var tamanho := JSON.stringify(dados).length()
	if tamanho > 16384: return false
	var fila := _ws.get_current_outbound_buffered_amount() + _saida_bytes
	if fila > (LIMITE_FILA_ESTADOS if estado else LIMITE_PACOTE): return false
	_saida.append({"p": para, "e": 1 if estado else 0, "m": dados})
	_saida_bytes += tamanho + 24
	return true

func _despachar() -> void:
	if _saida.is_empty(): return
	if not _ws_aberto():
		_saida.clear()
		_saida_bytes = 0
		return
	var lote: Array[Dictionary] = []
	var bytes := 0
	for item in _saida:
		var tamanho := JSON.stringify(item).length()
		if not lote.is_empty() and (bytes + tamanho > LIMITE_LOTE or lote.size() >= 64):
			_ws.send_text(JSON.stringify({"t": "coop_rede", "p": lote}))
			lote = []
			bytes = 0
		lote.append(item)
		bytes += tamanho
	if not lote.is_empty(): _ws.send_text(JSON.stringify({"t": "coop_rede", "p": lote}))
	_saida.clear()
	_saida_bytes = 0

## Anfitrião: para todos os convidados. Convidado: para o anfitrião. Verdadeiro se chegou a alguém.
func enviar(dados: Dictionary, estado := false) -> bool:
	if _pares.is_empty(): return false
	dados["de"] = eu
	return _enfileirar("*", dados, estado)

func enviar_para(id: String, dados: Dictionary, estado := false) -> bool:
	var par: Par = _pares.get(id)
	if par == null: return false
	dados["de"] = eu
	return _enfileirar(id, dados, estado)

## Anfitrião repassa o pacote de um convidado aos demais (o remetente é mantido em "de").
func _retransmitir(dados: Dictionary, origem: String, estado: bool) -> void:
	for id in _pares:
		if id != origem: _enfileirar(id, dados, estado)

func _process(delta: float) -> void:
	# Prioridade alta: roda depois dos outros nós, então o lote já leva o que o quadro produziu.
	_despachar()
	# Conserva os objetos até os callbacks de fechamento do navegador terminarem.
	_encerrados = _encerrados.filter(func(item: Dictionary): return Time.get_ticks_msec() < item.ate)
	_relogio -= delta
	if _ws != null:
		_ws.poll()
		if _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
			if not _autenticou:
				_autenticou = true
				if not OS.has_feature("web"): _ws.set_no_delay(true)
				var ranking = Ranking.para_jogador(_jogador)
				var pedido_entrada := {"t": "entrar", "codigo": str(ranking._codigo) + "#coop", "geracao": Crypto.new().generate_random_bytes(16).hex_encode(), "estado": {"x": 1, "y": 1, "mapa": 0, "apelido": _jogador.apelido, "aparencia": _perfil(_jogador).visual}}
				var token_conta: String = load("res://codigo/conta/cliente_conta.gd").token_para_servidor(get_tree())
				if not token_conta.is_empty(): pedido_entrada["token"] = token_conta
				_ws.send_text(JSON.stringify(pedido_entrada))
			while _ws.get_available_packet_count() > 0:
				_receber_ws.call_deferred(_ws.get_packet().get_string_from_utf8())
			if _relogio <= 0.0: _ws.send_text('{"t":"coop_ping"}')
		elif _ws.get_ready_state() == WebSocketPeer.STATE_CLOSED:
			_ws = null
			# A partida passa pelo servidor: sem ele não há como continuar.
			_falhar("CONEXAO COM O SERVIDOR DE SALAS ENCERRADA")
			return
	var agora := Time.get_ticks_msec()
	for id in _pares.keys():
		var par: Par = _pares.get(id)
		if par == null: continue
		if agora - par.recebeu > 15000:
			_par_caiu(par)
			if _pares.is_empty() and not sou_host(): return
	var havia := conectado
	if sou_host():
		conectado = false
		for par in _pares.values(): conectado = conectado or par.conectado
	else:
		var do_anfitriao: Par = _pares.get(dono)
		conectado = do_anfitriao != null and do_anfitriao.conectado
	var n_conectados := 0
	for par in _pares.values(): n_conectados += 1 if par.conectado else 0
	if conectado != havia or n_conectados != _n_conectados:
		_n_conectados = n_conectados
		mudou.emit()
	var maior := -1
	for par in _pares.values(): maior = maxi(maior, par.ping_ms)
	ping_ms = maior
	if not conectado and _prazo > 0 and agora > _prazo: _falhar("NAO FOI POSSIVEL CONECTAR AO SERVIDOR DE SALAS")
	if _relogio <= 0.0:
		_relogio = 1.0
		if conectado: enviar({"t": "ping", "tempo": Time.get_ticks_msec()})
	if ativo and get_tree().paused: get_tree().paused = false

## Convidado sem o anfitrião acaba a sessão; anfitrião só perde aquele jogador.
func _par_caiu(par: Par) -> void:
	if not sou_host():
		_falhar("O ANFITRIAO NAO RESPONDEU")
		return
	_remover_par(par.id)
	jogador_saiu.emit(par.id)
	if not ativo: erro.emit("UM JOGADOR NAO CONSEGUIU CONECTAR")

func _receber_ws(texto: String) -> void:
	var m = JSON.parse_string(texto)
	if not m is Dictionary: return
	if str(m.get("erro", "")) == "conta_obrigatoria":
		_falhar("ENTRE NA CONTA PARA JOGAR ONLINE")
		return
	if m.has("eu"):
		eu = str(m.eu)
		if not _pedido.is_empty():
			_ws.send_text(JSON.stringify(_pedido))
			_pedido = {}
	match str(m.get("t", "")):
		"coop_salas":
			_prazo = 0
			salas_recebidas.emit(m.get("salas", []))
		"coop_sala":
			var antes: Array[String] = []
			for j in jogadores: antes.append(str(j.get("id", "")))
			codigo = str(m.codigo)
			dono = str(m.dono)
			jogadores = m.jogadores
			_prazo = 0
			var agora_ids: Array[String] = []
			for j in jogadores: agora_ids.append(str(j.get("id", "")))
			for id in antes:
				if not id in agora_ids:
					_remover_par(id)
					jogador_saiu.emit(id)
			if not ativo or not sou_host():
				if sou_host():
					for id in outros(): _preparar_par(id)
				elif jogadores.size() >= 2: _preparar_par(dono)
			mudou.emit()
		"coop_rede":
			var lista = m.get("p", [])
			if not lista is Array: return
			for item in lista:
				if not item is Dictionary or not item.get("m") is Dictionary: continue
				var de := str(item.get("de", ""))
				if not _pares.has(de) and not sou_host() and de == dono: _preparar_par(de)
				var par: Par = _pares.get(de)
				if par == null: continue
				par.recebeu = Time.get_ticks_msec()
				_receber(item.m, de, int(item.get("e", 0)) == 1)
		"coop_erro": _falhar({"sala_inexistente": "SALA NAO ENCONTRADA", "sala_cheia": "SALA CHEIA", "em_partida": "ESTA SALA JA ESTA EM PARTIDA", "ja_na_sala": "VOCE JA ESTA EM UMA SALA"}.get(str(m.get("erro", "")), "NAO FOI POSSIVEL ENTRAR NA SALA"))
		"coop_fim":
			_falhar("O ANFITRIAO SAIU DA SALA" if not sou_host() else "VOCE SAIU DA SALA")

func _receber(m: Dictionary, de: String, estado := false) -> void:
	var par: Par = _pares.get(de)
	if par == null: return
	match str(m.get("t", "")):
		"ping": enviar_para(de, {"t": "pong", "tempo": m.get("tempo", 0)})
		"pong": par.ping_ms = maxi(0, Time.get_ticks_msec() - int(m.get("tempo", 0)))
		"iniciar":
			if not sou_host() and not ativo and de == dono: _iniciar_local(clampi(int(m.get("andar", 1)), 1, 1000))
		"mapa":
			if ativo and not sou_host() and de == dono: _abrir_andar(clampi(int(m.get("andar", 1)), 1, 1000))
		"pronto_avanco":
			if sou_host():
				prontos_avanco[de] = bool(m.get("pronto", false))
				enviar({"t": "prontos", "lista": prontos_avanco})
				prontos_mudaram.emit()
		"prontos":
			if not sou_host() and de == dono and m.get("lista") is Dictionary:
				prontos_avanco = m.lista
				prontos_mudaram.emit()
		"fim":
			if de == dono: _falhar("O ANFITRIAO ENCERROU A PARTIDA")
		_:
			if not ativo: return
			if sou_host():
				# O remetente é quem a conexão diz ser, nunca o que o pacote afirma.
				m["de"] = de
			if m.get("t") == "jogador":
				var nivel := int(m.get("andar", -1))
				var remetente := str(m.get("de", ""))
				if nivel < andar or nivel > andar + 1 or remetente.is_empty(): return
				var chave := "%d:%s" % [nivel, remetente]
				var anterior: Dictionary = _movimentos.get(chave, {})
				if m.has("seq") and anterior.has("seq") and int(m.seq) <= int(anterior.seq): return
				_movimentos[chave] = m
				if sou_host(): _retransmitir(m, de, estado)
				return
			if _fila.size() < 256: _fila.append(m)

func iniciar() -> void:
	if not sou_host() or ativo or not todos_conectados(): return
	if _ws != null and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.send_text('{"t":"coop_iniciar"}')
	var nivel := maxi(1, Progresso.onda_inicial)
	# Sozinho também vale: a sala fecha para novos jogadores e o anfitrião segue com a partida.
	enviar({"t": "iniciar", "andar": nivel})
	_iniciar_local(nivel)

func _iniciar_local(nivel: int) -> void:
	# Run nova começa limpa, mesmo que algo da anterior tenha sobrado no jogador.
	var local := Duelo.jogador_local(get_tree())
	if local != null and not local.itens_comprados.is_empty():
		local._remover_efeitos_itens_comprados()
		local.itens_comprados.clear()
	ativo = true
	motivo_final = ""
	Saves.salvar_tudo()
	Progresso.iniciar_partida()
	_abrir_andar(nivel)
	mudou.emit()

## Cada andar começa com todos de pé e com vida e fôlego cheios: antes, quem caiu entrava com 1 de vida.
func _recuperar_para_o_andar() -> void:
	var local := Duelo.jogador_local(get_tree())
	if local == null: return
	if local.caido: local.levantar_caido(1.0)
	local.estaMorto = false
	local.descansar()

func _abrir_andar(nivel: int) -> void:
	andar = nivel
	prontos_avanco.clear()
	_recuperar_para_o_andar()
	Transicao.estado.clear()
	Transicao.iniciar_onda_ao_chegar = sou_host()
	permitir_viagem = true
	Transicao.ir_para(Catalogo.cena(nivel), "portal")
	permitir_viagem = false

func instalar(cena: Node) -> void:
	if not ativo or cena == _cena: return
	_cena = cena
	var controlador = load("res://codigo/coop_online/andar_coop.gd").new()
	controlador.name = "AndarCoop"
	cena.add_child(controlador)
	controlador.configurar(self, cena)

func autorizar_viagem(caminho: String) -> bool:
	if not ativo or permitir_viagem: return true
	if not sou_host():
		get_tree().call_group("hud_p1", "avisar", "O ANFITRIAO ESCOLHE O PROXIMO ANDAR")
		return false
	var proximo := int(Progresso.onda_maxima) + 1
	if caminho == Catalogo.cena(proximo):
		andar = proximo
		enviar({"t": "mapa", "andar": andar})
	else:
		enviar({"t": "fim"})
		sair(false)
	return true

func _falhar(texto: String) -> void:
	var em_jogo := ativo
	motivo_final = texto
	sair(false)
	erro.emit(texto)
	if em_jogo:
		permitir_viagem = true
		Transicao.ir_para("res://cenas/cidade.tscn", "portal")
		permitir_viagem = false
		get_tree().call_group("hud_p1", "anunciar", "COOP ENCERRADO", texto + ("  +%d BRASAS" % brasas_ganhas if brasas_ganhas > 0 else ""), 5.0)

## Fecha a partida como "voltar para a cidade": o desempenho vira Brasas e o saque é vendido. Derrota (todos
## caíram) perde o saque, como a morte na arena. Sem isto, nada do coop online pagava Brasas.
var brasas_ganhas := 0
func _liquidar_partida() -> void:
	brasas_ganhas = 0
	# Totens, andar guardado e checkpoint da run que acabou não podem vazar para a próxima sala.
	Transicao.esquecer_partida()
	Progresso.onda_inicial = 1
	Progresso.ouro_compensacao = 0
	Progresso.onda_comecou = false
	# Quem caiu (ou todos caíram) voltava à cidade com a vida zerada, que a transição restaurava como 1 de vida.
	# Como na morte da arena, a volta é com a vida cheia.
	var local := Duelo.jogador_local(get_tree())
	if local != null and (local.caido or motivo_final.contains("CAIRAM")):
		if local.caido: local.levantar_caido(1.0)
		local.estaMorto = false
		local.descansar()
	if not Progresso.partida_ativa: return
	Saque.encerrar(not motivo_final.contains("CAIRAM"))
	var resultado: Dictionary = Progresso.encerrar_partida()
	brasas_ganhas = int(resultado.get("brasas", 0))
	InventarioJogador.reiniciar_equipamento_da_partida()
	DadosDosItems.resetar_precos()

func sair(avisar := true) -> void:
	if ativo: _liquidar_partida()
	if avisar: enviar({"t": "fim"})
	_despachar()
	var ws_antigo := _ws
	for id in _pares.keys(): _remover_par(id)
	if ws_antigo != null: _encerrados.append({"ws": ws_antigo, "ate": Time.get_ticks_msec() + 2000})
	ativo = false
	_fila.clear()
	_movimentos.clear()
	prontos_avanco.clear()
	conectado = false
	_prazo = 0
	ping_ms = -1
	if _ws != null:
		if _ws.get_ready_state() == WebSocketPeer.STATE_OPEN: _ws.send_text('{"t":"coop_sair"}')
		_ws.close()
	_ws = null
	_autenticou = false
	codigo = ""
	jogadores = []
	_cena = null
	encerrou.emit(motivo_final)
	mudou.emit()

func permite_entrada_sem_tutorial() -> bool:
	return false
