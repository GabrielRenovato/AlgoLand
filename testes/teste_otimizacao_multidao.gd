extends SceneTree
const Grade := preload("res://codigo/inimigos/vizinhos_inimigos.gd")
class JogadorTeste extends Node2D:
	var estaMorto := false
	var caido := false
var falhas := 0
var verificacoes := 0
func _initialize(): rodar.call_deferred()
func quadros(n: int):
	for i in n:
		await physics_frame
		await process_frame
func conferir(ok: bool,msg: String):
	verificacoes+=1
	if not ok:
		falhas+=1
		push_error(msg)
func referencia(e: Node2D, todos: Array[Node]) -> Vector2:
	var soma := Vector2.ZERO
	for outro in todos:
		if outro==e or outro.get_world_2d()!=e.get_world_2d():continue
		var diff: Vector2=e.global_position-outro.global_position
		var dist := diff.length()
		if dist<.01 or dist>=e.alcance_separacao:continue
		soma+=diff/dist*(1.0-dist/e.alcance_separacao)
	return (soma*e.forca_separacao).limit_length(e.forca_separacao)
func rodar():
	assert(OS.get_user_data_dir().contains("AlgoLand testes"))
	root.get_node("Ranking").conexao_habilitada=false
	root.get_node("Introducao").pular_prologo()
	root.get_node("Introducao").aula_arena=false
	root.get_node("Progresso").iniciar_partida()
	var tr=root.get_node("Transicao")
	tr.retornando=true
	tr.estado={"onda_atual":10}
	tr.iniciar_onda_ao_chegar=false
	change_scene_to_file("res://cenas/fendas/andar_10.tscn")
	await quadros(20)
	tr.retornando=false
	var j=current_scene.get_node("Jogador")
	j.set_physics_process(false)
	j.invulneravel=true
	j.temporizador_invul=10000
	var g=current_scene.get_node("enemySpawner/GerenciadorOndas")
	g.iniciar_onda(true)
	await quadros(4)
	g.set_physics_process(false)
	g.economizar_patrulhas=true
	var todos := get_nodes_in_group("enemy")
	var origens := {}
	var patrulhas := []
	for e in todos:
		e.set_physics_process(false)
		origens[e]=e.global_position
		if e.has_node("PatrulhaAndar"):
			var p=e.get_node("PatrulhaAndar")
			p.set_physics_process(false)
			patrulhas.append(p)
	conferir(todos.size()>=100,"Andar real com mais de cem mobs")
	# Distribuição, bordas negativas e mutantes: força igual à busca completa.
	var rng := RandomNumberGenerator.new()
	rng.seed=1234
	var i := 0
	for e in todos:
		e.global_position=Vector2(rng.randf_range(-600,600),rng.randf_range(-400,400))
		if i%3==0:e.alcance_separacao=28.0
		i+=1
	Grade.invalidar()
	var candidatos := 0
	for e in todos:
		conferir(e.calcular_separacao().distance_to(referencia(e,todos))<.001,"Repulsão equivalente à busca completa")
		candidatos+=Grade.proximos(e,e.alcance_separacao).size()
	conferir(candidatos<todos.size()*todos.size()/3,"Redução das comparações na multidão")
	# Cruzamento de células no mesmo passo não perde o vizinho em movimento.
	var a: Node2D=todos[0]
	var b: Node2D=todos[1]
	a.global_position=Vector2(-64,-64)
	b.global_position=Vector2(-10,-64)
	Grade.invalidar()
	Grade.proximos(a,18)
	b.global_position=Vector2(-60,-64)
	conferir(Grade.proximos(a,18).has(b),"Movimento entre células preserva vizinho")
	b.global_position=a.global_position
	conferir(a.calcular_separacao().is_finite(),"Corpos sobrepostos sem NaN")
	for e in todos:e.global_position=origens[e]
	Grade.invalidar()
	# Outro World2D não empurra a multidão desta câmera.
	var vp := SubViewport.new()
	vp.size=Vector2i(576,324)
	vp.world_2d=World2D.new()
	root.add_child(vp)
	var visitante := Node2D.new()
	vp.add_child(visitante)
	visitante.add_to_group("enemy")
	visitante.global_position=a.global_position
	Grade.invalidar()
	conferir(not Grade.proximos(a,100).has(visitante),"Separação isolada por World2D")
	# A segunda câmera mantém as patrulhas do seu mundo, sem misturar áreas.
	var parceiro := JogadorTeste.new()
	vp.add_child(parceiro)
	parceiro.add_to_group("jogadores")
	visitante.position=Vector2(100,100)
	g._quadro_patrulhas=-1
	conferir(g.patrulha_proxima(visitante),"Patrulha visível para o segundo jogador")
	parceiro.caido=true
	g._quadro_patrulhas=-1
	conferir(not g.patrulha_proxima(visitante),"Câmera de jogador caído não mantém outro mundo ativo")
	vp.free()
	Grade.invalidar()
	g._quadro_patrulhas=-1
	var pedidos := 0
	for q in 40:pedidos+=int(g.reservar_rota_patrulha())
	conferir(pedidos==g.CONSULTAS_PATRULHA_POR_QUADRO,"Orçamento de novas rotas por passo")
	await quadros(1)
	conferir(g.reservar_rota_patrulha(),"Orçamento renovado no passo seguinte")
	var longe: Node
	for p in patrulhas:
		if not g.patrulha_proxima(p.inimigo) and p.inimigo.get("parado")!=true:
			longe=p
			break
	conferir(longe!=null,"Patrulha fora das câmeras disponível")
	if longe!=null:
		var e: Node2D=longe.inimigo
		var inicio := e.global_position
		for q in 60:longe._physics_process(1.0/60)
		conferir(longe._suspensa and e.global_position==inicio,"Longe da câmera sem mover ou teleportar")
		var tempo: float=longe._tempo
		longe._physics_process(600.0)
		conferir(longe._tempo==tempo,"Tempo de patrulha não acumula fora da câmera")
		var posicao_jogador: Vector2=j.global_position
		j.global_position=e.global_position+Vector2(40,20)
		var camera: Camera2D=j.get_node("Camera2D")
		camera.reset_smoothing()
		camera.force_update_scroll()
		await quadros(3)
		for q in 90:
			longe._physics_process(1.0/60)
			await quadros(1)
		conferir(not longe._suspensa,"Patrulha retoma antes de entrar na câmera")
		conferir(e.global_position.distance_to(inicio)>1.0 and e.global_position.distance_to(inicio)<150,"Retoma caminhada real sem teleporte")
		j.global_position=posicao_jogador
		camera.reset_smoothing()
		camera.force_update_scroll()
		await quadros(3)
		var vida: int=e.vida
		e.aplicar_queimadura(1,.5,1.0,Color.ORANGE)
		longe._physics_process(.6)
		conferir(e.vida<vida,"Dano periódico continua fora da câmera")
		g._physics_process(.21)
		conferir(e.is_physics_processing(),"Dano acorda o combate mesmo fora da câmera")
		e.set_physics_process(false)
		await quadros(2)
	# AnimationTree: suspensão não interfere no gelo nem na retomada do combate.
	var slime=load("res://cenas/inimigos/slime.tscn").instantiate()
	slime.global_position=a.global_position+Vector2(2,2)
	current_scene.add_child(slime)
	conferir(Grade.proximos(a,18).has(slime),"Spawn atualiza o índice no mesmo passo")
	slime.position=Vector2(-5000,-5000)
	g.registrar_inimigo_adormecido(slime)
	var p=slime.get_node("PatrulhaAndar")
	p.set_physics_process(false)
	p._physics_process(.016)
	conferir(p._suspensa and slime.arvore_animacao.process_mode==Node.PROCESS_MODE_DISABLED,"AnimationTree suspensa fora da tela")
	slime.aplicar_congelamento(.05)
	p._physics_process(.10)
	conferir(not slime.esta_congelado() and slime.arvore_animacao.active,"Gelo mantém estado da animação")
	p.free()
	conferir(slime.arvore_animacao.process_mode!=Node.PROCESS_MODE_DISABLED,"Combate restaura AnimationTree")
	slime.free()
	var flor=load("res://cenas/inimigos/flor.tscn").instantiate()
	flor.parado=true
	flor.position=Vector2(-5000,-5100)
	current_scene.add_child(flor)
	g.registrar_inimigo_adormecido(flor)
	var patrulha_flor=flor.get_node("PatrulhaAndar")
	patrulha_flor.set_physics_process(false)
	var ponto_flor: Vector2=flor.global_position
	flor.esta_recuando=true
	flor.velocity=Vector2(100,0)
	patrulha_flor._physics_process(.016)
	conferir(flor.global_position==ponto_flor,"Inimigo enraizado preserva sua posição")
	flor.free()
	conferir(current_scene.get_node("enemySpawner")._populacao.size()==todos.size(),"Quantidade original dos mobs preservada")
	g.parar_ondas()
	print("MULTIDAO TESTE: ",verificacoes," verificações; ",falhas," falhas; candidatos=",candidatos," contra ",todos.size()*todos.size())
	await quadros(2)
	quit(0 if falhas==0 else 1)
