extends SceneTree
## Confere a prévia da mochila contra o jogador, sem consultar sprites legados.
const Raven := preload("res://codigo/dados/aparencia_raven.gd")
var falhas := 0

func _initialize() -> void: rodar.call_deferred()
func esperar(n: int) -> void:
	for i in n: await process_frame
func verificar(ok: bool, texto: String) -> void:
	if not ok:
		falhas += 1
		push_error(texto)

func rodar() -> void:
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	assert(DisplayServer.get_name() != "headless")
	root.get_node("Introducao").pular_prologo()
	root.get_node("Transicao").hora_salva = 12.0
	change_scene_to_file("res://cenas/fazenda.tscn")
	await esperar(30)
	var jogador: Node2D = current_scene.get_node("Jogador")
	jogador.set_physics_process(false)
	jogador.aparencia_raven = {"pele":2,"cabelo":28,"roupa":8,"cor":[0.35,0.6,1,1]}
	var visual: Sprite2D = jogador.get_node("HeroiRaven")
	visual.set_process(false)
	jogador._direcao_ataque = Vector2.LEFT
	jogador.velocity = Vector2.LEFT*80
	visual._process(0.25)
	var textura_anterior := visual.texture
	var quadro_anterior := visual.frame
	var material_anterior := visual.material
	var ui = root.get_node("EventosJogo").interface_p1()
	ui._abrir_tela("inventario")
	await esperar(5)
	var tela = ui._telas["inventario"]
	tela._atualizar_boneco()
	verificar(visual.texture==textura_anterior and visual.frame==quadro_anterior and visual.material==material_anterior,"Abrir mochila preserva a animação do jogador")
	var previa: Sprite2D = tela._previa
	verificar((previa.texture as AtlasTexture).atlas.resource_path.ends_with("camadas/corpo_2.png"),"Prévia usa a pele Raven salva")
	verificar(previa.frame==0,"Prévia neutra de frente")
	verificar(previa.get_child_count()==visual._camadas.size(),"Prévia inclui roupa, cabelo e equipamentos")
	verificar((previa.get_child(6).texture as AtlasTexture).atlas.resource_path.ends_with("camadas/cabelo_28.png"),"Prévia usa o cabelo salvo")
	verificar(previa.get_child(6).modulate.is_equal_approx(Color(0.35,0.6,1,1)),"Prévia mantém a tintura")
	verificar(not tela._boneco.get_node("Corpo").visible,"Prévia não mostra o corpo legado")
	var saida := ProjectSettings.globalize_path("res://arte/previas/inventario_raven")
	DirAccess.make_dir_recursive_absolute(saida)
	root.mode = Window.MODE_WINDOWED
	await esperar(3)
	for conjunto in ["personalizado","carrasco","cavaleiro_rubro","cavalheiro"]:
		for par in [["cabeca","elmo"],["corpo","peitoral"],["luvas","luvas"],["botas","botas"]]:
			jogador.inventario.equipados[par[0]]=null if conjunto=="personalizado" else preload("res://codigo/dados/forja_armas.gd").criar_item(par[1]+"_"+conjunto)
		tela._atualizar_boneco()
		previa=tela._previa
		if conjunto!="personalizado":
			for i in 4:
				verificar((previa.get_child(9+i).texture as AtlasTexture).atlas.resource_path.contains("conjuntos/"+conjunto+"/raven_"),"Prévia acompanha peça equipada: "+conjunto)
		for tamanho in [Vector2i(576,324),Vector2i(288,512),Vector2i(320,324)]:
			root.content_scale_size=tamanho
			root.size=tamanho*2
			await esperar(4)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(saida+"/%s-%dx%d.png" % [conjunto,tamanho.x,tamanho.y])
			# Mede pixels desenhados, sem contar a margem transparente da célula80.
			for sprite: Sprite2D in [previa]+previa.get_children():
				var regiao := sprite.texture.get_image().get_region(Rect2i(0,0,80,80)).get_used_rect()
				if not regiao.has_area(): continue
				var desenho: Rect2 = sprite.get_global_transform()*Rect2(Vector2(regiao.position)+sprite.offset,regiao.size)
				for slot in tela._slots_equipamento.values():
					verificar(not desenho.grow(2).intersects(slot.get_global_rect()),"Prévia mantém margem dos slots: "+str(tamanho))
	print("PREVIA INVENTARIO RAVEN: ",falhas," falhas; aparência salva, tintura, três conjuntos, três tamanhos e animação preservada.")
	quit(1 if falhas else 0)
