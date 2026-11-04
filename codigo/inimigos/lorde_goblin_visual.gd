extends Sprite2D
## Boss pintado em 2D. Um relógio controla quadro, contato e conclusão.
signal impacto(centro: Vector2)
signal acao_concluida
const DADOS := preload("res://assets/inimigos/lorde_goblin_2d/boss_direcoes.json")
const PALETA := preload("res://recursos/shaders/lorde_goblin_paleta.gdshader")
const PIVO := Vector2(320,500)
var direcao := "baixo"
var quadro := 0
var atacando := false
var andando := false
var quadro_andada := 0
var _tempo_andada_ms := 0.0
var _tempo_ms := 0.0
var _impactou := false
var _texturas: Dictionary = {}
var _texturas_andada: Dictionary = {}

func _ready() -> void:
	centered=false;region_enabled=false;offset=-PIVO
	scale=Vector2.ONE*.2
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var paleta:=ShaderMaterial.new();paleta.shader=PALETA;material=paleta
	for id in ["baixo","cima","direita"]:
		var atlas:Texture2D=load(DADOS.data[id].textura)
		var quadros:Array[AtlasTexture]=[]
		var dados:Dictionary=_dados(id)
		var colunas:=int(dados.colunas)
		for i in dados.tempos_ms.size():
			var recorte:=AtlasTexture.new();recorte.atlas=atlas
			recorte.region=Rect2(i%colunas*640,i/colunas*640,640,640)
			quadros.append(recorte)
		_texturas[id]=quadros
		var caminhada:Dictionary=dados.andada
		var atlas_andada:Texture2D=load(caminhada.textura)
		var poses:Array[AtlasTexture]=[]
		for i in caminhada.tempos_ms.size():
			var recorte:=AtlasTexture.new();recorte.atlas=atlas_andada
			recorte.region=Rect2(i%3*640,i/3*640,640,640)
			poses.append(recorte)
		_texturas_andada[id]=poses
	_mostrar_quadro(0)

func direcao_para(rumo: Vector2) -> String:
	if rumo.is_zero_approx():return direcao
	if absf(rumo.x)>absf(rumo.y):return "direita" if rumo.x>0 else "esquerda"
	return "baixo" if rumo.y>0 else "cima"

func _dados(id: String) -> Dictionary:
	return DADOS.data["direita" if id=="esquerda" else id]

func orientar(rumo: Vector2) -> void:
	if atacando:return
	direcao=direcao_para(rumo)
	if andando:_mostrar_andada(quadro_andada)
	else:_mostrar_quadro(0)

func definir_andando(ativo: bool) -> void:
	if atacando:return
	if andando==ativo:return
	andando=ativo
	if ativo:
		_tempo_andada_ms=0.0;quadro_andada=0;_mostrar_andada(0)
	else:_mostrar_quadro(0)

func ponto_contato_para(rumo: Vector2) -> Vector2:
	var id:=direcao_para(rumo)
	var contato: Array=_dados(id).contato
	var uv:=Vector2(contato[0],contato[1])
	if id=="esquerda":uv.x=640-uv.x
	return transform*(uv-PIVO)

func iniciar_ataque(rumo: Vector2) -> bool:
	if atacando:return false
	orientar(rumo);andando=false;atacando=true;_tempo_ms=0.0;_impactou=false
	_mostrar_quadro(0)
	return true

func cancelar_ataque() -> void:
	atacando=false;andando=false;_impactou=true;_tempo_ms=0.0
	_mostrar_quadro(0)

func _process(delta: float) -> void:
	if not atacando:
		if andando:
			_tempo_andada_ms=fmod(_tempo_andada_ms+delta*1000.0,660.0)
			_mostrar_andada(int(_tempo_andada_ms/110.0))
		return
	_tempo_ms+=delta*1000.0
	var dados:=_dados(direcao)
	# Mesmo um passo grande cruza o contato uma única vez; cancelamento não deixa timer.
	if not _impactou and _tempo_ms>=float(dados.impacto_ms):
		_impactou=true
		_mostrar_quadro(int(dados.impacto_quadro))
		impacto.emit(ponto_contato_para(Vector2.ZERO))
		if not atacando:return
	var acumulado:=0.0
	for i in dados.tempos_ms.size():
		acumulado+=float(dados.tempos_ms[i])
		if _tempo_ms<acumulado:
			_mostrar_quadro(i);return
	atacando=false
	_mostrar_quadro(dados.tempos_ms.size()-1)
	acao_concluida.emit()

func _mostrar_quadro(indice: int) -> void:
	quadro=indice
	var dados:=_dados(direcao)
	var quadros:Array=_texturas.get("direita" if direcao=="esquerda" else direcao,[])
	if not quadros.is_empty():texture=quadros[indice]
	flip_h=direcao=="esquerda"
	if material!=null:
		var couro: Array=dados.ganhos_couro[indice]
		var manto: Array=dados.ganhos_manto[indice]
		material.set_shader_parameter("ganho_couro",Vector3(couro[0],couro[1],couro[2]))
		material.set_shader_parameter("ganho_manto",Vector3(manto[0],manto[1],manto[2]))

func _mostrar_andada(indice: int) -> void:
	quadro_andada=indice
	var id:="direita" if direcao=="esquerda" else direcao
	texture=_texturas_andada[id][indice]
	flip_h=direcao=="esquerda"
	var dados:Dictionary=_dados(direcao).andada
	var couro:Array=dados.ganhos_couro[indice]
	var manto:Array=dados.ganhos_manto[indice]
	material.set_shader_parameter("ganho_couro",Vector3(couro[0],couro[1],couro[2]))
	material.set_shader_parameter("ganho_manto",Vector3(manto[0],manto[1],manto[2]))

func ponto_cabeca() -> Vector2:
	var uv:=Vector2(320,140)
	if andando:
		uv=Vector2(350 if direcao in ["direita","esquerda"] else 320,155)
		if direcao=="esquerda":uv.x=640-uv.x
		return transform*(uv-Vector2(0,16)-PIVO)
	if direcao in ["direita","esquerda"]:
		var pontos: Array[Vector2]=[Vector2(330,155),Vector2(332,160),Vector2(330,150),Vector2(370,180),Vector2(375,210),Vector2(365,225),Vector2(350,200),Vector2(335,160)]
		uv=pontos[quadro]
		if direcao=="esquerda":uv.x=640-uv.x
	elif direcao=="cima":
		uv.y=[140,145,125,175,235,195,220,150,140][quadro]
	else:
		uv.y=[140,155,130,180,175,215,230,160,140][quadro]
	return transform*(uv-Vector2(0,16)-PIVO)
