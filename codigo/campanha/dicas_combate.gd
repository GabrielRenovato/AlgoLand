extends Node

## Dicas curtas na hora certa, uma vez por sessão: ensinam ataque, defesa e esquiva sem tela de tutorial.
var cena: Node2D
var _espera := 0.0
const INTERVALO := 7.0

func _vistas() -> Dictionary:
	if not get_tree().has_meta("dicas_vistas"): get_tree().set_meta("dicas_vistas", {})
	return get_tree().get_meta("dicas_vistas")

func _dar(id: String, titulo: String, texto: String) -> void:
	_vistas()[id] = true
	_espera = INTERVALO
	cena.hud.anunciar(titulo, texto, 5.0)

func _process(delta: float) -> void:
	_espera = maxf(_espera - delta, 0.0)
	if _espera > 0.0 or not is_instance_valid(cena) or not is_instance_valid(cena.jogador) or cena.jogador.estaMorto: return
	if not cena.interface._telas_abertas.is_empty() or bool(get_tree().get_meta("cinema_ativo", false)): return
	var vistas := _vistas()
	var equipados: Array = cena.equipamentos_encontrados()
	if not vistas.has("golpe") and "espada_basica" in equipados and "escudo_basico" in equipados:
		_dar("golpe", "Espada e escudo prontos", "Clique ou Espaço para atacar. Segure Ctrl para defender e Shift para esquivar.")
		return
	if not vistas.has("rebento"):
		for inimigo in get_tree().get_nodes_in_group("enemy"):
			if is_instance_valid(inimigo) and "rebento" in inimigo.scene_file_path and not inimigo.get("esta_morto") and inimigo.global_position.distance_to(cena.jogador.global_position) < 130.0:
				_dar("rebento", "Um rebento à frente", "Ele ataca em dois golpes. Defenda com Ctrl ou esquive com Shift quando ele armar a garra.")
				return
	if not vistas.has("vida") and cena.jogador.hp_atual <= cena.jogador.estatisticas.hp_maximo * 0.35:
		_dar("vida", "Vida baixa", "Afaste-se do combate e use uma poção (R). A esquiva (Shift) ajuda a sair de perto.")
