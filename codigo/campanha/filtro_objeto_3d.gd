extends RefCounted
## Pós-processo compartilhado: a grade de 2 px é definida no mundo, após o render 3D.
static func aplicar(sprite: Sprite2D) -> void:
	var material := ShaderMaterial.new()
	material.shader = preload("res://codigo/campanha/filtro_pixel_natureza.gdshader")
	material.set_shader_parameter("passo",2.0)
	material.set_shader_parameter("suavizacao",0.0)
	sprite.material = material
	atualizar(sprite)

static func atualizar(sprite: Sprite2D) -> void:
	if not is_instance_valid(sprite) or sprite.material == null: return
	var tamanho := sprite.texture.get_size()
	var inicio := sprite.offset-tamanho*0.5 if sprite.centered else sprite.offset
	sprite.material.set_shader_parameter("origem",sprite.to_global(inicio))
	sprite.material.set_shader_parameter("tamanho_logico",tamanho*sprite.global_scale.abs())
