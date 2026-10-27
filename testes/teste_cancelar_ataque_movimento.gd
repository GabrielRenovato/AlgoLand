extends SceneTree
## Entradas reais de teclado, toque e P2 cancelam o golpe e seus contatos.
var falhas:=0
var verificacoes:=0
var j: Node2D
var inventario: Node
class Alvo extends Node2D:
	var acertos:=0
	var vida:=100
	var esta_morto:=false
	func receber_dano(_dano: int,_forca: Vector2): acertos+=1
func _initialize(): rodar.call_deferred()
func quadros(n:=4):
	for i in n:
		await process_frame
		await physics_frame
func conferir(ok: bool,texto: String):
	verificacoes+=1
	if not ok:
		falhas+=1
		push_error(texto)
func soltar():
	for prefixo in ["","p2_"]:
		for acao in ["move_up","move_down","move_left","move_right"]:
			if InputMap.has_action(prefixo+acao): Input.action_release(prefixo+acao)
	root.get_node("Controle").vetor_toque=Vector2.ZERO
func equipar(id: String):
	soltar()
	j._cancelar_acoes_em_andamento()
	j.troca_sem_pose=true
	var item=preload("res://codigo/dados/forja_armas.gd").criar_item(id)
	inventario.mochila[20]=item
	conferir(inventario.equipar(item),"Equipa "+id)
	await quadros()
func atacar(fase:=1):
	j._fase_combo=fase
	if j.usando_lanca: j.iniciar_slash_ataque_lanca("AtaqueLancaSlash_2",.6)
	else: j.iniciar_slash_ataque("AtaqueEspadaSlash_1",.6)
func conferir_cancelamento(rotulo: String):
	conferir(not j._esta_atacando and j._temporizador.is_stopped(),"Golpe encerra: "+rotulo)
	conferir(not j.ataque_enfileirado and j._fase_combo==0 and j._buffer_ataque_ate_ms==0,"Fila e buffer limpos: "+rotulo)
	conferir(not j.get_node("AreaAtaque").monitoring and j.get_node("AreaAtaque/CollisionShape2D").disabled,"Contato desliga no mesmo passo: "+rotulo)
	conferir(j.velocity.length()>0,"Movimento começa no mesmo passo: "+rotulo)
func rodar():
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	root.mode=Window.MODE_WINDOWED
	root.size=Vector2i(1152,648)
	root.get_node("Ranking").conexao_habilitada=false
	root.get_node("Introducao").pular_prologo()
	change_scene_to_file("res://cenas/casa.tscn")
	await quadros(30)
	j=current_scene.get_node("Jogador")
	j.set_physics_process(false)
	j.position=Vector2(1000,1000)
	j.modo_fazenda=false
	inventario=j.inventario
	for arma in ["espada_basica","espada_gemea","lanca_basica","machado","maca"]:
		await equipar(arma)
		var fases: int=j.get_node("HeroiBase3D")._duracoes_combo().size() if arma not in ["machado","maca"] else 1
		for fase in range(1,fases+1):
			for p in [.1,.45,.85]:
				soltar()
				atacar(fase)
				await create_timer(j._temporizador.wait_time*p).timeout
				conferir(j._esta_atacando,"Golpe ainda ativo antes do comando")
				if p==.45: conferir(not j.get_node("AreaAtaque/CollisionShape2D").disabled,"Contato estava ativo antes de cancelar")
				j.ataque_enfileirado=true
				j._buffer_ataque_ate_ms=Time.get_ticks_msec()+150
				Input.action_press("move_right")
				j.mover()
				j.logica_combo_ataque()
				conferir_cancelamento("%s / %d / %.2f"%[arma,fase,p])
				j.animar()
				await quadros(2)
				conferir(j.get_node("HeroiBase3D")._acao=="correr","Modelo acompanha a corrida")
				conferir(not j.get_node("HeroiBase3D")._rastro.visible,"Rastro do golpe não continua na corrida")
	await equipar("espada_basica")
	for i in 8:
		soltar()
		atacar()
		var direcao:=Vector2.DOWN.rotated(-i*PI/4)
		if absf(direcao.x)>.5: Input.action_press("move_right" if direcao.x>0 else "move_left")
		if absf(direcao.y)>.5: Input.action_press("move_down" if direcao.y>0 else "move_up")
		j.mover()
		conferir_cancelamento("direção %d"%i)
	# Segurar uma direção antes do ataque não o cancela acidentalmente.
	Input.action_press("move_up")
	atacar()
	j.mover()
	conferir(j._esta_atacando and j.velocity==Vector2.ZERO,"Direção já segurada preserva o golpe")
	Input.action_release("move_up")
	j.mover()
	Input.action_press("move_up")
	j.mover()
	conferir_cancelamento("soltar e reapertar a mesma direção")
	soltar()
	Input.action_press("move_up")
	atacar()
	Input.action_press("move_right")
	j.mover()
	conferir_cancelamento("nova direção diagonal")
	# Analógico/toque: tremor pequeno não interrompe; um comando claro interrompe.
	soltar()
	atacar()
	root.get_node("Controle").vetor_toque=Vector2(.1,0)
	j.mover()
	conferir(j._esta_atacando,"Zona morta não cancela por tremor do direcional")
	root.get_node("Controle").vetor_toque=Vector2(.8,.6)
	j.mover()
	conferir_cancelamento("direcional de toque")
	var alvo:=Alvo.new()
	current_scene.add_child(alvo)
	j._acertar_alvo_da_area(alvo)
	conferir(alvo.acertos==0,"Sinal pendente não causa dano depois de cancelar")
	alvo.queue_free()
	soltar()
	atacar()
	await quadros(2)
	var antes: Vector2=j.position
	Input.action_press("move_right")
	j.set_physics_process(true)
	await quadros(4)
	j.set_physics_process(false)
	conferir(not j._esta_atacando and j.position.x>antes.x,"Entrada no ciclo físico real cancela e desloca o personagem")
	conferir(j.get_node("HeroiBase3D")._acao=="correr","Ciclo físico real troca o golpe pela corrida")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/cancelar-ataque-movimento.png")
	# O comando do P2 não cancela o golpe do P1.
	soltar()
	root.get_node("Cooperativo").entrar(1)
	await quadros(20)
	var p1=j
	atacar()
	p1._temporizador.paused=true
	j=root.get_node("Cooperativo").jogador2()
	j.set_physics_process(false)
	j.modo_fazenda=false
	inventario=j.inventario
	await equipar("espada_basica")
	atacar()
	Input.action_press("p2_move_left")
	j.mover()
	conferir_cancelamento("P2")
	conferir(p1._esta_atacando,"P2 não cancela o golpe do P1")
	soltar()
	root.get_node("Cooperativo").sair()
	print("CANCELAR ATAQUE: %d verificações, %d falhas"%[verificacoes,falhas])
	current_scene.queue_free()
	await quadros()
	quit(1 if falhas else 0)
