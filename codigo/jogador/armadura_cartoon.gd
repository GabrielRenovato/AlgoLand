extends Node2D
## Quatro camadas independentes, sincronizadas com o atlas e quadro do corpo.
const RAIZ := "res://assets/personagens/raven_cartoon/armaduras/cavaleiro_aco/"
const PECAS := ["elmo","peitoral","luvas","botas"]
const SHADER := "shader_type canvas_item;\nuniform sampler2D cobertura : filter_nearest, repeat_disable;\nuniform vec4 pecas;\nvoid fragment(){ int g=int(round(texture(cobertura,UV).r*4.0)); if((g==1&&pecas.x>0.5)||(g==2&&pecas.y>0.5)||(g==3&&pecas.z>0.5)||(g==4&&pecas.w>0.5)){COLOR.a=0.0;} }"
var corpo: AnimatedSprite2D
var mascara := 0
var camadas: Array[Sprite2D] = []
var rosto: Sprite2D
var _material: ShaderMaterial
var _material_original: Material
var _cache := {}
var _chave := ""

func configurar(ator: AnimatedSprite2D, pecas: int = 15) -> void:
	corpo = ator
	name = "ArmaduraCartoon"
	_material_original = corpo.material
	_material = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = SHADER
	_material.shader = shader
	rosto = Sprite2D.new()
	rosto.name = "RostoOriginal"
	rosto.centered = false
	rosto.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(rosto)
	for peca in PECAS:
		var camada := Sprite2D.new()
		camada.name = peca.capitalize()
		camada.centered = false
		camada.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(camada)
		camadas.append(camada)
	mascara = pecas & 15
	atualizar()

func definir_pecas(pecas: int) -> void:
	mascara = pecas & 15
	_chave = ""
	atualizar()

func _textura(pasta: String, pagina: String) -> Texture2D:
	var caminho := RAIZ+pasta+"/"+pagina+".png"
	if not _cache.has(caminho): _cache[caminho] = load(caminho)
	return _cache[caminho]

func atualizar() -> void:
	if corpo == null: return
	rosto.visible = (mascara & 1) != 0
	rosto.position = corpo.offset
	for i in 4:
		camadas[i].visible = (mascara & (1 << i)) != 0
		camadas[i].position = corpo.offset
	if mascara == 0:
		corpo.material = _material_original
		corpo.remove_meta("luvas_armadura")
		return
	var quadro: AtlasTexture = corpo.sprite_frames.get_frame_texture(corpo.animation,corpo.frame)
	var origem := quadro.atlas.resource_path.get_file().get_basename()
	var pagina := origem.trim_suffix("_sem_arma").trim_suffix("_4")
	if origem == "parado_quatro_direcoes": pagina = "repouso"
	var chave := pagina+":"+str(quadro.region)+":"+str(mascara)
	if chave != _chave:
		_chave = chave
		for i in 4:
			var recorte := AtlasTexture.new()
			recorte.atlas = _textura(PECAS[i],pagina)
			recorte.region = quadro.region
			recorte.filter_clip = true
			camadas[i].texture = recorte
		var face := AtlasTexture.new()
		face.atlas = _textura("rosto",pagina)
		face.region = quadro.region
		face.filter_clip = true
		rosto.texture = face
		_material.set_shader_parameter("cobertura",_textura("cobertura",pagina))
		_material.set_shader_parameter("pecas",Vector4(1 if mascara & 1 else 0,1 if mascara & 2 else 0,1 if mascara & 4 else 0,1 if mascara & 8 else 0))
	corpo.material = _material
	if mascara & 4:
		corpo.set_meta("luvas_armadura",camadas[2].texture)
	else:
		corpo.remove_meta("luvas_armadura")

func _exit_tree() -> void:
	if is_instance_valid(corpo):
		if corpo.material == _material: corpo.material = _material_original
		corpo.remove_meta("luvas_armadura")
