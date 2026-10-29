extends "res://codigo/conta/tela_conta.gd"
## Estado da conta, aberto pelo menu de pausa: sincronizar agora, sair, ou (offline) criar a conta sem perder o progresso.
var _atualizacao: Label

func _cancelar() -> void:
	queue_free()

func _montar() -> void:
	for filho in _caixa.get_children():
		_caixa.remove_child(filho)
		filho.queue_free()
	_caixa.add_child(_rotulo("CONTA", 16, COR_OURO, HORIZONTAL_ALIGNMENT_LEFT))
	if not conta.logado():
		_caixa.add_child(_rotulo("Voce esta jogando offline: o progresso fica so neste aparelho e some se o jogo for desinstalado.", 8, COR_SUAVE, HORIZONTAL_ALIGNMENT_LEFT))
		_caixa.add_child(_rotulo("Crie uma conta agora: o seu progresso atual vai para a nuvem e nada se perde.", 8, COR_TEXTO, HORIZONTAL_ALIGNMENT_LEFT))
		_caixa.add_child(_botao("CRIAR CONTA OU ENTRAR", _abrir_login, COR_DESTAQUE, Vector2(0, 32)))
		_caixa.add_child(_botao("FECHAR", queue_free, COR_LINHA, Vector2(0, 26)))
		return
	var nome: String = conta.apelido if not conta.apelido.is_empty() else conta.email
	_caixa.add_child(_rotulo(nome.to_upper(), 11, COR_TEXTO, HORIZONTAL_ALIGNMENT_LEFT))
	_caixa.add_child(_rotulo(conta.email, 8, COR_SUAVE, HORIZONTAL_ALIGNMENT_LEFT))
	_atualizacao = _rotulo("", 8, COR_SUAVE, HORIZONTAL_ALIGNMENT_LEFT)
	_atualizacao.custom_minimum_size.y = 24
	_caixa.add_child(_atualizacao)
	_texto_estado()
	_caixa.add_child(_botao("SINCRONIZAR AGORA", _sincronizar, COR_DESTAQUE, Vector2(0, 30)))
	if conta.nuvem.estado == "conflito":
		_caixa.add_child(_botao("RESOLVER CONFLITO DO SAVE", _resolver, COR_BOTAO, Vector2(0, 28)))
	_caixa.add_child(_botao("SAIR DA CONTA", _sair, COR_BOTAO, Vector2(0, 26)))
	_caixa.add_child(_botao("FECHAR", queue_free, COR_LINHA, Vector2(0, 26)))

func _texto_estado() -> void:
	if not is_instance_valid(_atualizacao): return
	var nuvem: Node = conta.nuvem
	var texto := ""
	if nuvem.ultima_sincronizacao > 0:
		var minutos := int((Time.get_unix_time_from_system() - nuvem.ultima_sincronizacao) / 60.0)
		texto = "NUVEM: SALVO HA %s" % ("MENOS DE 1 MIN" if minutos < 1 else ("%d MIN" % minutos if minutos < 120 else "%d H" % (minutos / 60)))
	else:
		texto = "NUVEM: AINDA NAO SINCRONIZOU"
	if conta.offline: texto += "\nSEM CONEXAO: VOLTA A SINCRONIZAR QUANDO HOUVER REDE"
	elif not nuvem.mensagem.is_empty(): texto += "\n" + nuvem.mensagem
	_atualizacao.text = texto

func _sincronizar() -> void:
	_atualizacao.text = "SINCRONIZANDO..."
	var resultado: String = await conta.nuvem.sincronizar("manual")
	if not is_instance_valid(self): return
	_montar()
	if resultado == "conflito": _resolver()

func _resolver() -> void:
	var arvore := get_tree()
	queue_free()
	arvore.root.add_child(preload("res://codigo/conta/conflito_nuvem.gd").new())

func _abrir_login() -> void:
	var arvore := get_tree()
	queue_free()
	arvore.root.add_child(preload("res://codigo/conta/tela_conta.gd").new())

func _sair() -> void:
	await conta.sair()
	if is_instance_valid(self): queue_free()
