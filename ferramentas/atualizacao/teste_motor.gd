extends SceneTree

## Executado no projeto mínimo preparado por teste_pacotes_atualizacao.py.
var falhas := 0
func _initialize() -> void: rodar.call_deferred()
func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ", nome)
	if not ok: falhas += 1
func rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes pacotes"):
		print("FALHA: prepare o projeto mínimo com teste_pacotes_atualizacao.py --preparar-motor")
		quit(1)
		return
	var boot = root.get_node("InicializacaoPatches")
	var envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://servidor/envelope.json"))
	var manifesto: Dictionary = boot.validar_manifesto(envelope)
	verificar("manifesto assinado aceito", not manifesto.is_empty())
	var adulterado := envelope.duplicate(true)
	adulterado.dados += " "
	verificar("manifesto adulterado rejeitado", boot.validar_manifesto(adulterado).is_empty())
	var invalidos: Array = JSON.parse_string(FileAccess.get_file_as_string("res://servidor/invalidos.json"))
	for invalido in invalidos:
		verificar("rejeita caminhos e ids inválidos mesmo assinados", boot.validar_manifesto(invalido).is_empty())
	if "--corrompido" in OS.get_cmdline_user_args():
		verificar("corrupção local não monta geração parcial", boot.conteudo == 0 and not boot.erro.is_empty() and root.get_node("Sentinela").VALOR == "base")
		DirAccess.remove_absolute(boot.REGISTRO)
		DirAccess.remove_absolute(boot.PASTA + "area.pck")
		quit(falhas)
		return
	if "--montado" in OS.get_cmdline_user_args():
		verificar("patch carregado antes de compilar autoload", root.get_node("Sentinela").VALOR == "patch antes dos autoloads")
		verificar("geração ativa", boot.conteudo == 1)
		verificar("tema global já em cache recebe patch", ThemeDB.get_project_theme().default_font_size == 18)
		var arquivo := FileAccess.open(boot.PASTA + "area.pck", FileAccess.READ_WRITE)
		arquivo.seek_end()
		arquivo.store_8(1)
		arquivo.close()
		quit(falhas)
		return
	verificar("primeira abertura usa base", root.get_node("Sentinela").VALOR == "base")
	DirAccess.make_dir_recursive_absolute(boot.PASTA)
	var atualizador = load("res://atualizador_teste.gd").new()
	root.add_child(atualizador)
	atualizador.url_base = "http://127.0.0.1:18764/"
	var incompleto: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://servidor/incompleto.json"))
	verificar("download interrompido não ativa geração", not await atualizador._baixar_geracao(incompleto, boot.validar_manifesto(incompleto)))
	verificar("registro preservado sem geração parcial", not FileAccess.file_exists(boot.REGISTRO))
	verificar("atualização obrigatória persiste após falha", not atualizador._ler_pendente().is_empty())
	var entradas := {"total": 0}
	atualizador.concluida.connect(func(): entradas.total += 1)
	atualizador._ir_para_o_jogo()
	verificar("falha bloqueia entrada no jogo", entradas.total == 0)
	process_frame.connect(func():
		verificar("falha oferece só tentar novamente e sair", atualizador._botoes.get_child_count() == 2 and atualizador._botoes.get_child(0).text == "TENTAR NOVAMENTE" and atualizador._botoes.get_child(1).text == "SAIR")
		atualizador._botoes.get_child(0).pressed.emit(), CONNECT_ONE_SHOT)
	verificar("nova tentativa solicitada", await atualizador._aguardar_nova_tentativa())
	atualizador.remoto_teste = {}
	process_frame.connect(_sair_quando_falhar.bind(atualizador), CONNECT_ONE_SHOT)
	await atualizador._executar()
	verificar("pendência offline não permite pular atualização", atualizador.encerrou and entradas.total == 0 and atualizador.estado == "falha_atualizacao")
	atualizador.encerrou = false
	verificar("instalação completa", await atualizador._baixar_geracao(envelope, manifesto))
	verificar("não mistura geração na sessão atual", root.get_node("Sentinela").VALOR == "base")
	# Sem servidor: um pacote já íntegro deve ser reaproveitado sem HTTP.
	atualizador.url_base = "http://127.0.0.1:1/"
	verificar("pacote intacto reutilizado sem baixar", await atualizador._baixar_geracao(envelope, manifesto))
	var pacote: Dictionary = manifesto.pacotes[0]
	verificar("hash e assinatura do pacote", boot.conferir_pacote(boot.PASTA + pacote.arquivo, pacote))
	verificar("pendência removida após instalação íntegra", atualizador._ler_pendente().is_empty())
	# Exercita a orquestração real, incluindo o retorno após pedir reabertura.
	atualizador.remoto_teste = {"pacotes": {"linux": {"teste": envelope}}}
	await atualizador._executar()
	verificar("atualização concluída reinicia sozinha", atualizador.pedido_reinicio)
	verificar("atualização concluída exige reabertura e não libera jogo", atualizador.encerrou and entradas.total == 0 and atualizador.estado == "aguardando_reabertura")
	for dimensao in [Vector2i(576,324), Vector2i(480,270), Vector2i(288,512), Vector2i(320,324)]:
		root.content_scale_size = dimensao
		root.size = dimensao
		for fase in ["download", "falha", "pronto"]:
			atualizador._limpar_botoes()
			atualizador._barra.visible = fase == "download"
			if fase == "download":
				atualizador._texto.text = "Atualizando interface (12/12)…"
				atualizador._detalhe.text = "124,5 / 200,0 MB · Aguarde para entrar no jogo."
				atualizador._barra.value = 62
			elif fase == "falha":
				atualizador._texto.text = "Não foi possível concluir a atualização."
				atualizador._detalhe.text = "Confira sua conexão e tente novamente para entrar no jogo."
				atualizador._botao("TENTAR NOVAMENTE", func(): pass)
				atualizador._botao("SAIR", func(): pass)
			else:
				atualizador._texto.text = "Atualização pronta!"
				atualizador._detalhe.text = "Reiniciando o jogo para ativar o novo conteúdo…"
			for i in 8: await process_frame
			var limite := Rect2(Vector2(15,15),Vector2(dimensao)-Vector2(30,30))
			verificar("painel cabe %s %s" % [fase, dimensao], limite.encloses(atualizador._painel.get_global_rect()))
			var interior: Rect2 = atualizador._papel.get_global_rect().grow(-10)
			for no in [atualizador._texto, atualizador._detalhe, atualizador._barra]:
				if not no.visible: continue
				verificar("moldura preserva margens %s %s %s" % [fase,dimensao,no.get_class()], interior.encloses(no.get_global_rect()))
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("/tmp/algoland-atualizacao-%s-%dx%d.png" % [fase,dimensao.x,dimensao.y])
	quit(falhas)

func _sair_quando_falhar(atualizador: Node) -> void:
	if atualizador.estado != "falha_atualizacao":
		process_frame.connect(_sair_quando_falhar.bind(atualizador), CONNECT_ONE_SHOT)
		return
	atualizador._botoes.get_child(1).pressed.emit()
