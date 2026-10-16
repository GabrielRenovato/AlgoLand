extends Sprite2D

## Cabelo colorido e cartola são compostos na mesma folha, acima da roupa.
## A animação controla a pose da roupa; esta camada acompanha essa pose.
var cabelo: Sprite2D
var roupa: Sprite2D

func _enter_tree() -> void:
	RenderingServer.frame_pre_draw.connect(sincronizar)

func _exit_tree() -> void:
	RenderingServer.frame_pre_draw.disconnect(sincronizar)

func sincronizar() -> void:
	if not is_instance_valid(cabelo) or not is_instance_valid(roupa):
		hide()
		return
	visible = cabelo.visible and roupa.visible
	# A cabeça composta não herda o quadro divergente de cabelo em idle_up.
	transform = roupa.transform
	if texture != null:
		scale = roupa.scale * (float(roupa.texture.get_width()) / texture.get_width())
	hframes = roupa.hframes
	vframes = roupa.vframes
	frame = roupa.frame
	flip_h = roupa.flip_h
	flip_v = roupa.flip_v
	centered = roupa.centered
	offset = roupa.offset
	z_index = maxi(cabelo.z_index, roupa.z_index) + 1
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
