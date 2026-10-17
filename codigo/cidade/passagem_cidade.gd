extends "res://codigo/logica/passagem.gd"

## Saída automática (porta de dentro das casas): troca de cena assim que o jogador pisa no vão, sem aviso nem
## botão. Trilhas externas usam direcao_saida; portas de lojas continuam por interação.
@export var automatica := false

func _ready() -> void:
	super._ready()

func pode_interagir() -> bool:
	var jogador := Cooperativo.jogador_no_ambiente(self)
	return jogador != null and jogador.movimento_habilitado and super.pode_interagir()

## Na saída automática o aviso F/Y não aparece
func disponivel_para_interacao() -> bool:
	return not automatica and super.disponivel_para_interacao()

func disponivel_para_p2() -> bool:
	return not automatica and super.disponivel_para_p2()

## A saída automática também não disputa o F com as zonas em volta
func disponivel_isolada() -> bool:
	return not automatica and super.disponivel_isolada()

func disponivel_isolada_p2() -> bool:
	return not automatica and super.disponivel_isolada_p2()

## Lojas: a porta só abre no horário do dono (Dados.servico_fechado); fechada, avisa e não deixa entrar.
## A taverna abre à noite; a enfermaria segue o expediente da curandeira. A casa do Bento é livre.
const Dados := preload("res://codigo/cidade/dados_cidade.gd")
const LOJAS := {"palafita":["nilo","PESCARIA DO NILO"],"venda": ["mercador", "VENDA"], "enfermaria": ["curandeira", "ENFERMARIA"], "mistica": ["mistica", "CASA DA ESTELA"],
	"sede": ["lia", "SEDE"], "pousada": ["bardo", "TAVERNA"]}

func _atravessar(jogador: Node2D) -> void:
	var loja: String = cena_destino.get_file().get_basename()
	if LOJAS.has(loja) and pode_interagir():
		var cena := Cooperativo.cena_de(self)
		var luz := cena.get_node_or_null("Iluminacao")
		var hora: float = luz.hora if luz != null else 12.0
		var dono: String = LOJAS[loja][0]
		var motivo := Dados.servico_fechado(dono, hora, Calendario.dia_da_semana())
		if loja == "pousada" and not Dados.taverna_aberta(hora, Calendario.dia_da_semana()):
			motivo = "ABRE AS 18H"
		if motivo != "":
			_avisar_fechada(loja, dono, motivo, jogador)
			return
	super._atravessar(jogador)

## Aviso na caixa de diálogo (a mesma das falas), com o nome da loja no título: "Fechado. Abre as 8h."
func _avisar_fechada(loja: String, dono: String, motivo: String, jogador: Node2D) -> void:
	var interface := EventosJogo.interface_de(jogador)
	if interface == null:
		return
	var nome := String(Dados.MORADORES[dono]["nome"]).capitalize()
	var horario: Array = Dados.HORARIO_TAVERNA if loja == "pousada" else Dados.HORARIOS[dono]
	var texto := ""
	if motivo == "FOLGA HOJE":
		texto = "Fechado. Hoje e folga de %s. Volte amanha, das %dh as %dh." % [nome, int(horario[0]), int(horario[1])]
	elif motivo.begins_with("ABRE"):
		texto = "Fechado. Abre as %dh." % int(horario[0])
		if loja == "pousada":
			texto = "A taverna abre das 18h as 2h. Volte a noite."
	else:
		texto = "Fechado por hoje. Abre amanha as %dh." % int(horario[0])
	var dialogo: Control = interface._telas["introducao"]
	var paginas: Array[String] = [texto]
	dialogo.iniciar(paginas, LOJAS[loja][1])
	EventosJogo.abrir_tela_para(jogador, "introducao")

## Só atravessa quando o ponto dos pés cruza o centro do bloco da porta.
## body_entered chega antes: o círculo de colisão encosta na área com os pés ainda dentro da sala.
const Profundidade := preload("res://codigo/globais/profundidade.gd")

func _physics_process(delta: float) -> void:
	if not automatica:
		super._physics_process(delta)
		return
	var forma := get_node_or_null("Forma") as CollisionShape2D
	if forma == null or not forma.shape is RectangleShape2D:
		return
	for corpo in get_overlapping_bodies():
		if not corpo.is_in_group("jogadores"):
			continue
		var pes := forma.to_local(corpo.global_position + Vector2(0, Profundidade.PES_JOGADOR))
		if pes.y >= 0.0 and absf(pes.x) < forma.shape.size.x / 2.0:
			_atravessar.call_deferred(corpo)

func _process(delta: float) -> void:
	if automatica:
		_aviso.hide()
	else:
		super._process(delta)
