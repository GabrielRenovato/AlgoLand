extends Node
## Parada de impacto: reduz o tempo do jogo por alguns milissegundos reais a cada acerto.
## Vive na raiz da árvore para sempre devolver a velocidade normal, mesmo que o jogador saia da cena.

const ESCALA_PARADA := 0.05
var _fim_ms := 0

static func pedir(arvore: SceneTree, ms: int) -> void:
	if arvore == null or arvore.paused:
		return
	var no := arvore.root.get_node_or_null("ParadaImpacto")
	if no == null:
		no = preload("res://codigo/efeitos/parada_impacto.gd").new()
		no.name = "ParadaImpacto"
		no.process_mode = Node.PROCESS_MODE_ALWAYS
		arvore.root.add_child(no)
	no._iniciar(ms)

func _iniciar(ms: int) -> void:
	# Só mexe no tempo quando ninguém mais está alterando a escala
	if Engine.time_scale != 1.0 and _fim_ms == 0:
		return
	_fim_ms = maxi(_fim_ms, Time.get_ticks_msec() + ms)
	Engine.time_scale = ESCALA_PARADA

func _process(_delta: float) -> void:
	if _fim_ms != 0 and (Time.get_ticks_msec() >= _fim_ms or get_tree().paused):
		_fim_ms = 0
		Engine.time_scale = 1.0

func _exit_tree() -> void:
	if _fim_ms != 0:
		Engine.time_scale = 1.0
