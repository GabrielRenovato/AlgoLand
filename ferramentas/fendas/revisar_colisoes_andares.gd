extends SceneTree

## Revisão real com contornos físicos sobre o cenário, sem tocar na partida.
class Sobreposicao extends Node2D:
	var terreno: Node2D
	func _draw() -> void:
		var contorno: CollisionPolygon2D = terreno.get_node("LimiteArena/Contorno")
		var linha := contorno.polygon.duplicate()
		linha.append(linha[0])
		draw_polyline(linha,Color(1,.5,.2,.9),1.0)
		for forma in terreno.get_node("Obstaculos").get_children():
			if not forma is CollisionPolygon2D: continue
			var cor := Color(.2,1,.8,.35) if forma.has_meta("sprite_colisao") else Color(1,.5,.2,.20)
			draw_colored_polygon(forma.polygon,cor)
			linha = forma.polygon.duplicate()
			linha.append(linha[0])
			draw_polyline(linha,Color(cor,1),.8)

func _initialize() -> void: rodar.call_deferred()
func quadros(n := 4) -> void:
	for i in n:
		await physics_frame
		await process_frame
func rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name","")).begins_with("AlgoLand testes") or DisplayServer.get_name()=="headless":
		quit(1)
		return
	await process_frame
	var pasta := "res://arte/previas/fenda/colisoes/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(pasta))
	var vista := SubViewport.new()
	vista.disable_3d = true
	vista.size = Vector2i(1152,648)
	vista.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vista.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(vista)
	for andar in range(1,12):
		vista.world_2d = World2D.new()
		var terreno: Node2D = load("res://cenas/fendas/terreno_%02d.tscn" % andar).instantiate()
		vista.add_child(terreno)
		var sobre := Sobreposicao.new()
		sobre.terreno = terreno
		sobre.z_index = 1000
		terreno.add_child(sobre)
		var camera := Camera2D.new()
		vista.add_child(camera)
		camera.make_current()
		var dados: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://codigo/fendas/plantas/andar_%02d.json" % andar))
		var limites: Array = dados.limites
		camera.position = Vector2(limites[0]+limites[2]*.5,limites[1]+limites[3]*.5)
		camera.zoom = Vector2.ONE*minf(1152.0/(limites[2]+256),648.0/(limites[3]+256))
		await quadros()
		terreno.get_node("Estacoes").definir_estacao(0,true)
		await quadros()
		await RenderingServer.frame_post_draw
		vista.get_texture().get_image().save_png(pasta+"andar_%02d_geral.png" % andar)
		camera.zoom = Vector2(2,2)
		var posicao: Vector2 = terreno.get_node("Setores").get_child(1).position
		for forma in terreno.get_node("Obstaculos").get_children():
			var nome: String = forma.get_meta("sprite_colisao","")
			if nome.begins_with("Marco") or nome.begins_with("ArbustoMargem"):
				posicao = terreno.get_node("Objetos3D/"+str(forma.get_meta("sprite_colisao"))).position
				break
		camera.position = posicao-Vector2(0,40)
		await quadros()
		for estacao in 4:
			terreno.get_node("Estacoes").definir_estacao(estacao,true)
			await quadros()
			await RenderingServer.frame_post_draw
			vista.get_texture().get_image().save_png(pasta+"andar_%02d_estacao_%d.png" % [andar,estacao])
		print("RENDER COLISOES ",andar," quatro estacoes")
		terreno.queue_free()
		camera.queue_free()
		await quadros()
	vista.queue_free()
	await quadros()
	quit()
