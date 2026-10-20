extends SceneTree

## Terreno próprio, cômodos, acessibilidade, aves, estações, mapa e travessias cooperativas.
var falhas := 0
var capturar := false
const PASTA := "res://arte/previas/carpintaria/"
func _initialize() -> void: rodar.call_deferred()
func quadros(n := 12) -> void:
	for i in n:
		await process_frame
		await physics_frame
func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ",nome)
	if not ok: falhas += 1
func foto(nome: String) -> void:
	if not capturar: return
	await quadros(3)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PASTA))
	root.get_texture().get_image().save_png(PASTA+nome+".png")
func sem_hud() -> void:
	for hud in get_nodes_in_group("hud"): hud.visible = false
func rodar() -> void:
	await process_frame
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"): quit(1); return
	capturar = "--capturar" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless"
	root.mode = Window.MODE_WINDOWED
	root.get_node("Introducao").pular_prologo()
	root.get_node("Calendario").dia = 1
	root.get_node("Fazenda").clima_hoje = 0
	root.get_node("Transicao").hora_salva = 9
	root.content_scale_size = Vector2i(1024,576)
	root.size = Vector2i(2048,1152)
	change_scene_to_file("res://cenas/cidade.tscn")
	await quadros(40)
	var vila = current_scene
	var p1 = vila.get_node("Jogador")
	var luz = vila.get_node("Iluminacao")
	luz.definir_hora(9); luz.set_process(false)
	p1.camera.zoom = Vector2.ONE
	p1.position = Vector2(512,288)
	p1.camera.reset_smoothing()
	sem_hud()
	var dados = load("res://codigo/cidade/dados_cidade.gd")
	verificar("terreno da família amplia cidade e preserva locais existentes",vila.limites.size == Vector2(1024,576) and dados.PREDIOS.carpintaria.base == Vector2(816,224) and dados.PREDIOS.sede.base == Vector2(336,168))
	var caminho: PackedVector2Array = vila.caminho_morador(Vector2(392,310),Vector2(816,266),"helena")
	verificar("ponte liga praça e casa com rota para a cadeira",caminho.size() > 2 and caminho[-1].distance_to(Vector2(816,266))<20)
	var helena = vila.moradores.helena
	helena.collision_mask = 64
	var livre := true
	for i in range(1,caminho.size()):
		if helena.test_move(Transform2D(0,caminho[i-1]),caminho[i]-caminho[i-1]): livre = false
	verificar("rota pela ponte respeita volume físico da cadeira",livre)
	var quintal = vila.get_node("QuintalCarpinteiro")
	var limites = vila.get_node("LimitesVila")
	verificar("margem leste não recebe fragmentos da cerca antiga",limites._pecas.all(func(p): return p.position.x<704))
	var decoracao: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/cenario/cidade/decoracao/decoracao.json"))
	var copas_livres := true
	for item in decoracao:
		if not item.get("quintal_carpinteiro",false) or item.p != "vegetacao/arvore": continue
		var usado: Array = item.usado
		var copa := Rect2(Vector2(item.x-float(usado[2])/2,item.y-float(usado[3])),Vector2(usado[2],usado[3]))
		if copa.intersects(quintal.cercado.grow(12)): copas_livres = false
	verificar("copas deixam cercado inteiro e abrigo visíveis",copas_livres)
	var aves := get_nodes_in_group("aves_quintal_carpinteiro")
	verificar("cercado recebe quatro galinhas e um galo próprios",aves.size()==5 and aves[4].sprite.texture.resource_path.ends_with("galo.png"))
	var fotos := []
	for estacao in 4:
		vila.get_node("Terrains/Estacoes").definir_estacao(estacao,true)
		vila.get_node("Terrains/Estacoes/Meteorologia").definir_clima(0,true)
		await quadros()
		var textura: Texture2D = vila.get_node("Terrains/Construcoes/Carpintaria/Fachada").texture
		fotos.append(textura.resource_path)
		verificar("fachada sazonal e cercas integradas: "+str(estacao),textura.get_size()==Vector2(192,128) and quintal._estacao==estacao)
		await foto("cidade-"+str(estacao))
	verificar("quatro imagens sazonais efetivamente utilizadas",fotos.size()==4 and fotos[0]!=fotos[1] and fotos[1]!=fotos[2] and fotos[2]!=fotos[3])
	vila.get_node("Terrains/Estacoes").definir_estacao(0,true)
	vila.get_node("Terrains/Estacoes/Meteorologia").definir_clima(0,true)
	var antes := aves.map(func(a): return a.position)
	await quadros(200)
	var moveram := false
	for i in aves.size():
		if aves[i].position.distance_to(antes[i])>3: moveram = true
	verificar("aves caminham e bicam dentro do pasto",moveram and aves.all(func(a): return quintal.cercado.grow(-6).has_point(a.position)))
	p1.position = Vector2(832,280)
	verificar("portão deixa jogador entrar sem atravessar a cerca",not p1.test_move(Transform2D(0,Vector2(832,280)),Vector2(0,64)))
	verificar("cerca lateral bloqueia saída do pasto",p1.test_move(Transform2D(0,Vector2(752,380)),Vector2(-30,0)))
	luz.definir_hora(19)
	for i in 1200:
		for ave in aves: ave._physics_process(1.0/60)
	verificar("aves procuram abrigo à noite",aves.all(func(a): return not a.visible))
	luz.definir_hora(9)
	await quadros(200)
	verificar("aves retornam ao pasto pela manhã",aves.all(func(a): return a.visible))
	root.content_scale_size = Vector2i(576,432)
	root.size = Vector2i(1152,864)
	p1.position = Vector2(832,272)
	p1.camera.reset_smoothing()
	await quadros()
	await foto("quintal-jogo")
	if capturar:
		p1.position = Vector2(192,208)
		p1.camera.reset_smoothing()
		await foto("forja-acesso")
	p1.position = Vector2(816,244)
	await quadros()
	verificar("porta exterior oferece interação ao se aproximar",vila.get_node("Porta_carpintaria").disponivel_para_interacao())
	vila.get_node("Porta_carpintaria")._atravessar(p1)
	await create_timer(1.0).timeout
	verificar("entrada própria abre a casa da família",current_scene.scene_file_path.ends_with("carpintaria.tscn"))
	await testar_interior()
	await testar_coop()
	print("FALHAS: ",falhas)
	quit(falhas)

func testar_interior() -> void:
	var casa = current_scene
	casa.get_node("Iluminacao").definir_hora(9)
	casa.get_node("Iluminacao").set_process(false)
	var planta: Dictionary = casa.get_node("Interior/Sala").geometria
	var quartos: Array = planta.areas.filter(func(a): return a.nome.begins_with("quarto_"))
	verificar("três quartos separados, sala e cozinha",quartos.size()==3 and planta.areas.any(func(a): return a.nome=="sala") and planta.areas.any(func(a): return a.nome=="cozinha"))
	var dados: Dictionary = load("res://codigo/cidade/interior_casa.gd").dados().casas.carpintaria
	verificar("cada morador tem sua cama no próprio quarto",dados.itens.filter(func(i): return i.p=="cama").size()==3 and casa.get_node("Interior").find_children("Cama*","Node2D",false,false).size()==3)
	var helena = casa.moradores.helena
	helena.collision_mask = 64
	var acessivel := true
	for fim in [Vector2(104,136),Vector2(304,136),Vector2(512,136),Vector2(480,476),Vector2(264,400)]:
		var rota: PackedVector2Array = casa.caminho_morador(casa.get_node("Chegada_entrada").position,fim,"helena")
		if rota.size()<2 or rota[-1].distance_to(fim)>16: acessivel = false
		for i in range(1,rota.size()):
			if helena.test_move(Transform2D(0,rota[i-1]),rota[i]-rota[i-1]): acessivel = false
	verificar("cadeira alcança todos os quartos, cozinha e oficina",acessivel)
	verificar("posição da planta antiga não prende continuação numa parede",casa.ajustar_posicao_continuacao(Vector2(264,270))==casa.get_node("Chegada_entrada").position)
	root.content_scale_size = Vector2i(640,560)
	root.size = Vector2i(1280,1120)
	var camera: Camera2D = casa.get_node("Jogador").camera
	camera.zoom = Vector2.ONE
	camera.set_as_top_level(true)
	camera.global_position = Vector2(320,280)
	sem_hud()
	await foto("interior-completo")
	var familia = load("res://codigo/cidade/familia_carpinteiro.gd")
	verificar("descanso usa três quartos distintos",familia.agenda("osvaldo",23,0,0).ponto!=familia.agenda("helena",23,0,0).ponto and familia.agenda("helena",23,0,0).ponto!=familia.agenda("clara",23,0,0).ponto)
	var ui = casa.get_node("Interface")
	ui._abrir_tela("mapa_mundi")
	await quadros()
	var mapa = ui._telas.mapa_mundi
	verificar("mapa mostra a casa e os três moradores",mapa._servicos.has("carpintaria") and mapa._atores.npc_osvaldo.visible and mapa._atores.npc_helena.visible and mapa._atores.npc_clara.visible)
	verificar("jogador dentro da casa fica marcado no terreno correto",mapa._atores.p1.visible and mapa._atores.p1.get_meta("ponto_carta").x>0.8)
	await foto("mapa-atualizado")
	ui._fechar_tela("mapa_mundi")

func testar_coop() -> void:
	root.get_node("Saves").trocar("coop")
	root.get_node("Introducao").pular_prologo()
	root.get_node("Transicao").hora_salva = 9
	root.content_scale_size = Vector2i(576,324)
	root.size = Vector2i(1152,648)
	change_scene_to_file("res://cenas/cidade.tscn")
	await quadros(40)
	var coop = root.get_node("Cooperativo")
	var p1 = coop._jogador1()
	var p2 = coop.jogador2()
	coop.viajar_local(p2,"res://cenas/cidade/carpintaria.tscn","entrada")
	await quadros(40)
	verificar("P2 entra em casa enquanto P1 permanece na vila",coop.cena_de(p1).local=="cidade" and coop.cena_de(p2).local=="carpintaria")
	coop.cena_de(p2).get_node("Saida").abrir_tela_p2()
	await quadros(40)
	verificar("saída cooperativa retorna à fachada nova",coop.cena_de(p2).local=="cidade" and p2.position.distance_to(Vector2(816,266))<3)
