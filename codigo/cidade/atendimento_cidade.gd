extends "res://codigo/logica/interagivel.gd"

## O serviço pertence ao móvel. O morador continua disponível para conversar ao lado.
const POSTOS := {
	"venda": ["mercador", "servicos", "LOJA", Vector2(240,274)],
	"enfermaria": ["curandeira", "servicos", "CUIDADOS", Vector2(96,248)],
	"sede": ["lia", "servicos", "VILA", Vector2(272,180)],
	"mistica": ["mistica", "servicos", "JORNADA", Vector2(320,98)],
	"carpintaria": ["osvaldo", "carpintaria", "CONSTRUIR", Vector2(264,394)],
	"palafita": ["nilo", "servicos", "VARAS", Vector2(160,148)],
	"pousada": ["bardo", "servicos", "POUSADA", Vector2(268,162)],
}
var id := ""
var modo := "servicos"
var legenda := ""

static func montar(interior: Node2D, local: String) -> void:
	if not POSTOS.has(local): return
	var dados: Array = POSTOS[local]
	var posto = load("res://codigo/cidade/atendimento_cidade.gd").new()
	posto.name = "Atendimento"
	posto.id = dados[0]
	posto.modo = dados[1]
	posto.legenda = dados[2]
	posto.position = dados[3]
	interior.add_child(posto)
	if local == "pousada":
		var cozinha = load("res://codigo/cidade/atendimento_cidade.gd").new()
		cozinha.name = "Cozinha"
		cozinha.id = "bardo"
		cozinha.modo = "cozinha"
		cozinha.legenda = "COZINHAR"
		cozinha.position = Vector2(48,86)
		interior.add_child(cozinha)

## Consulta também na confirmação, pois o expediente pode acabar com a tela aberta.
static func impedimento(cena: Node, morador: String, modo_local := "servicos") -> String:
	var dados = load("res://codigo/cidade/dados_cidade.gd")
	if cena == null or cena.get("local") != dados.MORADORES[morador]["casa"]:
		return "Use o balcao no estabelecimento."
	if modo_local == "cozinha": return ""
	var hora: float = cena.hora_atual()
	if morador == "osvaldo" or morador == "nilo":
		if hora < 8 or hora >= 17: return "ATENDIMENTO: 8H AS 17H"
	elif morador != "bardo":
		var fechado: String = dados.servico_fechado(morador,hora,Calendario.dia_da_semana())
		if fechado != "": return fechado
	elif not dados.taverna_aberta(hora,Calendario.dia_da_semana()):
		return "BALCAO: DAS 18H AS 2H"
	var npc: Node2D = cena.get_node_or_null("Nilo") if morador == "nilo" else cena.moradores.get(morador)
	if npc == null or not npc.visible or npc._saindo or npc.agenda.get("local","") != cena.local:
		return "%s JA VOLTA. AGUARDE NO BALCAO." % dados.MORADORES[morador]["nome"]
	return ""

func _ready() -> void:
	nome_tela = "conversa_cidade"
	so_entre_ondas = false
	deslocamento_aviso = Vector2(0,-42)
	var forma := CollisionShape2D.new()
	var area := RectangleShape2D.new()
	area.size = Vector2(32,24)
	forma.shape = area
	add_child(forma)
	super._ready()

func _montar_aviso() -> void:
	super._montar_aviso()
	var texto := Label.new()
	texto.text = legenda
	texto.position = Vector2(-65,14)
	texto.size = Vector2(130,18)
	texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texto.add_theme_font_override("font",FONTE_AVISO)
	texto.add_theme_font_size_override("font_size",8)
	texto.add_theme_color_override("font_color",Color("fff0cc"))
	texto.add_theme_color_override("font_outline_color",Color("302016"))
	texto.add_theme_constant_override("outline_size",3)
	_aviso.add_child(texto)

func prioridade_interacao() -> int:
	return 1

func abrir_tela() -> void:
	_atender(Cooperativo._jogador1())

func abrir_tela_p2() -> void:
	_atender(Cooperativo.jogador2())

## O balcão da carpintaria abre o catálogo de obras (como a bigorna do Ivo abre a forja); os outros postos abrem a conversa
func _atender(quem: Node2D) -> void:
	if not pode_interagir_para(quem): return
	if modo == "carpintaria":
		EventosJogo.abrir_tela_para(quem,"carpintaria")
	else:
		Cidade.atender(id,modo,quem)

func _ao_corpo_saiu(corpo: Node2D) -> void:
	# Sair de uma zona vizinha não fecha a conversa iniciada com o personagem.
	if corpo.is_in_group("jogador2"): p2_perto = false
	elif corpo.is_in_group("character"): jogador_perto = false
