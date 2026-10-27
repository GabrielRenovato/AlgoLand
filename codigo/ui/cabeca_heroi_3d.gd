extends Node2D
## Recorte independente do mesmo rig: a cama nunca muda a pose do jogador real.
var aparencia: Dictionary = {}
var olhos_fechados := false
var previa: Node2D
var rosto: Sprite2D
func _ready() -> void:
	previa = preload("res://codigo/ui/previa_heroi_3d.gd").new()
	previa.aparencia_raven = aparencia
	previa.roupas_3d = preload("res://codigo/dados/visual_ranking.gd").roupas_do_visual(aparencia)
	add_child(previa)
	var heroi = previa.heroi
	heroi._sprite.hide()
	heroi._vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var corpo = heroi._modelo.find_child("CorpoBase",true,false)
	corpo.material_override.set_shader_parameter("olhos_fechados",olhos_fechados)
	heroi._player.speed_scale = 0.0
	heroi._player.seek(0.0,true)
	await RenderingServer.frame_post_draw
	if not is_inside_tree(): return
	var s: Skeleton3D = heroi._esqueleto
	var cabeca: Transform3D = s.global_transform*s.get_bone_global_pose(s.find_bone("DEF-head"))
	var regiao := Rect2()
	var primeiro := true
	for x in [-0.145,0.145]:
		for y in [-0.005,0.29]:
			for z in [-0.14,0.15]:
				var ponto: Vector2 = heroi._camera.unproject_position(cabeca*Vector3(x,y,z))
				if primeiro: regiao=Rect2(ponto,Vector2.ZERO); primeiro=false
				else: regiao=regiao.expand(ponto)
	regiao = regiao.grow(1).intersection(Rect2(Vector2.ZERO,heroi._vp.size))
	var atlas := AtlasTexture.new()
	atlas.atlas = heroi._vp.get_texture()
	atlas.region = regiao
	rosto = Sprite2D.new()
	rosto.name = "Rosto3D"
	rosto.texture = atlas
	rosto.centered = false
	rosto.texture_filter = TEXTURE_FILTER_NEAREST
	rosto.scale = Vector2.ONE*minf(22.0/regiao.size.x,21.0/regiao.size.y)
	rosto.position = Vector2(12.0-regiao.size.x*rosto.scale.x/2.0,1.0)
	add_child(rosto)
