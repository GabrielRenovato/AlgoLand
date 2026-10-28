extends Node

signal hora_mudou(hora: int, minuto: int)
## O relógio chegou às 02:00 e o jogador apagou (Transicao.dormir já foi pedido)
signal fim_do_dia

# Pontos do dia (hora, cor). Entre eles a cor é interpolada; 24h volta para o início
const PONTOS_DO_DIA := [
	[0.0, Color(0.42, 0.45, 0.68)],
	[4.5, Color(0.42, 0.45, 0.68)],
	[6.0, Color(0.85, 0.78, 0.85)],
	[7.5, Color(1.0, 1.0, 1.0)],
	[16.0, Color(1.0, 1.0, 1.0)],
	[18.0, Color(1.0, 0.82, 0.66)],
	[19.5, Color(0.68, 0.6, 0.78)],
	[21.0, Color(0.42, 0.45, 0.68)],
	[24.0, Color(0.42, 0.45, 0.68)],
]
const INTENSIDADE_VINHETA_DIA := 0.3
const INTENSIDADE_VINHETA_NOITE := 0.6

@export_range(0.0, 24.0) var hora_inicial := 6.0
## Como no Stardew Valley, o dia vai de 06:00 até 02:00 (20 h) e depois o jogador apaga e acorda no dia seguinte.
## Segundos reais por hora do jogo: 24 = 10 min do jogo a cada 4 s (o Stardew usa 42, 10 min a cada 7 s) e ~8 min por dia
@export var segundos_reais_por_hora := 24.0
## Hora em que o dia começa (acordar) e quantas horas ele dura (06:00 + 20 h = 02:00)
const HORA_DESPERTAR := 6.0
const DURACAO_DIA_H := 20.0

## Multiplicador de cor da estação do ano (ver codigo/cenario/estacoes.gd); branco = sem efeito
var tom_estacao := Color.WHITE
## Multiplicador temporário de um evento de onda (NEBLINA); branco = sem efeito. Fica por cima do ciclo e da estação
var tom_evento := Color.WHITE
## Multiplicador do clima (chuva, tempestade, nublado; ver codigo/cenario/clima.gd); branco = sem efeito.
## Também fica por cima do ciclo, da estação e do evento
var tom_clima := Color.WHITE
var _tween_evento: Tween
var _tween_clima: Tween

@onready var _modulador: CanvasModulate = $CanvasModulate

## Hora do relógio (0..24, o que vale para a cor do dia e para o relógio do HUD; 0..2 é a madrugada do fim do dia)
var hora := 0.0
## Horas passadas desde as 06:00 (passa de DURACAO_DIA_H se o fim do dia teve que esperar a onda acabar)
var horas_decorridas := 0.0
var _dormindo := false
var _vinheta: Node
var _gradiente := Gradient.new()
var _ultimo_minuto := -1
## Dentro da arena e dos andares da fenda (há um gerenciador de ondas) o tempo passa como no resto do jogo: o mesmo relógio,
## a mesma luz do dia e o mesmo cansaço da madrugada. A flag só avisa o resto do jogo que o jogador está lutando (o pombo
## e a agenda da vila não valem lá); a Transicao guarda a hora corrente ao sair e a cena seguinte continua dela.
var em_arena := false

func _ready() -> void:
	add_to_group("iluminacao")
	_vinheta = get_parent().get_node_or_null("Vinheta")
	_gradiente.offsets = PackedFloat32Array(PONTOS_DO_DIA.map(func(p): return p[0] / 24.0))
	_gradiente.colors = PackedColorArray(PONTOS_DO_DIA.map(func(p): return p[1]))
	definir_hora(hora_inicial)
	# Atravessando a porta (Transicao) o dia segue a hora em que estava, em vez de voltar para a manhã
	if Transicao.hora_salva >= 0.0:
		definir_hora(Transicao.hora_salva)
	_aplicar()
	_ligar_arena.call_deferred()

## O gerenciador de ondas entra no grupo no próprio _ready: confere depois que a cena inteira montou
func _ligar_arena() -> void:
	if get_tree().get_first_node_in_group("gerenciador_ondas") == null or Introducao.ativa():
		return
	em_arena = true

## A hora que vale para o mundo (Calendario, portas, relógio da cidade): é a do relógio, na arena também
func hora_do_mundo() -> float:
	return hora

func _process(delta: float) -> void:
	# O prólogo não consome o primeiro dia enquanto o jogador aprende.
	if Introducao.ativa() or Comercio.em_viagem:
		_aplicar()
		return
	# O relógio nunca para, nem nos andares. Passando das 02:00 o jogador apaga assim que der (se estiver numa onda, o
	# relógio segue rolando e ele só apaga quando a onda acaba, para não desmaiar no meio do combate)
	horas_decorridas += delta / segundos_reais_por_hora
	hora = fposmod(HORA_DESPERTAR + horas_decorridas, 24.0)
	if horas_decorridas >= DURACAO_DIA_H:
		_tentar_fim_do_dia()
	_aplicar()

## Põe o relógio numa hora (0..24): usado ao acordar, ao atravessar portas e nos testes
func definir_hora(nova: float) -> void:
	hora = fposmod(nova, 24.0)
	horas_decorridas = fposmod(hora - HORA_DESPERTAR, 24.0)
	_dormindo = false

## Fim do dia: só com um jogador em cena (não na tela de título), fora de onda e sem outra transição em andamento
func _tentar_fim_do_dia() -> void:
	if _dormindo or Transicao.ocupada or not is_inside_tree():
		return
	var jogador: Node = get_tree().get_first_node_in_group("character")
	if jogador == null or not jogador is CharacterBody2D:
		return
	# Dentro da arena e dos andares da fenda ninguém desmaia: a corrida longa não é cortada. O cansaço cobra na saída
	# (a Transicao leva o jogador para a vila à 00:00)
	if em_arena:
		return
	for grupo in ["gerenciador_ondas", "gerenciador_andar"]:
		var gerenciador := get_tree().get_first_node_in_group(grupo)
		if gerenciador != null and gerenciador.get("onda_em_andamento"):
			return
	if bool(jogador.get("estaMorto")):
		return
	_dormindo = true
	# Grava o fim do dia já aqui: um save antes do dormir não pode voltar às 6h do mesmo dia
	Calendario.encerrar_dia()
	fim_do_dia.emit()
	# Fora de casa o jogador desmaia e acorda na casa da fazenda
	Transicao.desmaiar()

## Leva o tom do evento até a cor dada (branco desfaz) sem mexer no ciclo do dia nem na estação
func definir_tom_evento(cor: Color, duracao: float = 0.0) -> void:
	if _tween_evento:
		_tween_evento.kill()
	if duracao <= 0.0 or not is_inside_tree():
		tom_evento = cor
		return
	_tween_evento = create_tween()
	_tween_evento.tween_property(self, "tom_evento", cor, duracao)

## Leva o tom do clima até a cor dada (branco desfaz) sem mexer no resto
func definir_tom_clima(cor: Color, duracao: float = 0.0) -> void:
	if _tween_clima:
		_tween_clima.kill()
	if duracao <= 0.0 or not is_inside_tree():
		tom_clima = cor
		return
	_tween_clima = create_tween()
	_tween_clima.tween_property(self, "tom_clima", cor, duracao)

func _aplicar() -> void:
	var cor_ciclo := _gradiente.sample(hora / 24.0)
	var cor := cor_ciclo
	var ambiente := Cooperativo.cena_de(self)
	if ambiente != null and ambiente.get("local") == "pousada":
		cor = Color(1.0, 0.94, 0.84)
	# O tom da estação só tinge a cena; a intensidade da noite (luzes, vinheta) segue o ciclo puro
	_modulador.color = cor if ambiente != null and ambiente.get("local") == "pousada" else cor * tom_estacao * tom_evento * tom_clima
	var cor_noite: Color = PONTOS_DO_DIA[0][1]
	var noite := clampf(inverse_lerp(1.0, cor_noite.get_luminance(), cor_ciclo.get_luminance()), 0.0, 1.0)
	for luz in get_tree().get_nodes_in_group("luzes_noturnas"):
		if luz is CanvasItem and luz.get_canvas() == _modulador.get_canvas():
			luz.set("multiplicador_noite", noite)
	if is_instance_valid(_vinheta):
		_vinheta.intensidade = lerpf(INTENSIDADE_VINHETA_DIA, INTENSIDADE_VINHETA_NOITE, noite)
	# Stardew avança o relógio de 10 em 10 minutos
	var minuto_total := floori(hora * 6.0) * 10
	if minuto_total != _ultimo_minuto:
		_ultimo_minuto = minuto_total
		hora_mudou.emit(floori(minuto_total / 60.0), minuto_total % 60)
