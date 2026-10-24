extends Node2D
## Fole de couro e madeira pintados, ligado à entrada de ar da fornalha.
const Biblioteca := preload("res://codigo/cidade/interiores_detalhados.gd")
const Profundidade := preload("res://codigo/globais/profundidade.gd")
const ESTACOES := ["primavera","verao","outono","inverno"]
var pressao := 1.0
var _imagem: Sprite2D
var _material: ShaderMaterial
var _estacao := -1
var _bocal: Sprite2D
func _ready() -> void:
	position = Vector2(360,36)
	z_as_relative = false
	z_index = Profundidade.z_de(65)
	_imagem = Sprite2D.new()
	_imagem.name = "Imagem"
	_imagem.centered = false
	_imagem.scale = Vector2(50.0/192.0,1.0/4.0)
	_imagem.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_material = ShaderMaterial.new()
	_material.shader = preload("res://codigo/cidade/fole_ferreiro.gdshader")
	_imagem.material = _material
	add_child(_imagem)
	var corpo := StaticBody2D.new()
	corpo.collision_layer = 64
	corpo.collision_mask = 0
	add_child(corpo)
	var forma := CollisionShape2D.new()
	var retangulo := RectangleShape2D.new()
	retangulo.size = Vector2(25,8)
	forma.shape = retangulo
	forma.position = Vector2(24.5,25)
	corpo.add_child(forma)
	# A metade dianteira do bocal oclui a ponta do bico já encaixada.
	_bocal = Sprite2D.new()
	_bocal.name = "BocalFrente"
	_bocal.centered = false
	_bocal.scale = Vector2.ONE/4.0
	_bocal.position = Vector2(406.5,48.5)-position
	_bocal.z_as_relative = false
	_bocal.z_index = Profundidade.z_de(65)+2
	_bocal.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_bocal)
	_atualizar()
func _process(_delta: float) -> void:
	_atualizar()
func _atualizar() -> void:
	var atual := Biblioteca.estacao(self)
	if atual != _estacao:
		_estacao = atual
		var frente := AtlasTexture.new()
		frente.atlas = get_parent().get_node("Fornalha/Imagem").texture
		frente.region = Rect2(10,194,18,28)
		_bocal.texture = frente
		_imagem.texture = load("res://assets/cenario/cidade/interiores_detalhados/fole/"+ESTACOES[atual]+".png")
	_material.set_shader_parameter("pressao",pressao)
func ponto_mao() -> Vector2:
	return global_position + Vector2(2,2 + (4.0 + pressao * 7.0) * (1.0-2.0/35.0))
