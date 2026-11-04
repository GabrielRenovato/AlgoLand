extends Node2D
## Natureza 3D modular; renders compartilhados, sem imagem de fundo do mapa.
const FABRICA := preload("res://codigo/campanha/modelo_natureza_bacia_3d.gd")
const PROJECAO := 0.70710678
const PIXELS_METRO := 32.0
const ESPECIES := ["carvalho","jovem","pinheiro","arbustos"]
const CORES_SOLO := [
	["718b38","a8784b","979481","779644"],
	["5f7e32","997048","8d8c7d","6d8d3c"],
	["918244","97704b","918b7a","b1944d"],
	["77877a","807361","9ca5a0","a9b8b2"],
]
var terreno: Node2D
var _renders: Dictionary = {}
var _vegetacao: Array[Dictionary] = []
var _solo: ShaderMaterial
var _grama: ShaderMaterial
var _grama_frente: ShaderMaterial
var _frentes: Dictionary = {}
var _rastros: Array[Dictionary] = []
var _ultimos_passos: Dictionary = {}
var _gramados: Dictionary = {}
var _bases_frentes: Array[Dictionary] = []
var _pedra: StandardMaterial3D
var _visores: Array[SubViewport] = []
var _blocos: Dictionary = {}
var _sombras: Array[Dictionary] = []
var _proxies_sombra: Array[Dictionary] = []
var _estacao := -1
var _rng := RandomNumberGenerator.new()
var _volume: ArrayMesh
var _tufo: ArrayMesh

func _ready() -> void:
	_solo = ShaderMaterial.new()
	_solo.shader = preload("res://codigo/campanha/solo_bacia_lowpoly.gdshader")
	_solo.set_shader_parameter("mascaras",load("res://assets/cenario/campanha/clareiras_modulares/mascaras.png"))
	_grama = ShaderMaterial.new()
	_grama.shader = preload("res://codigo/campanha/grama_interativa_bacia.gdshader")
	_grama_frente = _grama.duplicate() as ShaderMaterial
	_grama_frente.set_shader_parameter("somente_frente",true)
	_pedra = StandardMaterial3D.new()
	_volume = FABRICA.new().volume(46,3,7)
	_tufo = _malha_tufo()
	for y in range(-512,512,256):
		for x in range(-768,768,256):
			_montar_bloco(Vector2(x,y))
	terreno.terreno_alterado.connect(_ao_terreno_alterado)

func _ao_terreno_alterado(celula: Vector2i, _tipo: int) -> void:
	var afetados: Dictionary = {}
	for y in range(-1,2):
		for x in range(-1,2):
			var ponto := Vector2(celula+Vector2i(x,y))*16.0
			var origem := (ponto/256.0).floor()*256.0
			if _blocos.has(origem): afetados[origem] = true
	for origem in afetados: _montar_bloco(origem)

func _visor(tamanho: Vector2i, centro_y: float, tamanho_camera: float) -> Dictionary:
	var visor := SubViewport.new()
	visor.size = tamanho
	visor.transparent_bg = true
	visor.own_world_3d = true
	visor.render_target_update_mode = SubViewport.UPDATE_ONCE
	visor.msaa_3d = Viewport.MSAA_DISABLED
	add_child(visor)
	_visores.append(visor)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = tamanho_camera
	camera.position = Vector3(0,30+centro_y,30)
	visor.add_child(camera)
	camera.look_at(Vector3(0,centro_y,0))
	camera.current = true
	var ambiente := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("9bb8cb")
	e.ambient_light_energy = .52
	ambiente.environment = e
	visor.add_child(ambiente)
	var sol := DirectionalLight3D.new()
	sol.layers = 7
	sol.light_cull_mask = 7
	sol.rotation_degrees = Vector3(-52,-35,0)
	sol.light_color = Color("ffe4b5")
	sol.light_energy = .82
	sol.shadow_enabled = true
	visor.add_child(sol)
	return {"visor":visor,"camera":camera}

func _ponto(p: Vector2) -> Vector3:
	return Vector3(p.x/PIXELS_METRO,0,p.y/(PIXELS_METRO*PROJECAO))

func _altura(p: Vector2) -> float:
	# Relevo contínuo em metros: caminhos quase planos, tufos e taludes elevados.
	var afastamento := 1.0
	for i in terreno.CAMINHOS.size():
		var pontos: Array = terreno.CAMINHOS[i]
		for j in pontos.size()-1:
			var d := p.distance_to(Geometry2D.get_closest_point_to_segment(p,pontos[j],pontos[j+1]))-float(terreno.LARGURAS_CAMINHOS[i])
			afastamento = minf(afastamento,smoothstep(0.0,30.0,d))
	afastamento *= smoothstep(106.0,142.0,p.length())
	afastamento *= smoothstep(80.0,135.0,p.distance_to(Vector2(-464,-315)))
	var agua: float = terreno.peso_agua(p)
	var relevo := .13+.10*sin(p.x/57.0)*sin(p.y/69.0)+.025*sin(p.x/17.0+p.y/23.0)
	return lerpf(relevo*afastamento,-.075,smoothstep(.12,.85,agua))

func _normal(p: Vector2) -> Vector3:
	var dx := (_altura(p+Vector2(2,0))-_altura(p-Vector2(2,0)))*8.0
	var dz := (_altura(p+Vector2(0,2))-_altura(p-Vector2(0,2)))*8.0*PROJECAO
	return Vector3(-dx,1,-dz).normalized()

func _peso_grama(p: Vector2) -> float:
	var celula := Vector2i((p/16.0).floor())
	var uv := p/16.0-Vector2(celula)
	var pesos := [(1.-uv.x)*(1.-uv.y),uv.x*(1.-uv.y),(1.-uv.x)*uv.y,uv.x*uv.y]
	var acumulado := [0.0,0.0,0.0,0.0]
	var cantos := [Vector2i.ZERO,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.ONE]
	for i in 4: acumulado[terreno._tipo_canto(celula+cantos[i])] += pesos[i]
	var total := 0.0
	for i in 4:
		acumulado[i] = pow(maxf(float(acumulado[i])-.18,0.0),2.0)
		total += float(acumulado[i])
	return float(acumulado[0])/maxf(total,.001)

func _montar_bloco(origem: Vector2) -> void:
	if _blocos.has(origem):
		var antigo: Dictionary = _blocos[origem]
		_visores.erase(antigo.visor)
		antigo.visor.queue_free()
		antigo.imagem.queue_free()
		_visores.erase(antigo.visor_grama)
		antigo.visor_grama.queue_free()
		antigo.imagem_grama.queue_free()
	# Margem de 16px permite desenhar os tufos sem recortá-los nas emendas.
	var centro := origem+Vector2(128,128)
	var render := _visor(Vector2i(288,288),0,9.0)
	var visor: SubViewport = render.visor
	(render.camera as Camera3D).cull_mask = 1
	visor.name = "Solo_%d_%d" % [origem.x,origem.y]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for y in range(int(origem.y/16),int(origem.y/16)+16):
		for x in range(int(origem.x/16),int(origem.x/16)+16):
			var celula := Vector2i(x,y)
			var indice: int = terreno._tipo_canto(celula)+(terreno._tipo_canto(celula+Vector2i.RIGHT)<<2)+(terreno._tipo_canto(celula+Vector2i.DOWN)<<4)+(terreno._tipo_canto(celula+Vector2i.ONE)<<6)
			for canto in [Vector2.ZERO,Vector2.DOWN,Vector2.RIGHT,Vector2.RIGHT,Vector2.DOWN,Vector2.ONE]:
				var p: Vector2 = (Vector2(celula)+canto)*16.0
				st.set_normal(_normal(p))
				st.set_uv((Vector2(indice%16,indice/16)+canto*.999+Vector2.ONE*.0005)/16.0)
				st.set_uv2(p)
				var vertice := _ponto(p-centro)
				vertice.y = _altura(p)
				st.add_vertex(vertice)
	var malha := MeshInstance3D.new()
	malha.mesh = st.commit()
	malha.material_override = _solo
	visor.add_child(malha)
	_rng.seed = int(origem.x)*771+int(origem.y)*139+840417
	var tufos: Array[Transform3D] = []
	var pedras: Array[Transform3D] = []
	# Gramado denso: lâminas reais cobrem o solo, em vez de tufos sobre imagem de folhas.
	for gy in range(0,256,5):
		for gx in range(0,256,5):
			var p := origem+Vector2(gx+_rng.randf_range(.4,4.6),gy+_rng.randf_range(.4,4.6))
			if terreno.peso_agua(p) > .30: continue
			if _rng.randf() > smoothstep(.18,.80,_peso_grama(p)): continue
			var b := Basis(Vector3.UP,_rng.randf()*TAU).scaled(Vector3.ONE*_rng.randf_range(.8,1.25))
			tufos.append(Transform3D(b,_ponto(p-centro)+Vector3.UP*_altura(p)))
	for i in 250:
		var p := origem+Vector2(_rng.randf_range(3,253),_rng.randf_range(3,253))
		if terreno._tipo_canto(Vector2i((p/16).floor())) != 1 or terreno.peso_agua(p) > .1: continue
		var b := Basis(Vector3.UP,_rng.randf()*TAU).scaled(Vector3(_rng.randf_range(.035,.09),.03,_rng.randf_range(.03,.075)))
		pedras.append(Transform3D(b,_ponto(p-centro)+Vector3(0,_altura(p)+.015,0)))
	_gramados[origem] = _instancias(visor,_tufo,_grama,tufos,centro,true)
	_instancias(visor,_volume,_pedra,pedras)
	var imagem := Sprite2D.new()
	imagem.texture = visor.get_texture()
	imagem.position = centro
	imagem.scale = Vector2.ONE
	imagem.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	imagem.z_as_relative = false
	imagem.z_index = terreno.Profundidade.Z_CHAO+1
	add_child(imagem)
	_aplicar_filtro_pixel(imagem)
	var visor_grama := SubViewport.new()
	visor_grama.size = Vector2i(864,864)
	visor_grama.transparent_bg = true
	visor_grama.world_3d = visor.find_world_3d()
	add_child(visor_grama)
	_visores.append(visor_grama)
	var camera_grama := Camera3D.new()
	camera_grama.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera_grama.size = 9.0
	camera_grama.position = Vector3(0,30,30)
	camera_grama.cull_mask = 2
	visor_grama.add_child(camera_grama)
	camera_grama.look_at(Vector3.ZERO)
	camera_grama.current = true
	var imagem_grama := Sprite2D.new()
	imagem_grama.texture = visor_grama.get_texture()
	imagem_grama.position = centro
	imagem_grama.scale = Vector2.ONE/3.0
	imagem_grama.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	imagem_grama.z_as_relative = false
	imagem_grama.z_index = terreno.Profundidade.Z_CHAO+2
	add_child(imagem_grama)
	_blocos[origem] = {"visor":visor,"imagem":imagem,"visor_grama":visor_grama,"imagem_grama":imagem_grama}
	for item in _vegetacao:
		if is_instance_valid(item.sprite): _sombra_3d(item.registro,item.render,origem)

func _instancias(pai: Node, malha: Mesh, material: Material, transformacoes: Array[Transform3D], centro := Vector2.ZERO, interativa := false) -> MultiMesh:
	if transformacoes.is_empty(): return null
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_custom_data = interativa
	multi.mesh = malha
	multi.instance_count = transformacoes.size()
	for i in transformacoes.size():
		multi.set_instance_transform(i,transformacoes[i])
		if interativa:
			var base := transformacoes[i].origin
			multi.set_instance_custom_data(i,Color(base.x*PIXELS_METRO+centro.x,base.z*PIXELS_METRO*PROJECAO+centro.y,base.y,0.0))
	var no := MultiMeshInstance3D.new()
	no.multimesh = multi
	no.material_override = material
	no.layers = 2 if interativa else 1
	if interativa: no.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pai.add_child(no)
	if interativa:
		var frente := MultiMeshInstance3D.new()
		frente.multimesh = multi
		frente.material_override = _grama_frente
		frente.layers = 4
		frente.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pai.add_child(frente)
	return multi

func _malha_tufo() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for i in 8:
		var a := i*TAU/8.0
		var base := Vector3(cos(a)*.045,0,sin(a)*.045)
		var lateral := Vector3(-sin(a),0,cos(a))
		var altura := .22+float(i%3)*.045
		for j in 3:
			var t := float(j)/3.0
			var u := float(j+1)/3.0
			var c0 := base+Vector3(cos(a)*.11*t*t,altura*t,sin(a)*.11*t*t)
			var c1 := base+Vector3(cos(a)*.11*u*u,altura*u,sin(a)*.11*u*u)
			var l0 := lateral*.037*pow(1.-t,.65)
			var l1 := lateral*.037*pow(1.-u,.65)
			var nervura := Vector3(cos(a),.1,sin(a))*.008
			var m0 := c0+nervura*(1.-t)
			var m1 := c1+nervura*(1.-u)
			for v in [c0-l0,c1-l1,m0,m0,c1-l1,m1,m0,m1,c0+l0,c0+l0,m1,c1+l1]:
				var f := clampf(v.y/altura,0.,1.)
				st.set_color(Color(.48+f*.52,.58+f*.42,.38+f*.52))
				st.add_vertex(v)
	st.generate_normals()
	return st.commit()

func substituir(registro: Dictionary) -> void:
	var tipo: String = registro.tipo
	if not tipo in ESPECIES: return
	var variante := posmod(str(registro.id).hash(),3)
	var chave := tipo+str(variante)
	if not _renders.has(chave):
		var fabrica := FABRICA.new()
		var modelo := fabrica.criar(tipo,variante)
		var render := _visor(Vector2i(384,480),1.8,5.0)
		var visor: SubViewport = render.visor
		visor.name = "Vegetacao_"+chave
		visor.add_child(modelo)
		var camera: Camera3D = render.camera
		var ancora := camera.unproject_position(Vector3.ZERO)
		_renders[chave] = {"fabrica":fabrica,"visor":visor,"ancora":ancora,"modelo":modelo}
	var render: Dictionary = _renders[chave]
	var sprite: Sprite2D = registro.sprite
	var largura: float = registro.largura
	var escala := largura/(132.0 if tipo == "arbustos" else 288.0)
	sprite.position = registro.ponto+Vector2(0,(-8 if tipo != "arbustos" else 0)-_altura(registro.ponto)*PIXELS_METRO*PROJECAO)
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_vegetacao.append({"sprite":sprite,"render":render,"escala":escala,"registro":registro})
	_aplicar_sprite(_vegetacao.back())
	_sombra(registro,tipo)
	for origem in _blocos: _sombra_3d(registro,render,origem)
	_montar_frente_base(registro)
	sprite.tree_exiting.connect(_invalidar_sombras)

func _invalidar_sombras() -> void:
	_atualizar_visores.call_deferred()

func _atualizar_visores() -> void:
	for visor in _visores:
		if is_instance_valid(visor): visor.render_target_update_mode = SubViewport.UPDATE_ONCE

func _aplicar_sprite(item: Dictionary) -> void:
	item.sprite.texture = item.render.visor.get_texture()
	item.sprite.offset = -item.render.ancora
	item.sprite.scale = Vector2.ONE*item.escala
	_aplicar_filtro_pixel(item.sprite)

func _aplicar_filtro_pixel(sprite: Sprite2D) -> void:
	var filtro := sprite.material as ShaderMaterial
	if filtro == null:
		filtro = ShaderMaterial.new()
		filtro.shader = preload("res://codigo/campanha/filtro_pixel_natureza.gdshader")
		sprite.material = filtro
	var tamanho: Vector2 = sprite.texture.get_size()*sprite.scale
	var origem := sprite.position+sprite.offset*sprite.scale
	if sprite.centered: origem -= tamanho*.5
	filtro.set_shader_parameter("origem",origem)
	filtro.set_shader_parameter("tamanho_logico",tamanho)

func _sombra(registro: Dictionary, tipo: String) -> void:
	var sombra := Polygon2D.new()
	var pontos := PackedVector2Array()
	var largura: float = registro.largura*.13
	for i in 16:
		var a := i*TAU/16.0
		pontos.append(Vector2(cos(a)*largura,sin(a)*largura*.30)+Vector2(8,-5))
	sombra.polygon = pontos
	sombra.color = Color(.10,.15,.19,.20 if tipo != "arbustos" else .12)
	sombra.position = registro.ponto
	sombra.z_as_relative = false
	sombra.z_index = terreno.Profundidade.Z_CHAO+2
	add_child(sombra)
	_sombras.append({"no":sombra,"tipo":tipo})
	# Integra a sombra ao ciclo de remoção do objeto, sem deixar manchas órfãs.
	registro.sprite.tree_exiting.connect(sombra.queue_free)

func _sombra_3d(registro: Dictionary, render: Dictionary, origem: Vector2) -> void:
	var centro := origem+Vector2(128,128)
	var area := Rect2(origem,Vector2(256,256)).grow(160)
	if not area.has_point(registro.ponto): return
	var proxy := render.modelo.duplicate() as Node3D
	proxy.position = _ponto(registro.ponto-centro+Vector2(0,-8))
	proxy.position.y = _altura(registro.ponto)
	proxy.scale = Vector3.ONE*float(registro.largura)/(44.0 if registro.tipo == "arbustos" else 96.0)
	for parte in proxy.get_children():
		if parte is GeometryInstance3D: parte.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	_blocos[origem].visor.add_child(proxy)
	_proxies_sombra.append({"no":proxy,"modelo":render.modelo})
	registro.sprite.tree_exiting.connect(proxy.queue_free)

func definir_estacao(indice: int) -> void:
	_estacao = indice
	var cores: Array = CORES_SOLO[indice]
	var nome: String = terreno.NOMES[indice]
	_solo.set_shader_parameter("terra",load("res://assets/cenario/campanha/natureza_bacia_3d/terra.png"))
	_solo.set_shader_parameter("pedra",load("res://assets/cenario/campanha/clareiras_modulares/%s/pedra.png" % nome))
	_solo.set_shader_parameter("ajuste_vegetacao",.85)
	_solo.set_shader_parameter("estacao",indice)
	_solo.set_shader_parameter("tom_terra",Vector3(.89,.95,1.025) if indice != 3 else Vector3(.93,.97,1.02))
	for material in [_grama,_grama_frente]:
		var cor := Color(["4d781e","466d24","9e853b","b2c3b7"][indice]).linear_to_srgb()
		material.set_shader_parameter("cor_grama",Vector3(cor.r,cor.g,cor.b))
	_pedra.albedo_color = Color("6e604d") if indice != 3 else Color("a3ada5")
	for render in _renders.values(): render.fabrica.definir_estacao(indice)
	for item in _proxies_sombra:
		if not is_instance_valid(item.no): continue
		for i in item.no.get_child_count():
			item.no.get_child(i).visible = item.modelo.get_child(i).visible
	for item in _vegetacao:
		if is_instance_valid(item.sprite): _aplicar_sprite(item)
	for item in _sombras:
		if is_instance_valid(item.no):
			item.no.scale = Vector2.ONE*(.45 if indice == 3 and item.tipo != "pinheiro" else 1.0)
	for visor in _visores:
		if is_instance_valid(visor): visor.render_target_update_mode = SubViewport.UPDATE_ONCE

func _process(delta: float) -> void:
	var jogadores := PackedVector4Array()
	var atores: Array[Node2D] = []
	var ativos: Dictionary = {}
	for ator in get_tree().get_nodes_in_group("jogadores"):
		if not ator is Node2D or not ator.is_visible_in_tree(): continue
		var pes: Vector2 = ator.global_position+Vector2(0,terreno.Profundidade.PES_JOGADOR)
		if not terreno.limites.has_point(pes): continue
		var direcao := Vector2.ZERO
		if ator is CharacterBody2D: direcao = ator.velocity/130.0
		jogadores.append(Vector4(pes.x,pes.y,direcao.x,direcao.y))
		atores.append(ator)
		var id: int = ator.get_instance_id()
		ativos[id] = true
		var anterior: Vector2 = _ultimos_passos.get(id,pes)
		if anterior.distance_to(pes) >= 5.0:
			_rastros.append({"p":pes,"d":(pes-anterior).normalized(),"forca":1.0})
			_ultimos_passos[id] = pes
		elif not _ultimos_passos.has(id): _ultimos_passos[id] = pes
		if atores.size() >= 8: break
	for id in _ultimos_passos.keys():
		if not ativos.has(id): _ultimos_passos.erase(id)
	for i in range(_rastros.size()-1,-1,-1):
		_rastros[i].forca = maxf(0.0,float(_rastros[i].forca)-delta*1.6)
		if _rastros[i].forca <= 0.0: _rastros.remove_at(i)
	while _rastros.size() > 16: _rastros.pop_front()
	var rastros := PackedVector4Array()
	var forcas := PackedFloat32Array()
	for rastro in _rastros:
		rastros.append(Vector4(rastro.p.x,rastro.p.y,rastro.d.x,rastro.d.y))
		forcas.append(rastro.forca)
	# Arrays com tamanho fixo mantêm o contrato dos uniforms em todas as fases.
	jogadores.resize(8)
	rastros.resize(16)
	forcas.resize(16)
	for material in [_grama,_grama_frente]:
		material.set_shader_parameter("jogadores",jogadores)
		material.set_shader_parameter("quantidade_jogadores",atores.size())
		material.set_shader_parameter("rastros",rastros)
		material.set_shader_parameter("forcas_rastros",forcas)
		material.set_shader_parameter("quantidade_rastros",_rastros.size())
	var inversa := get_viewport().get_canvas_transform().affine_inverse()
	var inicio := inversa*Vector2.ZERO
	var fim := inversa*get_viewport_rect().size
	var visivel := Rect2(inicio,fim-inicio).abs().grow(24)
	for origem in _blocos:
		var bloco: Dictionary = _blocos[origem]
		bloco.visor_grama.render_target_update_mode = SubViewport.UPDATE_ALWAYS if visivel.intersects(Rect2(origem,Vector2(256,256))) else SubViewport.UPDATE_DISABLED
	for chave in _frentes.keys():
		var frente: Dictionary = _frentes[chave]
		if not ativos.has(frente.ator):
			frente.imagem.queue_free()
			frente.visor.queue_free()
			_frentes.erase(chave)
			continue
		frente.imagem.visible = false
		frente.visor.render_target_update_mode = SubViewport.UPDATE_DISABLED
	for base in _bases_frentes:
		if is_instance_valid(base.visor):
			base.visor.render_target_update_mode = SubViewport.UPDATE_ALWAYS if visivel.has_point(base.p) else SubViewport.UPDATE_DISABLED
	for ator in atores:
		var pes: Vector2 = ator.global_position+Vector2(0,terreno.Profundidade.PES_JOGADOR)
		if _peso_grama(pes) < .08: continue
		var origens: Dictionary = {}
		for dy in [-20.0,20.0]:
			for dx in [-20.0,20.0]:
				var origem := ((pes+Vector2(dx,dy))/256.0).floor()*256.0
				if _blocos.has(origem): origens[origem] = true
		for origem in origens: _atualizar_frente(ator,pes,origem)

func _atualizar_frente(ator: Node2D, pes: Vector2, origem: Vector2) -> void:
	var chave := "%d_%d_%d" % [ator.get_instance_id(),origem.x,origem.y]
	if not _frentes.has(chave):
		var visor := SubViewport.new()
		visor.size = Vector2i(192,144)
		visor.transparent_bg = true
		add_child(visor)
		var camera := Camera3D.new()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 1.5
		camera.cull_mask = 4
		visor.add_child(camera)
		camera.current = true
		var imagem := Sprite2D.new()
		imagem.texture = visor.get_texture()
		imagem.scale = Vector2.ONE/3.0
		imagem.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var mascara := ShaderMaterial.new()
		mascara.shader = preload("res://codigo/campanha/frente_grama_bacia.gdshader")
		imagem.material = mascara
		imagem.z_as_relative = false
		add_child(imagem)
		_frentes[chave] = {"visor":visor,"camera":camera,"imagem":imagem,"ator":ator.get_instance_id()}
	var frente: Dictionary = _frentes[chave]
	frente.visor.world_3d = _blocos[origem].visor.find_world_3d()
	var alvo := _ponto(pes-origem-Vector2(128,128))
	frente.camera.position = alvo+Vector3(0,30,30)
	frente.camera.look_at(alvo)
	frente.imagem.position = pes
	frente.imagem.z_index = terreno.Profundidade.z_de(pes.y)+7
	frente.imagem.visible = true
	frente.imagem.material.set_shader_parameter("origem",pes-Vector2(32,24))
	frente.imagem.material.set_shader_parameter("pes",pes)
	frente.visor.render_target_update_mode = SubViewport.UPDATE_ALWAYS

func _montar_frente_base(registro: Dictionary) -> void:
	var base: Vector2 = registro.ponto+Vector2(0,-8 if registro.tipo != "arbustos" else 0)
	var centro: Vector2 = registro.sprite.position
	var transformacoes: Array[Transform3D] = []
	for origem in _gramados:
		if not Rect2(origem,Vector2(256,256)).grow(20).has_point(base): continue
		var fonte := _gramados[origem] as MultiMesh
		if fonte == null: continue
		for i in fonte.instance_count:
			var dado := fonte.get_instance_custom_data(i)
			var p := Vector2(dado.r,dado.g)
			var d := p-base
			if d.y < -.5 or d.y > 12. or absf(d.x) > 16.: continue
			var transformacao := fonte.get_instance_transform(i)
			transformacao.origin = _ponto(p-centro)+Vector3.UP*dado.b
			transformacoes.append(transformacao)
	if transformacoes.is_empty(): return
	var render := _visor(Vector2i(192,144),0,1.5)
	(render.camera as Camera3D).cull_mask = 2
	var visor: SubViewport = render.visor
	_instancias(visor,_tufo,_grama,transformacoes,centro,true)
	var imagem := Sprite2D.new()
	imagem.texture = visor.get_texture()
	imagem.scale = Vector2.ONE/3.0
	imagem.position = centro
	imagem.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	imagem.z_as_relative = false
	imagem.z_index = registro.sprite.z_index+7
	var mascara := ShaderMaterial.new()
	mascara.shader = preload("res://codigo/campanha/frente_grama_bacia.gdshader")
	mascara.set_shader_parameter("pes",centro)
	mascara.set_shader_parameter("origem",centro-Vector2(32,24))
	imagem.material = mascara
	add_child(imagem)
	_bases_frentes.append({"visor":visor,"imagem":imagem,"p":centro})
	registro.sprite.tree_exiting.connect(imagem.queue_free)
	registro.sprite.tree_exiting.connect(visor.queue_free)
