extends Control
const EscalaInterface := preload("res://codigo/ui/escala_interface.gd")
const PreviaDigitacao := preload("res://codigo/ui/previa_digitacao.gd")
## Chat global opcional, na interface do dono (P1/P2), sem dados técnicos na tela.
var painel: PanelContainer
var _alternar: Button
var _estado: Label
var _lista: VBoxContainer
var _rolagem: ScrollContainer
var _campo: LineEdit
var _enviar: Button
var _fechar: Button
var _botao_hud: Button
var _contador_novas: Label
var _teclado: CanvasLayer
var _falas: Control
var _historico: PanelContainer
var _historico_texto: RichTextLabel
var _historico_campo: LineEdit
const LARGURA_HISTORICO := 240.0
const ALTURA_HISTORICO := 128.0
const LINHAS_HISTORICO := 30
var _sessao: Node
var _ultimo_chat := -1
var _aviso := ""
var _aviso_ate := 0.0

func _ready() -> void:
 set_anchors_and_offsets_preset(PRESET_FULL_RECT)
 mouse_filter = MOUSE_FILTER_IGNORE
 theme = preload("res://recursos/ui/tema_sidebar.tres")
 painel = PanelContainer.new()
 painel.name = "Painel"
 painel.add_theme_stylebox_override("panel",preload("res://codigo/ui/estilo_interface.gd").painel(false,8.0))
 add_child(painel)
 var margem := MarginContainer.new()
 for lado in ["left","right","top","bottom"]: margem.add_theme_constant_override("margin_"+lado,10)
 painel.add_child(margem)
 var coluna := VBoxContainer.new()
 coluna.add_theme_constant_override("separation",6)
 margem.add_child(coluna)
 var cabecalho := HBoxContainer.new()
 cabecalho.add_theme_constant_override("separation",8)
 coluna.add_child(cabecalho)
 var titulo := Label.new()
 titulo.text = "CHAT GLOBAL"
 titulo.size_flags_horizontal = SIZE_EXPAND_FILL
 titulo.add_theme_font_size_override("font_size",10)
 cabecalho.add_child(titulo)
 _alternar = Button.new()
 _alternar.add_theme_font_size_override("font_size",8)
 _alternar.pressed.connect(_trocar_modo)
 cabecalho.add_child(_alternar)
 _estado = Label.new()
 _estado.add_theme_font_size_override("font_size",7)
 _estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 coluna.add_child(_estado)
 _rolagem = ScrollContainer.new()
 _rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 _rolagem.size_flags_vertical = SIZE_EXPAND_FILL
 _rolagem.custom_minimum_size.y = 36
 coluna.add_child(_rolagem)
 var folga := MarginContainer.new()
 folga.add_theme_constant_override("margin_right",8)
 folga.size_flags_horizontal = SIZE_EXPAND_FILL
 _rolagem.add_child(folga)
 _lista = VBoxContainer.new()
 _lista.size_flags_horizontal = SIZE_EXPAND_FILL
 _lista.add_theme_constant_override("separation",5)
 folga.add_child(_lista)
 var entrada := HBoxContainer.new()
 entrada.add_theme_constant_override("separation",6)
 coluna.add_child(entrada)
 _campo = LineEdit.new()
 _campo.placeholder_text = "MENSAGEM..."
 _campo.max_length = 160
 _campo.add_theme_font_size_override("font_size",8)
 _reservar_margens_campo(_campo)
 _campo.size_flags_horizontal = SIZE_EXPAND_FILL
 _campo.focus_entered.connect(func() -> void: Controle.digitando=true)
 _campo.focus_exited.connect(func() -> void: Controle.digitando=false)
 _campo.gui_input.connect(_tecla_do_campo.bind(_campo))
 _campo.text_submitted.connect(func(_texto: String) -> void: _enviar_mensagem())
 entrada.add_child(_campo)
 var teclado := Button.new()
 teclado.text = "ABC"
 teclado.tooltip_text = "DIGITAR COM CONTROLE"
 teclado.add_theme_font_size_override("font_size",7)
 teclado.pressed.connect(_abrir_teclado)
 entrada.add_child(teclado)
 var botoes := HBoxContainer.new()
 botoes.add_theme_constant_override("separation",8)
 coluna.add_child(botoes)
 _enviar = Button.new()
 _enviar.text = "ENVIAR"
 _enviar.size_flags_horizontal = SIZE_EXPAND_FILL
 _enviar.pressed.connect(_enviar_mensagem)
 botoes.add_child(_enviar)
 _fechar = Button.new()
 _fechar.text = "VOLTAR"
 _fechar.size_flags_horizontal = SIZE_EXPAND_FILL
 _fechar.pressed.connect(func() -> void: EventosJogo.fechar_tela_de(self,"lobby"))
 botoes.add_child(_fechar)
 _botao_hud = Button.new()
 _botao_hud.name = "BotaoCidadeOnline"
 _botao_hud.add_to_group("toque_hud")
 _botao_hud.icon = preload("res://codigo/ui/icones_toque.gd").glifo(Vector2i(4,0))
 _botao_hud.expand_icon = true
 _botao_hud.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
 _botao_hud.add_theme_constant_override("icon_max_width",16)
 _botao_hud.focus_mode = FOCUS_NONE
 for estado_icone in ["normal","hover","pressed","focus"]:
  _botao_hud.add_theme_color_override("icon_"+estado_icone+"_color",Color("493629"))
 _botao_hud.set_anchors_and_offsets_preset(PRESET_TOP_LEFT)
 _botao_hud.position = Vector2(8,8)
 _botao_hud.custom_minimum_size = Vector2(32,32)
 _botao_hud.size = Vector2(32,32)
 _botao_hud.pressed.connect(func() -> void: EventosJogo.abrir_tela_de(self,"lobby"))
 get_parent().add_child(_botao_hud)
 _contador_novas = Label.new()
 _contador_novas.name = "MensagensNaoLidas"
 _contador_novas.mouse_filter = MOUSE_FILTER_IGNORE
 _contador_novas.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 _contador_novas.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
 _contador_novas.add_theme_font_size_override("font_size",8)
 _contador_novas.add_theme_color_override("font_color",Color.WHITE)
 _contador_novas.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)
 var selo := StyleBoxFlat.new()
 selo.bg_color = Color("bd302a")
 selo.border_color = Color("f5cf7a")
 selo.set_border_width_all(1)
 selo.set_corner_radius_all(8)
 selo.content_margin_left = 3
 selo.content_margin_right = 3
 selo.content_margin_top = 1
 selo.content_margin_bottom = 1
 _contador_novas.add_theme_stylebox_override("normal",selo)
 _contador_novas.visible = false
 _botao_hud.add_child(_contador_novas)
 _historico = PanelContainer.new()
 _historico.name = "HistoricoChat"
 _historico.mouse_filter = MOUSE_FILTER_IGNORE
 _historico.size = Vector2(LARGURA_HISTORICO,ALTURA_HISTORICO)
 var fundo := StyleBoxFlat.new()
 fundo.bg_color = Color(0.1,0.07,0.04,0.55)
 fundo.set_corner_radius_all(3)
 fundo.set_content_margin_all(5)
 _historico.add_theme_stylebox_override("panel",fundo)
 _historico_texto = RichTextLabel.new()
 _historico_texto.mouse_filter = MOUSE_FILTER_IGNORE
 _historico_texto.bbcode_enabled = true
 _historico_texto.scroll_following = true
 _historico_texto.add_theme_font_size_override("normal_font_size",8)
 _historico_texto.add_theme_font_size_override("bold_font_size",8)
 _historico_texto.add_theme_constant_override("line_separation",1)
 _historico_texto.get_v_scroll_bar().modulate.a = 0.0
 _historico_texto.size_flags_vertical = SIZE_EXPAND_FILL
 var historico_coluna := VBoxContainer.new()
 historico_coluna.add_theme_constant_override("separation",3)
 historico_coluna.mouse_filter = MOUSE_FILTER_IGNORE
 _historico.add_child(historico_coluna)
 historico_coluna.add_child(_historico_texto)
 _historico_campo = LineEdit.new()
 _historico_campo.placeholder_text = "ENTER PARA ESCREVER"
 _historico_campo.max_length = 160
 _historico_campo.add_theme_font_size_override("font_size",8)
 _reservar_margens_campo(_historico_campo)
 _historico_campo.focus_entered.connect(func() -> void: Controle.digitando=true)
 _historico_campo.focus_exited.connect(func() -> void: Controle.digitando=false)
 _historico_campo.text_submitted.connect(_enviar_do_canto)
 _historico_campo.gui_input.connect(_tecla_do_canto)
 historico_coluna.add_child(_historico_campo)
 _historico.visible = false
 get_parent().add_child(_historico)
 _falas = preload("res://codigo/ui/falas_lobby.gd").new()
 _falas.name = "FalasLobby"
 get_parent().add_child(_falas)
 _teclado = preload("res://codigo/ui/teclado_virtual.gd").new()
 _teclado.titulo_texto = "MENSAGEM"
 _teclado.com_pontuacao = true
 add_child(_teclado)
 _teclado.confirmado.connect(func(texto: String) -> void:
  _campo.text=texto
  _enviar.grab_focus())
 PreviaDigitacao.ligar(_campo,"MENSAGEM")
 PreviaDigitacao.ligar(_historico_campo,"MENSAGEM")
 visibility_changed.connect(_ao_abrir)
 resized.connect(_ajustar)
 painel.minimum_size_changed.connect(func() -> void: _ajustar.call_deferred())
 _ajustar()
 _atualizar()

func _reservar_margens_campo(campo: LineEdit) -> void:
 for estado in ["normal","read_only","focus"]:
  var estilo := campo.get_theme_stylebox(estado).duplicate() as StyleBox
  estilo.set_content_margin(SIDE_LEFT,12)
  estilo.set_content_margin(SIDE_RIGHT,12)
  estilo.set_content_margin(SIDE_TOP,5)
  estilo.set_content_margin(SIDE_BOTTOM,5)
  campo.add_theme_stylebox_override(estado,estilo)

func _localizar_sessao() -> Node:
 var dono := EventosJogo.dono(self)
 return Cooperativo.sessao_chat_de(dono)

func _process(_delta: float) -> void:
 var nova := _localizar_sessao()
 if nova != _sessao:
  if is_instance_valid(_sessao):
   _sessao.fala_recebida.disconnect(_falas.mostrar)
   _sessao.alterada.disconnect(_atualizar)
   _sessao.mensagem_confirmada.disconnect(_confirmar_envio)
  _sessao = nova
  _falas.limpar()
  _falas.sessao = nova
  if _sessao!=null:
   _sessao.fala_recebida.connect(_falas.mostrar)
   _sessao.alterada.connect(_atualizar)
   _sessao.mensagem_confirmada.connect(_confirmar_envio)
  _ultimo_chat = -1
  _atualizar()
 _botao_hud.position = Vector2(8,EscalaInterface.tamanho_logico(self).y-_botao_hud.size.y-(8 if Controle.usando_toque else 48))
 if Controle.usando_toque: _encaixar_ao_lado_do_mapa()
 _falas.visible = get_parent()._telas_abertas.is_empty()
 # Proporcional à tela (janela pequena não pode ser tomada pelo registro); o máximo é o tamanho de uma tela grande
 var logico := EscalaInterface.tamanho_logico(self)
 _historico.size = Vector2(clampf(logico.x*0.3,120.0,LARGURA_HISTORICO),clampf(logico.y*0.3,72.0,ALTURA_HISTORICO))
 _historico.position = Vector2(8,logico.y-8-_historico.size.y)
 _evitar_barra_de_itens()
 _historico.visible = not Controle.usando_toque and _sessao!=null and get_parent()._telas_abertas.is_empty() and not Introducao.cinematica
 var escrevendo: bool = _historico.visible and is_instance_valid(_sessao) and _sessao.online and _sessao.conectado and not EventosJogo.eh_do_p2(self)
 _historico_campo.visible = escrevendo
 if not escrevendo and _historico_campo.has_focus(): _historico_campo.release_focus()
 _botao_hud.visible = _sessao!=null and Controle.usando_toque and get_parent()._telas_abertas.is_empty() and not Introducao.cinematica
 _contador_novas.size = Vector2(maxf(16,_contador_novas.get_combined_minimum_size().x),16)
 # Mantém a notificação sobre o próprio botão, com folga do botão MAPA.
 _contador_novas.position = Vector2(_botao_hud.size.x-_contador_novas.size.x+2,-4).round()
 if not _aviso.is_empty() and Time.get_ticks_msec()>_aviso_ate: _aviso=""; _atualizar()

func _evitar_barra_de_itens() -> void:
 var pai := get_parent()
 var para_pai: Transform2D = pai.get_final_transform().affine_inverse() if pai is CanvasLayer else pai.get_global_transform_with_canvas().affine_inverse()
 for hud in get_tree().get_nodes_in_group("hud"):
  if hud.get_viewport()!=get_viewport(): continue
  var barra = hud.get("barra_armas")
  if not is_instance_valid(barra): continue
  var moldura = barra.get("_painel")
  if not is_instance_valid(moldura) or not moldura.is_visible_in_tree(): continue
  var area: Rect2 = para_pai * moldura.get_global_transform_with_canvas() * Rect2(Vector2.ZERO,moldura.size)
  if Rect2(_historico.position,_historico.size).grow(6).intersects(area):
   _historico.position.y = maxf(8,area.position.y-8-_historico.size.y)
  var objetivo := hud.get_node_or_null("ObjetivoPrincipal") as Control
  if objetivo!=null and objetivo.is_visible_in_tree():
   var area_objetivo: Rect2 = para_pai * objetivo.get_global_transform_with_canvas() * Rect2(Vector2.ZERO,objetivo.size)
   if Rect2(_historico.position,_historico.size).grow(6).intersects(area_objetivo):
    var rodape := _historico.position.y+_historico.size.y
    var disponivel := rodape-area_objetivo.end.y-8
    _historico.size.y = maxf(_historico.get_combined_minimum_size().y,disponivel)
    _historico.position.y = rodape-_historico.size.y

func _atualizar() -> void:
 if _estado==null: return
 var ativo: bool = is_instance_valid(_sessao) and _sessao.online
 if is_visible_in_tree() and is_instance_valid(_sessao): _sessao.mensagens_nao_lidas = 0
 var novas: int = _sessao.mensagens_nao_lidas if ativo else 0
 _contador_novas.text = "99+" if novas>99 else str(novas)
 _contador_novas.visible = novas>0
 _alternar.text = "FICAR OFFLINE" if ativo else "FICAR ONLINE"
 _alternar.disabled = not is_instance_valid(_sessao)
 _campo.editable = ativo and _sessao.conectado
 _enviar.disabled = not ativo or not _sessao.conectado or not _sessao._envio.is_empty()
 _estado.text = _aviso if not _aviso.is_empty() else (_sessao.estado if is_instance_valid(_sessao) else "CHAT GLOBAL")
 _botao_hud.tooltip_text = "CHAT GLOBAL ONLINE" if ativo and _sessao.conectado else "CHAT - AGUARDE" if ativo else "CHAT GLOBAL OFFLINE"
 var ultimo: int = _sessao._depois if is_instance_valid(_sessao) else 0
 _montar_historico()
 if ultimo==_ultimo_chat: return
 _ultimo_chat = ultimo
 var no_fim := _rolagem.scroll_vertical>=_rolagem.get_v_scroll_bar().max_value-_rolagem.size.y-20
 for filho in _lista.get_children(): _lista.remove_child(filho); filho.queue_free()
 if _sessao!=null and not _sessao.mensagens.is_empty():
  for item: Dictionary in _sessao.mensagens:
   var rotulo := Label.new()
   rotulo.text = str(item.apelido)+": "+str(item.texto)
   rotulo.add_theme_font_size_override("font_size",8)
   rotulo.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
   rotulo.size_flags_horizontal = SIZE_EXPAND_FILL
   if item.jogador==_sessao.eu: rotulo.modulate=Color("f5cf7a")
   _lista.add_child(rotulo)
 else:
  var ajuda := Label.new()
  ajuda.text = "Fique online para encontrar outros jogadores e conversar." if not ativo else "Converse com jogadores de qualquer mapa."
  ajuda.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
  ajuda.add_theme_font_size_override("font_size",8)
  _lista.add_child(ajuda)
 if no_fim: _ir_ao_fim.call_deferred()

## Registro fixo no canto da tela (só no PC), como nos MMORPGs; o chat completo continua no painel central.
## No toque o ícone do chat fica na fileira do topo, logo à esquerda do botão MAPA (que usa a escala própria do HUD)
func _encaixar_ao_lado_do_mapa() -> void:
 var mapa: Control = null
 for no in get_tree().get_nodes_in_group("toque_hud"):
  if no.name=="BotaoMapaMundi" and no is Control and no.get_viewport()==get_viewport() and no.is_visible_in_tree(): mapa=no; break
 if mapa==null: return
 var fator := EscalaInterface.fator(self)
 var origem := mapa.get_global_transform_with_canvas().origin
 var altura_mapa := mapa.size.y*mapa.get_global_transform_with_canvas().get_scale().y
 var tela_px := origem+Vector2(-(_botao_hud.size.x+6.0)*fator,(altura_mapa-_botao_hud.size.y*fator)*0.5)
 var pai := get_parent()
 var da_tela_para_pai: Transform2D = pai.get_final_transform().affine_inverse() if pai is CanvasLayer else pai.get_global_transform_with_canvas().affine_inverse()
 _botao_hud.position = (da_tela_para_pai*tela_px).round()

func _montar_historico() -> void:
 _historico_texto.clear()
 if _sessao==null: return
 if not _sessao.online or not _sessao.conectado:
  _historico_texto.append_text("[color=#c9b79c]%s\nENTER: abrir o chat[/color]" % _sessao.estado)
  return
 for item: Dictionary in _sessao.mensagens.slice(-LINHAS_HISTORICO):
  var cor := "f5cf7a" if item.jogador==_sessao.eu else "8fd3ff"
  _historico_texto.append_text("[color=#%s][b]%s:[/b][/color] %s\n" % [cor,str(item.apelido).replace("[","(").replace("]",")"),str(item.texto).replace("[","(").replace("]",")")])

func _enviar_do_canto(texto: String) -> void:
 if texto.strip_edges().is_empty():
  _historico_campo.release_focus()
  return
 var erro: String = _sessao.enviar_mensagem(texto) if _sessao!=null else ""
 if not erro.is_empty():
  _avisar(erro)
  _historico_campo.placeholder_text = erro
  return
 _historico_campo.placeholder_text = "ENVIANDO..."
 _historico_campo.release_focus()

func _tecla_do_canto(evento: InputEvent) -> void:
 _tecla_do_campo(evento,_historico_campo)

func _tecla_do_campo(evento: InputEvent, campo: LineEdit) -> void:
 if evento is InputEventKey and evento.pressed and evento.keycode==KEY_TAB:
  campo.get_viewport().set_input_as_handled()
  return
 if evento is InputEventKey and evento.pressed and evento.keycode==KEY_ESCAPE:
  campo.release_focus()
  campo.get_viewport().set_input_as_handled()

func _exit_tree() -> void:
 if (_historico_campo!=null and _historico_campo.has_focus()) or (_campo!=null and _campo.has_focus()): Controle.digitando=false

func _ir_ao_fim() -> void:
 _rolagem.scroll_vertical = int(_rolagem.get_v_scroll_bar().max_value)

func _trocar_modo() -> void:
 if _sessao!=null:
  _sessao.definir_online(not _sessao.online)
  _ultimo_chat = -1
  _atualizar()

func _enviar_mensagem() -> void:
 if _sessao==null: return
 var erro: String = _sessao.enviar_mensagem(_campo.text)
 _avisar(erro if not erro.is_empty() else "ENVIANDO...")
 _atualizar()

func _confirmar_envio(texto: String, erro: String) -> void:
 _historico_campo.placeholder_text = erro if not erro.is_empty() else "ENTER PARA ESCREVER"
 if erro.is_empty() and RegEx.create_from_string("[[:cntrl:]]").sub(_campo.text," ",true).strip_edges().left(160)==texto: _campo.text=""
 if erro.is_empty() and _historico_campo.text.strip_edges().left(160)==texto: _historico_campo.text=""
 _avisar(erro)
 _atualizar()

func _avisar(texto: String) -> void:
 _aviso = texto
 _aviso_ate = Time.get_ticks_msec()+4000

func _abrir_teclado() -> void:
 if _campo.editable: _teclado.abrir(_campo.text,160)

func _ao_abrir() -> void:
 if not visible:
  if _teclado!=null: _teclado.visible=false
  return
 _atualizar()
 _ajustar.call_deferred()

func focar_inicio() -> void:
 _alternar.grab_focus()

func _ajustar() -> void:
 if painel==null: return
 painel.size = Vector2(minf(420,size.x-24),minf(300,size.y-24))
 painel.position = ((size-painel.size)*0.5).floor()

func _unhandled_key_input(evento: InputEvent) -> void:
 if not is_visible_in_tree() and _sessao!=null and not EventosJogo.eh_do_p2(self) and get_parent()._telas_abertas.is_empty():
  if evento is InputEventKey and evento.pressed and not evento.echo and evento.keycode==KEY_ENTER:
   if _historico_campo.visible: _historico_campo.grab_focus()
   else: EventosJogo.abrir_tela_de(self,"lobby")
   get_viewport().set_input_as_handled()
