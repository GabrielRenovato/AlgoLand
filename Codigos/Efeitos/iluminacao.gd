extends Node

signal hora_mudou(hora: int, minuto: int)

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
## Duração real de um dia completo (24h do jogo)
@export var minutos_reais_por_dia := 14.0

## Multiplicador de cor da estação do ano (ver Codigos/Design/estacoes.gd); branco = sem efeito
var tom_estacao := Color.WHITE
## Multiplicador temporário de um evento de onda (NEBLINA); branco = sem efeito. Fica por cima do ciclo e da estação
var tom_evento := Color.WHITE
## Multiplicador do clima (chuva, tempestade, nublado; ver Codigos/Design/clima.gd); branco = sem efeito.
## Também fica por cima do ciclo, da estação e do evento
var tom_clima := Color.WHITE
var _tween_evento: Tween
var _tween_clima: Tween

@onready var _modulador: CanvasModulate = $CanvasModulate

var hora := 0.0
var _vinheta: Node
var _gradiente := Gradient.new()
var _ultimo_minuto := -1

func _ready() -> void:
	add_to_group("iluminacao")
	_vinheta = get_parent().get_node_or_null("Vinheta")
	_gradiente.offsets = PackedFloat32Array(PONTOS_DO_DIA.map(func(p): return p[0] / 24.0))
	_gradiente.colors = PackedColorArray(PONTOS_DO_DIA.map(func(p): return p[1]))
	hora = hora_inicial
	_aplicar()

func _process(delta: float) -> void:
	hora = fmod(hora + delta * 24.0 / (minutos_reais_por_dia * 60.0), 24.0)
	_aplicar()

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
	var cor := _gradiente.sample(hora / 24.0)
	# O tom da estação só tinge a cena; a intensidade da noite (luzes, vinheta) segue o ciclo puro
	_modulador.color = cor * tom_estacao * tom_evento * tom_clima
	var cor_noite: Color = PONTOS_DO_DIA[0][1]
	var noite := clampf(inverse_lerp(1.0, cor_noite.get_luminance(), cor.get_luminance()), 0.0, 1.0)
	get_tree().call_group("luzes_noturnas", "set", "multiplicador_noite", noite)
	if is_instance_valid(_vinheta):
		_vinheta.intensidade = lerpf(INTENSIDADE_VINHETA_DIA, INTENSIDADE_VINHETA_NOITE, noite)
	# Stardew avança o relógio de 10 em 10 minutos
	var minuto_total := floori(hora * 6.0) * 10
	if minuto_total != _ultimo_minuto:
		_ultimo_minuto = minuto_total
		hora_mudou.emit(floori(minuto_total / 60.0), minuto_total % 60)
