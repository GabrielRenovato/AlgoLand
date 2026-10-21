extends RefCounted
## Máscara contínua da superfície: ondas e margens atravessam a grade sem costuras.
const SHADER := preload("res://codigo/cenario/agua_viva.gdshader")
const NOMES := ["spring","summer","autumn","winter"]
var material: ShaderMaterial
var _camada: TileMapLayer

func _material(imagem: Image, ponto: Vector2, fluxo: Vector2) -> void:
	_profundidade(imagem)
	material=ShaderMaterial.new()
	material.shader=SHADER
	material.set_shader_parameter("contorno",ImageTexture.create_from_image(imagem))
	material.set_shader_parameter("origem",ponto)
	material.set_shader_parameter("tamanho",Vector2(imagem.get_size()))
	material.set_shader_parameter("corrente",fluxo)
	aplicar(0)

func _profundidade(imagem: Image) -> void:
	# Campo de distância em meia resolução; r continua sendo a máscara exata.
	# Uma varredura em cada sentido evita contornos concêntricos por amostragem.
	var w:=ceili(imagem.get_width()/2.0)
	var h:=ceili(imagem.get_height()/2.0)
	var dist:=PackedFloat32Array()
	dist.resize(w*h)
	for y in h:
		for x in w:
			var dentro:=imagem.get_pixel(mini(x*2,imagem.get_width()-1),mini(y*2,imagem.get_height()-1)).r>0.5
			dist[y*w+x]=64.0 if dentro else 0.0
			if dentro and (x==0 or y==0 or x==w-1 or y==h-1):dist[y*w+x]=1.0
	for y in h:
		for x in w:
			var i:=y*w+x
			if x>0:dist[i]=minf(dist[i],dist[i-1]+1.0)
			if y>0:dist[i]=minf(dist[i],dist[i-w]+1.0)
			if x>0 and y>0:dist[i]=minf(dist[i],dist[i-w-1]+1.4142)
	for y in range(h-1,-1,-1):
		for x in range(w-1,-1,-1):
			var i:=y*w+x
			if x<w-1:dist[i]=minf(dist[i],dist[i+1]+1.0)
			if y<h-1:dist[i]=minf(dist[i],dist[i+w]+1.0)
			if x<w-1 and y<h-1:dist[i]=minf(dist[i],dist[i+w+1]+1.4142)
	for y in imagem.get_height():
		for x in imagem.get_width():
			var cor:=imagem.get_pixel(x,y)
			cor.g=clampf(dist[(y/2)*w+x/2]*2.0/48.0,0.0,1.0)
			imagem.set_pixel(x,y,cor)

func configurar(camada: TileMapLayer, mascara_atlas: Texture2D=null, fluxo:=Vector2(1.5,0.4)) -> void:
	_camada=camada
	var celulas:=camada.get_used_cells()
	if celulas.is_empty():return
	var area:=camada.get_used_rect()
	var origem_local:=Vector2(area.position*16)
	var imagem:=Image.create(area.size.x*16,area.size.y*16,false,Image.FORMAT_RGBA8)
	var fontes: Dictionary={}
	var mascara: Image=mascara_atlas.get_image() if mascara_atlas else null
	for celula in celulas:
		var id:=camada.get_cell_source_id(celula)
		var fonte:=camada.tile_set.get_source(id) as TileSetAtlasSource
		if fonte==null:continue
		if not fontes.has(id):fontes[id]=fonte.texture.get_image()
		var textura: Image=fontes[id]
		var atlas:=camada.get_cell_atlas_coords(celula)*16
		var destino: Vector2i=(celula-area.position)*16
		for y in 16:
			for x in 16:
				var uv:=atlas+Vector2i(x,y)
				var valor:=mascara.get_pixelv(uv).r if mascara else textura.get_pixelv(uv).a
				imagem.set_pixelv(destino+Vector2i(x,y),Color(valor,valor,valor,1))
	_material(imagem,camada.to_global(origem_local),fluxo)
	camada.material=material

func configurar_poligono(no: Node2D, poligono: PackedVector2Array) -> void:
	var area:=Rect2(poligono[0],Vector2.ZERO)
	for p in poligono:area=area.expand(p)
	area=area.grow(2)
	var imagem:=Image.create(ceili(area.size.x),ceili(area.size.y),false,Image.FORMAT_RGBA8)
	for y in imagem.get_height():
		for x in imagem.get_width():
			var agua:=Geometry2D.is_point_in_polygon(area.position+Vector2(x+0.5,y+0.5),poligono)
			imagem.set_pixel(x,y,Color.WHITE if agua else Color.BLACK)
	_material(imagem,no.to_global(area.position),Vector2(1.5,0.4))

func aplicar(estacao: int, protegido:=false, ativo:=true) -> void:
	if material==null:return
	material.set_shader_parameter("inverno",1.0 if estacao==3 and not protegido else 0.0)
	material.set_shader_parameter("terra",load("res://assets/cenario/substitutos/terra_continua/campo_%s.png" % NOMES[clampi(estacao,0,3)]))
	if _camada:_camada.material=material if ativo else null
