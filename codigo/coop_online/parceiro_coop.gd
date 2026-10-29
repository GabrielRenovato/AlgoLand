extends "res://codigo/duelo/adversario_remoto.gd"
## Apenas o avatar do parceiro, sem inventário ou save locais.
var controlador: Node
var invulneravel := false
var hp_atual: int:
	get: return hp
	set(valor): hp = valor

func _ready() -> void:
	remove_from_group("enemy")
	add_to_group("jogadores")
	set_meta("parceiro_coop", true)
	collision_layer = 0
	var area := Area2D.new()
	area.name = "AreaDano"
	area.collision_layer = 2
	area.collision_mask = 0
	var forma := CollisionShape2D.new()
	var capsula := CapsuleShape2D.new()
	capsula.radius = 6.0
	capsula.height = 26.0
	forma.shape = capsula
	forma.position = Vector2(0, -2)
	area.add_child(forma)
	add_child(area)

func receber_dano(dano: int, empurrao: Vector2 = Vector2.ZERO) -> void:
	if controlador != null and not estaMorto:
		controlador.dano_no_parceiro(dano, empurrao)

func grupo_hud() -> String: return "hud_remoto_coop"

func levantar_caido() -> void:
	if controlador != null and controlador.sessao.sou_host():
		controlador.sessao.enviar({"t": "reviver", "andar": controlador.andar})

func aplicar_petrificacao(duracao: float) -> bool:
	if controlador != null and controlador.sessao.sou_host():
		controlador.sessao.enviar({"t": "petrificar", "andar": controlador.andar, "duracao": duracao})
	return true

func receber_hitkill_chefe() -> void:
	if controlador != null and controlador.sessao.sou_host():
		controlador.sessao.enviar({"t": "execucao", "andar": controlador.andar})
