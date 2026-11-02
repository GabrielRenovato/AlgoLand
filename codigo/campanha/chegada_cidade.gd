extends Node

## Primeiro encontro com Dara. O relato concluído é a marca persistente da cena.
signal concluida
const Estilo := preload("res://codigo/ui/estilo_campanha.gd")
const FONTE := Estilo.FONTE
const FALAS := [
	["Dara", "Pare um instante. Você veio pela Estrada dos Carreteiros? Um dos nossos saiu com mantimentos e não voltou."],
	["Você", "Encontrei um trabalhador escondido perto do carreto. Está vivo. As criaturas vieram pelos sulcos no chão."],
	["Dara", "Vivo… Certo. Vou mandar uma equipe pelo caminho que você indicou. Ninguém fica para trás."],
	["Dara", "Sou Dara. Cuido desta entrada e da estrada. Se precisar sair outra vez, diga a alguém por onde pretende voltar."],
	["Dara", "Entre. Procure Lia, na praça. Conte a ela o que viu. Por enquanto, você tem abrigo na Vila das Flores."]]

var cena: Node2D
var ativa := false
var fase := "preparacao"
var indice := 0
var _dara: CharacterBody2D
var _camera: Camera2D
var _camera_jogo: Camera2D
var _camada: CanvasLayer
var _raiz: Control
var _cortina: ColorRect
var _topo: ColorRect
var _rodape: ColorRect
var _titulo: VBoxContainer
var _painel: PanelContainer
var _nome: Label
var _texto: Label
var _contador: Label
var _continuar: Button
var _pular: Button
var _tween: Tween
var _digitando: Tween
var _espera := 0.0
var _hud_visivel := true
var _interface_visivel := true
var _preparada := false
var _enquadramento := Vector2.ZERO
var _acomodacao := 0.0

func iniciar() -> void:
	ativa = true
	cena._ocupado = true
	get_tree().set_meta("cinema_ativo", true)
	_hud_visivel = cena.hud.visible
	_interface_visivel = cena.interface.visible
	cena.hud.hide()
	cena.interface.hide()
	cena.jogador.desabilitar_todas_acoes(true)
	cena.jogador.velocity = Vector2.ZERO
	# O mapa e o rig de Dara precisam existir antes do primeiro enquadramento.
	var tempo := 0.0
	while ativa:
		if cena.regiao != "vila":
			cancelar()
			return
		var carregando: bool = is_instance_valid(cena.carregamento) and cena.carregamento.ativa
		if not carregando and cena.moradores.has("dara"):
			_dara = cena.moradores.dara
			if _dara.has_node("NomeNPC"): break
		await get_tree().process_frame
		tempo += get_process_delta_time()
		if tempo > 15.0:
			cancelar()
			return
	if not ativa: return
	# Marcações no corredor livre da portaria, sob a cortina inicial.
	# A ronda de Dara passa junto às copas; a conversa precisa mostrar os dois rostos.
	_dara.position = cena._livre(Vector2(-18, 348))
	cena.jogador.position = cena._livre(Vector2(18, 360))
	_dara.iniciar_conversa(cena.jogador.global_position)
	cena.jogador.parar_para_conversa(_dara.global_position)
	_camera_jogo = cena.jogador.get_node("Camera2D")
	_camera = Camera2D.new()
	_camera.position = Vector2(0, 24)
	_camera.zoom = Vector2.ONE * 0.9
	_camera.limit_left = _camera_jogo.limit_left
	_camera.limit_top = _camera_jogo.limit_top
	_camera.limit_right = _camera_jogo.limit_right
	_camera.limit_bottom = _camera_jogo.limit_bottom
	cena.add_child(_camera)
	_camera.make_current()
	_montar_interface()
	_preparada = true
	fase = "apresentacao"
	_tween = create_tween()
	_tween.tween_property(_cortina, "color:a", 0.0, 0.8)
	_tween.tween_interval(1.6)
	_tween.tween_property(_titulo, "modulate:a", 0.0, 0.6)
	_tween.tween_property(_camera, "position", _centro_conversa(), 2.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.parallel().tween_property(_camera, "zoom", Vector2.ONE * 1.55, 2.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_callback(_abrir_conversa)

func _centro_conversa() -> Vector2:
	return cena.jogador.global_position.lerp(_dara.global_position, 0.5) + Vector2(0, -17)

func _montar_interface() -> void:
	_camada = CanvasLayer.new()
	_camada.layer = 90
	add_child(_camada)
	_raiz = Control.new()
	_raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_STOP
	_camada.add_child(_raiz)
	_topo = ColorRect.new()
	_topo.color = Color("0b1014")
	_topo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_topo)
	_rodape = ColorRect.new()
	_rodape.color = Color("0b1014")
	_rodape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_rodape)
	_titulo = VBoxContainer.new()
	_titulo.add_theme_constant_override("separation", 6)
	_raiz.add_child(_titulo)
	for texto in ["VILA DAS FLORES", "Vale da Primeira Raiz"]:
		var rotulo := _rotulo(texto, 18 if texto == "VILA DAS FLORES" else 10)
		rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_titulo.add_child(rotulo)
	_pular = _botao("Pular cena", pular)
	_raiz.add_child(_pular)
	_painel = PanelContainer.new()
	_painel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	Estilo.painel(_painel,false,12)
	_raiz.add_child(_painel)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 7)
	_painel.add_child(coluna)
	_nome = _rotulo("", 12)
	_nome.add_theme_font_override("font",Estilo.FONTE_TITULO)
	_nome.add_theme_color_override("font_color",Estilo.VERDE)
	_nome.add_theme_constant_override("outline_size",0)
	coluna.add_child(_nome)
	_texto = _rotulo("", 12)
	_texto.add_theme_color_override("font_color",Estilo.TINTA)
	_texto.add_theme_constant_override("outline_size",0)
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	coluna.add_child(_texto)
	var botoes := HBoxContainer.new()
	coluna.add_child(botoes)
	_contador = _rotulo("", 9)
	_contador.add_theme_color_override("font_color",Estilo.SUAVE)
	_contador.add_theme_constant_override("outline_size",0)
	_contador.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_contador.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	botoes.add_child(_contador)
	_continuar = _botao("Continuar", avancar)
	botoes.add_child(_continuar)
	_painel.hide()
	_cortina = ColorRect.new()
	_cortina.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cortina.color = Color("0b1014")
	_cortina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_cortina)
	_raiz.resized.connect(_organizar)
	Controle.dicas_alteradas.connect(_organizar)
	_organizar()

func _rotulo(texto: String, tamanho: int) -> Label:
	var rotulo := Label.new()
	rotulo.text = texto
	rotulo.add_theme_font_override("font", FONTE)
	rotulo.add_theme_font_size_override("font_size", tamanho)
	rotulo.add_theme_color_override("font_color", Color("f4eddd"))
	rotulo.add_theme_color_override("font_outline_color", Color("101a20"))
	rotulo.add_theme_constant_override("outline_size", 2)
	return rotulo

func _botao(texto: String, acao: Callable) -> Button:
	var botao := Button.new()
	botao.text = texto
	botao.custom_minimum_size = Vector2(88, 32)
	botao.add_theme_font_override("font", FONTE)
	botao.add_theme_font_size_override("font_size", 10)
	for estado in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		botao.add_theme_color_override(estado, Color("f4eddd"))
	for estado in ["normal", "hover", "pressed", "focus"]:
		var fundo := StyleBoxFlat.new()
		fundo.bg_color = Color("374853") if estado != "normal" else Color("202d35")
		fundo.border_color = Color("ba9f6b")
		fundo.set_border_width_all(1 if estado == "focus" else 0)
		fundo.content_margin_left = 10
		fundo.content_margin_right = 10
		fundo.content_margin_top = 5
		fundo.content_margin_bottom = 5
		botao.add_theme_stylebox_override(estado, fundo)
	botao.pressed.connect(acao)
	Estilo.botao(botao)
	return botao

func _organizar() -> void:
	if _raiz == null: return
	var tamanho := _raiz.size
	var seguras := Controle.margens_seguras()
	var margem := 12.0
	var esquerda := margem + seguras.x
	var direita := tamanho.x - margem - seguras.z
	var largura := minf(520.0, direita - esquerda)
	var centro := (esquerda + direita) * 0.5
	_pular.size = Vector2(90, 32)
	_pular.position = Vector2(direita - _pular.size.x, 6 + seguras.y)
	_topo.size = Vector2(tamanho.x, 44 + seguras.y)
	_titulo.position = Vector2(esquerda, tamanho.y * 0.31)
	_titulo.size.x = direita - esquerda
	_painel.position.x = centro - largura * 0.5
	_painel.size.x = largura
	_texto.add_theme_font_size_override("font_size", 13 if Controle.usando_toque else 12)
	# O contêiner cresce conforme as quebras da fonte, inclusive em retrato e meia tela.
	_painel.size.y = 0
	_painel.position.y = tamanho.y - 12 - seguras.w - _painel.size.y
	_rodape.size = Vector2(tamanho.x, 24 + seguras.w)
	_rodape.position = Vector2(0, tamanho.y - _rodape.size.y)

func _abrir_conversa() -> void:
	if not ativa: return
	fase = "dialogo"
	_enquadramento = _camera.position
	_titulo.hide()
	_painel.show()
	_continuar.grab_focus()
	_mostrar_fala()

func _mostrar_fala() -> void:
	_nome.text = str(FALAS[indice][0]).to_upper()
	_texto.text = FALAS[indice][1]
	_contador.text = "%d / %d" % [indice + 1, FALAS.size()]
	_continuar.text = "Entrar na vila" if indice == FALAS.size() - 1 else "Continuar"
	_espera = 0.2
	if _digitando != null and _digitando.is_valid(): _digitando.kill()
	_texto.visible_ratio = 0.0
	_digitando = create_tween()
	_digitando.tween_property(_texto, "visible_ratio", 1.0, _texto.text.length() / 48.0)
	_organizar()
	if _tween != null and _tween.is_valid(): _tween.kill()
	_tween = create_tween()
	var foco := _centro_conversa()
	foco.x += 6 if FALAS[indice][0] == "Você" else -6
	_tween.tween_property(self, "_enquadramento", foco, 0.6).set_trans(Tween.TRANS_SINE)
	_tween.parallel().tween_property(self, "_acomodacao", 1.0, 0.6)

func _process(delta: float) -> void:
	_espera = maxf(0, _espera - delta)
	if not ativa or not _preparada: return
	# A altura muda depois de o contêiner medir o texto ou de girar a tela.
	_painel.position.y = _raiz.size.y - 12 - Controle.margens_seguras().w - _painel.size.y
	if fase == "dialogo":
		_rodape.position.y = _painel.position.y - 8
		_rodape.size.y = _raiz.size.y - _rodape.position.y
		var altura_livre := _rodape.position.y - _topo.size.y
		var altura_atores: float = absf(cena.jogador.position.y - _dara.position.y) + 50.0
		var largura_atores: float = absf(cena.jogador.position.x - _dara.position.x) + 36.0
		var zoom_conversa := minf(1.55, minf((altura_livre - 16.0) / altura_atores, (_raiz.size.x - 48.0) / largura_atores))
		_camera.zoom = Vector2.ONE * maxf(0.5, zoom_conversa)
		# Enquadra os rostos na área livre acima da legenda, também em retrato.
		# O limite só avança sob a faixa opaca: nenhuma borda vazia fica exposta.
		_camera.limit_bottom = _camera_jogo.limit_bottom + ceili(_rodape.size.y / _camera.zoom.y)
		_camera.position = _enquadramento + Vector2(0, (_rodape.size.y - _topo.size.y) * 0.5 / _camera.zoom.y * _acomodacao)

func avancar() -> void:
	if not ativa or fase != "dialogo" or _espera > 0: return
	if _texto.visible_ratio < 1.0:
		if _digitando != null and _digitando.is_valid(): _digitando.kill()
		_texto.visible_ratio = 1.0
		return
	indice += 1
	if indice < FALAS.size():
		_mostrar_fala()
	else:
		_concluir_relato()

func pular() -> void:
	if not ativa or not _preparada or fase == "saida": return
	_concluir_relato()

func _concluir_relato() -> void:
	# Usa os mesmos eventos do diálogo comum e só avança o que ainda está pendente.
	for tipo in ["conversar", "entregar"]:
		if cena.controlador.objetivos_disponiveis().any(func(o): return o.alvo == "dara" and o.tipo == tipo):
			var erro: Error = cena.controlador.interagir(tipo, "dara")
			if erro != OK:
				cena._avisar("Não foi possível salvar a conversa com Dara. Fale com ela novamente.")
				cancelar()
				return
	cena._visitas_moradores.dara = 1
	fase = "saida"
	if _tween != null and _tween.is_valid(): _tween.kill()
	if _digitando != null and _digitando.is_valid(): _digitando.kill()
	_pular.hide()
	_painel.hide()
	_tween = create_tween()
	_tween.tween_property(_cortina, "color:a", 1.0, 0.3)
	_tween.tween_callback(_encerrar)

func _input(evento: InputEvent) -> void:
	if not ativa or not _preparada or evento.is_echo(): return
	if evento.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		pular()
	elif fase == "dialogo" and (evento.is_action_pressed("ui_accept") or evento.is_action_pressed("open_menu")):
		get_viewport().set_input_as_handled()
		if _pular.has_focus(): pular()
		else: avancar()

func cancelar() -> void:
	if _tween != null and _tween.is_valid(): _tween.kill()
	_encerrar()

func _encerrar() -> void:
	if not ativa: return
	ativa = false
	_restaurar()
	if is_instance_valid(cena):
		cena.salvar_retorno()
		cena._atualizar()
	concluida.emit()

func _restaurar() -> void:
	if _digitando != null and _digitando.is_valid(): _digitando.kill()
	if is_instance_valid(_dara): _dara.encerrar_conversa()
	if is_instance_valid(_camera_jogo):
		_camera_jogo.make_current()
		_camera_jogo.reset_smoothing()
	if is_instance_valid(_camera): _camera.queue_free()
	if is_instance_valid(_camada): _camada.queue_free()
	if not is_instance_valid(cena): return
	get_tree().set_meta("cinema_ativo", false)
	cena._ocupado = false
	if is_instance_valid(cena.hud): cena.hud.visible = _hud_visivel
	if is_instance_valid(cena.interface): cena.interface.visible = _interface_visivel
	if is_instance_valid(cena.jogador) and not cena.jogador.estaMorto:
		cena.jogador.desabilitar_todas_acoes(false)

func _exit_tree() -> void:
	if ativa:
		ativa = false
		_restaurar()
