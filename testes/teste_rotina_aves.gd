extends SceneTree

const Criacao := preload("res://codigo/fazenda/criacao_galinhas.gd")
var falhas := 0
func _initialize() -> void: rodar.call_deferred()
func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ", nome)
	if not ok: falhas += 1
func quadros(n := 10) -> void:
	for i in n:
		await process_frame
		await physics_frame
func foto(nome: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var pasta := "res://arte/previas/revisao_galinheiro/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(pasta))
	root.get_texture().get_image().save_png(pasta+nome+".png")
func rodar() -> void:
	await process_frame
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"): quit(1); return
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1152,648)
	root.content_scale_size = Vector2i(576,324)
	root.get_node("Introducao").pular_prologo()
	var fazenda := root.get_node("Fazenda")
	var transicao := root.get_node("Transicao")
	var bando: Node = fazenda.bando
	fazenda.apagar()
	fazenda.galinheiro.nivel = 1
	fazenda.galinheiro.aves = [Criacao.nova_ave(0),Criacao.nova_ave(1),Criacao.nova_ave(2,"galo")]
	fazenda.galinheiro.aves[0].ovos = 3
	fazenda.galinheiro.aves[1].ovos = 2
	fazenda.galinheiro.incubacao = 4
	fazenda.galinheiro.portinha_aberta = false
	transicao.hora_salva = 9
	change_scene_to_file("res://cenas/galinheiro.tscn")
	await quadros(35)
	for hud in get_nodes_in_group("hud"): hud.hide()
	for nivel in [1,2,3]:
		fazenda.galinheiro.nivel = nivel
		fazenda.galinheiro_alterado.emit()
		await quadros()
		var ovos: Node = current_scene._ovos
		verificar("ovos usam um icone nativo, nivel%d" % nivel, ovos.get_child_count() == 5 and ovos.get_child(0).texture.region == Rect2(0,0,16,16) and ovos.get_child(0).scale == Vector2.ONE)
		verificar("ovos apoiados nas cavidades, nivel%d" % nivel, ovos.get_child(0).position.y == 34 and ovos.get_node("OvoChocando").position.x == current_scene.largura-35)
		for estacao in 4:
			current_scene._estacao_mudou(estacao)
			await quadros()
			await foto("interior-%d-estacao-%d" % [nivel,estacao])
	fazenda.galinheiro.nivel = 1
	fazenda.galinheiro.portinha_aberta = true
	fazenda.galinheiro.incubacao = -1
	change_scene_to_file("res://cenas/fazenda.tscn")
	await quadros(35)
	var jogador := current_scene.get_node("Jogador")
	jogador.position = Vector2(320,330)
	bando.set_process(false)
	bando.reiniciar()
	var galinheiro := current_scene.get_node("Galinheiro")
	for ave in galinheiro._aves.get_children(): ave.set_physics_process(false)
	var maior_separacao_corpos := 0.0
	var maior_passeio_corpo := 0.0
	var erro_posicao := 0.0
	var saiu := false
	var voltou_de_dia := false
	var separacao := 0.0
	for passo in 7200:
		bando.avancar(1.0/60,9,0)
		for ave in galinheiro._aves.get_children():
			ave._physics_process(1.0/60)
			if bando.aves[ave.indice].estado == "fora":
				erro_posicao = maxf(erro_posicao,ave.position.distance_to(ave.portinha+bando.aves[ave.indice].ponto))
		if bando.aves.all(func(a):return a.estado == "fora"): saiu = true
		if saiu and bando.aves.any(func(a):return a.estado != "fora"): voltou_de_dia = true
		if saiu:
			separacao = maxf(separacao,bando.aves[0].ponto.distance_to(bando.aves[1].ponto))
		if saiu:
			var corpos_atuais: Array = galinheiro._aves.get_children()
			maior_separacao_corpos = maxf(maior_separacao_corpos,corpos_atuais[0].position.distance_to(corpos_atuais[1].position))
			for corpo in corpos_atuais: maior_passeio_corpo = maxf(maior_passeio_corpo,corpo.position.distance_to(corpo.portinha))
		if passo%100 == 0: await physics_frame
	print("MAIOR DIFERENCA ENTRE ROTA E CORPO: ",erro_posicao)
	verificar("corpos visiveis tambem se dispersam pelo pasto",maior_separacao_corpos > 150 and maior_passeio_corpo > 180)
	verificar("aves permanecem fora durante a manha", saiu and not voltou_de_dia)
	verificar("aves exploram areas separadas da fazenda", separacao > 150 and bando.aves.any(func(a): return a.ponto.length() > 180))
	var luzes := get_nodes_in_group("iluminacao")
	for luz in luzes: luz.remove_from_group("iluminacao")
	bando._process(.1)
	verificar("intervalo sem relogio nao manda aves para dentro",bando.aves.all(func(a):return a.estado == "fora"))
	for luz in luzes: luz.add_to_group("iluminacao")
	transicao.ocupada = true
	current_scene.get_node("Iluminacao").definir_hora(6)
	bando._process(.1)
	verificar("troca de mapa mantem estado das aves",bando.aves.all(func(a):return a.estado == "fora"))
	transicao.ocupada = false
	current_scene.get_node("Iluminacao").definir_hora(9)
	jogador.camera.zoom = Vector2(0.5,0.5)
	jogador.camera.position = Vector2(180,100)
	for hud in get_nodes_in_group("hud"): hud.hide()
	for estacao in 4:
		current_scene.get_node("Terrains/Estacoes").definir_estacao(estacao,true)
		await quadros()
		await foto("pasto-estacao-%d" % estacao)
	for passo in 4800: bando.avancar(.05,18,2)
	verificar("aves voltam pelo caminho navegavel ao anoitecer",bando.aves.all(func(a):return a.estado == "dentro"))
	fazenda.galinheiro.obra = 2
	fazenda.galinheiro.inicio_obra = root.get_node("Calendario").dia
	fazenda.galinheiro.pronto_dia = fazenda.galinheiro.inicio_obra+3
	fazenda.galinheiro_alterado.emit()
	await quadros()
	current_scene.get_node("ObraCarpinteiro").set_process(false)
	var npc := current_scene.get_node("ObraCarpinteiro").moradores.osvaldo as Node2D
	npc.set_physics_process(false)
	npc.position = Vector2(240,256)
	npc.visible = true
	npc._saindo = false
	npc.agenda = {"local":"fazenda","ponto":Vector2(272,256),"construindo":true}
	npc._alvo = Vector2(272,256)
	npc.caminho = PackedVector2Array([npc.position,Vector2(248,256),Vector2(256,256),Vector2(264,256),Vector2(272,256)])
	var paradas := 0
	for i in 60:
		npc._physics_process(1.0/60)
		if npc.caminho.size() > 1 and npc.sprite.frame % npc._colunas == 0: paradas += 1
	verificar("caminhada nao pisca idle a cada ponto da rota",paradas == 0)
	npc.agenda.ponto = Vector2(144,236)
	npc._alvo = npc.agenda.ponto
	npc.position = npc.agenda.ponto
	npc.caminho.clear()
	await quadros()
	jogador.camera.zoom = Vector2(2,2)
	jogador.camera.position = jogador.to_local(npc.global_position)
	var trabalho := npc.get_node("TrabalhoCarpinteiro")
	verificar("martelada esta ativa no ponto de trabalho",trabalho.martelando)
	verificar("martelada tem seis quadros e o mesmo pivo",trabalho._sprite.hframes == 6 and trabalho._sprite.vframes == 4 and trabalho._sprite.position == npc.sprite.position)
	for quadro in 6:
		trabalho.set_process(false)
		trabalho._tempo = quadro/8.0
		trabalho._process(0)
		await foto("martelo-%d" % quadro)
	print("FALHAS: ",falhas)
	quit(1 if falhas else 0)
