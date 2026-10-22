extends Node

## Quadros locais com âncora fixa e estação compartilhada com o terreno/F3.
## Um armário continua imóvel; apenas os quadros de folhas, chamas ou enfeites mudam.
var imagem: Sprite2D
var dados: Dictionary
var estacao := -1
var tempo := 0.0
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
	_atualizar_estacao()

func _atualizar_estacao() -> void:
	var atual := preload("res://codigo/cidade/interiores_detalhados.gd").estacao(self)
	if atual != estacao:
		estacao = atual
		imagem.texture = _texturas[estacao]
		for filho in get_parent().get_children():
			if filho is PointLight2D and dados.get("calor_sazonal", false):
				filho.visible = estacao in [2, 3]
			if filho is CPUParticles2D and dados.get("calor_sazonal", false):
				filho.emitting = estacao in [2, 3]

func _process(delta: float) -> void:
	_atualizar_estacao()
	var fps := float(dados.get("fps", 0))
	if fps > 0 and get_parent().is_visible_in_tree():
		tempo += delta
		imagem.frame = int(tempo * fps) % imagem.hframes
