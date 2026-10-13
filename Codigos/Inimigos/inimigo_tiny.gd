extends "Inimigo-generico.gd"

## O Tiny usa a mesma vida, navegação, mutantes e drops dos demais inimigos.
## Arqueiro e espinhento disparam; bombardeiro e flor avisam a área antes do impacto.
const ProjetilTiny := preload("res://Codigos/Inimigos/projetil_tiny.gd")
@export_enum("contato", "flecha", "espinho", "bomba", "esporos") var tipo_disparo: String = "contato"

func _physics_process(delta: float) -> void:
	# Os tipos imóveis não passam pelo movimento da base, que reduz o tempo de atordoamento.
	if parado and not esta_morto and _atordoado > 0.0:
		_atordoado = maxf(_atordoado - delta, 0.0)
	super(delta)

func _iniciar_ataque(direcao: Vector2) -> void:
	if esta_morto:
		return
	if tipo_disparo == "contato":
		super(direcao)
		return
	var alvo := obter_jogador()
	if alvo == null:
		return
	# Mira no começo do golpe: o jogador pode desviar durante a preparação.
	var destino := alvo.global_position
	super(direcao)
	await get_tree().create_timer(_frames("ataque").size() / fps_ataque * 0.5).timeout
	if esta_morto or esta_atordoado() or not is_instance_valid(alvo):
		return
	var disparo := ProjetilTiny.new()
	disparo.tipo = tipo_disparo
	disparo.dano = obter_dano()
	disparo.alvo = alvo
	disparo.origem = global_position
	disparo.destino = global_position if tipo_disparo == "esporos" else destino
	# Filho com coordenadas globais: ao remover o inimigo, os ataques pendentes também somem.
	add_child(disparo)
