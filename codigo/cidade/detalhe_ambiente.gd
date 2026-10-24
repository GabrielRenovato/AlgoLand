extends Node

## Quadros locais com âncora fixa e estação compartilhada com o terreno/F3.
## Um armário continua imóvel; apenas os quadros de folhas, chamas ou enfeites mudam.
var imagem: Sprite2D
var dados: Dictionary
var estacao := -1
var tempo := 0.0
var vigor := 0.06
var impulso := 0.0
var _texturas: Array[Texture2D] = []

static func instalar(pai: Node2D, sprite: Sprite2D, item: Dictionary) -> void:
	if sprite.name == "Fachada" and sprite.texture != null:
		var detalhada: Dictionary = preload("res://codigo/cidade/fachadas_detalhadas.gd").dados(sprite.texture.resource_path.get_file().get_basename())
		if not detalhada.is_empty(): item = detalhada
	if not item.has("texturas"):
		return
	var detalhe := new()
	detalhe.name = "DetalheAmbiente"
	detalhe.imagem = sprite
	detalhe.dados = item
	pai.add_child(detalhe)

func _ready() -> void:
	var resolucao := float(dados.get("resolucao",1.0))
	if resolucao>1.0:
		imagem.scale /= resolucao
		imagem.offset *= resolucao
		imagem.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for caminho in dados["texturas"]:
		_texturas.append(load(caminho))
	imagem.hframes = int(dados.get("quadros", 1))
	tempo = fposmod(get_parent().position.x * 0.17 + get_parent().position.y * 0.13, 4.0)
	if dados.get("chamas_fornalha",false):
		var chamas := ShaderMaterial.new()
		chamas.shader = preload("res://codigo/cidade/chamas_fornalha.gdshader")
		if dados.has("boca_fogo"):
			var boca: Array = dados["boca_fogo"]
			chamas.set_shader_parameter("boca",Vector4(boca[0],boca[1],boca[2],boca[3]))
		imagem.material = chamas
	_atualizar_estacao()

func _atualizar_estacao() -> void:
	var atual := preload("res://codigo/cidade/interiores_detalhados.gd").estacao(self)
	if atual != estacao:
		estacao = atual
		imagem.texture = _texturas[estacao]
		if dados.has("texturas_fracas"):
			imagem.material.set_shader_parameter("fria",load(dados["texturas_fracas"][estacao]))
		for filho in get_parent().get_children():
			if filho is PointLight2D and dados.get("calor_sazonal", false):
				filho.visible = estacao in [2, 3]
			if filho is CPUParticles2D and dados.get("calor_sazonal", false):
				filho.emitting = estacao in [2, 3]

func receber_ar(quantidade: float) -> void:
	vigor = minf(1.0,vigor+quantidade*0.55)
	impulso = minf(1.0,impulso+quantidade*3.0)

func _process(delta: float) -> void:
	_atualizar_estacao()
	if dados.get("chamas_fornalha",false):
		tempo += delta
		vigor = move_toward(vigor,0.06,delta*0.012)
		impulso = move_toward(impulso,0.0,delta*1.8)
		imagem.material.set_shader_parameter("instante",tempo)
		imagem.material.set_shader_parameter("ar",vigor)
		for nome in ["FumacaChamine","FumacaBraseiro"]:
			var fumaca: CPUParticles2D = get_parent().get_node_or_null(nome)
			if fumaca != null:
				fumaca.emitting = vigor > 0.1
				fumaca.modulate.a = clampf(vigor*0.65+impulso*0.6,0.0,1.0)
				fumaca.speed_scale = 0.65+vigor*0.5+impulso*0.6
		for filho in get_parent().get_children():
			if filho is PointLight2D: filho.energy = 0.15+vigor*0.75+impulso*0.15
	var fps := float(dados.get("fps", 0))
	if fps > 0 and get_parent().is_visible_in_tree():
		tempo += delta
		imagem.frame = int(tempo * fps) % imagem.hframes
