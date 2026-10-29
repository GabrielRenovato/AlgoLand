extends Node
## Conta do jogador (Supabase Auth, e-mail e senha). Sem autoload: nasce sob a raiz na primeira vez (`obter`).
## A conta guarda o código secreto que o jogo já usa no ranking e no mercado (ver docs/conta/PLANO.md): vincular não muda nenhuma RPC.
## A senha nunca é gravada; o disco guarda só o token de renovação, cifrado com uma chave do aparelho.
signal mudou

const Config := preload("res://codigo/dados/ranking_config.gd")
const ARQUIVO := "user://conta.cfg"
## A tela de login abre ao iniciar o jogo quando não há sessão, e tem sempre a saída "JOGAR OFFLINE".
const ABRIR_LOGIN_AO_INICIAR := true
## Com verdadeiro, coop, duelo e demais recursos online exigem conta (offline joga o solo normalmente).
## Fica falso até o Supabase estar configurado (confirmação de e-mail e SQL aplicado).
const ONLINE_EXIGE_CONTA := false
## Sem rede, quem já entrou continua jogando por este prazo antes de precisar validar o login de novo.
const DIAS_OFFLINE := 14
const SENHA_MINIMA := 8
const ERROS := {
	"invalid_credentials": "E-MAIL OU SENHA INCORRETOS",
	"email_not_confirmed": "CONFIRME O E-MAIL ANTES DE ENTRAR",
	"user_already_exists": "ESTE E-MAIL JA TEM CONTA",
	"email_exists": "ESTE E-MAIL JA TEM CONTA",
	"weak_password": "SENHA FRACA: USE 8 OU MAIS CARACTERES",
	"validation_failed": "E-MAIL INVALIDO",
	"over_request_rate_limit": "MUITAS TENTATIVAS. AGUARDE UM POUCO",
	"over_email_send_rate_limit": "MUITOS E-MAILS ENVIADOS. TENTE MAIS TARDE",
	"signup_disabled": "NOVAS CONTAS ESTAO DESLIGADAS NO MOMENTO",
}

var email := ""
var apelido := ""
var usuario_id := ""
## "" (não vinculou), "ok", "pendente" (sem rede/RPC), "outro_codigo" (a conta já tem outro personagem), "codigo_em_uso"
var vinculo := ""
var codigo_da_conta := ""
var offline := false
## O jogador escolheu jogar offline nesta sessão: não pergunta de novo ao voltar para o título.
var escolheu_offline := false
var _acesso := ""
var _renovacao := ""
var _expira_ms := 0
var _ultimo_ok := 0
var _ocupado := false

static func obter(arvore: SceneTree) -> Node:
	var no := arvore.root.get_node_or_null("ContaJogador")
	if no == null:
		no = load("res://codigo/conta/cliente_conta.gd").new()
		no.name = "ContaJogador"
		arvore.root.add_child(no)
	return no

var nuvem: Node
var amigos: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_carregar()
	nuvem = load("res://codigo/conta/nuvem_save.gd").new()
	nuvem.name = "Nuvem"
	add_child(nuvem)
	amigos = load("res://codigo/conta/amigos.gd").new()
	amigos.name = "Amigos"
	add_child(amigos)
	amigos.convite_recebido.connect(func(convite: Dictionary):
		var aviso = load("res://codigo/conta/convite_popup.gd").new()
		aviso.convite = convite
		get_tree().root.add_child(aviso))
	var calendario := get_tree().root.get_node_or_null("Calendario")
	if calendario != null: calendario.dia_passou.connect(func(_dia: int): nuvem.sincronizar("dormir"))

func _notification(motivo: int) -> void:
	# Fechar a janela ou mandar o app para o fundo: última chance de subir o progresso.
	if motivo in [NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED] and nuvem != null and logado():
		nuvem.sincronizar("saida")

# --- Estado

func disponivel() -> bool:
	return not url_base().is_empty() and not Config.CHAVE.is_empty()

func logado() -> bool:
	return not _acesso.is_empty() or (offline and not _renovacao.is_empty())

func ocupado() -> bool:
	return _ocupado

func deve_abrir_login() -> bool:
	return ABRIR_LOGIN_AO_INICIAR and disponivel() and not logado() and not escolheu_offline

## Recursos online (coop, duelo...) liberados? Sempre, até ONLINE_EXIGE_CONTA ser ligado.
func online_liberado() -> bool:
	return not ONLINE_EXIGE_CONTA or not disponivel() or logado()

## --conta-url=http://127.0.0.1:PORTA nos testes locais (nunca aponta para produção por acidente).
static func url_base() -> String:
	for argumento in OS.get_cmdline_user_args():
		if argumento.begins_with("--conta-url="):
			var url := argumento.trim_prefix("--conta-url=")
			if url.begins_with("http://127.0.0.1") or url.begins_with("http://localhost"): return url
	return Config.URL

static func email_valido(texto: String) -> bool:
	var regex := RegEx.new()
	regex.compile("^[A-Za-z0-9._%+\\-]+@[A-Za-z0-9.\\-]+\\.[A-Za-z]{2,}$")
	return regex.search(texto.strip_edges()) != null and texto.length() <= 120

# --- Ações (devolvem "" em sucesso, ou o texto do erro para a tela)

func entrar(endereco: String, senha: String) -> String:
	if not email_valido(endereco): return "E-MAIL INVALIDO"
	if senha.is_empty(): return "DIGITE A SENHA"
	var r := await _requisitar("POST", "/auth/v1/token?grant_type=password", {"email": endereco.strip_edges().to_lower(), "password": senha})
	var erro := _erro(r)
	if not erro.is_empty(): return erro
	_aceitar_sessao(r.corpo)
	await vincular()
	return ""

## Devolve "CONFIRMAR_EMAIL" quando a conta nasceu mas o projeto exige confirmação por e-mail.
func criar(endereco: String, senha: String, nome: String) -> String:
	if not email_valido(endereco): return "E-MAIL INVALIDO"
	if senha.length() < SENHA_MINIMA: return "SENHA FRACA: USE 8 OU MAIS CARACTERES"
	var limpo := nome.strip_edges().left(24)
	if limpo.is_empty(): return "ESCOLHA UM APELIDO"
	var r := await _requisitar("POST", "/auth/v1/signup", {"email": endereco.strip_edges().to_lower(), "password": senha, "data": {"apelido": limpo}})
	var erro := _erro(r)
	if not erro.is_empty(): return erro
	if not (r.corpo is Dictionary and r.corpo.has("access_token")):
		email = endereco.strip_edges().to_lower()
		return "CONFIRMAR_EMAIL"
	apelido = limpo
	_aceitar_sessao(r.corpo)
	await vincular()
	return ""

func recuperar(endereco: String) -> String:
	if not email_valido(endereco): return "E-MAIL INVALIDO"
	var r := await _requisitar("POST", "/auth/v1/recover", {"email": endereco.strip_edges().to_lower()})
	return _erro(r)

func sair() -> void:
	if not _acesso.is_empty():
		await _requisitar("POST", "/auth/v1/logout", {}, _acesso)
	_limpar_sessao()

## Ao abrir o jogo: renova a sessão guardada. Sem rede, vale o prazo offline; com a renovação recusada, pede login.
func restaurar() -> bool:
	if _renovacao.is_empty(): return false
	var r := await _requisitar("POST", "/auth/v1/token?grant_type=refresh_token", {"refresh_token": _renovacao})
	if int(r.status) == 0:
		offline = (Time.get_unix_time_from_system() - _ultimo_ok) < DIAS_OFFLINE * 86400.0
		mudou.emit()
		return offline
	if not _erro(r).is_empty():
		_limpar_sessao()
		return false
	_aceitar_sessao(r.corpo)
	await vincular()
	return true

## Token válido para chamar o Supabase como o jogador (renova se estiver perto de vencer). "" se não há sessão.
func token() -> String:
	if _acesso.is_empty() or _renovacao.is_empty(): return ""
	if Time.get_ticks_msec() > _expira_ms - 60000:
		var r := await _requisitar("POST", "/auth/v1/token?grant_type=refresh_token", {"refresh_token": _renovacao})
		if _erro(r).is_empty(): _aceitar_sessao(r.corpo)
	return _acesso

## Liga o código secreto deste aparelho à conta. Não bloqueia nem apaga nada se falhar: o jogo segue com o código local.
func vincular() -> String:
	var ranking := get_tree().root.get_node_or_null("Ranking")
	if ranking == null or _acesso.is_empty(): return "pendente"
	var r := await _requisitar("POST", "/rest/v1/rpc/vincular_conta", {"p_codigo": ranking.codigo_secreto(), "p_apelido": apelido if not apelido.is_empty() else str(ranking.get("apelido"))}, _acesso)
	if not _erro(r).is_empty() or not r.corpo is Dictionary:
		vinculo = "pendente"
	else:
		vinculo = str(r.corpo.get("estado", "pendente"))
		codigo_da_conta = str(r.corpo.get("codigo_secreto", ""))
		if r.corpo.has("apelido") and apelido.is_empty(): apelido = str(r.corpo.apelido)
	mudou.emit()
	return vinculo

# --- Sessão

func _aceitar_sessao(corpo) -> void:
	if not corpo is Dictionary: return
	_acesso = str(corpo.get("access_token", ""))
	_renovacao = str(corpo.get("refresh_token", _renovacao))
	_expira_ms = Time.get_ticks_msec() + int(float(corpo.get("expires_in", 3600)) * 1000.0)
	var usuario = corpo.get("user", {})
	if usuario is Dictionary:
		usuario_id = str(usuario.get("id", usuario_id))
		email = str(usuario.get("email", email))
		var meta = usuario.get("user_metadata", {})
		if meta is Dictionary and str(meta.get("apelido", "")) != "": apelido = str(meta.apelido)
	offline = false
	_ultimo_ok = int(Time.get_unix_time_from_system())
	_gravar()
	mudou.emit()

func _limpar_sessao() -> void:
	_acesso = ""
	_renovacao = ""
	usuario_id = ""
	vinculo = ""
	offline = false
	if FileAccess.file_exists(ARQUIVO): DirAccess.remove_absolute(ProjectSettings.globalize_path(ARQUIVO))
	mudou.emit()

static func _chave() -> String:
	return (OS.get_unique_id() if not OS.get_unique_id().is_empty() else "algoland") + "#conta"

func _gravar() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("conta", "renovacao", _renovacao)
	cfg.set_value("conta", "email", email)
	cfg.set_value("conta", "apelido", apelido)
	cfg.set_value("conta", "usuario", usuario_id)
	cfg.set_value("conta", "ultimo_ok", _ultimo_ok)
	cfg.save_encrypted_pass(ARQUIVO, _chave())

func _carregar() -> void:
	var cfg := ConfigFile.new()
	if cfg.load_encrypted_pass(ARQUIVO, _chave()) != OK: return
	_renovacao = str(cfg.get_value("conta", "renovacao", ""))
	email = str(cfg.get_value("conta", "email", ""))
	apelido = str(cfg.get_value("conta", "apelido", ""))
	usuario_id = str(cfg.get_value("conta", "usuario", ""))
	_ultimo_ok = int(cfg.get_value("conta", "ultimo_ok", 0))

## Token atual para os servidores de lobby, coop e duelo conferirem a conta no "entrar" ("" sem conta). Sem esperar rede:
## quem renova é `token()`, chamado a cada poucos segundos pelos convites.
static func token_para_servidor(arvore: SceneTree) -> String:
	var no := arvore.root.get_node_or_null("ContaJogador")
	return no._acesso if no != null else ""

## RPC do Supabase como o jogador logado. {"erro": texto} ou o corpo da resposta.
func chamar(funcao: String, corpo := {}) -> Dictionary:
	var autenticacao := await token()
	if autenticacao.is_empty(): return {"erro": "SEM LOGIN"}
	var r := await _requisitar("POST", "/rest/v1/rpc/" + funcao, corpo, autenticacao)
	var erro := _erro(r)
	if not erro.is_empty(): return {"erro": erro}
	if r.corpo is Dictionary: return r.corpo
	# Funções que devolvem um valor simples (texto) ou nada (void).
	return {} if r.corpo == null else {"valor": r.corpo}

## Mantém o save desta conta apontando para o código deste aparelho (usado ao escolher "manter este aparelho").
func adotar_codigo_local() -> String:
	var ranking := get_tree().root.get_node_or_null("Ranking")
	if ranking == null: return "pendente"
	var r := await chamar("trocar_codigo_conta", {"p_codigo": ranking.codigo_secreto()})
	if r.has("erro"): return "pendente"
	if str(r.get("estado", "")) == "ok": vinculo = "ok"
	mudou.emit()
	return str(r.get("estado", "pendente"))

# --- Rede

func _erro(r: Dictionary) -> String:
	if int(r.status) == 0: return "SEM CONEXAO COM O SERVIDOR"
	if int(r.status) >= 200 and int(r.status) < 300: return ""
	var corpo = r.corpo
	if corpo is Dictionary:
		var codigo := str(corpo.get("error_code", corpo.get("code", corpo.get("error", ""))))
		if ERROS.has(codigo): return ERROS[codigo]
		if int(r.status) == 429: return ERROS["over_request_rate_limit"]
	return "NAO FOI POSSIVEL CONCLUIR (%d)" % int(r.status)

## {status, corpo}. status 0 = sem resposta (rede, DNS, tempo esgotado).
func _requisitar(metodo: String, caminho: String, corpo: Dictionary, token_usuario := "") -> Dictionary:
	_ocupado = true
	var http := HTTPRequest.new()
	http.timeout = 15.0
	add_child(http)
	var cabecalhos := PackedStringArray(["apikey: " + Config.CHAVE, "Content-Type: application/json"])
	if not token_usuario.is_empty(): cabecalhos.append("Authorization: Bearer " + token_usuario)
	var metodo_http := HTTPClient.METHOD_POST if metodo == "POST" else HTTPClient.METHOD_GET
	var inicio := http.request(url_base() + caminho, cabecalhos, metodo_http, JSON.stringify(corpo))
	var resultado := {"status": 0, "corpo": null}
	if inicio == OK:
		var resposta: Array = await http.request_completed
		if int(resposta[0]) == HTTPRequest.RESULT_SUCCESS:
			resultado.status = int(resposta[1])
			var texto: String = (resposta[3] as PackedByteArray).get_string_from_utf8()
			resultado.corpo = JSON.parse_string(texto) if not texto.is_empty() else null
	http.queue_free()
	_ocupado = false
	return resultado
