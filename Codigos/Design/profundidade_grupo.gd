extends Node2D

const Profundidade := preload("res://Codigos/Globais/profundidade.gd")

## Grupo de sprites parados (árvores, tocos, troncos, fatias da barraca...) cuja origem é a base.
## Cada filho recebe o z da sua base; quando o jogador passa atrás de um deles, o sprite fica
## semitransparente para o personagem não sumir.
const ALFA_ATRAS := 0.5
const VELOCIDADE_FADE := 6.0
## Margem interna do retângulo do sprite (as folhas têm bordas transparentes)
const MARGEM := 10.0

## Para objetos fatiados (barraca): se qualquer fatia esconde o jogador, todas ficam transparentes juntas
@export var fade_em_conjunto: bool = false

var _jogador: Node2D
var _filhos: Array[Sprite2D] = []

func _ready() -> void:
	for filho in get_children():
		if filho is Sprite2D:
			filho.z_index = Profundidade.z_de(filho.global_position.y)
			_filhos.append(filho)

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	if not is_instance_valid(_jogador):
		var cena := get_tree().current_scene
		_jogador = cena.get_node_or_null("Jogador") if cena else null
		if _jogador == null:
			return
	var pes := _jogador.global_position.y + Profundidade.PES_JOGADOR
	# Pernas e meio do corpo: se algum deles fica escondido, o objeto da frente fica transparente
	var pernas := Vector2(_jogador.global_position.x, pes - 6.0)
	var corpo := Vector2(_jogador.global_position.x, pes - 16.0)
	var algum_atras := false
	var alvos: Array[float] = []
	for s in _filhos:
		var atras := false
		if pes < s.global_position.y and s.texture != null:
			var ret := _retangulo(s)
			atras = ret.has_point(pernas) or ret.has_point(corpo)
		algum_atras = algum_atras or atras
		alvos.append(ALFA_ATRAS if atras else 1.0)
	for i in _filhos.size():
		var alvo: float = (ALFA_ATRAS if algum_atras else 1.0) if fade_em_conjunto else alvos[i]
		var s := _filhos[i]
		if not is_equal_approx(s.modulate.a, alvo):
			s.modulate.a = move_toward(s.modulate.a, alvo, VELOCIDADE_FADE * delta)

func _retangulo(s: Sprite2D) -> Rect2:
	var tam := s.texture.get_size() * s.global_scale.abs()
	var canto := s.to_global(s.offset)
	# sprites baixos ou fatias finas não aguentam a margem inteira
	var margem_x := minf(MARGEM, tam.x * 0.25) if tam.x > 8.0 else 0.0
	var margem_y := minf(MARGEM, tam.y * 0.25)
	return Rect2(canto, tam).grow_individual(-margem_x, -margem_y, -margem_x, -margem_y)
