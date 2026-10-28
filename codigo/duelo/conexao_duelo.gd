extends Node
## Conexão das salas de duelo: nó único "/root/Duelo", criado na primeira vez (obter). Não é autoload
## porque o patch de conteúdo não pode mudar o project.godot; na raiz ele atravessa as trocas de mapa. Fala com o mesmo servidor do lobby
## (ferramentas/lobby/servidor/duelo.mjs), numa conexão própria: o perfil entra com uma identidade
## derivada do código secreto, então não derruba a sessão do chat/lobby.
signal conexao_alterada(conectado: bool)
signal salas_recebidas(salas: Array)
signal sala_alterada(sala: Dictionary)
signal saiu_da_sala
signal erro(codigo: String)
signal round_comecou(dados: Dictionary)
signal ponto_marcado(dados: Dictionary)
signal partida_terminou(dados: Dictionary)
signal estado_remoto(estado: Dictionary)
signal evento_remoto(evento: Dictionary)
## A vida do jogador local zerou durante a partida (jogador.gd: morrer).
signal caiu_local

const Config := preload("res://codigo/dados/ranking_config.gd")
const Visual := preload("res://codigo/dados/visual_ranking.gd")
const CENA_ARENA := "res://cenas/duelo/arena_duelo.tscn"
const ERROS := {
	"senha_errada": "SENHA ERRADA", "sala_cheia": "SALA CHEIA", "sala_em_jogo": "PARTIDA EM ANDAMENTO",
	"sala_inexistente": "A SALA NAO EXISTE MAIS", "muitas_salas": "MUITAS SALAS ABERTAS",
	"adversario_nao_pronto": "O ADVERSARIO AINDA NAO ESTA PRONTO", "perfil_invalido": "PERFIL INVALIDO",
	"sem_servidor": "SEM SERVIDOR DE DUELO", "sem_conexao": "SEM CONEXAO COM O SERVIDOR",
}

var eu := ""
var sala: Dictionary = {}
## Partida em andamento (cena da arena): round atual e meu lado (0 = esquerda, 1 = direita).
var em_partida := false
var round_atual := 0
var meu_lado := 0
var placar: Dictionary = {}
## Para onde voltar depois da partida.
var cena_de_volta := ""
## Depois da partida a tela da sala reabre sozinha na cena de volta.
var reabrir_sala_ao_chegar := false
var _ws: WebSocketPeer
var _entrou := false
var _jogador: Node2D
var _pendentes: Array = []

static func obter(arvore: SceneTree) -> Node:
	var existente := arvore.root.get_node_or_null("Duelo")
	if existente != null: return existente
	var novo: Node = load("res://codigo/duelo/conexao_duelo.gd").new()
	novo.name = "Duelo"
	arvore.root.add_child(novo)
	return novo

## Partida de duelo em andamento, sem criar o nó (usado pelo jogador.gd a cada queda).
static func em_partida_em(arvore: SceneTree) -> bool:
	var no := arvore.root.get_node_or_null("Duelo")
	return no != null and bool(no.em_partida)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Transicao.troca_concluida.connect(_ao_trocar_cena)

func _ao_trocar_cena(caminho: String) -> void:
	if caminho == CENA_ARENA or not reabrir_sala_ao_chegar: return
	reabrir_sala_ao_chegar = false
	abrir_tela()

## Jogador 1 da cena (o grupo "character" também tem a área de ataque e o timer do jogador).
static func jogador_local(arvore: SceneTree) -> Node2D:
	for no in arvore.get_nodes_in_group("character"):
		if no is CharacterBody2D and not bool(no.get("eh_p2")): return no
	return null

## Saguão das salas (tela_salas_duelo.gd), aberto pelo menu de pausa.
func abrir_tela() -> void:
	var raiz := get_tree().root
	if raiz.get_node_or_null("TelaSalasDuelo") != null: return
	var tela = preload("res://codigo/duelo/tela_salas_duelo.gd").new()
	tela.name = "TelaSalasDuelo"
	raiz.add_child(tela)

func conectado() -> bool:
	return _ws != null and _entrou and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN

## Endereço igual ao do lobby (sessao_lobby.gd): --duelo-ws= / --lobby-ws= em testes locais,
## opcoes.cfg [lobby] servidor, ou o padrão do jogo. Só wss:// ou ws:// local.
static func endereco() -> String:
	var candidato: String = Config.LOBBY_WS
	var preferencias := ConfigFile.new()
	preferencias.load("user://opcoes.cfg")
	var salvo := str(preferencias.get_value("lobby", "servidor", ""))
	if not salvo.is_empty(): candidato = salvo
	if "--script" in OS.get_cmdline_args() or OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"): candidato = ""
	for argumento in OS.get_cmdline_user_args():
		if argumento.begins_with("--lobby-ws="): candidato = argumento.trim_prefix("--lobby-ws=")
		if argumento.begins_with("--duelo-ws="): candidato = argumento.trim_prefix("--duelo-ws=")
	return candidato if candidato.begins_with("wss://") or candidato.begins_with("ws://127.0.0.1:") or candidato.begins_with("ws://localhost:") else ""

func conectar(jogador: Node2D) -> void:
	_jogador = jogador
	if _ws != null and _ws.get_ready_state() in [WebSocketPeer.STATE_OPEN, WebSocketPeer.STATE_CONNECTING]: return
	var url := endereco()
	if url.is_empty():
		erro.emit("sem_servidor")
		return
	_ws = WebSocketPeer.new()
	_ws.heartbeat_interval = 15.0
	_entrou = false
	if _ws.connect_to_url(url) != OK:
		_ws = null
		erro.emit("sem_conexao")

func desconectar() -> void:
	if _ws != null and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_enviar({"t": "sair"})
		_ws.close()
	_ws = null
	_entrou = false
	sala = {}
	em_partida = false
	conexao_alterada.emit(false)

## Visual do personagem para o adversário: roupas/cabelo 3D, cores e armas em uso.
static func perfil_do(jogador: Node2D) -> Dictionary:
	var heroi := jogador.get_node_or_null("HeroiBase3D")
	var perfil := {
		"apelido": Ranking.apelido_personagem(jogador.apelido),
		"aparencia_raven": jogador.aparencia_raven,
		"roupas_3d": heroi.roupas_3d if heroi != null else {},
		"pecas": heroi.pecas_visiveis if heroi != null else 8,
		"arma": str(jogador.id_arma_atual),
		"espada": bool(jogador.usando_espada), "escudo": bool(jogador.usando_escudo),
		"lanca": bool(jogador.usando_lanca), "arco": bool(jogador.usando_arco),
		"hp_maximo": int(jogador.estatisticas.hp_maximo),
	}
	return perfil

func listar() -> void: _enviar({"t": "duelo_salas"})
func criar(titulo: String, senha: String) -> void: _enviar({"t": "duelo_criar", "titulo": titulo, "senha": senha, "perfil": perfil_do(_jogador)})
func entrar(id: int, senha := "") -> void: _enviar({"t": "duelo_entrar", "id": id, "senha": senha, "perfil": perfil_do(_jogador)})
func sair_da_sala() -> void: _enviar({"t": "duelo_sair"})
func marcar_pronto(pronto: bool) -> void: _enviar({"t": "duelo_pronto", "pronto": pronto})
func iniciar() -> void: _enviar({"t": "duelo_iniciar"})
func enviar_estado(estado: Dictionary) -> void: _enviar({"t": "duelo_estado", "e": estado})
func enviar_evento(evento: Dictionary) -> void: _enviar({"t": "duelo_evento", "ev": evento})
func avisar_queda() -> void: _enviar({"t": "duelo_caiu", "round": round_atual})

func sou_dono() -> bool: return not sala.is_empty() and str(sala.get("dono", "")) == eu
func adversario() -> Dictionary:
	for j in sala.get("jogadores", []):
		if str(j.id) != eu: return j
	return {}

func _enviar(objeto: Dictionary) -> void:
	if conectado():
		_ws.send_text(JSON.stringify(objeto))
	else:
		_pendentes.append(objeto)

## O servidor desconecta quem passa 20 s calado: na sala ou na lista, um sinal de vida a cada 5 s.
const INTERVALO_VIDA := 5.0
var _tempo_vida := 0.0

func _process(delta: float) -> void:
	if _ws == null: return
	_ws.poll()
	_tempo_vida -= delta
	if _tempo_vida <= 0.0 and conectado():
		_tempo_vida = INTERVALO_VIDA
		_ws.send_text(JSON.stringify({"t": "duelo_vivo"}))
	match _ws.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			if not _entrou: _entrar()
			while _ws.get_available_packet_count() > 0:
				_receber(_ws.get_packet().get_string_from_utf8())
		WebSocketPeer.STATE_CLOSED:
			var estava := _entrou
			_ws = null
			_entrou = false
			if estava: conexao_alterada.emit(false)
			if em_partida:
				em_partida = false
				partida_terminou.emit({"vencedor": "", "motivo": "conexao"})
			erro.emit("sem_conexao")

func _entrar() -> void:
	if not is_instance_valid(_jogador): return
	var perfil_ranking = Ranking.para_jogador(_jogador)
	# Identidade própria do duelo: entrar com o código do lobby derrubaria a sessão do chat.
	var codigo: String = str(perfil_ranking._codigo) + "#duelo"
	var estado := {"x": 1, "y": 1, "mapa": 0, "apelido": Ranking.apelido_personagem(_jogador.apelido), "aparencia": Visual.do_jogador(_jogador)}
	_ws.send_text(JSON.stringify({"t": "entrar", "codigo": codigo, "geracao": Crypto.new().generate_random_bytes(16).hex_encode(), "estado": estado}))
	_entrou = true
	conexao_alterada.emit(true)
	for pendente in _pendentes: _ws.send_text(JSON.stringify(pendente))
	_pendentes.clear()

func _receber(texto: String) -> void:
	var dados = JSON.parse_string(texto)
	if not dados is Dictionary: return
	if dados.has("eu"): eu = str(dados.eu)
	match str(dados.get("t", "")):
		"duelo_salas": salas_recebidas.emit(dados.get("salas", []))
		"duelo_sala":
			sala = dados.sala
			sala_alterada.emit(sala)
		"duelo_saiu":
			sala = {}
			saiu_da_sala.emit()
		"duelo_erro": erro.emit(str(dados.erro))
		"duelo_round":
			round_atual = int(dados.round)
			placar = dados.get("placar", {})
			meu_lado = int(dados.get("lados", {}).get(eu, 0))
			if not em_partida:
				em_partida = true
				_ir_para_arena()
			round_comecou.emit(dados)
		"duelo_ponto":
			placar = dados.get("placar", {})
			ponto_marcado.emit(dados)
		"duelo_fim":
			placar = dados.get("placar", placar)
			em_partida = false
			partida_terminou.emit(dados)
		"duelo_estado": estado_remoto.emit(dados.e)
		"duelo_evento": evento_remoto.emit(dados.ev)

func _ir_para_arena() -> void:
	var atual := get_tree().current_scene
	if atual != null and atual.scene_file_path != CENA_ARENA: cena_de_volta = atual.scene_file_path
	Transicao.ir_para(CENA_ARENA)

func texto_erro(codigo: String) -> String:
	return ERROS.get(codigo, codigo.to_upper())
