extends SceneTree
var Mineracao: GDScript
class ColetorFora extends Node2D:
	var estaMorto := false

var falhas := 0
var mineracao: Node
var jogador: Node
var inv: Node
func _initialize() -> void: rodar.call_deferred()
func quadros(n := 8) -> void:
	for i in n:
		await physics_frame
		await process_frame
func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ",nome)
	if not ok: falhas+=1
func golpe() -> void:
	jogador._pedido_ataque=true
	jogador.logica_combo_ataque()
	for i in 80:
		await physics_frame
		if not jogador.esta_em_acao_fazenda: break
func mirar(veio: Node2D, quem: Node = jogador) -> void:
	quem.global_position=veio.global_position-Vector2(0,29)
	quem._direcao_ataque=Vector2.DOWN
	quem.z_index=preload("res://codigo/globais/profundidade.gd").z_de(quem.global_position.y+11)
func foto(nome: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await quadros()
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://arte/previas/mineracao_arena")
	root.get_texture().get_image().save_png("res://arte/previas/mineracao_arena/"+nome+".png")
func rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name","")).begins_with("AlgoLand testes"):
		quit(1)
		return
	await process_frame
	Mineracao=load("res://codigo/logica/mineracao_arena.gd")
	if OS.get_cmdline_user_args().has("--somente-coop"):
		root.get_node("Introducao").pular_prologo()
		await coop()
		print("Mineracao coop: %d falhas" % falhas)
		quit(1 if falhas else 0)
		return
	root.get_node("Saves").trocar("solo")
	root.get_node("Introducao").pular_prologo()
	var prog = root.get_node("Progresso")
	prog.apagar()
	inv=root.get_node("InventarioJogador")
	inv.limpar()
	inv.criar_itens_iniciais()
	root.get_node("Transicao").limpar()
	preload("res://codigo/globais/opcoes_jogo.gd").fechar_mini_tutorial()
	verificar("minerio tem progressao de onda e recompensa pequena",Mineracao.recompensa(5)==0 and Mineracao.recompensa(6)==1 and Mineracao.recompensa(9)==1 and Mineracao.recompensa(10)==0 and Mineracao.recompensa(20)==0 and Mineracao.recompensa(21)==2)
	verificar("pedras da fazenda nao dao minerio",not preload("res://codigo/dados/forja_armas.gd").extracao("pedra").has("ferro"))
	root.content_scale_size=Vector2i(576,324)
	change_scene_to_file("res://cenas/cenario.tscn")
	await quadros(35)
	var gerenciador = current_scene.get_node("enemySpawner/GerenciadorOndas")
	gerenciador.parar_ondas()
	jogador=current_scene.get_node("Jogador")
	jogador.set_physics_process(false)
	mineracao=current_scene.get_node("MineracaoArena")
	gerenciador.onda_iniciada.emit(5)
	await quadros()
	verificar("ondas iniciais nao criam veios",mineracao._veios.is_empty())
	gerenciador.onda_atual=6
	gerenciador.onda_iniciada.emit(6)
	await quadros()
	verificar("onda 6 cria um veio em area caminhavel",mineracao._veios.size()==1)
	if mineracao._veios.is_empty(): quit(1); return
	var veio: Node2D=mineracao._veios.values()[0]
	if OS.get_cmdline_user_args().has("--somente-navegacao"):
		await conferir_navegacao(veio)
		current_scene.queue_free()
		current_scene=null
		await quadros()
		print("Navegacao do veio: %d falhas" % falhas)
		quit(1 if falhas else 0)
		return
	await conferir_profundidade(veio)
	if OS.get_cmdline_user_args().has("--somente-profundidade"):
		current_scene.queue_free()
		current_scene=null
		await quadros()
		print("Profundidade: %d falhas" % falhas)
		quit(1 if falhas else 0)
		return
	mirar(veio)
	var hud = get_first_node_in_group("hud_p1")
	verificar("energia da mineracao esta visivel",hud.barra_energia!=null and hud.barra_energia.visible)
	var barra = hud.barra_armas
	var picareta = inv.buscar_por_tipo("picareta")
	var indice: int=inv.indice_de(picareta)
	barra._fileira=indice/inv.COLUNAS_MOCHILA
	barra._atualizar()
	var arma = inv.equipados.arma
	verificar("barra seleciona picareta sem trocar equipamento",barra.escolher(indice%inv.COLUNAS_MOCHILA) and jogador.picareta_arena_ativa and inv.equipados.arma==arma)
	var energia: int=root.get_node("Fazenda").energia_de(1)
	await golpe()
	verificar("golpe real usa animacao e energia sem dano de arma",mineracao._veios.size()==1 and prog.veios_arena["6"][0].golpes==1 and inv.quantidade_tipo("material:ferro")==0 and root.get_node("Fazenda").energia_de(1)==energia-2 and not jogador._esta_atacando)
	await golpe()
	verificar("segundo golpe ainda nao entrega ferro",mineracao._veios.size()==1 and prog.veios_arena["6"][0].golpes==2)
	await mineracao.preparar_onda(6)
	await quadros()
	verificar("recriar a mesma onda preserva golpes parciais",prog.veios_arena["6"][0].golpes==2)
	for i in inv.capacidade():
		if inv.item_na_celula(i)==null: inv.mochila[i]=inv._criar_item({"tipo":"espada_basica","categoria":"arma","duas_maos":false})
	await golpe()
	await quadros()
	var drops: Array=get_nodes_in_group("equipamento_drop").filter(func(d): return d.item.tipo=="material:ferro")
	verificar("ultimo golpe cria drop fisico e mochila cheia o mantem no chao",mineracao._veios.is_empty() and drops.size()==1 and drops[0].item.quantidade==1 and inv.quantidade_tipo("material:ferro")==0)
	inv.mochila[inv.capacidade()-1]=null
	for drop in drops: drop._tentar_pegar()
	verificar("ferro coletado ocupa mochila",inv.quantidade_tipo("material:ferro")==1)
	await mineracao.preparar_onda(6)
	await quadros()
	verificar("mesma onda nao recria veio extraido",mineracao._veios.is_empty())
	# Recriar a cena representa viajar ate a vila e voltar na mesma partida.
	root.get_node("Transicao").retornando=true
	root.get_node("Transicao").estado={"onda_atual":6}
	change_scene_to_file("res://cenas/cenario.tscn")
	await quadros(35)
	mineracao=current_scene.get_node("MineracaoArena")
	jogador=current_scene.get_node("Jogador")
	jogador.set_physics_process(false)
	verificar("viajar nao duplica ferro minerado",mineracao._veios.is_empty() and prog.veios_arena["6"][0].extraido)
	await mineracao.preparar_onda(21)
	await quadros()
	verificar("ondas altas mantem apenas um veio solo",mineracao._veios.size()==1)
	veio=mineracao._veios.values()[0]
	mirar(veio)
	jogador.picareta_arena_ativa=true
	get_first_node_in_group("hud_p1").barra_armas._atualizar()
	var estacoes=current_scene.get_node("Terrains/Estacoes")
	for estacao in 4:
		estacoes.definir_estacao(estacao,true)
		mineracao._trocar_estacao(estacao)
		await quadros()
		verificar("veio integrado a estacao "+str(estacao),veio.get_node("Pedra").texture.resource_path.ends_with(Mineracao.ESTACOES[estacao]+".png"))
		await foto(Mineracao.ESTACOES[estacao])
	root.content_scale_size=Vector2i(288,216)
	await foto("mobile")
	root.content_scale_size=Vector2i(576,324)
	await quadros()
	root.get_node("Fazenda")._definir_energia(1,100)
	var antes_rico: int=inv.quantidade_tipo("material:ferro")
	await golpe()
	await golpe()
	await golpe()
	verificar("veio rico exige quatro impactos",mineracao._veios.size()==1 and prog.veios_arena["21"][0].golpes==3)
	await golpe()
	await quadros(15)
	var ferro_no_chao := 0
	for drop in get_nodes_in_group("equipamento_drop"):
		if drop.item.tipo=="material:ferro": ferro_no_chao+=drop.item.quantidade
	verificar("veio rico rende exatamente dois ferros fisicos",mineracao._veios.is_empty() and inv.quantidade_tipo("material:ferro")-antes_rico+ferro_no_chao==2)
	await mineracao.preparar_onda(24)
	await quadros()
	mirar(mineracao._veios.values()[0])
	jogador.invulneravel=false
	var vida: int=jogador.hp_atual
	verificar("mineracao inicia antes do risco",mineracao.pedir_golpe(jogador))
	jogador.receber_dano(2)
	await create_timer(0.7).timeout
	verificar("dano interrompe a picareta antes do impacto",jogador.hp_atual<vida and not jogador.esta_em_acao_fazenda and prog.veios_arena["24"][0].golpes==0)
	root.get_node("Fazenda")._definir_energia(1,0)
	verificar("sem energia nao inicia nem entrega minerio",not mineracao.pedir_golpe(jogador) and not jogador.esta_em_acao_fazenda and prog.veios_arena["24"][0].golpes==0)
	prog.iniciar_partida()
	verificar("nova partida renova veios e preserva ferro coletado",prog.veios_arena.is_empty() and inv.quantidade_tipo("material:ferro")>=1)
	current_scene.queue_free()
	current_scene=null
	await quadros()
	await coop()
	print("Mineracao arena: %d falhas" % falhas)
	quit(1 if falhas else 0)

func coop() -> void:
	root.get_node("Saves").trocar("coop")
	root.get_node("Progresso").apagar()
	for nome in ["InventarioJogador","InventarioJogador2"]:
		var mochila=root.get_node(nome)
		mochila.limpar()
		mochila.criar_itens_iniciais()
	var cooperativo=root.get_node("Cooperativo")
	cooperativo.dispositivo_p1=cooperativo.SEM_CONTROLE
	cooperativo.dispositivo_p2=40
	cooperativo._reconfigurar_entrada()
	root.get_node("Transicao").limpar()
	change_scene_to_file("res://cenas/cenario.tscn")
	await quadros(40)
	current_scene.get_node("enemySpawner/GerenciadorOndas").parar_ondas()
	mineracao=current_scene.get_node("MineracaoArena")
	jogador=cooperativo.jogador2()
	var p1=cooperativo._jogador1()
	jogador.set_physics_process(false)
	p1.set_physics_process(false)
	await mineracao.preparar_onda(9)
	await quadros()
	verificar("coop cria um veio por jogador",mineracao._veios.size()==2)
	if mineracao._veios.is_empty(): return
	mirar(mineracao._veios.values()[0])
	inv=root.get_node("InventarioJogador2")
	var inv1=root.get_node("InventarioJogador")
	var barra=get_first_node_in_group("hud_p2").barra_armas
	var indice: int=inv.indice_de(inv.buscar_por_tipo("picareta"))
	barra._fileira=indice/inv.COLUNAS_MOCHILA
	barra._atualizar()
	verificar("P2 seleciona picareta pela propria barra",barra.escolher(indice%inv.COLUNAS_MOCHILA) and jogador.picareta_arena_ativa and not p1.picareta_arena_ativa)
	var fazenda=root.get_node("Fazenda")
	fazenda._definir_energia(1,100)
	fazenda._definir_energia(2,100)
	await golpe()
	await golpe()
	await golpe()
	await create_timer(1.0).timeout
	print("COLETA P1=",inv1.quantidade_tipo("material:ferro")," P2=",inv.quantidade_tipo("material:ferro")," veios=",mineracao._veios.size()," registro=",root.get_node("Progresso").veios_arena," drops=",get_nodes_in_group("equipamento_drop").size())
	verificar("P2 coleta na propria mochila sem duplicar",inv.quantidade_tipo("material:ferro")==1 and inv1.quantidade_tipo("material:ferro")==0 and mineracao._veios.size()==1)
	verificar("P2 gasta somente sua energia",fazenda.energia_de(2)==94 and fazenda.energia_de(1)==100)
	var vista := SubViewport.new()
	vista.world_2d=World2D.new()
	root.add_child(vista)
	var fora := ColetorFora.new()
	vista.add_child(fora)
	fora.add_to_group("jogadores")
	var drop=load("res://codigo/logica/drops_forja.gd").soltar_material("ferro",1,jogador.global_position+Vector2(0,12),current_scene)
	fora.global_position=drop.global_position
	verificar("jogador em outro mapa nao atrai o minerio",drop._jogador()==jogador)
	drop.queue_free()
	fora.free()
	vista.queue_free()
	await foto("coop")
	current_scene.queue_free()
	current_scene=null
	await quadros()

func imagem() -> Image:
	await quadros(3)
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func conferir_profundidade(veio: Node2D) -> void:
	var colisao := KinematicCollision2D.new()
	var inicio := Transform2D(0,veio.global_position-Vector2(0,29))
	var bloqueia: bool = jogador.test_move(inicio,Vector2(0,35),colisao)
	verificar("base do veio impede atravessar a pedra",bloqueia and colisao.get_collider()==veio)
	if DisplayServer.get_name()=="headless": return
	var camera: Camera2D=jogador.camera
	camera.top_level=true
	camera.position_smoothing_enabled=false
	camera.global_position=veio.global_position
	camera.force_update_scroll()
	var iluminacao=current_scene.get_node_or_null("Iluminacao")
	if iluminacao!=null:
		iluminacao.set_process(false)
		iluminacao.definir_hora(12)
	for clima in get_nodes_in_group("clima"):
		clima.definir_clima(0,true)
	# A luz presa ao jogador mudaria a cor da pedra entre a referencia e o jogador visivel.
	for luz in current_scene.find_children("*","PointLight2D",true,false): luz.enabled=false
	var sprite: Sprite2D=veio.get_node("Pedra")
	var original: Image=sprite.texture.get_image()
	var transformacao: Transform2D=root.get_final_transform()*sprite.get_global_transform_with_canvas()
	jogador.hide()
	var referencia: Image=await imagem()
	jogador.show()
	jogador.global_position=veio.global_position-Vector2(0,27)
	jogador.z_index=preload("res://codigo/globais/profundidade.gd").z_de(jogador.global_position.y+11)
	var atras: Image=await imagem()
	jogador.global_position=veio.global_position+Vector2(0,8)
	jogador.z_index=preload("res://codigo/globais/profundidade.gd").z_de(jogador.global_position.y+11)
	var frente: Image=await imagem()
	var alterados_atras := 0
	var alterados_frente := 0
	for y in original.get_height():
		for x in original.get_width():
			if original.get_pixel(x,y).a<0.99: continue
			var tela: Vector2=transformacao*Vector2(x+0.5,y+0.5)
			var pixel := Vector2i(tela.floor())
			if not Rect2i(Vector2i.ZERO,referencia.get_size()).has_point(pixel): continue
			var cor:=referencia.get_pixelv(pixel)
			if atras.get_pixelv(pixel)!=cor: alterados_atras+=1
			if frente.get_pixelv(pixel)!=cor: alterados_frente+=1
	print("SOBREPOSICAO atras=",alterados_atras," frente=",alterados_frente," transformacao=",transformacao)
	referencia.save_png("/tmp/algoland-mineracao-referencia.png")
	verificar("render real cobre o jogador atras da pedra",alterados_atras==0)
	verificar("render real poe jogador da frente diante da pedra",alterados_frente>10)
	DirAccess.make_dir_recursive_absolute("res://arte/previas/mineracao_arena")
	atras.save_png("res://arte/previas/mineracao_arena/profundidade_atras.png")
	frente.save_png("res://arte/previas/mineracao_arena/profundidade_frente.png")
	camera.top_level=false
	camera.position=Vector2.ZERO
	camera.force_update_scroll()

func conferir_navegacao(veio: Node2D) -> void:
	jogador.global_position=veio.global_position-Vector2(0,40)
	jogador.invulneravel=true
	var inimigo=load("res://cenas/inimigos/slime.tscn").instantiate()
	current_scene.add_child(inimigo)
	inimigo.global_position=veio.global_position+Vector2(0,35)
	var contornou := false
	for i in 300:
		await physics_frame
		if inimigo.global_position.y < veio.global_position.y-14:
			contornou=true
			break
	verificar("inimigo de chao contorna o veio dinamico sem ficar preso",contornou)
	inimigo.queue_free()
