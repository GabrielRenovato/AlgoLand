extends SceneTree
var falhas := 0
func _initialize() -> void: rodar.call_deferred()
func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ",nome)
	if not ok: falhas+=1
func quadros(n := 8) -> void:
	for i in n: await process_frame
func rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name","")).begins_with("AlgoLand testes"):
		quit(1)
		return
	await process_frame
	root.content_scale_size=Vector2i(576,324)
	var papel := PanelContainer.new()
	papel.theme=load("res://recursos/ui/tema_sidebar.tres")
	papel.add_theme_stylebox_override("panel",load("res://codigo/ui/estilo_interface.gd").painel(true,12))
	papel.position=Vector2(16,16)
	papel.size=Vector2(544,292)
	root.add_child(papel)
	var mapa=load("res://codigo/ui/mapa_jornada_arena.gd").new()
	mapa.preparar(3,1)
	papel.add_child(mapa)
	await quadros()
	verificar("ondas 1 a 3 mostram aparencia descoberta",[1,2,3].all(func(onda): return mapa._marcos[onda].find_child("Inimigos",true,false).self_modulate==Color.WHITE))
	verificar("ondas 4 a 10 mostram silhuetas",range(4,11).all(func(onda): return mapa._marcos[onda].find_child("Inimigos",true,false).self_modulate==Color.BLACK))
	var chefe=mapa._marcos[10].find_child("Inimigos",true,false)
	verificar("chefe futuro nao revela nome",chefe.especies.all(func(nome): return not mapa._marcos[10].tooltip_text.contains(nome.replace("_"," ").to_upper())))
	var antes: int=chefe.quadro
	chefe._process(0.15)
	verificar("silhueta permanece preta enquanto anima",chefe.self_modulate==Color.BLACK and chefe.quadro!=antes)
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://arte/previas/interface_bosque/portal_descoberta_onda3.png")
	mapa._mudar_pagina(1)
	await quadros()
	verificar("segunda pagina tambem oculta ondas 11 a 20",mapa._marcos.values().all(func(marco): return marco.find_child("Inimigos",true,false).self_modulate==Color.BLACK))
	mapa.recorde=10
	mapa._mudar_pagina(-1)
	await quadros()
	verificar("chefe alcancado passa a mostrar sprite e nome",mapa._marcos[10].find_child("Inimigos",true,false).self_modulate==Color.WHITE and mapa._marcos[10].tooltip_text.contains("MINOTAURO"))
	papel.queue_free()
	await quadros()
	print("Jornada descoberta: %d falhas" % falhas)
	quit(1 if falhas else 0)
