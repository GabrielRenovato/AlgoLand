extends Node3D
## Modelo visual animado; não implementa IA, dano ou deslocamento físico.
const CICLOS := [&"parado", &"correr", &"defesa"]
@export var animacao_inicial: StringName = &"parado"
var animador: AnimationPlayer

func _ready() -> void:
	animador = find_children("*", "AnimationPlayer", true, false)[0]
	for nome in animador.get_animation_list():
		animador.get_animation(nome).loop_mode = Animation.LOOP_LINEAR if nome in CICLOS else Animation.LOOP_NONE
	animador.animation_finished.connect(_ao_terminar)
	tocar(animacao_inicial, 0.0)

func tocar(nome: StringName, transicao := 0.12) -> bool:
	if animador == null or not animador.has_animation(nome):
		return false
	animador.play(nome, transicao)
	return true

func _ao_terminar(nome: StringName) -> void:
	if nome != &"morrer":
		tocar(&"parado")
