extends SceneTree
var falhas:=0
var papel:="A"
var coordenacao:=""
var cena: Node2D
func _initialize():rodar.call_deferred()
func verificar(nome: String,ok: bool):
	print("OK " if ok else "FALHA ",papel," ",nome)
	if not ok:falhas+=1
func esperar(condicao: Callable,nome: String,segundos:=25.0):
	var fim:=Time.get_ticks_msec()+int(segundos*1000)
	while not condicao.call() and Time.get_ticks_msec()<fim:await create_timer(.05).timeout
	verificar(nome,condicao.call())
func marcar(nome: String):FileAccess.open(coordenacao.path_join(nome),FileAccess.WRITE).store_string("ok")
func existe(nome: String)->bool:return FileAccess.file_exists(coordenacao.path_join(nome))
func foto(nome: String):
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(coordenacao.path_join(nome+"-"+papel+".png"))
func rodar():
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes") or DisplayServer.get_name()=="headless":quit(1);return
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--papel="):papel=a.trim_prefix("--papel=")
		if a.begins_with("--coordenacao="):coordenacao=a.trim_prefix("--coordenacao=")
	if coordenacao.is_empty():quit(1);return
	create_timer(100).timeout.connect(func():quit(1))
	var ranking: Node=root.get_node("Ranking")
	ranking.conexao_habilitada=false;ranking.apelido="VISITANTE "+papel
	root.size=Vector2i(1152,648);root.content_scale_size=Vector2i(576,324)
	var p=load("res://codigo/campanha/progresso_campanha.gd").new()
	p.iniciar("user://percurso_primeira_raiz","prototipo")
	for id in ["sobreviver_queda","estrada_interrompida","acolhimento"]:p.confirmar_conclusao(id)
	set_meta("campanha_destino","vila");set_meta("campanha_nova_instancia",true)
	change_scene_to_file("res://cenas/campanha/percurso_prototipo.tscn")
	await esperar(func():return current_scene!=null and is_instance_valid(current_scene.get("lobby_cidade")),"cidade montada")
	cena=current_scene
	var lobby: Node=cena.lobby_cidade
	var sessao: Node=lobby.sessao_de(cena.jogador)
	await esperar(func():return sessao.online and sessao.conectado and lobby.remotos.size()==1,"entrada automática encontra outro jogador")
	verificar("mapa público da campanha",sessao.mapa_id()==4 and sessao.participantes.size()==2)
	cena.jogador.position=Vector2(80 if papel=="A" else 140,180)
	var esperado: float=140 if papel=="A" else 80
	await esperar(func():return not lobby.remotos.is_empty() and absf(lobby.remotos.values()[0].position.x-esperado)<3,"movimento chega ao outro cliente")
	await create_timer(2.3).timeout
	verificar("cidade não abre relatório nem sala de expedição",cena.interface._telas_abertas.is_empty() and (cena.sessao==null or not cena.sessao.ativo))
	await foto("encontro-online")
	marcar(papel+"-movimento")
	await esperar(func():return existe("A-movimento") and existe("B-movimento"),"ambos revisaram movimento")
	if papel=="B":
		cena.abrir_regiao("chegada",false)
		await esperar(func():return sessao.mapa_id()==0,"estágio mantém presença privada")
		await esperar(func():return existe("A-saida"),"outro jogador confirma saída")
		cena.abrir_regiao("vila")
		lobby=cena.lobby_cidade
	else:
		await esperar(func():return lobby.remotos.is_empty(),"jogador no estágio sai da praça")
		marcar("A-saida")
	await esperar(func():return is_instance_valid(lobby) and lobby.remotos.size()==1,"retorno reencontra a mesma praça pública")
	await foto("retorno-online")
	marcar(papel+"-fim")
	await esperar(func():return existe("A-fim") and existe("B-fim"),"ambos terminaram")
	print("FALHAS: ",falhas)
	quit(falhas)
