extends CanvasLayer

const FONTE_STATUS: FontFile = preload("res://assets/ui/Planes_ValMore.ttf")

func _ready() -> void:
	$InformacaoPersonagem.visible = false

# Reconstruir os rótulos todo frame (com load de fonte) enquanto a tecla estava segurada pesava à toa
func _unhandled_input(evento: InputEvent) -> void:
	if Controle.digitando and evento is InputEventKey: return
	if evento.is_action_pressed("show_stats") and not evento.is_echo():
		$InformacaoPersonagem.visible = true
		atualizar_menu()
	elif evento.is_action_released("show_stats"):
		$InformacaoPersonagem.visible = false

func atualizar_menu() -> void:
	var jogador = get_tree().get_root().get_node("cenario/Jogador")
	if jogador == null:
		return

	# --- Atualizar Estatísticas do Jogador (em um GridContainer) ---
	for filho in $InformacaoPersonagem/StatusJogador.get_children():
		filho.queue_free()

	var array_estatisticas = [
		"FOR: " + str(jogador.estatisticas.forca),
		"AGI: " + str(jogador.estatisticas.agilidade),
		"VIT: " + str(jogador.estatisticas.vitalidade),
		"INT: " + str(jogador.estatisticas.inteligencia),
		"SOR: " + str(jogador.estatisticas.sorte),
		"DEF: " + str(jogador.estatisticas.defesa),
		"DAN: " + str(jogador.estatisticas.dano_ataque)
	]

	var arquivo_fonte: FontFile = FONTE_STATUS

	for linha_estatistica in array_estatisticas:
		var rotulo = Label.new()
		rotulo.text = linha_estatistica
		
		rotulo.add_theme_font_override("font", arquivo_fonte)
		rotulo.add_theme_font_size_override("font_size", 8)  # Tamanho definido aqui
		rotulo.add_theme_color_override("font_color", Color.WHITE)
		rotulo.add_theme_constant_override("line_spacing", 3)
		
		rotulo.add_theme_color_override("shadow_color", Color.BLACK)
		rotulo.add_theme_constant_override("shadow_size", 1)
		rotulo.add_theme_constant_override("shadow_offset_x", 1)
		rotulo.add_theme_constant_override("shadow_offset_y", 1)
		
		$InformacaoPersonagem/StatusJogador.add_child(rotulo)

	# --- Atualizar Itens Comprados (em outro GridContainer) ---
	for filho in $InformacaoPersonagem/FundoItensComprados/ItensComprados.get_children():
		filho.queue_free()

	if jogador.itens_comprados.size() > 0:
		var cena_item = preload("res://cenas/item.tscn")
		for dados_item in jogador.itens_comprados:
			var instancia_item = cena_item.instantiate()
			instancia_item.definir_dados_item(dados_item)
			$InformacaoPersonagem/FundoItensComprados/ItensComprados.add_child(instancia_item)
	else:
		var rotulo_vazio = Label.new()
		rotulo_vazio.text = "NENHUM ITEM COMPRADO"
		rotulo_vazio.add_theme_font_override("font", arquivo_fonte)
		rotulo_vazio.add_theme_font_size_override("font_size", 8)  # Adicione aqui também
		rotulo_vazio.add_theme_color_override("font_color", Color.WHITE)
		$InformacaoPersonagem/FundoItensComprados/ItensComprados.add_child(rotulo_vazio)
