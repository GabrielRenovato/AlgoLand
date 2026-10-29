extends "res://codigo/logica/cenario.gd"

## Cada andar usa seu terreno próprio; a arena original segue intacta.
func _ready() -> void:
	if Introducao.ativa(): return
	_montar_portal()
	var mineracao := preload("res://codigo/fendas/mineracao_fenda.gd").new()
	mineracao.name = "MineracaoArena"
	add_child(mineracao)
	var coop := get_tree().root.get_node_or_null("CoopOnline")
	if coop != null and coop.ativo: coop.instalar(self)

func _montar_portal() -> void:
	var portal := Portal.new()
	portal.name = "PortalDaArena"
	portal.position = to_local(get_node("Terrains/Chegada_portal").global_position) - Vector2(48, 24)
	add_child(portal)
	var zona: Node = portal.get_node("InteracaoPortal")
	zona.nome_tela = "mercante"
	zona.so_entre_ondas = true
	# O círculo da arena original não inicia combates neste modo.
