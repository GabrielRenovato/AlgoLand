extends SceneTree
## Combos reais, retorno interrompível e consistência das poses no rig canônico.
var falhas := 0
var verificacoes := 0
func _initialize(): rodar.call_deferred()
func conferir(ok: bool,texto: String):
	verificacoes+=1
	if not ok:
		falhas+=1
		push_error(texto)
func quadros(n:=4):
	for i in n:
		await process_frame
		await physics_frame
func rodar():
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	root.get_node("Ranking").conexao_habilitada=false
	root.get_node("Introducao").pular_prologo()
	change_scene_to_file("res://cenas/casa.tscn")
	await quadros(25)
	var j=current_scene.get_node("Jogador")
	j.set_physics_process(false)
	j.modo_fazenda=false
	var item=preload("res://codigo/dados/forja_armas.gd").criar_item("espada_basica")
	j.inventario.mochila[20]=item
	j.inventario.equipar(item)
	var h=j.get_node("HeroiBase3D")
	await quadros()
	var mochila=j.inventario.fotografar_mochila()
	var inicio: Vector2=j.global_position
	var vida: int=j.hp_atual
	for i in 3:
		var clipe: Animation=h._player.get_animation(h.COMBO.NOMES[i])
		conferir(clipe.get_meta("fonte")==h.COMBO.FONTES[i] and clipe.length==h.COMBO.DURACOES[i],"Cada golpe usa UAL2 com a duração original do combate")
		conferir(clipe.loop_mode==Animation.LOOP_NONE,"Golpe não repete sozinho")
		for trilha in clipe.get_track_count():
			var nome: String=clipe.track_get_path(trilha).get_concatenated_subnames()
			conferir(h._esqueleto.find_bone(nome)>=0,"Trilha aponta para um osso existente")
			for chave in clipe.track_get_key_count(trilha):
				var valor=clipe.track_get_key_value(trilha,chave)
				conferir(valor.is_finite(),"Pose sem coordenadas inválidas")
	# O fim de cada ataque intermediário encaixa na recuperação fornecida pelo autor.
	for i in 2:
		var ataque: Animation=h._player.get_animation(h.COMBO.NOMES[i])
		var rec: Animation=h._player.get_animation("quaternius/Sword_Regular_%s_Rec" % ("A" if i==0 else "B"))
		for trilha in ataque.get_track_count():
			if ataque.track_get_type(trilha)!=Animation.TYPE_ROTATION_3D:continue
			var outra: int=rec.find_track(ataque.track_get_path(trilha),Animation.TYPE_ROTATION_3D)
			conferir(outra>=0 and ataque.rotation_track_interpolate(trilha,ataque.length).angle_to(rec.rotation_track_interpolate(outra,0.0))<.04,"Ataque e recuperação compartilham a pose de passagem")
	# Enfileira os três golpes usando o temporizador real do personagem.
	for direcao in [Vector2.DOWN,Vector2.RIGHT,Vector2.UP,Vector2.LEFT]:
		j._direcao_ataque=direcao
		j._fase_combo=1
		j.iniciar_slash_ataque("AtaqueEspadaSlash_1",.38)
		for fase in [1,2,3]:
			await quadros(2)
			conferir(h._player.assigned_animation==h.COMBO.NOMES[fase-1],"Controlador reproduz o golpe certo")
			conferir(h._espada.get_parent()==h._mao,"Espada permanece presa à mão")
			if fase<3:j.ataque_enfileirado=true
			await create_timer(j._temporizador.time_left+.012).timeout
		await quadros(2)
		conferir(not j._esta_atacando and j._fase_combo==0,"Finalizador encerra sem ataque fantasma")
		conferir(j.global_position.is_equal_approx(inicio),"Combo preserva o pivô no mapa")
	# Um ataque isolado usa a recuperação sem manter a colisão/dano ligados.
	for fase in [1,2]:
		j._fase_combo=fase
		j.iniciar_slash_ataque("AtaqueEspadaSlash_1",.38)
		await create_timer(j._temporizador.time_left+.04).timeout
		conferir(h._acao=="recuperar_espada" and h._espada.get_parent()==h._mao,"Soltar o combo reproduz recuperação na mão")
		conferir(not j._esta_atacando and j.get_node("AreaAtaque/CollisionShape2D").disabled,"Recuperação não causa dano")
		if fase==1:
			Input.action_press("move_right")
			j.mover()
			await quadros(2)
			conferir(h._acao=="correr","Andar interrompe recuperação imediatamente")
			Input.action_release("move_right")
			j.velocity=Vector2.ZERO
		else:
			j._fase_combo=1
			j.iniciar_slash_ataque("AtaqueEspadaSlash_1",.38)
			await quadros(2)
			conferir(h._acao=="espada" and h._player.assigned_animation==h.COMBO.NOMES[0],"Novo ataque interrompe recuperação")
			j._cancelar_golpe()
		await create_timer(.6).timeout
		conferir(h._acao=="parado" and h._espada.get_parent()==h._costas,"Recuperação termina e guarda a arma")
	conferir(j.hp_atual==vida and j.inventario.fotografar_mochila()==mochila,"Animações não alteram vida ou inventário")
	print("COMBO QUATERNIUS: %d verificações, %d falhas" % [verificacoes,falhas])
	quit(1 if falhas else 0)
