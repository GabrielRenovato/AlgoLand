extends Node2D
## Bancada de montagem isolada. Os interiores são cenas reutilizáveis, sem trocar casas antigas.
var casa:Node2D
var camera:Camera2D
var titulo:Label
var estacao:=0
var indice:=0
var exterior:Node2D
var por_fora:=false
const IDS=["mara","cora","rosa"]
const EXTERIORES={
	"mara":preload("res://cenas/cidade/familias/exterior_mara.tscn"),
	"cora":preload("res://cenas/cidade/familias/exterior_cora.tscn"),
	"rosa":preload("res://cenas/cidade/familias/exterior_rosa.tscn")}
func _ready() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"):
		get_tree().quit(1);return
	RenderingServer.set_default_clear_color(Color("202b30"))
	camera=Camera2D.new()
	add_child(camera)
	var hud:=CanvasLayer.new()
	add_child(hud)
	var margem:=MarginContainer.new()
	margem.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	margem.offset_left=16;margem.offset_right=-16;margem.offset_top=12
	hud.add_child(margem)
	titulo=Label.new()
	titulo.add_theme_font_size_override("font_size",12)
	titulo.add_theme_color_override("font_outline_color",Color("202b30"))
	titulo.add_theme_constant_override("outline_size",4)
	titulo.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	margem.add_child(titulo)
	titulo.resized.connect(_enquadrar)
	get_viewport().size_changed.connect(_enquadrar)
	abrir("mara")
func abrir(id: String) -> void:
	if casa!=null:
		remove_child(casa);casa.queue_free()
	casa=load("res://cenas/cidade/familias/casa_"+id+".tscn").instantiate()
	add_child(casa)
	casa.definir_estacao(estacao)
	if exterior!=null:
		remove_child(exterior);exterior.queue_free()
	exterior=EXTERIORES[id].instantiate()
	add_child(exterior)
	exterior.definir_estacao(estacao)
	_atualizar_vista()

func _atualizar_vista() -> void:
	casa.visible=not por_fora
	exterior.visible=por_fora
	titulo.text=casa.planta.nome+" · "+("Exterior" if por_fora else "Interior")+"\n1–3: casas · F: dentro/fora · E: estação · roda: zoom · arrastar: mover"
	_enquadrar()
func _enquadrar() -> void:
	if casa==null:return
	var tamanho:=Vector2(casa.planta.geometria.recorte[2],casa.planta.geometria.recorte[3])
	var tela:=get_viewport_rect().size
	var topo:=maxf(80,titulo.get_global_rect().end.y+12)
	var disponivel:=Rect2(Vector2(16,topo),Vector2(tela.x-32,maxf(32,tela.y-topo-16)))
	var ret:=Rect2(Vector2(-16,0),tamanho+Vector2(32,16))
	if por_fora:ret=exterior.limites_visuais().grow(12)
	var zoom:=minf(disponivel.size.x/ret.size.x,disponivel.size.y/ret.size.y)
	camera.zoom=Vector2.ONE*zoom
	# Centraliza no espaço abaixo do texto, incluindo quebras em tela dividida.
	camera.position=ret.get_center()-(disponivel.get_center()-tela/2)/zoom
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_1,KEY_2,KEY_3]:
			indice=event.keycode-KEY_1;abrir(IDS[indice])
		if event.keycode==KEY_E:
			estacao=(estacao+1)%4;casa.definir_estacao(estacao);exterior.definir_estacao(estacao)
		if event.keycode==KEY_F:
			por_fora=not por_fora;_atualizar_vista()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP:camera.zoom*=1.15
		if event.button_index==MOUSE_BUTTON_WHEEL_DOWN:camera.zoom/=1.15
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):camera.position-=event.relative/camera.zoom
