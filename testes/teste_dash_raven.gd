extends SceneTree

var falhas := 0
var fotos: Array[Image] = []
var tempos: Array[float] = []

func _initialize() -> void:
	rodar.call_deferred()

func verificar(ok: bool, mensagem: String) -> void:
	if not ok:
		falhas += 1
		push_error(mensagem)

func esperar(n: int) -> void:
	for i in n: await process_frame

func conferir_sprite(sprite: Sprite2D, original: Sprite2D) -> void:
	verificar(sprite.texture == original.texture, "Rastro usa a textura atual")
	verificar(sprite.material == original.material, "Rastro preserva a paleta/material")
	verificar(sprite.frame == original.frame and sprite.offset == original.offset and sprite.centered == original.centered, "Rastro preserva quadro e pivô")
	var fonte := sprite.texture
	while fonte is AtlasTexture: fonte = fonte.atlas
	verificar(fonte.resource_path.begins_with("res://assets/personagens/raven_fantasy/"), "Rastro sem camada Mana Seed")

func rodar() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes") or DisplayServer.get_name() == "headless":
		quit(1)
		return
	root.get_node("Introducao").pular_prologo()
	root.get_node("Transicao").hora_salva = 12.0
	root.get_node("Fazenda").definir_clima_hoje(0)
	change_scene_to_file("res://cenas/fazenda.tscn")
	await esperar(30)
	root.get_node("Transicao").limpar()
	var jogador: Node2D = current_scene.get_node("Jogador")
	jogador.set_physics_process(false)
	jogador.aparencia_raven = {"versao":1,"pele":0,"cabelo":1,"roupa":1,"cor":[0.45,0.65,1.0,1.0]}
	var visual: Sprite2D = jogador.get_node("HeroiRaven")
	visual.set_process(false)
	var vp := SubViewport.new()
	vp.size = Vector2i(320,224)
	vp.world_2d = current_scene.get_world_2d()
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(vp)
	var camera := Camera2D.new()
	camera.zoom = Vector2(2,2)
	vp.add_child(camera)
	camera.make_current()
	DirAccess.make_dir_recursive_absolute("/tmp/algoland-dash-raven")
	var direcoes := [Vector2.DOWN,Vector2.RIGHT,Vector2.UP,Vector2.LEFT]
	# Importa e aquece as texturas no renderer antes de medir a janela de150ms.
	jogador.esta_em_dash = true
	visual._process(0.0)
	await esperar(5)
	jogador.esta_em_dash = false
	visual._process(0.0)
	for d in 4:
		jogador.position = Vector2(640,520)
		jogador._direcao_ataque = direcoes[d]
		jogador.velocity = Vector2.ZERO
		jogador.stamina = jogador.stamina_maxima
		visual._process(0.0)
		camera.position = jogador.global_position + direcoes[d]*26.0 + Vector2(0,-14)
		# Exercita o disparo real, não apenas uma troca artificial de pose.
		jogador.iniciar_dash()
		verificar(not jogador.no_reacao.visible,"Dash Raven não aciona reação Mana Seed")
		var stamina_depois: float = jogador.stamina
		var vistos := {}
		var anterior := Time.get_ticks_usec()
		for i in 10:
			var agora := Time.get_ticks_usec()
			var delta := (agora-anterior)/1000000.0
			anterior = agora
			if jogador.esta_em_dash:
				visual._process(delta)
				var antes := get_nodes_in_group("rastros_dash")
				var anterior_id := antes[-1].get_instance_id() if not antes.is_empty() else 0
				var transformacao := visual.global_transform
				jogador._atualizar_dash(delta)
				vistos[visual.frame%4]=true
				var copia: Sprite2D = visual.criar_rastro()
				conferir_sprite(copia,visual)
				verificar(copia.get_child_count()==visual._camadas.size(),"Rastro completo com roupa e cabelo")
				for c in copia.get_child_count():conferir_sprite(copia.get_child(c),visual._camadas[c])
				copia.free()
				var rastros := get_nodes_in_group("rastros_dash")
				verificar(not rastros.is_empty(),"Dash cria rastro no cenário")
				if not rastros.is_empty():
					var real: Node2D = rastros[-1]
					if real.get_instance_id() != anterior_id:
						conferir_sprite(real.get_child(0),visual)
						# A fotografia nasce antes do deslocamento deste passo.
						verificar(real.global_transform.is_equal_approx(transformacao),"Rastro real mantém a transformação no instante da cópia")
			await RenderingServer.frame_post_draw
			fotos.append(vp.get_texture().get_image())
			tempos.append(Time.get_ticks_usec()/1000000.0)
			await physics_frame
		verificar(vistos.has(3),"Último quadro Raven cabe na duração do dash")
		verificar(jogador.stamina==stamina_depois,"Dash cobra stamina uma única vez")
		await create_timer(jogador.recarga_dash+0.3).timeout
		verificar(not jogador.esta_em_dash and jogador._dash_disponivel,"Dash encerra e recarrega")
	for i in fotos.size():fotos[i].save_png("/tmp/algoland-dash-raven/%03d.png" % i)
	var arquivo := FileAccess.open("/tmp/algoland-dash-raven/tempos.json",FileAccess.WRITE)
	arquivo.store_string(JSON.stringify(tempos))
	print("DASH RAVEN: ",falhas," falhas; quatro direções, camadas atuais, pivô, stamina e recarga.")
	quit(1 if falhas else 0)
