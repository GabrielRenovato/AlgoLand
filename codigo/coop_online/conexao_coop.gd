extends Node
## Dois jogadores. O WebSocket só transporta sinalização; os canais WebRTC levam a partida.
signal salas_recebidas(salas: Array)
signal mudou
signal erro(texto: String)
signal pacote(dados: Dictionary)
signal encerrou(motivo: String)
const Duelo := preload("res://codigo/duelo/conexao_duelo.gd")
const Catalogo := preload("res://codigo/fendas/catalogo_andares.gd")
const LIMITE_PACOTE := 262144
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
var _rtc: WebRTCPeerConnection
var _eventos: WebRTCDataChannel
var _estados: WebRTCDataChannel
var _autenticou := false
var _jogador: Node2D
var _pedido: Dictionary = {}
var _relogio := 0.0
var _prazo := 0
var _recebeu := 0
var _cena: Node
var motivo_final := ""
var _fila: Array[Dictionary] = []
var _encerrados: Array[Dictionary] = []

func retirar_pacotes(nivel: int) -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []
	var pendentes: Array[Dictionary] = []
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

func sou_host() -> bool:
	return not eu.is_empty() and dono == eu

func perfil_remoto() -> Dictionary:
	for j in jogadores:
		if str(j.get("id", "")) != eu: return j.get("perfil", {})
	return {}

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
	if Introducao.ativa():
		erro.emit("TERMINE O TUTORIAL ANTES DE ENTRAR NO COOP")
		return
	if not OS.has_feature("web") and not ClassDB.class_exists("WebRTCPeerConnectionExtension"):
		erro.emit("INSTALE A VERSAO COM SUPORTE AO COOP ONLINE")
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

func _sinal(dados: Dictionary) -> void:
	if _ws != null and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.send_text(JSON.stringify({"t": "coop_sinal", "dados": dados}))

func _preparar_rtc() -> void:
	if _rtc != null: return
	_rtc = WebRTCPeerConnection.new()
	# STUN apenas descobre o endereço público. Nenhum TURN/relay pago é configurado.
	var resultado := _rtc.initialize({"iceServers": [{"urls": ["stun:stun.cloudflare.com:3478"]}]})
	if resultado != OK:
		_falhar("ESTA VERSAO NAO TEM SUPORTE A CONEXAO DIRETA")
		return
	_rtc.session_description_created.connect(func(tipo: String, sdp: String):
		_rtc.set_local_description(tipo, sdp)
		_sinal({"tipo": tipo, "sdp": sdp}))
	_rtc.ice_candidate_created.connect(func(mid: String, indice: int, candidato: String):
		_sinal({"tipo": "ice", "mid": mid, "indice": indice, "candidato": candidato}))
	_eventos = _rtc.create_data_channel("eventos", {"negotiated": true, "id": 1, "ordered": true})
	_estados = _rtc.create_data_channel("estados", {"negotiated": true, "id": 2, "ordered": false, "maxRetransmits": 0})
	_prazo = Time.get_ticks_msec() + 25000
	if sou_host(): _rtc.create_offer()

func enviar(dados: Dictionary, estado := false) -> bool:
	var canal := _estados if estado else _eventos
	if not conectado or canal == null or canal.get_ready_state() != WebRTCDataChannel.STATE_OPEN: return false
	var bytes := JSON.stringify(dados).to_utf8_buffer()
	if bytes.size() > 16384 or canal.get_buffered_amount() > LIMITE_PACOTE: return false
	return canal.put_packet(bytes) == OK

func _process(delta: float) -> void:
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
				_ws.send_text(JSON.stringify({"t": "entrar", "codigo": str(ranking._codigo) + "#coop", "geracao": Crypto.new().generate_random_bytes(16).hex_encode(), "estado": {"x": 1, "y": 1, "mapa": 0, "apelido": _jogador.apelido, "aparencia": _perfil(_jogador).visual}}))
			while _ws.get_available_packet_count() > 0:
				_receber_ws.call_deferred(_ws.get_packet().get_string_from_utf8())
			if _relogio <= 0.0: _ws.send_text('{"t":"coop_ping"}')
		elif _ws.get_ready_state() == WebSocketPeer.STATE_CLOSED:
			_ws = null
			# Uma partida já direta continua se o servidor de sinalização cair.
			if not conectado: _falhar("CONEXAO COM O SERVIDOR DE SALAS ENCERRADA")
	if _rtc != null:
		_rtc.poll()
		var abriu := _eventos != null and _estados != null and _eventos.get_ready_state() == WebRTCDataChannel.STATE_OPEN and _estados.get_ready_state() == WebRTCDataChannel.STATE_OPEN
		if abriu and not conectado:
			conectado = true
			_recebeu = Time.get_ticks_msec()
			mudou.emit()
		for canal in [_eventos, _estados]:
			if canal == null: continue
			while canal.get_available_packet_count() > 0:
				var bytes: PackedByteArray = canal.get_packet()
				if bytes.size() > LIMITE_PACOTE: continue
				var dados = JSON.parse_string(bytes.get_string_from_utf8())
				if dados is Dictionary:
					_recebeu = Time.get_ticks_msec()
					_receber.call_deferred(dados)
		if _rtc != null and _rtc.get_connection_state() in [WebRTCPeerConnection.STATE_FAILED, WebRTCPeerConnection.STATE_CLOSED]:
			_falhar("CONEXAO DIRETA ENCERRADA")
	if _relogio <= 0.0:
		_relogio = 1.0
		if conectado: enviar({"t": "ping", "tempo": Time.get_ticks_msec()})
	if conectado and Time.get_ticks_msec() - _recebeu > 15000: _falhar("O PARCEIRO NAO RESPONDEU")
	if not conectado and _prazo > 0 and Time.get_ticks_msec() > _prazo:
		_falhar("A REDE NAO PERMITIU CONEXAO DIRETA. TENTE OUTRO WI-FI.")
	if ativo and get_tree().paused: get_tree().paused = false

func _receber_ws(texto: String) -> void:
	var m = JSON.parse_string(texto)
	if not m is Dictionary: return
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
			codigo = str(m.codigo)
			dono = str(m.dono)
			jogadores = m.jogadores
			_prazo = 0
			if jogadores.size() == 2: _preparar_rtc()
			mudou.emit()
		"coop_sinal":
			if _rtc == null: return
			var d: Dictionary = m.get("dados", {})
			if str(d.get("tipo", "")) == "ice":
				_rtc.add_ice_candidate(str(d.get("mid", "")), int(d.get("indice", 0)), str(d.get("candidato", "")))
			elif str(d.get("tipo", "")) in ["offer", "answer"]:
				_rtc.set_remote_description(str(d.tipo), str(d.get("sdp", "")))
		"coop_erro": _falhar({"sala_inexistente": "SALA NAO ENCONTRADA", "sala_cheia": "SALA CHEIA", "em_partida": "ESTA SALA JA ESTA EM PARTIDA", "ja_na_sala": "VOCE JA ESTA EM UMA SALA"}.get(str(m.get("erro", "")), "NAO FOI POSSIVEL ENTRAR NA SALA"))
		"coop_fim":
			# A sinalização pode cair sem derrubar uma conexão direta em andamento.
			if not conectado or m.get("intencional", false) == true: _falhar("O PARCEIRO SAIU DA SALA")

func _receber(m: Dictionary) -> void:
	match str(m.get("t", "")):
		"ping": enviar({"t": "pong", "tempo": m.get("tempo", 0)})
		"pong": ping_ms = maxi(0, Time.get_ticks_msec() - int(m.get("tempo", 0)))
		"iniciar":
			if not sou_host() and not ativo: _iniciar_local(clampi(int(m.get("andar", 1)), 1, 1000))
		"mapa":
			if ativo and not sou_host(): _abrir_andar(clampi(int(m.get("andar", 1)), 1, 1000))
		"fim": _falhar("O PARCEIRO ENCERROU A PARTIDA")
		_:
			if ativo and _fila.size() < 128: _fila.append(m)

func iniciar() -> void:
	if not sou_host() or not conectado or ativo: return
	var nivel := maxi(1, Progresso.onda_inicial)
	if enviar({"t": "iniciar", "andar": nivel}):
		if _ws != null and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
			_ws.send_text('{"t":"coop_iniciar"}')
		_iniciar_local(nivel)

func _iniciar_local(nivel: int) -> void:
	ativo = true
	motivo_final = ""
	Saves.salvar_tudo()
	Progresso.iniciar_partida()
	_abrir_andar(nivel)
	mudou.emit()

func _abrir_andar(nivel: int) -> void:
	andar = nivel
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
		get_tree().call_group("hud_p1", "anunciar", "COOP ENCERRADO", texto, 5.0)

func sair(avisar := true) -> void:
	if _rtc != null or _ws != null:
		_encerrados.append({"rtc": _rtc, "eventos": _eventos, "estados": _estados, "ws": _ws, "ate": Time.get_ticks_msec() + 2000})
	if avisar: enviar({"t": "fim"})
	ativo = false
	_fila.clear()
	conectado = false
	_prazo = 0
	_recebeu = 0
	if _rtc != null: _rtc.close()
	_rtc = null
	_eventos = null
	_estados = null
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
