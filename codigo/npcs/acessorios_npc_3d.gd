extends RefCounted
## Aplica ao NPC 3D a variedade sorteada em variacao_npcs.gd: cor das peças, altura, corpulência, postura e acessórios
## (malhas simples presas aos ossos da cabeça e da cintura, no mesmo acabamento do boneco). Idempotente: pode ser
## chamada de novo depois de trocar uma peça na oficina.
const Variacao := preload("res://codigo/dados/variacao_npcs.gd")
const NOME_NO := "AcessoriosNPC"
# Coordenadas de repouso do manequim (olha para +Z): a pose chibi amplia o osso da cabeça sozinha.
const ORIGEM_CABECA := Vector3(0.0, 1.5687, 0.0051)
const ORIGEM_CINTURA := Vector3(0.0, 1.0505, -0.0156)

static func aplicar(visual: Node, ficha: Dictionary) -> void:
	if visual == null: return
	var heroi = visual.get("heroi")
	if heroi == null or heroi._esqueleto == null or heroi._modelo == null: return
	var esqueleto: Skeleton3D = heroi._esqueleto
	for no in esqueleto.get_children():
		if str(no.name).begins_with(NOME_NO):
			esqueleto.remove_child(no)
			no.queue_free()
	_pelos_faciais(heroi,[],Color.WHITE)
	var variacao: Dictionary = ficha.get("variacao", {})
	if not Variacao.ATIVA or variacao.is_empty() or ficha.get("faixa_etaria", "") == "crianca": return
	_corpo(heroi, variacao)
	_cores(heroi, variacao)
	var cabelo := Color("51372b")
	var tinta = ficha.get("aparencia", {}).get("cor", [0.32, 0.22, 0.17, 1.0])
	if tinta is Array and tinta.size() >= 3: cabelo = Color(float(tinta[0]), float(tinta[1]), float(tinta[2]))
	var acessorios: Array = variacao.get("acessorios", [])
	_pelos_faciais(heroi,acessorios,cabelo)
	var corpo_cor := Color(variacao.get("cores", {}).get("camisa", "586c3e"))
	var cabeca := _fixar(esqueleto, "DEF-head", "%sCabeca" % NOME_NO)
	for id in acessorios:
		match id:
			"chapeu_palha": _chapeu(heroi, cabeca)
			"lenco": _lenco(heroi, cabeca, corpo_cor)
			"oculos": _oculos(heroi, cabeca)
	if "bolsa" in acessorios:
		_bolsa(heroi, _fixar(esqueleto, "DEF-spine.001", "%sCintura" % NOME_NO))

static func _corpo(heroi: Node, variacao: Dictionary) -> void:
	var altura: float = float(variacao.get("altura", 1.0))
	var corpulencia: float = float(variacao.get("corpulencia", 1.0))
	heroi._modelo.scale = Vector3(corpulencia, altura, corpulencia)
	heroi._modelo.rotation.x = float(variacao.get("postura", 0.0))

static func _cores(heroi: Node, variacao: Dictionary) -> void:
	var cores: Dictionary = variacao.get("cores", {})
	for i in Variacao.CATEGORIAS_COR.size():
		var categoria: String = Variacao.CATEGORIAS_COR[i]
		if not cores.has(categoria) or i >= heroi._pecas.size(): continue
		var material = heroi._pecas[i].material_override
		if material is ShaderMaterial: material.set_shader_parameter("cor", Color(str(cores[categoria])))

static func _fixar(esqueleto: Skeleton3D, osso: String, nome: String) -> Node3D:
	var fixo := BoneAttachment3D.new()
	fixo.name = nome
	fixo.bone_name = osso
	esqueleto.add_child(fixo)
	return fixo

static func _malha(pai: Node3D, malha: Mesh, material: Material, posicao: Vector3, rotacao := Vector3.ZERO, escala := Vector3.ONE) -> void:
	var instancia := MeshInstance3D.new()
	instancia.mesh = malha
	instancia.material_override = material
	instancia.position = posicao
	instancia.rotation = rotacao
	instancia.scale = escala
	pai.add_child(instancia)

static func _c(x: float, y: float, z: float) -> Vector3:
	return Vector3(x, y, z) - ORIGEM_CABECA

static func _cilindro(raio_cima: float, raio_baixo: float, altura: float, lados := 14) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = raio_cima
	m.bottom_radius = raio_baixo
	m.height = altura
	m.radial_segments = lados
	m.rings = 1
	return m

static func _esfera(raio: float, lados := 12) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = raio
	m.height = raio * 2.0
	m.radial_segments = lados
	m.rings = 6
	return m

static func _caixa(x: float, y: float, z: float) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = Vector3(x, y, z)
	return m

static func _chapeu(heroi: Node, cabeca: Node3D) -> void:
	var palha: Material = heroi._material(Color("d9b968"))
	var fita: Material = heroi._material(Color("7a3f2f"))
	# Copa alta e afunilada, aba curta e levemente caída: antes parecia um prato achatado.
	_malha(cabeca, _cilindro(0.088, 0.118, 0.1), palha, _c(0.0, 1.845, 0.0))
	_malha(cabeca, _cilindro(0.158, 0.172, 0.014, 16), palha, _c(0.0, 1.797, 0.004), Vector3(-0.05, 0.0, 0.0))
	_malha(cabeca, _cilindro(0.121, 0.121, 0.022), fita, _c(0.0, 1.81, 0.0))

static func _lenco(heroi: Node, cabeca: Node3D, base: Color) -> void:
	var tom := base.lerp(Color("c8574a"), 0.55)
	var pano: Material = heroi._material(tom)
	var no_pano: Material = heroi._material(tom.darkened(0.2))
	# Bandana: faixa na testa com nó e pontas de lado. Um pano cobrindo o alto da cabeça virava uma boina vista de cima.
	_malha(cabeca, _cilindro(0.142, 0.148, 0.04), pano, _c(0.0, 1.79, -0.006), Vector3(-0.08, 0.0, 0.0))
	_malha(cabeca, _esfera(0.03, 8), no_pano, _c(0.146, 1.785, -0.04))
	for lado in [0.0, 1.0]:
		_malha(cabeca, _caixa(0.02, 0.085, 0.012), pano, _c(0.156 + 0.014 * lado, 1.74, -0.05), Vector3(0.0, 0.0, -0.25 + 0.5 * lado))

static func _oculos(heroi: Node, cabeca: Node3D) -> void:
	var aro: Material = heroi._material(Color("2c2622"))
	for lado in [-1.0, 1.0]:
		var anel := TorusMesh.new()
		anel.inner_radius = 0.022
		anel.outer_radius = 0.03
		anel.rings = 12
		anel.ring_segments = 6
		_malha(cabeca, anel, aro, _c(0.046 * lado, 1.72, 0.124), Vector3(PI / 2.0, 0.0, 0.0))
	_malha(cabeca, _caixa(0.034, 0.006, 0.006), aro, _c(0.0, 1.726, 0.126))

static func _pelos_faciais(heroi: Node, acessorios: Array, cor: Color) -> void:
	# O rosto atual usa a pintura de oito direções, presa à pose da cabeça.
	# Pintar no mesmo material preserva o encaixe durante giros e inclinações.
	if heroi._cabeca_referencia==null: return
	var material: ShaderMaterial = heroi._cabeca_referencia.material
	material.set_shader_parameter("pelos_faciais_npc",1 if "barba" in acessorios else (2 if "bigode" in acessorios else 0))
	material.set_shader_parameter("cor_pelos_faciais_npc",cor)

static func _bolsa(heroi: Node, cintura: Node3D) -> void:
	var couro: Material = heroi._material(Color("7a4a2a"))
	var o := ORIGEM_CINTURA
	_malha(cintura, _caixa(0.15, 0.125, 0.075), couro, Vector3(-0.245, 0.93, 0.02) - o)
	_malha(cintura, _caixa(0.15, 0.03, 0.08), heroi._material(Color("5e3a20")), Vector3(-0.245, 0.99, 0.02) - o)
	_malha(cintura, _caixa(0.026, 0.58, 0.032), couro, Vector3(-0.035, 1.17, 0.085) - o, Vector3(0.0, 0.0, -0.625))
