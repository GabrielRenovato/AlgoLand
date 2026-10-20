extends SceneTree

var falhas := 0
var capturar := false
var Criacao: GDScript
var Familia: GDScript
func _initialize() -> void: rodar.call_deferred()
func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ",nome)
	if not ok: falhas += 1
func quadros(n := 8) -> void:
	for i in n:
		await process_frame
		await physics_frame
func foto(nome: String) -> void:
	if not capturar: return
	await quadros(2)
	await RenderingServer.frame_post_draw
	var pasta := "res://arte/previas/obras/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(pasta))
	root.get_texture().get_image().save_png(pasta+nome+".png")
func simular(npc: Node2D, passos := 2400) -> void:
	for i in passos:
		npc._physics_process(1.0/60)
		root.get_node("Cidade").tempo_moradores += 1.0/60
		if i%30 == 0: await physics_frame
		if npc.caminho.is_empty() and not npc._saindo: break
func carregar(caminho: String, hora: float) -> void:
	root.get_node("Transicao").hora_salva = hora
	change_scene_to_file(caminho)
	await quadros(30)
	current_scene.get_node("Iluminacao").definir_hora(hora)
	current_scene.get_node("Iluminacao").set_process(false)
	if capturar:
		for hud in get_nodes_in_group("hud"):
			if root.get_node("Cooperativo").cena_de(hud) == current_scene: hud.hide()
func rodar() -> void:
	await process_frame
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"): quit(1); return
	Criacao = load("res://codigo/fazenda/criacao_galinhas.gd")
	Familia = load("res://codigo/cidade/familia_carpinteiro.gd")
	capturar = "--capturar" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless"
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = Vector2i(576,324)
	root.size = Vector2i(1152,648)
	root.get_node("Introducao").pular_prologo()
	var fazenda := root.get_node("Fazenda")
	var cidade := root.get_node("Cidade")
	var calendario := root.get_node("Calendario")
	fazenda.apagar()
	cidade.apagar()
	calendario.dia = 1
	await carregar("res://cenas/cidade/carpintaria.tscn",9)
	var jogador := current_scene.get_node("Jogador")
	var npc: Node2D = current_scene.moradores.osvaldo
	var inv: Node = jogador.inventario
	inv.limpar()
	verificar("sem materiais não começa obra",Criacao.executar(fazenda,jogador,"construir") != "" and fazenda.galinheiro.obra == 0)
	for material in ["madeira","pedra","ferro"]: inv.adicionar_coletavel("material",material,100)
	verificar("contrato retira materiais e registra prazo de dois dias",Criacao.executar(fazenda,jogador,"construir") == "" and fazenda.galinheiro.pronto_dia == 3 and inv.quantidade_tipo("material:madeira") == 88)
	verificar("nova tentativa não cobra novamente",Criacao.executar(fazenda,jogador,"construir") != "" and inv.quantidade_tipo("material:madeira") == 88)
	npc.atualizar_rotina()
	verificar("contratação faz Osvaldo sair da oficina rumo à fazenda",npc.agenda.local == "fazenda" and npc._saindo and not npc.caminho.is_empty())
	npc.set_physics_process(false)
	await simular(npc,2000)
	verificar("sai pela porta sem atravessar a casa",not npc.visible)
	await carregar("res://cenas/cidade.tscn",9)
	npc = current_scene.moradores.osvaldo
	npc.set_physics_process(false)
	await simular(npc,4000)
	verificar("trajeto na vila alcança passagem da fazenda",not npc.visible and cidade.trajetos_moradores.osvaldo.fase == "chegou")
	await carregar("res://cenas/fazenda.tscn",9)
	var ambiente := current_scene.get_node("ObraCarpinteiro")
	npc = ambiente.moradores.osvaldo
	npc.set_physics_process(false)
	verificar("fazenda usa o mesmo Osvaldo da rotina",npc.visible and npc.agenda.local == "fazenda")
	var rota: PackedVector2Array = ambiente.caminho_morador(ambiente.porta_do_local("cidade"),npc.agenda.ponto,"osvaldo")
	verificar("há rota navegável da entrada até a obra",rota.size() > 2)
	npc.position = ambiente.porta_do_local("cidade")
	npc._ir_ate(npc.agenda.ponto)
	await simular(npc,5000)
	verificar("caminhada real chega ao trabalho",npc.caminho.is_empty() and npc.position.distance_to(npc._alvo) < 18)
	var trabalho := npc.get_node("TrabalhoCarpinteiro")
	await quadros()
	verificar("obra anima braços e martelo, com caminhada escondida",trabalho.martelando and not npc.sprite.visible)
	var poses := {}
	for i in 6:
		trabalho._process(.13)
		poses[trabalho._sprite.frame] = true
	verificar("seis fases distintas no ciclo de trabalho",poses.size() >= 5)
	if capturar:
		trabalho.set_process(false)
		for fase in 6:
			trabalho._tempo = fase/8.0
			trabalho._process(0)
			await foto("martelo-%d" % fase)
		trabalho.set_process(true)
	cidade.conversar("osvaldo",current_scene.get_node("Jogador"))
	await quadros()
	verificar("conversa pausa ferramenta",not trabalho.martelando and npc.sprite.visible)
	current_scene.get_node("Interface")._fechar_tela("conversa_cidade")
	await quadros()
	verificar("despedida retoma construção",trabalho.martelando)
	# Render real dos três estágios, das quatro estações e das duas ampliações.
	var galinheiro := current_scene.get_node("Galinheiro")
	var luz := current_scene.get_node("Iluminacao")
	var estacoes := current_scene.get_node("Terrains/Estacoes")
	var camera: Camera2D = current_scene.get_node("Jogador").camera
	camera.position = camera.to_local(Vector2(205,185))
	for nivel in range(1,4):
		for estacao in 4:
			estacoes.definir_estacao(estacao,true)
			galinheiro._estacao_mudou(estacao)
			for etapa in 3:
				fazenda.galinheiro.nivel = nivel-1
				fazenda.galinheiro.obra = nivel
				fazenda.galinheiro.inicio_obra = 1
				fazenda.galinheiro.pronto_dia = 3
				calendario.dia = 2 if etapa == 2 else 1
				luz.definir_hora(16 if etapa > 0 else 8)
				galinheiro._atualizar()
				await quadros(2)
				verificar("nível%d/estação%d/etapa%d carrega e mantém base" % [nivel,estacao,etapa],galinheiro.obra.texture != null and galinheiro._etapa_atual == etapa and galinheiro.obra.position == Vector2(-112,-144))
				verificar("porta preservada durante ampliação",galinheiro.imagem.visible == (nivel > 1) and galinheiro.portinha.visible == (nivel > 1))
				await foto("nivel%d-estacao%d-etapa%d" % [nivel,estacao,etapa])
	# Noite congela a obra e manda o ator para casa; fim do prazo é independente da visita.
	fazenda.galinheiro.nivel = 0
	fazenda.galinheiro.obra = 1
	fazenda.galinheiro.inicio_obra = 1
	fazenda.galinheiro.pronto_dia = 3
	calendario.dia = 2
	verificar("etapa não avança fora do expediente",Criacao.progresso_obra(fazenda.galinheiro,1,17) == Criacao.progresso_obra(fazenda.galinheiro,1,23))
	luz.definir_hora(17)
	npc.atualizar_rotina()
	await quadros()
	verificar("às 17h guarda martelo e parte para casa",not trabalho.martelando and npc._saindo and npc.agenda.local == "carpintaria")
	await simular(npc,5000)
	verificar("sai da fazenda pela passagem",not npc.visible)
	verificar("às 22h a agenda usa a cama do Osvaldo",Familia.agenda("osvaldo",22,0,0).get("dormindo",false))
	var antigo: Dictionary = Criacao.ler({"nivel":1,"obra":2,"pronto_dia":20})
	verificar("save antigo preserva o prazo contratado",antigo.pronto_dia == 20 and antigo.inicio_obra == 18)
	fazenda.galinheiro.ultimo_dia = 1
	Criacao.avancar(fazenda,2)
	verificar("não entrega antes do prazo",fazenda.galinheiro.nivel == 0 and fazenda.galinheiro.obra == 1)
	fazenda.salvar()
	fazenda.carregar()
	verificar("recarregar preserva data de início e prazo",fazenda.galinheiro.inicio_obra == 1 and fazenda.galinheiro.pronto_dia == 3)
	Criacao.avancar(fazenda,3)
	verificar("obra termina no dia contratado, mesmo fora do mapa",fazenda.galinheiro.nivel == 1 and fazenda.galinheiro.obra == 0)
	verificar("conclusão devolve rotina da oficina",Familia.agenda("osvaldo",9,0,0).local == "carpintaria")
	await carregar("res://cenas/cidade.tscn",17)
	npc = current_scene.moradores.osvaldo
	npc.set_physics_process(false)
	await simular(npc,5000)
	verificar("volta pela vila até a própria casa",not npc.visible)
	await carregar("res://cenas/cidade/carpintaria.tscn",22)
	npc = current_scene.moradores.osvaldo
	verificar("à noite aparece dormindo na própria cama",npc.visible and npc.dormindo and not npc.sprite.visible)
	verificar("cabeça apoiada no travesseiro, sem flutuar no encosto",npc.position.is_equal_approx(Vector2(64,72)))
	current_scene.get_node("Jogador").position = Vector2(100,170)
	current_scene.get_node("Jogador").camera.reset_smoothing()
	await quadros()
	await foto("osvaldo-dormindo")
	# Duas áreas abertas: o morador tem uma só presença, compartilhada entre os jogadores.
	root.get_node("Saves").trocar("coop")
	fazenda.galinheiro = Criacao.inicial()
	fazenda.galinheiro.obra = 1
	fazenda.galinheiro.inicio_obra = calendario.dia
	fazenda.galinheiro.pronto_dia = calendario.dia+2
	cidade.trajetos_moradores.clear()
	await carregar("res://cenas/fazenda.tscn",9)
	var coop := root.get_node("Cooperativo")
	var p1: Node2D = coop._jogador1()
	var p2: Node2D = coop.jogador2()
	coop.viajar_local(p2,"res://cenas/cidade/carpintaria.tscn","entrada")
	await quadros(40)
	var visiveis := 0
	for ator in get_nodes_in_group("moradores_cidade"):
		if ator.id == "osvaldo" and ator.visible: visiveis += 1
	verificar("coop mantém apenas um carpinteiro entre fazenda e oficina",visiveis == 1 and coop.cena_de(p1).scene_file_path.ends_with("fazenda.tscn") and coop.cena_de(p2).scene_file_path.ends_with("carpintaria.tscn"))
	var oficina: Node = coop.cena_de(p2)
	oficina.get_node("Interior/Atendimento").abrir_tela_p2()
	await quadros()
	verificar("consultar oficina vazia não interrompe o trabalho na outra tela",not cidade.em_conversa("osvaldo"))
	coop.interface_p2()._fechar_tela("conversa_cidade")
	p2.set_physics_process(false)
	coop.sair()
	print("FALHAS: ",falhas)
	quit(1 if falhas else 0)
