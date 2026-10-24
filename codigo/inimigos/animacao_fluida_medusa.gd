extends RefCounted
## Interpola o deslocamento das poses existentes sem alterar seus pixels.
const ShaderFluidez := preload("res://recursos/personagens/fluidez_medusa.gdshader")
const PASTA := "res://recursos/personagens/medusa/fluxos/"
var _materiais := {}

func aplicar(sprite: Sprite2D, pagina: String, fracao: float) -> void:
	if not _materiais.has(pagina):
		var material := ShaderMaterial.new()
		material.shader = ShaderFluidez
		for sentido in ["frente", "volta"]:
			var campo: Resource = load(PASTA + pagina + "_" + sentido + ".res")
			var dados: PackedByteArray = campo.vetores if campo != null else PackedByteArray()
			if dados.size() != 480 * 320 * 2:
				push_error("Fluxo de animação inválido: " + pagina + " / " + sentido)
				return
			var imagem := Image.create_from_data(480, 320, false, Image.FORMAT_RG8, dados)
			material.set_shader_parameter("fluxo_" + sentido, ImageTexture.create_from_image(imagem))
		_materiais[pagina] = material
	var material: ShaderMaterial = _materiais[pagina]
	material.set_shader_parameter("celula", Vector2(sprite.frame % 6, sprite.frame / 6))
	material.set_shader_parameter("progresso", fracao)
	sprite.material = material
