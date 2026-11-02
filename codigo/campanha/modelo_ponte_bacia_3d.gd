extends Node3D
## Malha reutilizável da ponte de madeira da Bacia, renderizada em baixa resolução.
var largura := 4.0
var comprimento := 10.0
var estacao := 0
var _materiais: Dictionary = {}
var _piso: Node3D
var _corrimaos: Node3D
var _apoios: Node3D

const PALETAS := {
	"tabua_a": [Color("a57445"), Color("ad7946"), Color("966744"), Color("a6a08f")],
	"tabua_b": [Color("bd8b54"), Color("c18e52"), Color("ad7848"), Color("b9b3a2")],
	"pincel_luz": [Color("cb9258"), Color("d09a5c"), Color("bd8050"), Color("e4e4d8")],
	"pincel_sombra": [Color("805535"), Color("855a38"), Color("764b34"), Color("8e9691")],
	"prego": [Color("5b4433"), Color("604632"), Color("513b31"), Color("737c7b")],
	"viga": [Color("765035"), Color("7a5335"), Color("654632"), Color("817a6a")],
	"travessa": [Color("875b38"), Color("8b5d39"), Color("754b33"), Color("898272")],
}

func _ready() -> void:
	name = "MalhaPonteBacia"
	_piso = _novo_grupo("CamadaPiso")
	_corrimaos = _novo_grupo("CamadaCorrimaos")
	_apoios = _novo_grupo("CamadaApoios")
	_montar()
	_agrupar_malhas(_piso)
	_agrupar_malhas(_corrimaos)
	_agrupar_malhas(_apoios)
	# O piso e os apoios ficam sob o personagem; os corrimãos têm camada própria.
	_definir_camada_malhas(_piso, 1)
	_definir_camada_malhas(_corrimaos, 2)
	_definir_camada_malhas(_apoios, 1)
	definir_estacao(estacao)

func _novo_grupo(nome_grupo: String) -> Node3D:
	var grupo := Node3D.new()
	grupo.name = nome_grupo
	add_child(grupo)
	return grupo

func _definir_camada_malhas(pai: Node3D, camada: int) -> void:
	for parte in pai.get_children():
		if parte is MeshInstance3D:
			var malha := parte as MeshInstance3D
			malha.layers = camada
			malha.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func definir_camadas_visiveis(mostrar_piso: bool, mostrar_corrimaos: bool, mostrar_apoios: bool) -> void:
	if is_instance_valid(_piso): _piso.visible = mostrar_piso
	if is_instance_valid(_corrimaos): _corrimaos.visible = mostrar_corrimaos
	if is_instance_valid(_apoios): _apoios.visible = mostrar_apoios

func _material(tipo: String) -> StandardMaterial3D:
	if not _materiais.has(tipo):
		var material := StandardMaterial3D.new()
		material.resource_name = "Ponte_" + tipo
		material.roughness = 0.92
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		if tipo in ["viga", "travessa", "pincel_luz", "pincel_sombra", "prego"]:
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_materiais[tipo] = material
	_material_e_cor(tipo)
	return _materiais[tipo]

func _material_e_cor(tipo: String) -> void:
	var material: StandardMaterial3D = _materiais[tipo]
	material.albedo_color = PALETAS[tipo][0]

func _caixa(nome: String, posicao: Vector3, tamanho: Vector3, tipo: String, pai: Node3D = self) -> void:
	var malha := BoxMesh.new()
	malha.size = tamanho
	var parte := MeshInstance3D.new()
	parte.name = nome
	parte.mesh = malha
	parte.material_override = _material(tipo)
	parte.position = posicao
	pai.add_child(parte)

func _barra_diagonal(nome: String, inicio: Vector3, fim: Vector3, pai: Node3D) -> void:
	var diferenca := fim - inicio
	var malha := BoxMesh.new()
	malha.size = Vector3(0.20, diferenca.length(), 0.20)
	var parte := MeshInstance3D.new()
	parte.name = nome
	parte.mesh = malha
	parte.material_override = _material("travessa")
	parte.position = (inicio + fim) * 0.5
	parte.rotation.x = atan2(diferenca.z, diferenca.y)
	pai.add_child(parte)

func _montar() -> void:
	# A base dá espessura real; tábuas e marcas em blocos formam a pintura pixel art.
	_caixa("BaseDoTabuleiro", Vector3(0, 0.48, 0), Vector3(largura - 0.12, 0.16, comprimento), "tabua_a", _piso)
	_montar_piso_pixelado(_piso)
	# Vigas elevadas deixam o tabuleiro claramente tridimensional na escala real.
	for lado in [-1.0, 1.0]:
		var x: float = lado * (largura * 0.5 - 0.36)
		_caixa("VigaLateralSuperior", Vector3(x, 2.35, 0), Vector3(0.18, 0.18, comprimento), "viga", _corrimaos)
		var montantes := [-comprimento * 0.5 + 0.20, 0.0, comprimento * 0.5 - 0.20]
		for z in montantes:
			_caixa("PosteLateral", Vector3(x, 1.49, z), Vector3(0.18, 1.86, 0.18), "viga", _corrimaos)
		# Travessas diagonais fecham os vãos dos dois lados, como na ponte de referência.
		for i in montantes.size() - 1:
			var z0: float = montantes[i]
			var z1: float = montantes[i + 1]
			_barra_diagonal("DiagonalSubindo", Vector3(x, 0.62, z0 + 0.10), Vector3(x, 2.28, z1 - 0.10), _corrimaos)
			_barra_diagonal("DiagonalDescendo", Vector3(x, 2.28, z0 + 0.10), Vector3(x, 0.62, z1 - 0.10), _corrimaos)
	# Travessas e pés curtos sustentam o tabuleiro sobre os canais.
	for i in 3:
		var z := -comprimento * 0.5 + comprimento * (float(i) + 0.5) / 3.0
		_caixa("Travessa", Vector3(0, 0.22, z), Vector3(largura + 0.12, 0.22, 0.28), "travessa", _apoios)
		for lado in [-1.0, 1.0]:
			_caixa("Pe", Vector3(lado * (largura * 0.5 - 0.24), -0.10, z), Vector3(0.24, 0.58, 0.24), "viga", _apoios)
	# Cabeceiras niveladas com as margens, sem ressalto no caminho.
	for extremidade in [-1.0, 1.0]:
		_caixa("Cabeceira", Vector3(0, 0.48, extremidade * (comprimento * 0.5 - 0.08)), Vector3(largura, 0.18, 0.16), "travessa", _piso)

func _montar_piso_pixelado(pai: Node3D) -> void:
	# A imagem 160x64 já representa dez tábuas transversais em pixels nativos.
	# O UV gira a pintura sobre o piso sem deformar os pixels nem repetir faixas.
	var malha := ArrayMesh.new()
	var dados: Array = []
	dados.resize(Mesh.ARRAY_MAX)
	dados[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3(-largura * 0.5 + 0.10, 0.62, -comprimento * 0.5 + 0.08),
		Vector3(largura * 0.5 - 0.10, 0.62, -comprimento * 0.5 + 0.08),
		Vector3(largura * 0.5 - 0.10, 0.62, comprimento * 0.5 - 0.08),
		Vector3(-largura * 0.5 + 0.10, 0.62, comprimento * 0.5 - 0.08),
	])
	dados[Mesh.ARRAY_TEX_UV] = PackedVector2Array([
		Vector2(0.0, 1.0), Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0),
	])
	dados[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 2, 1, 0, 3, 2])
	malha.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, dados)
	var textura_piso := load("res://assets/cenario/campanha/bacia_moinho/pontes_3d/piso_pixel_art.png") as Texture2D
	var tinta := StandardMaterial3D.new()
	tinta.resource_name = "Ponte_PinturaPixelArt"
	tinta.albedo_texture = textura_piso
	tinta.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	tinta.cull_mode = BaseMaterial3D.CULL_DISABLED
	tinta.roughness = 1.0
	_materiais["PinturaPixelArt"] = tinta
	parte_pintada(malha, tinta, pai)

func parte_pintada(malha: ArrayMesh, tinta: StandardMaterial3D, pai: Node3D) -> void:
	var parte := MeshInstance3D.new()
	parte.name = "PinturaPixelArtDoTabuleiro"
	parte.mesh = malha
	parte.material_override = tinta
	parte.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parte.position.y = 0.0
	pai.add_child(parte)

func _agrupar_malhas(pai: Node3D) -> void:
	var ferramentas: Dictionary = {}
	for parte in pai.get_children():
		if not parte is MeshInstance3D:
			continue
		var malha := parte as MeshInstance3D
		var material := malha.material_override as StandardMaterial3D
		var chave := material.resource_name
		if not ferramentas.has(chave):
			var ferramenta := SurfaceTool.new()
			ferramenta.begin(Mesh.PRIMITIVE_TRIANGLES)
			ferramenta.set_material(material)
			ferramentas[chave] = ferramenta
		ferramentas[chave].append_from(malha.mesh, 0, malha.transform)
		pai.remove_child(malha)
		malha.free()
	for chave in ferramentas:
		var parte := MeshInstance3D.new()
		parte.name = "Malha_" + chave
		parte.mesh = ferramentas[chave].commit()
		parte.material_override = _materiais[chave.trim_prefix("Ponte_")]
		pai.add_child(parte)

func definir_estacao(indice: int) -> void:
	# A madeira desta ponte é pintada à mão e permanece igual nas quatro estações.
	estacao = clampi(indice, 0, 3)
	for tipo in PALETAS:
		_material(tipo)
		_material_e_cor(tipo)
