extends Node2D

## Folha de ação independente: a caminhada original conserva grade e pivô.
var martelando := false
var _sprite: Sprite2D
var _tempo := 0.0
var _ultimo_quadro := -1

func _ready() -> void:
	name = "TrabalhoCarpinteiro"
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://assets/npcs/cidade/osvaldo_construindo.png")
	_sprite.hframes = 6
	_sprite.vframes = 4
	_sprite.position = get_parent().sprite.position
	_sprite.texture_filter = TEXTURE_FILTER_NEAREST
	_sprite.hide()
	add_child(_sprite)

func _process(delta: float) -> void:
	var npc := get_parent()
	martelando = npc.visible and not npc._saindo and not npc.dormindo and npc.agenda.get("construindo",false) \
		and npc.caminho.is_empty() and npc.position.distance_to(npc._alvo) < 18 \
		and not Cidade.em_conversa(npc.id) and int(Fazenda.galinheiro.obra) > 0 \
		and npc.vila.hora_atual() >= 8 and npc.vila.hora_atual() < 17
	_sprite.visible = martelando
	npc.sprite.visible = not martelando
	if not martelando:
		_tempo = 0
		return
	_tempo += delta
	# Olha para o ponto onde a ferramenta toca, sem animar o corpo inteiro parado.
	var direcao := 3 if npc.position.x > 220 else 2
	var quadro := int(_tempo*8)%6
	_sprite.frame = direcao*6+quadro
	if quadro == 4 and _ultimo_quadro != quadro:
		# O som só existe perto da obra, sem emitir várias batidas por frame.
		var jogador := Cooperativo.jogador_no_ambiente(self)
		if jogador != null and jogador.global_position.distance_to(global_position) < 180:
			Sons.tocar("enxada",0.08,-14.0)
	_ultimo_quadro = quadro
