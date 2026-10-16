extends Node2D

## Máscaras próprias desenhadas no PixelLab, sobre o chão. A altura do sol muda a direção e o comprimento;
## o contato permanece junto à base e as sombras solares recolhem à noite ou sob tempo fechado.
const SILHUETA := preload("res://codigo/cidade/sombra_cidade.gdshader")
const RAIZ := "res://assets/cenario/cidade/sombras/"
const COR := Color(0.14, 0.17, 0.24, 1.0)
static var _material: ShaderMaterial
var _imagem: Sprite2D
var _contato_base: CanvasItem
var _largura := 1.0
var _altura := 1.0
var _tamanho_mascara := Vector2.ONE
var _iluminacao: Node
var _clima: Node

static func _material_mascara() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = SILHUETA
	return _material

static func projetar(pai: Node2D, chave: String, largura: float, altura: float) -> Node2D:
	var sombra := new()
	sombra.name = "SombraChao"
	sombra.z_as_relative = false
	sombra.z_index = -980
	sombra._largura = largura
	sombra._altura = altura
	var textura: Texture2D = load(RAIZ + chave + ".png")
	if textura == null:
		push_error("Máscara de sombra ausente: " + chave)
		sombra.free()
		return null
	sombra._tamanho_mascara = textura.get_size()
	var imagem := Sprite2D.new()
	imagem.name = "Projecao"
	imagem.texture = textura
	imagem.centered = false
	imagem.offset = -Vector2(textura.get_width() * 0.5, textura.get_height())
	imagem.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	imagem.material = _material_mascara()
	imagem.modulate = Color(COR, 0.0)
	sombra._imagem = imagem
	sombra.add_child(imagem)
	# O contato usa a mesma máscara artística, comprimida junto à fundação, sem elipse sob a casa inteira.
	var contato := imagem.duplicate() as Sprite2D
	contato.name = "Contato"
	contato.scale = Vector2(largura / textura.get_width(), minf(4.0, altura * 0.10) / textura.get_height())
	contato.position = Vector2(0, 2)
	contato.modulate = Color(COR, 0.10)
	sombra._contato_base = contato
	sombra.add_child(contato)
	pai.add_child(sombra)
	sombra._process(0.0)
	return sombra

## Sombra curta dos pés dos personagens; não é uma sombra solar de cenário.
static func contato(pai: Node2D, largura: float, altura: float, posicao: Vector2) -> Node2D:
	var sombra := new()
	sombra.name = "SombraChao"
	sombra.z_as_relative = false
	sombra.z_index = -979
	var contato := Polygon2D.new()
	contato.name = "Contato"
	var pontos := PackedVector2Array()
	for i in 16:
		var angulo := i * TAU / 16.0
		pontos.append((posicao + Vector2(cos(angulo) * largura * 0.5, sin(angulo) * altura)).round())
	contato.polygon = pontos
	contato.color = Color(COR, 0.14)
	sombra.add_child(contato)
	# A oclusão dos pés é estável e não precisa de atualização por quadro.
	sombra.set_process(false)
	pai.add_child(sombra)
	return sombra

func _process(_delta: float) -> void:
	if _imagem == null:
		return
	if not is_instance_valid(_iluminacao):
		_iluminacao = get_tree().get_first_node_in_group("iluminacao")
	if not is_instance_valid(_clima):
		_clima = get_tree().get_first_node_in_group("clima")
	if _iluminacao == null:
		_imagem.modulate.a = 0.0
		return
	_atualizar_sol(_iluminacao.hora)

func _atualizar_sol(hora: float) -> void:
	# O sol nasce à direita (leste) e se põe à esquerda (oeste); a sombra aponta para o lado oposto.
	var arco := clampf((hora - 6.0) / 12.0, 0.0, 1.0) * PI
	var direcao := Vector2(-cos(arco), 0.48).normalized()
	var comprimento := _altura * lerpf(0.65, 0.22, sin(arco))
	var dia := smoothstep(5.5, 7.0, hora) * (1.0 - smoothstep(17.0, 18.5, hora))
	var tempo_aberto := 1.0
	if is_instance_valid(_clima):
		# Ordem do enum Estado de clima.gd: limpo, nublado, chuvas, tempestade, neves.
		tempo_aberto = [1.0, 0.55, 0.35, 0.20, 0.10, 0.65, 0.35][clampi(_clima.clima_atual, 0, 6)]
	# Só a máscara sobre o chão se transforma; o sprite do objeto mantém sua posição e sua forma.
	_imagem.transform = Transform2D(Vector2(_largura / _tamanho_mascara.x, 0),
		-direcao * comprimento / _tamanho_mascara.y, Vector2(0, 1))
	_imagem.modulate.a = 0.13 * dia * tempo_aberto
	_contato_base.modulate.a = lerpf(0.05, 0.07, dia)
