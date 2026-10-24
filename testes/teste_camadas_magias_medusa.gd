extends SceneTree
## Compara pixels do corpo com e sem cada magia, usando o renderizador real.
var falhas := 0

func _initialize() -> void:
	rodar.call_deferred()

func capturar(vp: SubViewport) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return vp.get_texture().get_image()

func rodar() -> void:
	if DisplayServer.get_name() == "headless" or not OS.get_user_data_dir().contains("AlgoLand testes"):
		push_error("Use renderização gráfica e save isolado.")
		quit(1)
		return
	var vp := SubViewport.new()
	vp.size = Vector2i(480, 480)
	vp.transparent_bg = true
	vp.world_2d = World2D.new()
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var medusa: Node2D = load("res://cenas/inimigos/medusa.tscn").instantiate()
	medusa.position = Vector2(240, 280)
	vp.add_child(medusa)
	medusa.set_physics_process(false)
	var pasta := "res://arte/previas/inimigos/medusa/camadas_magias/"
	var salvar := "--capturar" in OS.get_cmdline_user_args()
	if salvar:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(pasta))
	var direcao := 0
	for rumo in [Vector2.DOWN, Vector2.UP, Vector2.RIGHT, Vector2.LEFT]:
		for tipo in ["garras", "cauda", "bote", "olhar", "ruina"]:
			medusa._sequencia.clear()
			medusa._recuperar()
			medusa.estado = medusa.Estado.LIVRE
			medusa.iniciar_ataque(tipo, medusa.global_position + rumo * (155 if tipo == "ruina" else 45))
			medusa._aviso.hide()
			medusa._rotulo_exposta.hide()
			if is_instance_valid(medusa._rotulo_ruina):
				medusa._rotulo_ruina.hide()
			for fase in (2 if tipo == "ruina" else 1):
				medusa._tempo = 0.4 if fase == 0 else 1.5
				if tipo == "ruina":
					medusa._animar_invocacao()
				else:
					medusa.estado = medusa.Estado.ATACANDO
					medusa._tempo = float(medusa.DURACOES[tipo]) * 0.4
				medusa._tocar("olhar" if tipo == "ruina" else tipo, 3.6)
				medusa._efeito.frame = 2 if tipo != "ruina" else 0
				medusa._efeito.hide()
				if is_instance_valid(medusa._canal):
					medusa._canal.hide()
				var corpo := await capturar(vp)
				medusa._efeito.show()
				if is_instance_valid(medusa._canal):
					medusa._canal.show()
				var magia := await capturar(vp)
				if salvar:
					magia.save_png(pasta + "%d_%s_%d.png" % [direcao, tipo, fase])
				var iguais := true
				var efeito_visivel := false
				for y in vp.size.y:
					for x in vp.size.x:
						var antes := corpo.get_pixel(x, y)
						var depois := magia.get_pixel(x, y)
						if antes.a >= 0.99:
							iguais = iguais and antes.to_rgba32() == depois.to_rgba32()
						elif antes.to_rgba32() != depois.to_rgba32():
							efeito_visivel = true
				var certo := iguais and efeito_visivel
				print("OK " if certo else "FALHA ", tipo, " ", rumo, " fase ", fase, ": corpo preservado=", iguais, "; efeito visível=", efeito_visivel)
				if not certo:
					falhas += 1
		direcao += 1
	medusa.queue_free()
	await process_frame
	vp.queue_free()
	await process_frame
	print("Falhas: ", falhas)
	quit(1 if falhas else 0)
