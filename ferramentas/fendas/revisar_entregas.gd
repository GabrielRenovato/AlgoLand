extends SceneTree
func _initialize() -> void: rodar.call_deferred()
func quadros(n := 8) -> void:
	for i in n:
		await physics_frame
		await process_frame
func foto(caminho: String) -> void:
	await quadros()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(caminho)
func rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name","")).begins_with("AlgoLand testes") or DisplayServer.get_name()=="headless":
		quit(1)
		return
	await process_frame
	root.mode=Window.MODE_WINDOWED
	await quadros()
	load("res://codigo/ui/mini_tutorial.gd")._fechado=1
	root.get_node("Introducao").pular_prologo()
	root.get_node("Progresso").iniciar_partida()
	root.get_node("Transicao").retornando=true
	root.get_node("Transicao").estado={"onda_atual":3}
	root.get_node("Transicao").iniciar_onda_ao_chegar=false
	change_scene_to_file("res://cenas/fendas/andar_03.tscn")
	await quadros(20)
	root.get_node("Transicao").retornando=false
	var jogador: Node2D=current_scene.get_node("Jogador")
	jogador.set_physics_process(false)
	current_scene.get_node("enemySpawner/GerenciadorOndas").set_physics_process(false)
	var medusa: Node2D=load("res://cenas/inimigos/medusa.tscn").instantiate()
	medusa.position=jogador.position+Vector2(110,10)
	current_scene.add_child(medusa)
	medusa.set_physics_process(false)
	medusa._definir_linha(Vector2.LEFT)
	var camera:=Camera2D.new()
	current_scene.add_child(camera)
	camera.global_position=jogador.global_position+Vector2(30,-15)
	camera.make_current()
	await create_timer(3).timeout
	var pasta:="res://arte/previas/entregas/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(pasta))
	medusa.iniciar_ataque("ruina",jogador.global_position)
	medusa._physics_process(.9)
	await foto(pasta+"medusa_especial.png")
	medusa._physics_process(1.6)
	medusa._tempo=.24
	medusa._efeito.material.set_shader_parameter("impacto",.37)
	await foto(pasta+"medusa_impacto.png")
	medusa._recuperar()
	change_scene_to_file("res://cenas/cidade/forja.tscn")
	await quadros(24)
	root.size=Vector2i(1152,648)
	root.content_scale_size=Vector2i(576,324)
	var inv: Node=root.get_node("InventarioJogador")
	inv.receber_materiais({"madeira":20,"pedra":20,"ferro":20,"fibra":10})
	var ui: Node=get_first_node_in_group("interface")
	ui._abrir_tela("forja")
	var tela: Control=ui._telas["forja"]
	tela._mudar_categoria(true)
	await foto(pasta+"ferramentas_bigorna_pc.png")
	root.size=Vector2i(780,1080)
	root.content_scale_size=Vector2i(390,540)
	await quadros(15)
	tela._mostrar_detalhes(true)
	await foto(pasta+"ferramentas_bigorna_mobile.png")
	current_scene.queue_free()
	current_scene=null
	await quadros()
	quit()
