extends Node2D
## Encostas de64px e platôs próprios, compostos sem ocupar as rotas de combate.
@export var andar := 1
const ESTACOES := ["spring","summer","autumn","winter"]
var formacoes: Array=[]
var _topos: Array[Polygon2D]=[]
var _faces: Array[Polygon2D]=[]

func _ready() -> void:
	z_index=-996
	z_as_relative=false
	texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	formacoes=JSON.parse_string(FileAccess.get_file_as_string("res://codigo/fendas/relevos/andar_%02d.json" % andar)).formacoes
	var terreno:=get_parent()
	if andar in [1,2,5,8]:terreno.get_node("Penhasco").visible=false
	var escondidos: Array[String]=[]
	for dados in formacoes:
		var topo:=PackedVector2Array()
		for p in dados.topo:topo.append(Vector2(p[0],p[1]))
		var todos:=topo.duplicate()
		for p in topo:todos.append(p+Vector2(0,dados.altura))
		var base:=Geometry2D.convex_hull(todos)
		var forma:=CollisionPolygon2D.new()
		forma.polygon=base
		# Reutiliza o corpo estático existente, lido também pela navegação.
		terreno.get_node("Obstaculos").add_child(forma)
		var sombra:=Polygon2D.new()
		sombra.polygon=base
		sombra.position=Vector2(3,3)
		sombra.color=Color(0.05,0.10,0.06,0.16)
		add_child(sombra)
		for i in topo.size():
			var a:=topo[i]
			var b:=topo[(i+1)%topo.size()]
			if b.x>=a.x:continue
			var face:=Polygon2D.new()
			face.polygon=PackedVector2Array([a,b,b+Vector2(0,dados.altura),a+Vector2(0,dados.altura)])
			# Coordenadas do mundo evitam esticar os pixels nas faces diagonais.
			var linha_base: float=topo[5].y
			face.uv=PackedVector2Array([Vector2(a.x,a.y-linha_base),Vector2(b.x,b.y-linha_base),Vector2(b.x,b.y-linha_base+dados.altura),Vector2(a.x,a.y-linha_base+dados.altura)])
			add_child(face)
			_faces.append(face)
		var teto:=Polygon2D.new()
		teto.polygon=topo
		teto.material=ShaderMaterial.new()
		teto.material.shader=preload("res://codigo/fendas/topo_relevo.gdshader")
		add_child(teto)
		_topos.append(teto)
		var mantidas: Array[Vector2]=[]
		for objeto in terreno.get_node("Objetos3D").get_children():
			if not objeto is Sprite2D:continue
			var no_topo:=Geometry2D.is_point_in_polygon(objeto.position,topo)
			var esconder:=false
			if no_topo:
				var atlas:=objeto.texture as AtlasTexture
				if atlas and atlas.resource_name in ["arvore","arvore_var","gentle_arvore"]:
					for p in mantidas:
						if p.distance_to(objeto.position)<80:esconder=true
					if not esconder:mantidas.append(objeto.position)
			else:
				esconder=Geometry2D.is_point_in_polygon(objeto.position+Vector2(0,8),base) or Geometry2D.is_point_in_polygon(objeto.position-Vector2(0,64),base)
			if esconder:
				objeto.visible=false
				escondidos.append(objeto.name)
	for forma in terreno.get_node("Obstaculos").get_children():
		if str(forma.get_meta("sprite_colisao","")) in escondidos:
			terreno.get_node("Obstaculos").remove_child(forma)
			forma.queue_free()
	var estacoes:=terreno.get_node("Estacoes")
	estacoes.estacao_mudou.connect(_estacao)
	_estacao(estacoes.estacao_atual)

func _estacao(e: int) -> void:
	for topo in _topos:topo.texture=load("res://assets/cenario/substitutos/grama_continua/%s.png" % ESTACOES[e])
	for face in _faces:face.texture=load("res://assets/cenario/substitutos/penhasco/%s.png" % ESTACOES[e])
