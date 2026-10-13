extends SceneTree

## Captura o menu real do F3 sem carregar a arena ou gravar saves.
func _initialize() -> void:
	_rodar()

func _rodar() -> void:
	await process_frame
	var painel := root.get_node("PainelDebug")
	painel._painel.visible = true
	painel._atualizar_estado()
	painel._ajustar_altura()
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var args := OS.get_cmdline_user_args()
	root.get_texture().get_image().save_png(args[0])
	print("Prévia do menu salva.")
	quit()
