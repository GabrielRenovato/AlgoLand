extends SceneTree
## Prévia isolada da técnica; não exporta sobre os sprites ativos.
func _initialize() -> void:
	rodar.call_deferred()

func rodar() -> void:
	var destino := "res://arte/previas/inimigos/goblins_moinho/lanceiro/estudo_rig/"
	DirAccess.make_dir_recursive_absolute(destino)
	root.size = Vector2i(768, 512)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1024, 1024)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var rig = load("res://ferramentas/inimigos/rig_lanceiro_2d.gd").new()
	viewport.add_child(rig)
	rig.position = Vector2(512, 832)
	rig.montar("direita")
	var poses: Array[Image] = []
	for q in 6:
		rig.aplicar_pose("andar", q)
		await process_frame
		await RenderingServer.frame_post_draw
		poses.append(viewport.get_texture().get_image())
	for q in 6:
		poses[q].save_png(destino + "direita-%d.png" % q)
	print("ESTUDO_RIG_DIREITA seis poses")
	quit()
