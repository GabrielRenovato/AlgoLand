extends "res://codigo/coop_online/conexao_coop.gd"

## A negociação reutiliza o coop; progresso e economia permanecem os da campanha.
const CAMPANHA := "campanha_primeira_raiz_v1"
signal mensagem_sala(autor: String, texto: String)
var _limites_chat: Dictionary = {}
var regiao := "chegada"
var eventos: Array[Dictionary] = []
class Representante extends Node2D:
	var apelido := "AVENTUREIRO"
	var eh_p2 := false
var representante: Node2D

static func obter_expedicao(arvore: SceneTree) -> Node:
	var no := arvore.root.get_node_or_null("CampanhaOnline")
	if no == null:
		no = load("res://codigo/campanha/sessao_expedicao.gd").new()
		no.name = "CampanhaOnline"
		arvore.root.add_child(no)
	return no

func _ready() -> void:
	super._ready()
	representante = Representante.new()
	add_child(representante)
	representante.apelido = Ranking.apelido_personagem("")

func permite_entrada_sem_tutorial() -> bool: return true

func _perfil(_j: Node2D) -> Dictionary:
	var dados: Dictionary={}
	var arquivo:=FileAccess.open(Saves.caminho_personagem(false),FileAccess.READ)
	if arquivo!=null:
		var salvo=JSON.parse_string(arquivo.get_as_text())
		if salvo is Dictionary and salvo.get("aparencia_raven") is Dictionary:dados=salvo.aparencia_raven.duplicate(true)
	dados["versao"]=1
	return {"apelido":representante.apelido,"visual":preload("res://codigo/dados/visual_ranking.gd").normalizar(dados),"hp":82,"dano_maximo":60}

func enviar_chat(texto: String) -> bool:
	texto=texto.strip_edges().replace("\n"," ").replace("\r"," ").left(180)
	if codigo.is_empty() or eu.is_empty() or ativo or texto.is_empty():return false
	var agora:=Time.get_ticks_msec()
	if agora<int(_limites_chat.get(eu,0)):return false
	_limites_chat[eu]=agora+350
	enviar({"t":"sala_chat","autor":eu,"texto":texto})
	mensagem_sala.emit(str(perfil_de(eu).get("apelido","Aventureiro")),texto)
	return true

func solicitar(acao: String, id: String, sala := "") -> void:
	if not id in ["chegada","estrada","vila","pomar"]: return
	regiao = id
	_pedir(representante,{"t":"coop_"+acao,"campanha":CAMPANHA,"regiao":id,"codigo":sala,"perfil":_perfil(representante)})

func _receber_ws(texto: String) -> void:
	var m = JSON.parse_string(texto)
	if m is Dictionary and m.get("t")=="coop_sala" and (m.get("campanha")!=CAMPANHA or m.get("regiao")!=regiao):
		_falhar("Este servidor ainda não oferece salas desta campanha.")
		return
	super._receber_ws(texto)

func iniciar() -> void:
	if not sou_host() or ativo or not todos_conectados(): return
	if _ws==null or _ws.get_ready_state()!=WebSocketPeer.STATE_OPEN:
		erro.emit("Reconecte a sala antes de iniciar."); return
	_ws.send_text('{"t":"coop_iniciar"}')
	enviar({"t":"expedicao_iniciar","regiao":regiao,"estacao":Calendario.estacao()})
	_abrir_expedicao(Calendario.estacao())

func _abrir_expedicao(estacao: int) -> void:
	ativo = true
	eventos.clear()
	get_tree().set_meta("campanha_nova_instancia",true)
	get_tree().set_meta("campanha_destino",regiao)
	get_tree().set_meta("campanha_estacao",clampi(estacao,0,3))
	get_tree().change_scene_to_file("res://cenas/campanha/percurso_prototipo.tscn")
	mudou.emit()

func _receber(m: Dictionary, de: String, estado := false) -> void:
	if not _pares.has(de): return
	var tipo := str(m.get("t",""))
	if tipo=="sala_chat":
		if ativo or codigo.is_empty() or (not sou_host() and de!=dono):return
		var autor:=de if sou_host() else str(m.get("autor",""))
		if not jogadores.any(func(j):return str(j.get("id",""))==autor):return
		var texto:=str(m.get("texto","")).strip_edges().replace("\n"," ").replace("\r"," ").left(180)
		var agora:=Time.get_ticks_msec()
		if texto.is_empty() or agora<int(_limites_chat.get(autor,0)):return
		_limites_chat[autor]=agora+350
		if sou_host():_retransmitir({"t":"sala_chat","autor":autor,"texto":texto},de,false)
		mensagem_sala.emit(str(perfil_de(autor).get("apelido","Aventureiro")),texto)
		return
	if tipo=="expedicao_iniciar":
		if not sou_host() and de==dono and not ativo and m.get("regiao")==regiao:
			_abrir_expedicao(int(m.get("estacao",0)))
		return
	# Mensagens da arena não podem acionar transições ou recompensas nesta sessão.
	if tipo in ["ping","pong","fim"]:
		super._receber(m,de,estado)
		return
	if not ativo: return
	var permitidos := ["jogador","pronto_andar","golpe","efeito","vigilia_pedido","perfil"] if sou_host() else ["jogador","nascer","mundo","remover","dano","texturas","combate_campanha","perfil","vigilia_estado","espelhos","efeitos_visuais","cerne_fala","maestria_credito","saque_inicial","resumo_campanha"]
	if not tipo in permitidos or (not sou_host() and de!=dono): return
	m["de"] = de if sou_host() or tipo!="jogador" else str(m.get("de",de))
	if sou_host() and tipo in ["jogador","perfil"]: _retransmitir(m,de,estado)
	if tipo=="combate_campanha":
		if eventos.size()<16: eventos.append(m)
	elif _fila.size()<256: _fila.append(m)

func registrar_combate(alvo: String) -> void:
	if ativo and sou_host(): enviar({"t":"combate_campanha","alvo":alvo,"andar":1})

func sair(avisar := true) -> void:
	ativo = false # Não liquida uma run da arena nem toca nas Brasas.
	_limites_chat.clear()
	eventos.clear()
	super.sair(avisar)

func _falhar(texto: String) -> void:
	var em_jogo := ativo
	motivo_final = texto
	var cena := get_tree().current_scene
	if em_jogo and cena!=null and cena.has_method("salvar_retorno"): cena.salvar_retorno()
	sair(false)
	erro.emit(texto)
	if em_jogo:
		get_tree().set_meta("campanha_mapa_regional",true)
		get_tree().set_meta("campanha_aviso",texto)
		get_tree().change_scene_to_file("res://cenas/campanha/seletor_campanha.tscn")
