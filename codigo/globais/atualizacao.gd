extends Control

## Consulta e baixa uma geração completa por áreas. A ativação acontece na próxima abertura,
## pelo primeiro autoload, antes de compilar o restante do jogo.
const Estilo := preload("res://codigo/ui/estilo_inicio_detalhado.gd")
const EstiloBarra := preload("res://codigo/ui/estilo_interface.gd")
const CENA_INICIAL := "res://cenas/inicio_do_jogo.tscn"
const PASTA := "user://atualizacao/"
const REGISTRO := PASTA + "pacotes.json"
const REGISTRO_PENDENTE := PASTA + "pendente.json"
const TEMPO_CONSULTA := 8.0
const TEMPO_DOWNLOAD := 120.0

signal concluida

var url_base := ""
var versao_app := ""
var conteudo_local := 0
var estado := "iniciando"
var _texto: Label
var _detalhe: Label
var _barra: ProgressBar
var _botoes: BoxContainer
var _coluna: VBoxContainer
var _painel: PanelContainer
var _papel: PanelContainer
var _titulo: Label
var _atualizacao_pendente := false
var _http: HTTPRequest
var _decisao := ""

func _ready() -> void:
	_montar_interface()
	_executar.call_deferred()

func _ativa() -> bool:
	if OS.has_feature("web"):
		return false
	url_base = _argumento("--atualizacao-url=")
	if url_base.is_empty():
		url_base = str(ProjectSettings.get_setting("algoland/url_atualizacao", ""))
		if OS.has_feature("editor"):
			return false
	if url_base.is_empty():
		return false
	if not url_base.ends_with("/"):
		url_base += "/"
	return true

func _argumento(prefixo: String) -> String:
	for a in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if a.begins_with(prefixo):
			return a.substr(prefixo.length())
	return ""

func _executar() -> void:
	versao_app = str(ProjectSettings.get_setting("application/config/version", ""))
	if not _ativa():
		_ir_para_o_jogo()
		return
	DirAccess.make_dir_recursive_absolute(PASTA)
	conteudo_local = InicializacaoPatches.conteudo
	estado = "consultando"
	_texto.text = "Procurando atualizações…"
	var remoto := await _baixar_json(url_base + "versao.json")
	var pendente := _ler_pendente()
	if remoto.is_empty() and pendente.is_empty():
		# Sem resposta (sem internet, servidor fora do ar): avisa em vez de abrir calado, para a falha não passar despercebida
		_texto.text = "Sem conexão com as atualizações."
		_detalhe.text = "O jogo abre na versão atual (%s)." % versao_app
		await get_tree().create_timer(1.6).timeout
		_ir_para_o_jogo()
		return
	var plataformas = remoto.get("pacotes", {})
	var por_plataforma = plataformas.get(InicializacaoPatches.plataforma(), {}) if plataformas is Dictionary else {}
	var envelope = por_plataforma.get(versao_app, {}) if por_plataforma is Dictionary else {}
	var dados: Dictionary = InicializacaoPatches.validar_manifesto(envelope) if envelope is Dictionary else {}
	var dados_pendentes := InicializacaoPatches.validar_manifesto(pendente)
	if not dados_pendentes.is_empty() and (dados.is_empty() or int(dados_pendentes.conteudo) > int(dados.conteudo)):
		envelope = pendente
		dados = dados_pendentes
	if not dados.is_empty() and int(dados.conteudo) > conteudo_local:
		_atualizacao_pendente = true
		while not await _baixar_geracao(envelope, dados):
			if not await _aguardar_nova_tentativa():
				return
		await _oferecer_reabertura()
		return

	var aplicativos = remoto.get("aplicativos", {})
	var aplicativo = aplicativos.get(InicializacaoPatches.plataforma(), {}) if aplicativos is Dictionary else {}
	if not aplicativo is Dictionary: aplicativo = {}
	if aplicativo.is_empty() and OS.has_feature("android"):
		aplicativo = {"versao": remoto.get("apk", ""), "url": remoto.get("url_apk", "")}
	var versao_nova := str(aplicativo.get("versao", ""))
	var url_app := str(aplicativo.get("url", ""))
	if not versao_nova.is_empty() and versao_nova != versao_app and not url_app.is_empty():
		await _oferecer_aplicativo(versao_nova, url_app)
	else:
		_barra.visible = false
		_texto.text = "Abrindo jogo…"
		_detalhe.text = "Versão %s · conteúdo %d" % [versao_app, conteudo_local]
		await get_tree().create_timer(0.5).timeout
	_ir_para_o_jogo()

func _baixar_geracao(envelope: Dictionary, dados: Dictionary) -> bool:
	_atualizacao_pendente = true
	_limpar_botoes()
	if not _gravar_registro(REGISTRO_PENDENTE, envelope): return false
	var indice := 0
	for pacote in dados.pacotes:
		indice += 1
		# Endereços pelo hash permitem reutilizar áreas intactas entre gerações.
		if InicializacaoPatches.conferir_pacote(PASTA + str(pacote.arquivo), pacote):
			continue
		_texto.text = "Atualizando %s (%d/%d)…" % [pacote.id, indice, dados.pacotes.size()]
		if not await _baixar_patch(pacote): return false
	# O registro antigo permanece válido até todos os pacotes estarem prontos.
	if not _gravar_registro(REGISTRO, envelope): return false
	DirAccess.remove_absolute(REGISTRO_PENDENTE)
	return true

func _ler_pendente() -> Dictionary:
	if not FileAccess.file_exists(REGISTRO_PENDENTE): return {}
	var envelope = JSON.parse_string(FileAccess.get_file_as_string(REGISTRO_PENDENTE))
	if not envelope is Dictionary: return {}
	var dados := InicializacaoPatches.validar_manifesto(envelope)
	if dados.is_empty() or int(dados.conteudo) <= conteudo_local: return {}
	return envelope

func _gravar_registro(caminho: String, envelope: Dictionary) -> bool:
	var saida := FileAccess.open(caminho + ".tmp", FileAccess.WRITE)
	if saida == null: return false
	saida.store_string(JSON.stringify(envelope))
	saida.flush()
	var erro_escrita := saida.get_error()
	saida.close()
	return erro_escrita == OK and DirAccess.rename_absolute(caminho + ".tmp", caminho) == OK

func _aguardar_nova_tentativa() -> bool:
	estado = "falha_atualizacao"
	_barra.hide()
	_texto.text = "Não foi possível concluir a atualização."
	_detalhe.text = "Confira sua conexão e tente novamente para entrar no jogo."
	_decisao = ""
	_limpar_botoes()
	_botao("TENTAR NOVAMENTE", func(): _decisao = "tentar")
	_botao("SAIR", func(): _decisao = "sair")
	while _decisao.is_empty(): await get_tree().process_frame
	_limpar_botoes()
	if _decisao == "sair":
		_encerrar()
		return false
	return true

func _oferecer_reabertura() -> void:
	estado = "aguardando_reabertura"
	_barra.hide()
	_limpar_botoes()
	_texto.text = "Atualização pronta!"
	_detalhe.text = "Reiniciando o jogo para ativar o novo conteúdo…"
	await get_tree().create_timer(1.2).timeout
	_reiniciar()

## Fecha e abre o jogo de novo sozinho (desktop e Android); se o sistema não reabrir, o jogo apenas fecha como antes
func _reiniciar() -> void:
	_pedir_reinicio()
	_encerrar()

func _pedir_reinicio() -> void:
	OS.set_restart_on_exit(true, OS.get_cmdline_args())

func _encerrar() -> void:
	get_tree().quit()

func _baixar_json(url: String) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = TEMPO_CONSULTA
	http.body_size_limit = 2 * 1024 * 1024
	add_child(http)
	if http.request(url) != OK:
		http.queue_free()
		return {}
	var resposta: Array = await http.request_completed
	http.queue_free()
	if resposta[0] != HTTPRequest.RESULT_SUCCESS or resposta[1] != 200:
		return {}
	var dados = JSON.parse_string((resposta[3] as PackedByteArray).get_string_from_utf8())
	return dados if dados is Dictionary else {}

func _baixar_patch(patch: Dictionary) -> bool:
	estado = "baixando"
	var nome := str(patch.get("arquivo", ""))
	var tamanho := int(patch.get("tamanho", 0))
	if nome.is_empty() or nome.contains("/") or nome.contains("..") or tamanho <= 0:
		return false
	var parcial := PASTA + "novo.part"
	DirAccess.remove_absolute(parcial)
	_barra.visible = true
	_barra.value = 0
	_http = HTTPRequest.new()
	_http.download_file = parcial
	_http.timeout = TEMPO_DOWNLOAD
	_http.body_size_limit = tamanho
	_http.use_threads = true
	add_child(_http)
	var fim := {"terminou": false, "resultado": -1, "codigo": 0}
	_http.request_completed.connect(func(resultado: int, codigo: int, _cab: PackedStringArray, _corpo: PackedByteArray):
		fim.terminou = true
		fim.resultado = resultado
		fim.codigo = codigo)
	if _http.request(url_base + nome) != OK:
		_http.queue_free()
		return false
	while not fim.terminou:
		var baixado := _http.get_downloaded_bytes()
		_barra.value = clampf(float(baixado) / float(tamanho), 0.0, 1.0) * 100.0
		_detalhe.text = "%.1f / %.1f MB" % [baixado / 1048576.0, tamanho / 1048576.0]
		await get_tree().process_frame
	_http.queue_free()
	_http = null
	if fim.resultado != HTTPRequest.RESULT_SUCCESS or fim.codigo != 200:
		print("[atualizacao] download falhou: resultado %d, HTTP %d" % [fim.resultado, fim.codigo])
		DirAccess.remove_absolute(parcial)
		return false
	var arquivo := FileAccess.open(parcial, FileAccess.READ)
	if arquivo == null or arquivo.get_length() != tamanho:
		print("[atualizacao] tamanho diferente do esperado (%d)" % tamanho)
		DirAccess.remove_absolute(parcial)
		return false
	arquivo.close()
	_detalhe.text = "Conferindo atualização…"
	if not InicializacaoPatches.conferir_pacote(parcial, patch):
		DirAccess.remove_absolute(parcial)
		return false
	if DirAccess.rename_absolute(parcial, PASTA + nome) != OK: return false
	return true


func _oferecer_aplicativo(versao: String, url: String) -> void:
	estado = "aviso_apk"
	_barra.visible = false
	_texto.text = "Há uma versão nova do jogo (%s)." % versao
	_detalhe.text = "Baixe o app novo para receber as novidades que não cabem em atualização rápida."
	_decisao = ""
	_limpar_botoes()
	_botao("BAIXAR", func(): OS.shell_open(url); _decisao = "baixar")
	_botao("CONTINUAR", func(): _decisao = "continuar")
	while _decisao.is_empty():
		await get_tree().process_frame
	_limpar_botoes()

func _ir_para_o_jogo() -> void:
	if _atualizacao_pendente:
		return
	estado = "pronto"
	concluida.emit()
	if get_tree().current_scene == self:
		get_tree().change_scene_to_file(CENA_INICIAL)

func _limpar_botoes() -> void:
	for filho in _botoes.get_children():
		_botoes.remove_child(filho)
		filho.queue_free()

func _botao(texto: String, acao: Callable) -> void:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(140, 36)
	Estilo.botao(b, true)
	b.pressed.connect(acao)
	_botoes.add_child(b)

func _montar_interface() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var fundo := ColorRect.new()
	fundo.color = Color("1b211c")
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	var margens := MarginContainer.new()
	margens.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for lado in ["left", "right", "top", "bottom"]:
		margens.add_theme_constant_override("margin_" + lado, 16)
	add_child(margens)
	var centro := CenterContainer.new()
	margens.add_child(centro)
	_painel = PanelContainer.new()
	Estilo.painel(_painel, false, 16, true)
	centro.add_child(_painel)
	_coluna = VBoxContainer.new()
	_coluna.add_theme_constant_override("separation", 8)
	_painel.add_child(_coluna)
	_titulo = _rotulo("ALGOLAND", 26, Color("efd08b"))
	_titulo.add_theme_font_override("font", Estilo.FONTE_TITULO)
	_coluna.add_child(_titulo)
	_papel = PanelContainer.new()
	Estilo.painel(_papel, true, 12)
	_coluna.add_child(_papel)
	var conteudo := VBoxContainer.new()
	conteudo.add_theme_constant_override("separation", 8)
	_papel.add_child(conteudo)
	_texto = _rotulo("Preparando sua jornada…", 12, Color("49321e"))
	conteudo.add_child(_texto)
	_barra = ProgressBar.new()
	_barra.visible = false
	_barra.show_percentage = false
	_barra.custom_minimum_size = Vector2(0, 12)
	_barra.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_barra.add_theme_stylebox_override("background", EstiloBarra.recorte(EstiloBarra.CAMPO, 4, 0))
	var preenchimento := EstiloBarra.recorte(preload("res://assets/ui/bosque/barra_neutra.png"), 3, 0)
	preenchimento.modulate_color = Color("b4c073")
	_barra.add_theme_stylebox_override("fill", preenchimento)
	conteudo.add_child(_barra)
	_detalhe = _rotulo("Aguarde para entrar no jogo.", 11, Color("62462c"))
	conteudo.add_child(_detalhe)
	_botoes = BoxContainer.new()
	_botoes.alignment = BoxContainer.ALIGNMENT_CENTER
	_botoes.add_theme_constant_override("separation", 8)
	_coluna.add_child(_botoes)
	get_viewport().size_changed.connect(_ajustar_interface)
	_ajustar_interface()

func _rotulo(texto: String, tamanho: int, cor: Color) -> Label:
	var rotulo := Label.new()
	rotulo.text = texto
	rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rotulo.add_theme_font_override("font", Estilo.FONTE)
	rotulo.add_theme_font_size_override("font_size", tamanho)
	rotulo.add_theme_color_override("font_color", cor)
	return rotulo

func _ajustar_interface() -> void:
	_painel.custom_minimum_size.x = minf(440.0, maxf(0.0, get_viewport_rect().size.x - 32.0))
	_botoes.vertical = get_viewport_rect().size.x < 400.0
