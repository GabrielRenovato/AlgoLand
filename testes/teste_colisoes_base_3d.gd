extends SceneTree
## Física real, projeção do rig e oito direções, com saves isolados.
var falhas := 0
var verificacoes := 0
var jogador: Node2D
var heroi: Node2D
var perfil: Node
var capturar := not "--sem-capturas" in OS.get_cmdline_user_args()

class Alvo extends StaticBody2D:
	var acertos := 0
	var esta_morto := false
	var vida := 10000
	func receber_dano(_dano: int, _forca: Vector2) -> void: acertos += 1; vida -= _dano
	func aplicar_atordoamento(_tempo: float) -> void: pass

class Inspecao extends Node2D:
	var j: Node2D
	func _process(_d: float): queue_redraw()
	func _draw():
		if j==null: return
		var pes: CollisionShape2D = j.get_node("CollisionShape2D")
		draw_circle(pes.position,pes.shape.radius,Color(0.2,1,.3,.25))
		draw_arc(pes.position,pes.shape.radius,0,TAU,32,Color.GREEN,.4)
		var dano: CollisionShape2D = j.get_node("AreaDano/CollisionShape2D")
		draw_set_transform_matrix(dano.transform)
		var r: float = dano.shape.radius
		var metade: float = dano.shape.height/2.0-r
		draw_line(Vector2(-r,-metade),Vector2(-r,metade),Color.CYAN,.4)
		draw_line(Vector2(r,-metade),Vector2(r,metade),Color.CYAN,.4)
		draw_arc(Vector2(0,-metade),r,PI,TAU,24,Color.CYAN,.4)
		draw_arc(Vector2(0,metade),r,0,PI,24,Color.CYAN,.4)
		draw_set_transform_matrix(Transform2D.IDENTITY)
		var forma: CollisionShape2D = j.get_node("AreaAtaque/CollisionShape2D")
		if not forma.disabled and forma.shape is ConvexPolygonShape2D:
			var pontos: PackedVector2Array = forma.shape.points
			draw_colored_polygon(pontos,Color(1,.2,.15,.3))
			pontos.append(pontos[0])
			draw_polyline(pontos,Color.ORANGE,.5)

func _initialize(): rodar.call_deferred()
func esperar(n := 3):
	for i in n: await process_frame
func conferir(ok: bool,texto: String):
	verificacoes+=1
	if not ok: falhas+=1; push_error(texto)
func preparar_arma(id: String):
	jogador._cancelar_acoes_em_andamento()
	if id.begins_with("arco_") and jogador.inventario.equipados.secundaria==null:
		var aljava = preload("res://codigo/dados/forja_armas.gd").criar_item("aljava_basica")
		jogador.inventario.mochila[21]=aljava
		conferir(jogador.inventario.equipar(aljava),"Equipa aljava")
	var item = preload("res://codigo/dados/forja_armas.gd").criar_item(id)
	jogador.inventario.mochila[20]=item
	conferir(jogador.inventario.equipar(item),"Equipa "+id)
	await esperar()
func fotografar(nome: String):
	if not capturar: return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/colisoes-3d-"+nome+".png")
func criar_alvo(ponto: Vector2, hurtbox := false) -> Alvo:
	var alvo := Alvo.new()
	alvo.collision_layer=4
	alvo.collision_mask=0
	alvo.add_to_group("enemy")
	var corpo := CollisionShape2D.new()
	corpo.shape=CircleShape2D.new()
	corpo.shape.radius=.8
	alvo.add_child(corpo)
	if hurtbox:
		var area := Area2D.new()
		area.collision_layer=4
		area.collision_mask=0
		area.monitoring=false
		area.add_to_group("hurtbox_inimigo")
		var forma := corpo.duplicate()
		area.add_child(forma)
		alvo.add_child(area)
	current_scene.add_child(alvo)
	alvo.global_position=ponto
	return alvo

func rodar():
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	root.mode=Window.MODE_WINDOWED
	root.content_scale_size=Vector2i(576,324)
	root.size=Vector2i(1152,648)
	root.get_node("Ranking").conexao_habilitada=false
	root.get_node("Introducao").pular_prologo()
	root.get_node("Transicao").hora_salva=12.0
	change_scene_to_file("res://cenas/casa.tscn")
	await esperar(30)
	jogador=current_scene.get_node("Jogador")
	jogador.set_physics_process(false)
	jogador.modo_fazenda=false
	jogador.position=Vector2(1000,1000)
	jogador.camera.position_smoothing_enabled=false
	jogador.camera.zoom=Vector2.ONE*4
	heroi=jogador.get_node("HeroiBase3D")
	perfil=jogador.get_node("ColisoesBase3D")
	var desenho := Inspecao.new()
	desenho.j=jogador
	desenho.z_index=20
	jogador.add_child(desenho)
	await esperar()
	var pes: CollisionShape2D = jogador.get_node("CollisionShape2D")
	var dano: CollisionShape2D = jogador.get_node("AreaDano/CollisionShape2D")
	conferir(pes.position==Vector2(0,11) and pes.shape.radius==5,"Base física alinhada aos pés, preservando largura das passagens")
	var usado: Rect2i = heroi._vp.get_texture().get_image().get_used_rect()
	var visivel: Rect2 = heroi.transform*heroi._sprite.transform*Rect2(Vector2(usado.position)+heroi._sprite.offset,Vector2(usado.size))
	var atingivel: Rect2 = dano.transform*dano.shape.get_rect()
	conferir(atingivel.position.y>=visivel.position.y-1 and atingivel.position.y<=visivel.position.y+6 and absf(atingivel.end.y-pes.position.y)<1,"Dano cobre cabeça/corpo até os pés sem prolongar acima do desenho")
	await fotografar("repouso")
	# Paredes físicas: não atravessa nas quatro direções, mantendo margem do raio.
	var parede := StaticBody2D.new()
	parede.collision_layer=64
	var forma := CollisionShape2D.new()
	forma.shape=RectangleShape2D.new()
	forma.shape.size=Vector2(120,8)
	parede.add_child(forma)
	current_scene.add_child(parede)
	for dir in [Vector2.DOWN,Vector2.RIGHT,Vector2.UP,Vector2.LEFT]:
		jogador.position=Vector2(1000,1000)
		parede.global_position=jogador.global_position+pes.position+dir*20
		parede.rotation=0 if dir.y!=0 else PI/2
		await physics_frame
		await physics_frame
		var colisao: KinematicCollision2D = jogador.move_and_collide(dir*40)
		conferir(colisao!=null and jogador.position.distance_to(Vector2(1000,1000))<12,"Parede bloqueia pelo apoio dos pés: "+str(dir))
	parede.rotation=0
	forma.shape.size=Vector2(2,40)
	var direita := parede.duplicate()
	current_scene.add_child(direita)
	for largura in [12.0,8.0]:
		jogador.position=Vector2(1000,1000)
		parede.global_position=jogador.global_position+pes.position+Vector2(-(largura+2)/2.0,30)
		direita.global_position=jogador.global_position+pes.position+Vector2((largura+2)/2.0,30)
		await physics_frame
		await physics_frame
		var contato: KinematicCollision2D=jogador.move_and_collide(Vector2(0,50))
		conferir((contato==null)==(largura>=10),"Passagem de %d pixels respeita o raio dos pés"%largura)
	parede.queue_free()
	direita.queue_free()
	jogador.position=Vector2(1000,1000)
	# Todas as armas usam a própria lâmina, e o repouso/preparação/recuperação não dão dano.
	for arma in ["espada_basica","espada_gemea","lanca_basica","machado","maca"]:
		await preparar_arma(arma)
		for fase in ([1] if arma in ["machado","maca"] else [1,2,3]):
			for i in 8:
				var dir := Vector2.DOWN.rotated(-i*PI/4)
				jogador._direcao_ataque=dir
				jogador._cardinal_anterior=jogador._cardinal_de(dir)
				jogador._fase_combo=fase
				if arma=="lanca_basica": jogador.iniciar_slash_ataque_lanca("AtaqueLancaSlash_2",.6)
				else: jogador.iniciar_slash_ataque("AtaqueEspadaSlash_1",.6)
				heroi.set_process(false)
				# O relógio real é mantido parado para amostrar as mesmas poses do jogador.
				jogador._temporizador.paused=true
				for p in [.10,.35,.50,.65,.90]:
					var tempo: float = jogador._temporizador.wait_time
					jogador._temporizador.start(tempo)
					jogador._temporizador.paused=false
					# Pose manual só no teste; os contatos continuam pela Area2D real.
					if arma in ["machado","maca"]:
						heroi._acao="pesada"
						var clipe: String=heroi._nome_animacao("pesada")
						heroi._player.play(clipe)
						heroi._player.speed_scale=0
						heroi._player.seek(lerpf(heroi.JANELA_PESADA.x,heroi.JANELA_PESADA.y,p)*heroi._player.get_animation(clipe).length,true)
					else:
						heroi._acao="lanca" if arma=="lanca_basica" else "espada"
						var clipe: String=heroi._nome_animacao(heroi._acao)
						heroi._player.play(clipe)
						heroi._player.speed_scale=0
						heroi._player.seek(p*heroi._player.get_animation(clipe).length,true)
						heroi._progresso_golpe=p
					heroi._modelo.rotation.y=atan2(dir.x,dir.y)
					heroi._encaixar_espada(arma not in ["machado","maca"])
					heroi._encaixar_arma_pesada(arma in ["machado","maca"])
					jogador._temporizador.paused=true
					await esperar(2)
					var geometria: Dictionary=heroi.geometria_golpe_2d()
					var g: CollisionShape2D=jogador.get_node("AreaAtaque/CollisionShape2D")
					conferir(g.disabled==(p<geometria.janela.x or p>geometria.janela.y),"Janela de dano acompanha o golpe: "+arma)
					if not g.disabled:
						for ponto in geometria.pontos: conferir(Geometry2D.is_point_in_polygon(ponto,g.shape.points),"Lâmina dentro do contato: "+arma)
					conferir(jogador.get_node("AreaAtaque").transform.is_equal_approx(Transform2D.IDENTITY),"Golpe não gira em torno do pivô 2D antigo")
					if i in [0,1,2,4,6] and p==.50: await fotografar(arma+"-"+str(i)+"-"+str(fase))
				jogador._temporizador.paused=false
				jogador._on_temporizador_ataque_timeout()
				heroi.set_process(true)
				await esperar()
	await preparar_arma("espada_basica")
	jogador._direcao_ataque=Vector2.RIGHT
	jogador._fase_combo=1
	jogador.iniciar_slash_ataque("AtaqueEspadaSlash_1",.6)
	heroi.set_process(false)
	jogador._temporizador.paused=true
	heroi._acao="espada"
	heroi._modelo.rotation.y=PI/2
	heroi._player.play(heroi._nome_animacao("espada"),0)
	heroi._player.speed_scale=0
	heroi._player.seek(heroi._player.get_animation(heroi._nome_animacao("espada")).length*.5,true)
	heroi._progresso_golpe=.5
	heroi._encaixar_espada(true)
	await esperar()
	var geometria: Dictionary=heroi.geometria_golpe_2d()
	var meio: Vector2=geometria.pontos[0].lerp(geometria.pontos[1],.7)
	var alvo := criar_alvo(jogador.to_global(meio),true)
	var distante := criar_alvo(jogador.to_global(meio+Vector2(65,65)),true)
	for i in 5: await physics_frame
	await esperar()
	conferir(alvo.acertos==1,"Corpo e hurtbox do mesmo alvo recebem um único golpe real")
	conferir(distante.acertos==0,"Alvo fora da lâmina não recebe dano fantasma")
	alvo.queue_free()
	distante.queue_free()
	jogador._temporizador.paused=false
	jogador._on_temporizador_ataque_timeout()
	heroi.set_process(true)

	# Disparo: origem visual e física coincidem, inclusive mirando na diagonal.
	await preparar_arma("arco_curto")
	jogador.no_arco.set_process(false)
	for dir in [Vector2.RIGHT,Vector2.UP,Vector2(1,1).normalized()]:
		jogador.no_arco.disparar(dir,1.0)
		jogador.no_arco._indice=4
		jogador.no_arco._tempo=.2
		heroi._process(0)
		await esperar()
		var antes := current_scene.get_children()
		jogador._ao_disparo_liberado(dir)
		for no in current_scene.get_children():
			if no in antes or not no is Area2D: continue
			if no.get_script()!=preload("res://codigo/jogador/flecha.gd"): continue
			conferir(no._visual.global_position.is_equal_approx(no.global_position),"Flecha não tem colisão invisível deslocada")
			var alvo_flecha := criar_alvo(no.global_position+dir*14)
			for i in 6: await physics_frame
			conferir(alvo_flecha.acertos==1,"Colisão da flecha encontra o alvo na trajetória visível")
			alvo_flecha.queue_free()
			if is_instance_valid(no): no.queue_free()
	jogador.no_arco.parar_disparo()
	# Um passo longo não pode pular uma parede fina e acertar o alvo atrás dela.
	var muro := StaticBody2D.new()
	muro.collision_layer=64
	muro.collision_mask=0
	var contorno := CollisionShape2D.new()
	contorno.shape=RectangleShape2D.new()
	contorno.shape.size=Vector2(1,20)
	muro.add_child(contorno)
	current_scene.add_child(muro)
	muro.global_position=Vector2(1016,800)
	var atras := criar_alvo(Vector2(1030,800))
	var flecha = preload("res://codigo/jogador/flecha.gd").new()
	current_scene.add_child(flecha)
	flecha.set_physics_process(false)
	flecha.global_position=Vector2(1000,800)
	flecha.iniciar(jogador,Vector2.RIGHT)
	for i in 3: await physics_frame
	flecha._physics_process(.12)
	conferir(flecha._acertou and atras.acertos==0,"Varredura bloqueia em parede de 1 pixel antes do alvo, mesmo com passo de 38 pixels")
	muro.queue_free()
	atras.queue_free()
	# Trocar para o Raven restaura o perfil legado e as bibliotecas originais.
	heroi.set_process(false)
	heroi.hide()
	await physics_frame
	await physics_frame
	conferir(not perfil.ativo and pes.position==Vector2(0,9) and dano.shape.height==24,"F3 restaura o perfil 2D")
	heroi.show()
	await physics_frame
	await physics_frame
	conferir(perfil.ativo and pes.position==Vector2(0,11),"Voltar ao 3D reaplica seu perfil")
	root.get_node("Cooperativo").entrar(1)
	await esperar(20)
	var p2 = root.get_node("Cooperativo").jogador2()
	conferir(p2!=null,"Segundo jogador disponível para conferir isolamento")
	if p2!=null:
		p2.set_physics_process(false)
		conferir(p2.get_node("ColisoesBase3D").ativo,"P2 também usa o perfil 3D")
		conferir(p2.get_node("CollisionShape2D").shape!=pes.shape and p2.get_node("AreaDano/CollisionShape2D").shape!=dano.shape,"Corpos físicos não compartilham recursos mutáveis")
		conferir(p2.get_node("AreaAtaque/CollisionShape2D").shape!=jogador.get_node("AreaAtaque/CollisionShape2D").shape,"Golpes de P1 e P2 têm geometrias independentes")
		conferir(p2.reprodutor_anim.get_animation_library("")!=jogador.reprodutor_anim.get_animation_library(""),"Trilhas do P1 não alteram o P2")
	root.get_node("Cooperativo").sair()
	print("COLISOES BASE 3D: ",falhas," falhas / ",verificacoes," verificações")
	quit(1 if falhas else 0)
