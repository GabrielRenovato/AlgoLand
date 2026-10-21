extends SceneTree
## Reproduz a espera de pesca no píer, com save isolado e as quatro direções.
var Sessao: GDScript
var falhas := 0
func _initialize() -> void: rodar.call_deferred()
func verificar(ok: bool, mensagem: String) -> void:
	if not ok:
		falhas += 1
		push_error(mensagem)
func quadros(n: int) -> void:
	for i in n: await process_frame
func rodar() -> void:
	assert(str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"))
	assert(DisplayServer.get_name() != "headless")
	Sessao = load("res://codigo/pesca/sessao_pesca.gd")
	root.get_node("Saves").trocar("solo")
	root.get_node("Introducao").pular_prologo()
	root.get_node("Transicao").hora_salva = 12.0
	preload("res://codigo/globais/opcoes_jogo.gd").fechar_mini_tutorial()
	root.size = Vector2i(1152,648)
	root.content_scale_size = Vector2i(576,324)
	change_scene_to_file("res://cenas/praia.tscn")
	await quadros(40)
	root.get_node("Transicao").limpar()
	current_scene.get_node("Iluminacao").definir_hora(12)
	current_scene.get_node("Iluminacao").set_process(false)
	var jogador := current_scene.get_node("Jogador")
	jogador.set_physics_process(false)
	jogador.aparencia_raven = {"pele":0,"roupa":1,"cabelo":1,"cor":[1,1,1,1]}
	var visual := jogador.get_node("HeroiRaven")
	visual.set_process(false)
	root.mode = Window.MODE_WINDOWED
	var saida := ProjectSettings.globalize_path("res://arte/previas/pesca_raven")
	DirAccess.make_dir_recursive_absolute(saida)
	var direcoes := [Vector2.DOWN,Vector2.RIGHT,Vector2.UP,Vector2.LEFT]
	var pontos := ["PescaPonta","PescaPierLeste","PescaPierLeste","PescaOeste"]
	var vp := SubViewport.new()
	vp.size = Vector2i(384,288)
	vp.world_2d = current_scene.get_world_2d()
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(vp)
	var camera := Camera2D.new()
	camera.zoom = Vector2(3,3)
	vp.add_child(camera)
	var amostras := []
	for direcao in 4:
		jogador.global_position = Vector2(224,482) if direcao==2 else current_scene.get_node(pontos[direcao]).global_position
		camera.position = jogador.global_position+direcoes[direcao]*18+Vector2(0,5)
		var sessao: Node2D = Sessao.new()
		sessao.iniciar(jogador,direcoes[direcao],"mar")
		sessao.set_process(false)
		sessao.set_physics_process(false)
		sessao.estado = Sessao.Estado.LANCANDO
		sessao._tempo = 0.35
		sessao._atualizar_animacao(0.0)
		visual._process(0.0)
		verificar(visual.frame == direcao*4+2,"Lançamento preserva o quadro de movimento original")
		sessao._tempo = Sessao.FIM_GESTO_ARREMESSO-0.001
		sessao._atualizar_animacao(0.0)
		var antes: Vector2 = sessao.posicao_boia()
		sessao._tempo = Sessao.FIM_GESTO_ARREMESSO+0.001
		sessao._atualizar_animacao(0.0)
		verificar(antes.distance_to(sessao.posicao_boia())<2.0,"Mudar a pose não teletransporta a boia")
		for estado in [Sessao.Estado.ESPERANDO,Sessao.Estado.BELISCANDO]:
			sessao.estado = estado
			sessao._atualizar_animacao(0.0)
			visual._process(0.0)
			verificar(visual._animacao == "pescar" and visual.frame == direcao*4+3,"Espera usa a pose final, sem congelar lançamento")
			verificar(visual._vara_pesca.visible,"Vara estável nas quatro direções")
			verificar(not visual._camadas[5].visible,"Sem rastro do lançamento na espera")
			if direcao != 2:
				var imagem: Image = visual._camadas[5].texture.get_image().get_region(Rect2i(240,direcao*80,80,80))
				for y in 80:
					for x in 80:
						verificar(imagem.get_pixel(x,y) != Color("b03a1f"),"Rastro laranja não pode ficar parado")
			else:
				verificar(sessao._animacao.ponta() == visual._vara_pesca.points[-1]+visual.position,"Linha nasce na ponta da vara de costas")
			sessao.queue_redraw()
			await quadros(5)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(saida+"/%d-%d.png" % [direcao,estado])
			visual._process(0.35)
			verificar(visual.frame == direcao*4+3,"Pose estável durante a espera")
		# Reprodução com o delta real: arremesso, acomodação, espera e disputa.
		sessao.estado = Sessao.Estado.LANCANDO
		sessao._tempo = 0.0
		var vistos := {}
		var decorrido := 0.0
		var proxima_captura := 0.0
		var numero := 0
		var puxando := false
		while decorrido < 2.5:
			await physics_frame
			var delta := root.get_physics_process_delta_time()
			decorrido += delta
			if decorrido > 1.0 and not puxando:
				puxando = true
				sessao.estado = Sessao.Estado.PUXANDO
				sessao._sacudir_vara()
			sessao._process(delta)
			visual._process(delta)
			vistos[visual.frame%4]=true
			if puxando:
				verificar(visual.frame%4==3 and not visual._camadas[5].visible,"Disputa não repete rastro nem preparação do arremesso")
				verificar(sessao._animacao.ponta().is_equal_approx(visual._vara_pesca.points[-1]+visual.position),"Linha acompanha a flexão da vara")
			if decorrido >= proxima_captura:
				proxima_captura += 0.08
				await RenderingServer.frame_post_draw
				vp.get_texture().get_image().save_png(saida+"/movimento-%d-%02d.png" % [direcao,numero])
				amostras.append({"direcao":direcao,"quadro":numero,"tempo":decorrido,"estado":sessao.estado,"pose":visual.frame%4,"ponta":str(sessao._animacao.ponta())})
				numero += 1
		verificar(vistos.size()==4,"Arremesso exibe as quatro fases antes da disputa")
		sessao._terminar()
		await quadros(3)
		visual._process(0.0)
		var descanso := "parado"
		verificar(visual._animacao == descanso and visual._camadas[5].visible and not visual._vara_pesca.visible,"Cancelar restaura o visual fora da pesca")
	var registro := FileAccess.open(saida+"/tempos.json",FileAccess.WRITE)
	registro.store_string(JSON.stringify(amostras))
	registro.close()
	vp.free()
	# Confere o recorte no GPU: só a haste original sobrevive no arremesso;
	# os dois quadros com a boia presa mantêm exatamente o alfa nativo.
	var raven := preload("res://codigo/dados/aparencia_raven.gd")
	var teste_vara := SubViewport.new()
	teste_vara.size = Vector2i(80,80)
	teste_vara.transparent_bg = true
	teste_vara.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(teste_vara)
	var haste := Sprite2D.new()
	haste.centered = false
	haste.texture = raven.folha("ferramentas","pescar")
	haste.hframes = 4
	haste.vframes = 4
	haste.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	teste_vara.add_child(haste)
	for d in 4:
		for q in 3:
			haste.frame = d*4+q
			haste.material = raven.material_pose(false,false,d,true,true)
			await quadros(2)
			await RenderingServer.frame_post_draw
			var render := teste_vara.get_texture().get_image()
			var origem := haste.texture.get_image().get_region(Rect2i(q*80,d*80,80,80))
			var erros := 0
			for y in 80:
				for x in 80:
					var pixel := origem.get_pixel(x,y)
					var alfa := pixel.a if q!=2 or pixel==Color("745c42") else 0.0
					if absf(render.get_pixel(x,y).a-alfa)>0.01: erros+=1
			verificar(erros==0,"Sem rastro; madeira e boia preparatória preservadas no GPU")
	teste_vara.free()
	print("ESPERA PESCA RAVEN: ",falhas," falhas; espera/belisco, quatro direções, ponta da linha e cancelamento.")
	current_scene.queue_free()
	await quadros(5)
	for id in Node.get_orphan_node_ids():
		var orfao = instance_from_id(id)
		if is_instance_valid(orfao) and orfao is Node: orfao.free()
	quit.call_deferred(1 if falhas else 0)
