extends Node

## Preserva os nós usados por sono, café e assentos. A cama continua em faixas
## com profundidades independentes, inclusive quando a cena é regenerada.
const Biblioteca := preload("res://codigo/cidade/interiores_detalhados.gd")
const Detalhe := preload("res://codigo/cidade/detalhe_ambiente.gd")
var _faixas: Array[AtlasTexture] = []
var _cama: Node2D
var _estacao := -1

func _ready() -> void:
	instalar.call_deferred()

func instalar() -> void:
	var objetos := get_parent().get_parent().get_node("Objetos3D")
	for nome in ["Estante", "Bau", "CadeiraE", "CadeiraD", "Mesa", "Mesa/Cafe_E", "Mesa/Cafe_D"]:
		var original: Sprite2D = objetos.get_node(nome)
		if "/Cafe_" in nome:
			original.position.y = -11
			original.z_index = 1
		var id: String = "cafe" if "/Cafe_" in nome else ("cadeira" if nome.begins_with("Cadeira") else nome.to_lower())
		var item := Biblioteca.dados("casa_inicial/" + id)
		var imagem := Sprite2D.new()
		imagem.name = "ImagemDetalhada"
		imagem.centered = original.centered
		imagem.flip_h = original.flip_h
		imagem.texture = load(item.texturas[0])
		imagem.offset = original.offset
		# self_modulate só esconde o atlas antigo: filhos como as xícaras e
		# o vapor continuam em coordenadas lógicas e conservam suas funções.
		original.self_modulate.a = 0.0
		original.add_child(imagem)
		Detalhe.instalar(original, imagem, item)
		original.set_meta("interior_detalhado", true)
	_cama = objetos.get_node("CamaDormindo")
	for filho in objetos.get_children():
		if not filho is Sprite2D or not str(filho.name).begins_with("Cama_f"):
			continue
		var antigo: AtlasTexture = filho.texture
		var parte := AtlasTexture.new()
		parte.region = Rect2(0, (antigo.region.position.y - 6) * 4, 128, antigo.region.size.y * 4)
		_faixas.append(parte)
		var imagem := Sprite2D.new()
		imagem.name = "FaixaDetalhada"
		imagem.texture = parte
		imagem.centered = false
		imagem.offset = filho.offset * 4
		imagem.scale = Vector2(0.25, 0.25)
		imagem.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		filho.self_modulate.a = 0.0
		filho.add_child(imagem)
		filho.set_meta("interior_detalhado", true)
	_atualizar()

func _process(_delta: float) -> void:
	if _cama != null:
		_atualizar()

func _atualizar() -> void:
	var atual := Biblioteca.estacao(self)
	if atual == _estacao:
		return
	_estacao = atual
	var item := Biblioteca.dados("casa_inicial/cama")
	var textura: Texture2D = load(item.texturas[atual])
	for parte in _faixas:
		parte.atlas = textura
	_cama.folha = textura
	_cama.regiao = Rect2(0, 0, 32, 58)
	_cama.resolucao = 4.0
