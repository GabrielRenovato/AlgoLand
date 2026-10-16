extends Node

## Agenda da vila: anuncia no banner do HUD os eventos de Dados.EVENTOS (convite de manhã e o começo na hora) e manda o
## pombo-correio com as cartas de pedido dos moradores: dormir deixa uma carta pendente (Cidade.carta_pendente) e o pombo
## a entrega quando o jogador sai de casa (a primeira vez que pisa ao ar livre depois de acordar).
## O relógio é o da cena principal; na arena (relógio próprio) e durante a introdução nada acontece. Os avisos vão para
## todos os HUDs (as duas metades no cooperativo) e o pombo pousa ao lado de um dos jogadores.

const Dados := preload("res://codigo/cidade/dados_cidade.gd")
const PomboCorreio := preload("res://codigo/cidade/pombo_correio.gd")
## Onde o pombo pode pousar (os interiores e a casa da fazenda não)
const CENAS_AO_AR_LIVRE := ["res://cenas/cidade.tscn", "res://cenas/fazenda.tscn", "res://cenas/praia.tscn"]
const TEMPO_BANNER := 3.0
const INTERVALO := 0.5

## Testes (--script) ligam só o que testam: o pombo pousando ao lado do jogador mudaria as interações de outros testes
var ligada := not OS.get_cmdline_args().has("--script")
## Avisos já mostrados ("evento:fase:dia"): não se repetem ao trocar de cena
var anunciados: Dictionary = {}
var pombo: Node2D = null
## Depois de um pombo que voltou sem entregar, ele só tenta de novo na próxima saída de casa
var esperando_sair := false
var _espera := 0.0

func _ready() -> void:
	Calendario.dia_passou.connect(_ao_dia_passar)

## Dormiu (na cama, na pousada ou desmaiou): amanhã cedo tem carta, se ainda houver pedido a entregar
func _ao_dia_passar(_dia: int) -> void:
	Cidade.marcar_carta_pendente()
	esperando_sair = false

func _process(delta: float) -> void:
	_espera -= delta
	if not ligada or _espera > 0.0:
		return
	_espera = INTERVALO
	verificar()

## Hora do mundo (a da cena principal) ou -1 quando o tempo da vila não vale aqui (arena, casa sem relógio)
func hora_da_vila() -> float:
	var cena := get_tree().current_scene
	if cena == null or get_tree().get_first_node_in_group("gerenciador_ondas") != null:
		return -1.0
	var luz := cena.get_node_or_null("Iluminacao")
	if luz == null or bool(luz.get("em_arena")):
		return -1.0
	return float(luz.hora)

func verificar() -> void:
	if Introducao.ativa() or Transicao.ocupada:
		return
	# A casa não tem relógio: entrar nela já conta para o pombo voltar na próxima saída
	if esperando_sair:
		esperando_sair = [Cooperativo._jogador1(), Cooperativo.jogador2()].any(_ao_ar_livre)
	var hora := hora_da_vila()
	if hora < 0.0:
		return
	verificar_eventos(hora)
	verificar_pombo(hora)

# --- Eventos -------------------------------------------------------------------------------------------------------

func verificar_eventos(hora: float) -> void:
	var dia_semana := Calendario.dia_da_semana()
	for id in Dados.EVENTOS:
		var evento: Dictionary = Dados.EVENTOS[id]
		var dia_evento := int(evento["dia_semana"])
		var inicio := float(evento["inicio"])
		var fim := float(evento["fim"])
		# Depois da meia-noite a festa de sábado ainda é a de sábado (o dia já virou para domingo)
		var madrugada := fim < inicio and hora < fim and dia_semana == (dia_evento + 1) % 7
		var no_dia := dia_semana == dia_evento
		var dia_do_evento := Calendario.dia - (1 if madrugada else 0)
		var acontecendo := (no_dia and hora >= inicio and (fim < inicio or hora < fim)) or madrugada
		if acontecendo:
			_anunciar("%s:comecou:%d" % [id, dia_do_evento], evento["comecou"], evento["detalhe_comecou"])
		elif no_dia and hora >= 6.0 and hora < inicio:
			_anunciar("%s:convite:%d" % [id, dia_do_evento], evento["convite"], evento["detalhe_convite"])

## Banner em todos os HUDs (cada metade da tela tem o seu), uma vez por evento e fase
func _anunciar(chave: String, texto: String, detalhe: String) -> void:
	if anunciados.has(chave):
		return
	anunciados[chave] = true
	get_tree().call_group("hud", "anunciar", texto, detalhe, TEMPO_BANNER)
	Sons.tocar("moeda", 0.05)

# --- Pombo-correio ------------------------------------------------------------------------------------------------

func verificar_pombo(_hora: float = -1.0) -> void:
	if is_instance_valid(pombo) or not Cidade.carta_pendente or Cidade.carta_do_dia() == "":
		return
	# Quem ignorou o pombo recebe a carta na próxima vez que sair de casa (precisa entrar em algum lugar antes)
	if esperando_sair:
		return
	var jogador := destinatario()
	if jogador != null:
		enviar_pombo(jogador, Cidade.carta_do_dia())

func _ao_ar_livre(jogador: Node2D) -> bool:
	return jogador != null and Cooperativo.cena_de(jogador) != null and Cooperativo.cena_de(jogador).scene_file_path in CENAS_AO_AR_LIVRE

## Quem recebe: o jogador 1 se estiver ao ar livre e livre; senão o jogador 2
func destinatario() -> Node2D:
	for jogador in [Cooperativo._jogador1(), Cooperativo.jogador2()]:
		if pode_receber(jogador):
			return jogador
	return null

func pode_receber(jogador: Node2D) -> bool:
	if jogador == null or not jogador is CharacterBody2D or not jogador.movimento_habilitado or bool(jogador.get("estaMorto")) \
			or bool(jogador.get("esta_sentado")):
		return false
	var cena := Cooperativo.cena_de(jogador)
	if cena == null or not cena.scene_file_path in CENAS_AO_AR_LIVRE:
		return false
	var interface := EventosJogo.interface_de(jogador)
	return interface == null or interface._telas_abertas.is_empty()

## Solta o pombo na cena do jogador; ele voa até o lado dele com a carta do pedido `missao`
func enviar_pombo(jogador: Node2D, missao: String) -> Node2D:
	if is_instance_valid(pombo):
		pombo.queue_free()
	pombo = PomboCorreio.new()
	pombo.missao = missao
	pombo.alvo = jogador
	pombo.voltou.connect(_ao_pombo_voltar)
	Cooperativo.cena_de(jogador).add_child(pombo)
	var remetente := "CARTA SEM REMETENTE"
	if Dados.MISSOES.has(missao):
		remetente = "CARTA DE " + String(Dados.MORADORES[Dados.MISSOES[missao]["dono"]]["nome"])
	var hud := _hud_de(jogador)
	if hud != null:
		hud.anunciar("POMBO-CORREIO!", remetente, TEMPO_BANNER)
	return pombo

func _hud_de(jogador: Node2D) -> Node:
	var lado := 2 if bool(jogador.get("eh_p2")) else 1
	var huds := get_tree().get_nodes_in_group("hud_p%d" % lado)
	if huds.is_empty():
		huds = get_tree().get_nodes_in_group("hud")
	return huds[0] if not huds.is_empty() else null

## O pombo foi embora: se a carta não foi lida, ela continua pendente para a próxima saída de casa
func _ao_pombo_voltar(entregue: bool) -> void:
	pombo = null
	esperando_sair = not entregue
