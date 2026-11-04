extends SceneTree
func _initialize() -> void:
	exportar.call_deferred()
func exportar() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/cenario/campanha/mecanismos_3d")
	for tipo in 2:
		var modelo := preload("res://codigo/campanha/modelo_mecanismo_bacia_3d.gd").new()
		modelo.tipo = tipo
		root.add_child(modelo)
		var documento := GLTFDocument.new()
		var estado := GLTFState.new()
		var erro := documento.append_from_scene(modelo,estado)
		if erro == OK:
			erro = documento.write_to_filesystem(estado,"res://assets/cenario/campanha/mecanismos_3d/%s.glb" % ("comporta" if tipo == 0 else "registro"))
		print("Exportação ",tipo,": ",error_string(erro))
		modelo.free()
	quit()
