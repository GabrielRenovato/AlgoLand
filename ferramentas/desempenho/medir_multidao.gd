extends SceneTree
## Mede a IA no andar real, com os saves obrigatoriamente isolados.
func _initialize(): rodar.call_deferred()
func quadros(n: int):
	for i in n:
		await physics_frame
		await process_frame
func rodar():
	assert(OS.get_user_data_dir().contains("AlgoLand testes"))
	root.get_node("Ranking").conexao_habilitada=false
	root.get_node("Introducao").pular_prologo()
	root.get_node("Introducao").aula_arena=false
	root.get_node("Progresso").iniciar_partida()
	var transicao=root.get_node("Transicao")
	transicao.retornando=true
	transicao.estado={"onda_atual":10}
	transicao.iniciar_onda_ao_chegar=false
	change_scene_to_file("res://cenas/fendas/andar_10.tscn")
	await quadros(20)
	transicao.retornando=false
	var j=current_scene.get_node("Jogador")
	j.set_physics_process(false)
	j.invulneravel=true
	j.temporizador_invul=10000
	var g=current_scene.get_node("enemySpawner/GerenciadorOndas")
	g.iniciar_onda(true)
	await quadros(5)
	g.set_physics_process(false)
	var patrulhas: Array[Node]=[]
	var quantidade := 0
	for e in get_nodes_in_group("enemy"):
		quantidade+=1
		e.set_physics_process(false)
		if e.has_node("PatrulhaAndar"):
			var p: Node=e.get_node("PatrulhaAndar")
			p.set_physics_process(false)
			patrulhas.append(p)
	var economico := "--economico" in OS.get_cmdline_user_args()
	if g.get("economizar_patrulhas")!=null:g.economizar_patrulhas=economico
	var amostras: Array[int]=[]
	for q in 180:
		var t := Time.get_ticks_usec()
		for p in patrulhas:p._physics_process(1.0/60)
		amostras.append(Time.get_ticks_usec()-t)
		await quadros(1)
	amostras.sort()
	var soma := 0.0
	for custo in amostras:soma+=custo
	var grade: GDScript=load("res://codigo/inimigos/vizinhos_inimigos.gd")
	var t := Time.get_ticks_usec()
	for q in 20:
		grade.invalidar()
		for e in get_nodes_in_group("enemy"):e.calcular_separacao()
	var separacao := (Time.get_ticks_usec()-t)/20.0
	var resultado := {"inimigos":quantidade,"patrulhas":patrulhas.size(),"economico":economico,"media_us":soma/amostras.size(),"mediana_us":amostras[90],"p95_us":amostras[171],"pico_us":amostras[-1],"separacao_todos_us":separacao}
	print("MULTIDAO ",JSON.stringify(resultado))
	var nome := "depois" if economico else "antes"
	FileAccess.open("/tmp/algoland-mobs-"+nome+".json",FileAccess.WRITE).store_string(JSON.stringify(resultado))
	g.parar_ondas()
	await quadros(2)
	quit()
