extends Node
## Entrada e diálogo do guardião. Pausa a luta e restaura câmera/controles ao sair.
signal concluida
const Dialogo := preload("res://codigo/introducao/dialogo_introducao.gd")
const FALAS: Array[String] = [
	"Então foi você que espalhou meus guardas pelas galerias...",
	"A água fica presa. O moinho para. E a vila aprende a pagar pelo que é meu!",
	"Quer a alavanca? Passe pelo meu martelo!"]
var chefe: Node2D
var jogador: Node2D
var dialogo: Control
var ativa := false
var fase := ""
var _camada: CanvasLayer
var _camera: Camera2D
var _offset_original := Vector2.ZERO
var _modo_camera := Node.PROCESS_MODE_INHERIT
var _modo_visual := Node.PROCESS_MODE_INHERIT
var _pausa_anterior := false
var _cinema_anterior := false
var _tween: Tween
var _restaurado := false
var _camadas_anteriores: Array[Dictionary] = []

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	iniciar.call_deferred()

func iniciar() -> void:
	if ativa or not is_instance_valid(chefe) or not is_instance_valid(jogador):return
	ativa=true;fase="chegada"
	_pausa_anterior=get_tree().paused;_cinema_anterior=get_tree().get_meta("cinema_ativo",false)
	get_tree().set_meta("cinema_ativo",true);get_tree().paused=true
	_modo_visual=chefe.sprite.process_mode;chefe.sprite.process_mode=Node.PROCESS_MODE_ALWAYS
	_camera=jogador.get_node_or_null("Camera2D")
	if _camera!=null:
		_offset_original=_camera.offset;_modo_camera=_camera.process_mode
		_camera.process_mode=Node.PROCESS_MODE_ALWAYS
		_tween=create_tween()
		_tween.tween_property(_camera,"offset",chefe.global_position-_camera.global_position+Vector2(0,10),.55).set_trans(Tween.TRANS_SINE)
	# Guardar e ocultar o HUD inteiro evita relógio, avisos e dicas sobre a fala,
	# inclusive na tela estreita. A própria caixa usa o layout responsivo existente.
	for camada: CanvasLayer in get_tree().current_scene.find_children("*","CanvasLayer",true,false):
		_camadas_anteriores.append({"no":camada,"visivel":camada.visible,"modo":camada.process_mode})
		camada.visible=false;camada.process_mode=Node.PROCESS_MODE_DISABLED
	_montar_dialogo()
	await get_tree().create_timer(.55,true).timeout
	if not ativa or fase!="chegada":return
	chefe.sprite.show();chefe.queue_redraw();chefe.sprite.orientar(jogador.global_position-chefe.global_position)
	chefe.sprite.position.y=-32.0
	chefe.sprite.iniciar_ataque(jogador.global_position-chefe.global_position)
	var contato: float=chefe.sprite._dados(chefe.sprite.direcao).impacto_ms/1000.0
	_tween=create_tween();_tween.tween_property(chefe.sprite,"position:y",0.0,contato).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await chefe.sprite.acao_concluida
	if ativa and fase=="chegada":_mostrar_fala()

func _montar_dialogo() -> void:
	_camada=CanvasLayer.new();_camada.layer=95;add_child(_camada)
	var barra:=ColorRect.new();barra.color=Color(.025,.035,.03,.85)
	barra.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE);barra.offset_bottom=24
	barra.mouse_filter=Control.MOUSE_FILTER_IGNORE;_camada.add_child(barra)
	var nome:=Label.new();nome.text="LORDE GOBLIN — GUARDIÃO DA COMPORTA"
	nome.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	nome.offset_left=12;nome.offset_right=-12
	nome.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;nome.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	nome.add_theme_font_override("font",preload("res://assets/ui/Planes_ValMore.ttf"))
	nome.add_theme_font_size_override("font_size",9)
	nome.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;barra.add_child(nome)
	dialogo=Dialogo.new();_camada.add_child(dialogo)
	dialogo.concluido.connect(finalizar)

func _mostrar_fala() -> void:
	fase="dialogo"
	chefe.sprite.position.y=0.0
	dialogo.iniciar(FALAS,"Lorde Goblin")
	dialogo.show()

func _unhandled_input(evento: InputEvent) -> void:
	if ativa and fase=="chegada" and evento.is_action_pressed("ui_cancel"):
		if _tween!=null and _tween.is_valid():_tween.kill()
		chefe.sprite.cancelar_ataque();chefe.sprite.show();chefe.queue_redraw()
		_mostrar_fala();get_viewport().set_input_as_handled()

func finalizar() -> void:
	if not ativa:return
	ativa=false;fase="concluida"
	if is_instance_valid(dialogo):dialogo.hide()
	if _camera!=null:
		_tween=create_tween();_tween.tween_property(_camera,"offset",_offset_original,.4).set_trans(Tween.TRANS_SINE)
		await _tween.finished
	_restaurar()
	if is_instance_valid(chefe):chefe.liberar_combate()
	concluida.emit();queue_free()

func _restaurar() -> void:
	if _restaurado:return
	_restaurado=true
	if is_instance_valid(chefe) and is_instance_valid(chefe.sprite):
		chefe.sprite.position.y=0.0;chefe.sprite.process_mode=_modo_visual
	if is_instance_valid(_camera):
		_camera.offset=_offset_original;_camera.process_mode=_modo_camera
	for estado in _camadas_anteriores:
		if is_instance_valid(estado.no):
			estado.no.visible=estado.visivel;estado.no.process_mode=estado.modo
	get_tree().paused=_pausa_anterior
	get_tree().set_meta("cinema_ativo",_cinema_anterior)
	for acao in ["ui_accept","ui_cancel","ataque","interagir"]:
		if InputMap.has_action(acao):Input.action_release(acao)

func _exit_tree() -> void:
	if ativa:
		_restaurar()
