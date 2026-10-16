extends "res://codigo/ui/missoes_inventario.gd"

const Desafios := preload("res://codigo/dados/desafios_armas.gd")
const Icones := preload("res://codigo/ui/icones_itens.gd")

func _ready() -> void:
	super._ready()
	name = "Desafios"
	Progresso.armas_liberadas_alteradas.connect(_agendar)
	Progresso.onda_vencida_alterada.connect(_agendar)
	EventosJogo.inventario_de(self).mochila_alterada.connect(_agendar)

func _atualizar() -> void:
	_atualizacao_pendente = false
	var foco := get_viewport().gui_get_focus_owner()
	var id_foco := str(foco.get_meta("arma", "")) if foco != null else ""
	for filho in _lista.get_children():
		filho.free()
	_rotulo(_lista, "ARMAS PERMANENTES", Color("f6d879"))
	_rotulo(_lista, "A cada nova tentativa, as armas liberadas voltam ao nivel 1. Melhorias da bigorna valem para a tentativa atual.")
	for tipo in Desafios.DESAFIOS:
		var dados: Dictionary = Desafios.DESAFIOS[tipo]
		var liberada := Progresso.arma_liberada(tipo)
		var cartao := PanelContainer.new()
		cartao.focus_mode = Control.FOCUS_ALL
		cartao.set_meta("arma", tipo)
		cartao.add_theme_stylebox_override("panel", get_theme_stylebox("panel", "TooltipPanel"))
		cartao.draw.connect(func():
			if cartao.has_focus():
				cartao.draw_rect(Rect2(Vector2.ZERO, cartao.size), Color("f6d879"), false, 1.0)
		)
		cartao.focus_entered.connect(cartao.queue_redraw)
		cartao.focus_exited.connect(cartao.queue_redraw)
		_lista.add_child(cartao)
		var linhas := VBoxContainer.new()
		linhas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cartao.add_child(linhas)
		var icone := TextureRect.new()
		icone.texture = Icones.obter_arma(tipo, get_tree())
		icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icone.custom_minimum_size = Vector2(20, 20)
		icone.modulate = Color.WHITE if liberada else Color(0.5, 0.5, 0.5)
		linhas.add_child(icone)
		_rotulo(linhas, DadosItem.NOMES[tipo], Color("f6d879"))
		_rotulo(linhas, dados["titulo"] + "\n" + dados["texto"])
		var atual := mini(int(Progresso.get(dados["campo"])), int(dados["meta"]))
		_rotulo(linhas, "LIBERADA PARA SEMPRE" if liberada else "PROGRESSO: %d / %d" % [atual, dados["meta"]], Color("a8dfad") if liberada else Color.WHITE)
		var inventario := EventosJogo.inventario_de(self)
		if liberada and not tipo in inventario.armas_permanentes_entregues:
			var retirar := Button.new()
			retirar.text = "RETIRAR ARMA NV 1"
			retirar.pressed.connect(inventario.entregar_armas_liberadas)
			linhas.add_child(retirar)
		if tipo == id_foco:
			cartao.grab_focus()
