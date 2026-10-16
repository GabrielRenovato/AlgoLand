extends RefCounted

const Profundidade := preload("res://codigo/globais/profundidade.gd")
const PASTA := "res://assets/cenario/praia/adornos/"

static func montar(praia: Node2D, itens: Array) -> void:
	var decoracao := Node2D.new()
	decoracao.name = "DecoracaoPraia"
	decoracao.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	praia.add_child(decoracao)
	for item: Array in itens:
		var tipo: String = item[0]
		var base := Vector2(item[1], item[2])
		var textura: Texture2D = load(PASTA + tipo + ".png")
		var objeto := Node2D.new()
		objeto.name = "%s_%d_%d" % [tipo, base.x, base.y]
		objeto.position = base
		objeto.z_index = Profundidade.z_de(base.y)
		decoracao.add_child(objeto)
		var sprite := Sprite2D.new()
		sprite.name = "Imagem"
		sprite.texture = textura
		sprite.centered = false
		sprite.offset = Vector2(-textura.get_width() / 2.0, -textura.get_height())
		objeto.add_child(sprite)
		if tipo.begins_with("coqueiro") or tipo == "pedras":
			var sombra := Sprite2D.new()
			sombra.name = "Sombra"
			sombra.texture = textura
			sombra.centered = false
			sombra.offset = sprite.offset
			sombra.scale = Vector2(0.9, 0.30)
			sombra.skew = -0.55
			sombra.position = Vector2(14, 0)
			sombra.z_as_relative = false
			sombra.z_index = -998
			var material := ShaderMaterial.new()
			material.shader = preload("res://codigo/pesca/sombra_adornos.gdshader")
			sombra.material = material
			objeto.add_child(sombra)
			var corpo := StaticBody2D.new()
			corpo.name = "Tronco" if tipo.begins_with("coqueiro") else "Rochas"
			corpo.collision_layer = 64
			corpo.collision_mask = 0
			objeto.add_child(corpo)
			var forma := CollisionShape2D.new()
			var caixa := RectangleShape2D.new()
			caixa.size = Vector2(12, 8) if tipo.begins_with("coqueiro") else Vector2(25, 12)
			forma.shape = caixa
			# A origem da imagem inclui a copa e a sombra; o tronco inclinado não fica no centro.
			forma.position = Vector2(6, -4) if tipo == "coqueiro_a" else (Vector2(-18, -4) if tipo == "coqueiro_b" else Vector2(0, -4))
			corpo.add_child(forma)
		else:
			# Conchas, capim e madeira seca são detalhes baixos e não travam a caminhada.
			objeto.z_index = -997
