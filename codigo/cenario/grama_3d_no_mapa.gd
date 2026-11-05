extends "res://codigo/campanha/natureza_bacia_lowpoly.gd"
## Reutiliza lâminas, vento, rastros e passes dos pés do moinho sobre pisos 2D.
## A máscara vem do terreno consumidor: nenhuma copa, água ou caminho é substituído.
## Mundo único (05/11): todos os blocos moram num só mundo 3D e saem de uma tela do tamanho da tela do jogo que segue
## a câmera. Antes cada bloco de 256 px tinha tela própria de 864x864 com sol e sombra (24 na vila, ~80 MB de vídeo).
var consultar_grama: Callable
var _bases_fisicas: Dictionary = {}
var _contatos: Array[Dictionary] = []
var _imagens_contato: Array[Sprite2D] = []
## Grama à frente do pé de cada árvore: também recorte da tela única (antes, uma tela 3D por árvore).
var _imagens_frente: Array[Sprite2D] = []
var _frentes_pendentes: Array[Dictionary] = []
const TAMANHO_BLOCO := 256
var resolucao_grama := 864
var passo_tufo := 5

func _ready() -> void:
	_grama = ShaderMaterial.new()
	_grama.shader = preload("res://codigo/campanha/grama_interativa_bacia.gdshader")
	_grama_frente = _grama.duplicate() as ShaderMaterial
	_grama_frente.set_shader_parameter("somente_frente",true)
	_tufo = _malha_tufo()
	# 288 px de tela por bloco: a resolução antiga vira o supersample da tela única (vila 3x, cidade 1x).
	_fator_grama = maxf(1.0, resolucao_grama/288.0)
	if preload("res://codigo/globais/dispositivo.gd").celular(): _fator_grama = minf(_fator_grama, 2.0)
	_criar_mundo_grama()
	_coletar_bases(terreno)
	var inicio: Vector2 = (terreno.limites.position/256.0).floor()*256.0
	for y in range(int(inicio.y),ceili(terreno.limites.end.y),256):
		for x in range(int(inicio.x),ceili(terreno.limites.end.x),256):
			_montar_bloco(Vector2(x,y))
	if terreno.has_signal("terreno_alterado"):
		terreno.terreno_alterado.connect(_ao_terreno_alterado)
	if terreno.has_signal("estacao_mudou"):
		terreno.estacao_mudou.connect(definir_estacao)
	definir_estacao(Calendario.estacao())
	_montar_contatos()
	for registro in _frentes_pendentes: _montar_frente_base(registro)
	_frentes_pendentes.clear()

func _criar_mundo_grama() -> void:
	var render := _visor(Vector2i(2,2),0,1.0)
	_visor_grama = render.visor
	_visores.erase(_visor_grama)
	_visor_grama.name = "MundoGrama"
	_visor_grama.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_camera_grama = render.camera
	_camera_grama.cull_mask = 2
	# A grama não projeta sombra e o mundo não tem outra peça: o mapa de sombra seria só custo.
	for filho in _visor_grama.get_children():
		if filho is DirectionalLight3D: filho.shadow_enabled = false
	_mundo = {"visor":_visor_grama,"camera":_camera_grama}
	_imagem_grama = Sprite2D.new()
	_imagem_grama.name = "GramaMundo"
	_imagem_grama.texture = _visor_grama.get_texture()
	_imagem_grama.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_imagem_grama.z_as_relative = false
	_imagem_grama.z_index = terreno.Profundidade.Z_CHAO+5
	add_child(_imagem_grama)
	var tamanho := Vector2i(get_viewport_rect().size)+Vector2i.ONE*MARGEM_MUNDO
	_ajustar_mundo(tamanho + Vector2i(tamanho.x%2,tamanho.y%2))

## Sem solo 3D aqui (o piso é 2D): só a tela da grama segue a câmera; os recortes de contato acompanham.
func _seguir_camera(visivel: Rect2) -> void:
	var tamanho := Vector2i(visivel.size)+Vector2i.ONE*MARGEM_MUNDO
	tamanho += Vector2i(tamanho.x%2,tamanho.y%2)
	if tamanho != _tamanho_mundo: _ajustar_mundo(tamanho)
	var centro := ((visivel.get_center()/2.0).round()*2.0)
	_camera_grama.position = _ponto(centro)+Vector3(0,30,30)
	_imagem_grama.position = centro
	var area := Rect2(centro-Vector2(_tamanho_mundo)*.5,Vector2(_tamanho_mundo))
	for imagem in _imagens_contato + _imagens_frente:
		if not is_instance_valid(imagem): continue
		var faixa: Rect2 = imagem.get_meta("faixa")
		imagem.visible = area.encloses(faixa)
		if imagem.visible: imagem.region_rect = Rect2((faixa.position-area.position)*_fator_grama,faixa.size*_fator_grama)

func _coletar_bases(no: Node) -> void:
	for filho in no.get_children():
		if filho is CollisionShape2D and filho.get_parent() is StaticBody2D and filho.shape is RectangleShape2D and not filho.disabled:
			var tamanho: Vector2 = filho.shape.size
			var ret := Rect2(filho.to_global(-tamanho*.5),Vector2.ZERO)
			for canto in [Vector2(-.5,.5),Vector2(.5,-.5),Vector2(.5,.5)]: ret = ret.expand(filho.to_global(tamanho*canto))
			var inicio := (ret.position/256.0).floor()*256.0
			for y in range(int(inicio.y),ceili(ret.end.y),256):
				for x in range(int(inicio.x),ceili(ret.end.x),256):
					var chave := Vector2(x,y)
					if not _bases_fisicas.has(chave): _bases_fisicas[chave] = []
					_bases_fisicas[chave].append({"ret":ret,"forma":filho})
			# Cercas usam colisões rasas de 20×4; postes estreitos também precisam de contato.
			if ret.size.x >= 8.0 and ret.size.y >= 1.0 and ret.size.y < 200.0 and ret.size.x < 500.0:
				_contatos.append({"ret":ret,"forma":filho})
		elif filho is CollisionShape2D and filho.get_parent() is StaticBody2D and not filho.disabled:
			var pontos := PackedVector2Array()
			if filho.shape is CircleShape2D:
				for i in 24:
					var a := TAU*float(i)/24.0
					pontos.append(filho.to_global(Vector2(cos(a),sin(a))*filho.shape.radius))
			elif filho.shape is CapsuleShape2D:
				var raio: float = filho.shape.radius
				var haste: float = maxf(0.0,filho.shape.height*.5-raio)
				for i in 24:
					var a := TAU*float(i)/24.0
					var v := Vector2(cos(a),sin(a))*raio
					v.y += haste if v.y >= 0.0 else -haste
					pontos.append(filho.to_global(v))
			elif filho.shape is ConvexPolygonShape2D:
				for ponto in filho.shape.points: pontos.append(filho.to_global(ponto))
			_registrar_poligono(filho,pontos)
		elif filho is CollisionPolygon2D and filho.get_parent() is StaticBody2D and not filho.disabled:
			var pontos := PackedVector2Array()
			for ponto in filho.polygon: pontos.append(filho.to_global(ponto))
			_registrar_poligono(filho,pontos)
		_coletar_bases(filho)

func _registrar_poligono(forma: Node2D, pontos: PackedVector2Array) -> void:
	if pontos.size() < 3: return
	var ret := Rect2(pontos[0],Vector2.ZERO)
	for ponto in pontos: ret = ret.expand(ponto)
	var inicio := (ret.position/256.0).floor()*256.0
	for y in range(int(inicio.y),ceili(ret.end.y),256):
		for x in range(int(inicio.x),ceili(ret.end.x),256):
			var chave := Vector2(x,y)
			if not _bases_fisicas.has(chave): _bases_fisicas[chave] = []
			_bases_fisicas[chave].append({"ret":ret,"forma":forma,"poligono":pontos})
	if ret.size.x > 500.0 or ret.size.y > 200.0: return
	# Seguir a frente curva da base, em vez de pintar uma linha reta sob a peça inteira.
	for x in range(floori(ret.position.x),ceili(ret.end.x),6):
		var meio := minf(float(x)+3.0,ret.end.x-.01)
		var frente := -INF
		for i in pontos.size():
			var a := pontos[i]
			var b := pontos[(i+1)%pontos.size()]
			if is_equal_approx(a.x,b.x) or meio < minf(a.x,b.x) or meio > maxf(a.x,b.x): continue
			frente = maxf(frente,lerpf(a.y,b.y,(meio-a.x)/(b.x-a.x)))
		if is_finite(frente):
			_contatos.append({"ret":Rect2(x,frente-1.0,minf(6.0,ret.end.x-x),1.0),"forma":forma})

func _dentro_base(p: Vector2) -> bool:
	var chave := (p/256.0).floor()*256.0
	for base in _bases_fisicas.get(chave,[]):
		if is_instance_valid(base.forma) and not base.forma.disabled and base.ret.has_point(p):
			if not base.has("poligono") or Geometry2D.is_point_in_polygon(p,base.poligono): return true
	return false

func _montar_contatos() -> void:
	# Recortes da tela única da grama: a região é refeita a cada quadro em _seguir_camera.
	for contato in _contatos:
		if not is_instance_valid(contato.forma) or contato.forma.is_queued_for_deletion(): continue
		var ret: Rect2 = contato.ret
		var faixa := Rect2(ret.position.x-2.0,ret.end.y-9.0,ret.size.x+4.0,16.0)
		if not _ha_grama_perto(faixa): continue
		var imagem := _recorte(faixa,ret.end.y,terreno.Profundidade.z_de(ret.end.y)+7)
		_imagens_contato.append(imagem)
		contato.forma.tree_exiting.connect(imagem.queue_free)

func _montar_frente_base(registro: Dictionary) -> void:
	if _visor_grama == null:
		_frentes_pendentes.append(registro)
		return
	var centro: Vector2 = registro.sprite.position
	var faixa := Rect2(centro.x-12.0,centro.y-9.0,24.0,16.0)
	if not _ha_grama_perto(faixa): return
	var imagem := _recorte(faixa,centro.y,registro.sprite.z_index+7)
	_imagens_frente.append(imagem)
	registro.sprite.tree_exiting.connect(imagem.queue_free)

func _recorte(faixa: Rect2, base_y: float, z: int) -> Sprite2D:
	var imagem := Sprite2D.new()
	imagem.texture = _visor_grama.get_texture()
	imagem.centered = false
	imagem.region_enabled = true
	imagem.set_meta("faixa",faixa)
	imagem.position = faixa.position
	imagem.scale = Vector2.ONE/_fator_grama
	imagem.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	imagem.z_as_relative = false
	imagem.z_index = z
	imagem.visible = false
	var recorte := ShaderMaterial.new()
	recorte.shader = preload("res://codigo/cenario/contato_grama_3d.gdshader")
	recorte.set_shader_parameter("base_y",base_y)
	imagem.material = recorte
	add_child(imagem)
	return imagem

func _ha_grama_perto(faixa: Rect2) -> bool:
	for origem in _blocos:
		if faixa.intersects(Rect2(origem,Vector2(256,256))): return true
	return false

func _ao_terreno_alterado(celula: Vector2i, tipo: int) -> void:
	super(celula,tipo)
	for imagem in _imagens_contato:
		if is_instance_valid(imagem): imagem.queue_free()
	_imagens_contato.clear()
	_montar_contatos()

func _altura(_p: Vector2) -> float:
	return 0.0

func _peso_grama(p: Vector2) -> float:
	if not terreno.limites.has_point(p) or not consultar_grama.is_valid() or _dentro_base(p): return 0.0
	return clampf(float(consultar_grama.call(p)),0.0,1.0)

func _montar_bloco(origem: Vector2) -> void:
	if _blocos.has(origem):
		_blocos[origem].no.queue_free()
		_blocos.erase(origem)
	_rng.seed = int(origem.x)*771+int(origem.y)*139+840417
	var tufos: Array[Transform3D] = []
	for gy in range(0,TAMANHO_BLOCO,passo_tufo):
		for gx in range(0,TAMANHO_BLOCO,passo_tufo):
			var p := origem+Vector2(gx+_rng.randf_range(.4,passo_tufo-.4),gy+_rng.randf_range(.4,passo_tufo-.4))
			# A margem evita lâminas nas soleiras, no calçamento e dentro da água.
			var peso := _peso_grama(p)
			for d in [Vector2(-2,0),Vector2(2,0),Vector2(0,2)]: peso = minf(peso,_peso_grama(p+d))
			if _rng.randf() >= smoothstep(.18,.80,peso): continue
			var b := Basis(Vector3.UP,_rng.randf()*TAU).scaled(Vector3.ONE*_rng.randf_range(.8,1.25))
			tufos.append(Transform3D(b,_ponto(p)))
	if tufos.is_empty():
		_gramados.erase(origem)
		return
	var bloco := Node3D.new()
	bloco.name = "Grama_%d_%d" % [origem.x,origem.y]
	_visor_grama.add_child(bloco)
	_gramados[origem] = _instancias(bloco,_tufo,_grama,tufos,Vector2.ZERO,true)
	_blocos[origem] = {"no":bloco}

func definir_estacao(indice: int) -> void:
	_estacao = clampi(indice,0,3)
	var cor := Color(["4d781e","466d24","9e853b","b2c3b7"][_estacao]).linear_to_srgb()
	for m in [_grama,_grama_frente]:
		m.set_shader_parameter("cor_grama",Vector3(cor.r,cor.g,cor.b))
	for visor in _visores:
		if is_instance_valid(visor): visor.render_target_update_mode = SubViewport.UPDATE_ONCE

static func peso_modular(p: Vector2, tipo_canto: Callable) -> float:
	var celula := Vector2i((p/16.0).floor())
	var tipos := [int(tipo_canto.call(celula)),int(tipo_canto.call(celula+Vector2i.RIGHT)),int(tipo_canto.call(celula+Vector2i.DOWN)),int(tipo_canto.call(celula+Vector2i.ONE))]
	# Regiões uniformes têm o mesmo resultado exato, sem pesos/potências por lâmina.
	if tipos.all(func(tipo: int) -> bool: return tipo == 0): return 1.0
	if not tipos.has(0): return 0.0
	var uv := p/16.0-Vector2(celula)
	var pesos := [(1.-uv.x)*(1.-uv.y),uv.x*(1.-uv.y),(1.-uv.x)*uv.y,uv.x*uv.y]
	var acumulado := [0.0,0.0,0.0,0.0]
	for i in 4: acumulado[tipos[i]] += pesos[i]
	var total := 0.0
	for i in 4:
		acumulado[i] = pow(maxf(float(acumulado[i])-.18,0.0),2.0)
		total += float(acumulado[i])
	return float(acumulado[0])/maxf(total,.001)
