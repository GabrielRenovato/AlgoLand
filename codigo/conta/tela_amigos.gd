extends "res://codigo/conta/tela_conta.gd"
## Amigos: meu código, adicionar por código, pedidos e lista. Com `convite` definido ({tipo, sala, andar}) cada amigo ganha CONVIDAR.
var convite: Dictionary = {}
var _linhas: VBoxContainer
var _campo_amigo: LineEdit
var _aviso: Label
var _meu_codigo := ""

func _cancelar() -> void:
	queue_free()

func _montar() -> void:
	for filho in _caixa.get_children():
		_caixa.remove_child(filho)
		filho.queue_free()
	_caixa.add_child(_rotulo("AMIGOS", 16, COR_OURO, HORIZONTAL_ALIGNMENT_LEFT))
	if not conta.logado():
		_caixa.add_child(_rotulo("Entre na conta para ter amigos e convidar para o coop.", 8, COR_SUAVE, HORIZONTAL_ALIGNMENT_LEFT))
		_caixa.add_child(_botao("FECHAR", queue_free, COR_LINHA, Vector2(0, 26)))
		return
	var topo := HBoxContainer.new()
	topo.add_theme_constant_override("separation", 6)
	_caixa.add_child(topo)
	var meu := _rotulo("SEU CODIGO: ...", 9, COR_TEXTO, HORIZONTAL_ALIGNMENT_LEFT)
	meu.name = "MeuCodigo"
	topo.add_child(meu)
	var copiar := _botao("COPIAR", func(): DisplayServer.clipboard_set(_meu_codigo), COR_BOTAO, Vector2(70, 26))
	topo.add_child(copiar)
	var adicionar := HBoxContainer.new()
	adicionar.add_theme_constant_override("separation", 4)
	_caixa.add_child(adicionar)
	_campo_amigo = _campo_texto("CODIGO DO AMIGO", 8)
	_campo_amigo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_campo_amigo.text_submitted.connect(func(_t): _pedir())
	adicionar.add_child(_campo_amigo)
	adicionar.add_child(_botao("ADICIONAR", _pedir, COR_DESTAQUE, Vector2(92, 28)))
	_aviso = _rotulo("", 8, COR_SUAVE, HORIZONTAL_ALIGNMENT_LEFT)
	_aviso.custom_minimum_size.y = 12
	_caixa.add_child(_aviso)
	var rolagem := ScrollContainer.new()
	rolagem.custom_minimum_size.y = 110
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_caixa.add_child(rolagem)
	_linhas = VBoxContainer.new()
	_linhas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_linhas.add_theme_constant_override("separation", 3)
	rolagem.add_child(_linhas)
	_caixa.add_child(_botao("FECHAR", queue_free, COR_LINHA, Vector2(0, 24)))
	_recarregar.call_deferred()

func _campo_texto(dica: String, maximo: int) -> LineEdit:
	var c: LineEdit = _campo(dica, maximo)
	c.text_changed.connect(func(t: String):
		var maiusculo := t.to_upper()
		if maiusculo != t:
			var cursor := c.caret_column
			c.text = maiusculo
			c.caret_column = cursor)
	return c

func _recarregar() -> void:
	var erro: String = await conta.amigos.atualizar()
	if not is_instance_valid(self): return
	_meu_codigo = conta.amigos.codigo
	var rotulo := _caixa.find_child("MeuCodigo", true, false)
	if rotulo != null: rotulo.text = "SEU CODIGO: " + (_meu_codigo if not _meu_codigo.is_empty() else "...")
	if not erro.is_empty(): _avisar_amigos(erro, COR_ERRO)
	_listar()

func _listar() -> void:
	if not is_instance_valid(_linhas): return
	for filho in _linhas.get_children():
		_linhas.remove_child(filho)
		filho.queue_free()
	var lista: Array = conta.amigos.lista
	if lista.is_empty():
		_linhas.add_child(_rotulo("Ninguem ainda. Passe o seu codigo ou digite o de um amigo.", 8, COR_SUAVE, HORIZONTAL_ALIGNMENT_LEFT))
		return
	for estado in ["recebido", "amigo", "enviado"]:
		for pessoa in lista:
			if pessoa is Dictionary and str(pessoa.get("estado", "")) == estado: _linhas.add_child(_linha(pessoa))

func _linha(pessoa: Dictionary) -> Control:
	var painel := _painel_claro()
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 4)
	painel.add_child(linha)
	var estado := str(pessoa.get("estado", ""))
	var nome := _rotulo(str(pessoa.get("apelido", "?")), 9, COR_TEXTO_ESCURO, HORIZONTAL_ALIGNMENT_LEFT)
	nome.autowrap_mode = TextServer.AUTOWRAP_OFF
	nome.clip_text = true
	linha.add_child(nome)
	var codigo_amigo := str(pessoa.get("codigo", ""))
	match estado:
		"recebido":
			linha.add_child(_botao("ACEITAR", func(): _responder(codigo_amigo, true), COR_DESTAQUE, Vector2(76, 26)))
			linha.add_child(_botao("RECUSAR", func(): _responder(codigo_amigo, false), COR_LINHA, Vector2(76, 26)))
		"enviado":
			linha.add_child(_rotulo("AGUARDANDO", 8, Color("7a6648"), HORIZONTAL_ALIGNMENT_RIGHT))
		_:
			if not convite.is_empty():
				linha.add_child(_botao("CONVIDAR", func(): _convidar(codigo_amigo), COR_DESTAQUE, Vector2(88, 26)))
			else:
				# Texto "X" seria confundido com o botão global de fechar janela.
				linha.add_child(_botao("REMOVER", func(): _remover(codigo_amigo), COR_LINHA, Vector2(80, 26)))
	return painel

func _avisar_amigos(texto: String, cor: Color) -> void:
	if is_instance_valid(_aviso):
		_aviso.text = texto
		_aviso.add_theme_color_override("font_color", cor)

func _pedir() -> void:
	if _campo_amigo.text.strip_edges().is_empty(): return
	_avisar_amigos("AGUARDE...", COR_SUAVE)
	var texto: String = await conta.amigos.pedir(_campo_amigo.text)
	if not is_instance_valid(self): return
	_campo_amigo.text = ""
	_avisar_amigos(texto, COR_OK if texto in ["PEDIDO ENVIADO", "VOCES AGORA SAO AMIGOS"] else COR_ERRO)
	_listar()

func _responder(codigo_amigo: String, aceitar: bool) -> void:
	await conta.amigos.responder(codigo_amigo, aceitar)
	if is_instance_valid(self): _listar()

func _remover(codigo_amigo: String) -> void:
	await conta.amigos.remover(codigo_amigo)
	if is_instance_valid(self): _listar()

func _convidar(codigo_amigo: String) -> void:
	_avisar_amigos("AGUARDE...", COR_SUAVE)
	var texto: String = await conta.amigos.convidar(codigo_amigo, str(convite.get("tipo", "coop")), str(convite.get("sala", "")), int(convite.get("andar", 1)))
	if is_instance_valid(self): _avisar_amigos(texto, COR_OK if texto == "CONVITE ENVIADO" else COR_ERRO)
