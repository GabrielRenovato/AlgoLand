extends "res://codigo/conta/tela_conta.gd"
## Este aparelho e a nuvem têm progressos diferentes: o jogador escolhe qual manter. Nada é apagado sem cópia.
var _rotulo_estado: Label
var _botoes: Array[Button] = []

func _cancelar() -> void:
	queue_free()

func _resumo_texto(resumo: Dictionary) -> String:
	return "DIA %d\nANDAR %d\n%d BRASAS" % [int(resumo.get("dia", 1)), int(resumo.get("recorde", 0)), int(resumo.get("brasas", 0))]

func _montar() -> void:
	for filho in _caixa.get_children():
		_caixa.remove_child(filho)
		filho.queue_free()
	var nuvem: Node = conta.nuvem
	var dados: Dictionary = nuvem.conflito
	_caixa.add_child(_rotulo("QUAL PROGRESSO MANTER?", 13, COR_OURO, HORIZONTAL_ALIGNMENT_LEFT))
	_caixa.add_child(_rotulo("Aparelho e conta tem jogos diferentes. Uma copia do que sair fica guardada.", 8, COR_SUAVE, HORIZONTAL_ALIGNMENT_LEFT))
	var colunas := HBoxContainer.new()
	colunas.add_theme_constant_override("separation", 8)
	_caixa.add_child(colunas)
	colunas.add_child(_cartao("ESTE APARELHO", _resumo_texto(dados.get("local", {})), COR_DESTAQUE))
	var quando := str(dados.get("atualizado_em", "")).left(10)
	var origem := str(dados.get("aparelho", "")).strip_edges()
	colunas.add_child(_cartao("NUVEM", _resumo_texto(dados.get("nuvem", {})) + ("\n" + quando if not quando.is_empty() else ""), COR_BOTAO))
	_rotulo_estado = _rotulo("", 8, COR_ERRO, HORIZONTAL_ALIGNMENT_LEFT)
	_rotulo_estado.custom_minimum_size.y = 12
	_caixa.add_child(_rotulo_estado)
	_botoes.clear()
	_botoes.append(_botao("MANTER ESTE APARELHO", func(): _escolher(false), COR_DESTAQUE, Vector2(0, 28)))
	_botoes.append(_botao("USAR A NUVEM", func(): _escolher(true), COR_BOTAO, Vector2(0, 28)))
	for b in _botoes: _caixa.add_child(b)
	_caixa.add_child(_botao("DECIDIR DEPOIS", queue_free, COR_LINHA, Vector2(0, 24)))

func _cartao(titulo: String, texto: String, cor: Color) -> Control:
	var painel := _painel_claro(14.0, 8.0)
	painel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 2)
	painel.add_child(coluna)
	coluna.add_child(_rotulo(titulo, 9, Color("8a4b14") if cor == COR_DESTAQUE else Color("5a4128")))
	coluna.add_child(_rotulo(texto, 9, COR_TEXTO_ESCURO))
	return painel

func _escolher(usar_nuvem: bool) -> void:
	if conta.nuvem.ocupado(): return
	for b in _botoes: b.disabled = true
	_rotulo_estado.add_theme_color_override("font_color", COR_SUAVE)
	_rotulo_estado.text = "AGUARDE..."
	if usar_nuvem and not conta.nuvem.no_titulo(get_tree()):
		_rotulo_estado.add_theme_color_override("font_color", COR_ERRO)
		_rotulo_estado.text = "VOLTE AO MENU INICIAL PARA USAR A NUVEM"
		for b in _botoes: b.disabled = false
		return
	var resultado: String = await conta.nuvem.resolver(usar_nuvem)
	if not is_instance_valid(self): return
	if resultado in ["ok", "baixado"]:
		queue_free()
	else:
		_rotulo_estado.add_theme_color_override("font_color", COR_ERRO)
		_rotulo_estado.text = conta.nuvem.mensagem if not conta.nuvem.mensagem.is_empty() else "NAO FOI POSSIVEL CONCLUIR"
		for b in _botoes: b.disabled = false
