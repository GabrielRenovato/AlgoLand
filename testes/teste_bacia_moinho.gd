extends SceneTree
## Percurso da Bacia em save descartável: puzzle, guardião, subsolo e guia.
var falhas := 0
var cena: Node2D
var capturas := "res://capturas-bacia"
func _initialize() -> void: rodar.call_deferred()
func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ", nome)
	if not ok: falhas += 1
func quadros(n := 4) -> void:
	for i in n:
		await process_frame
		await physics_frame
func foto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	verificar("captura " + nome, root.get_texture().get_image().save_png(capturas.path_join(nome + ".png")) == OK)
func rodar() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes") or DisplayServer.get_name() == "headless":
		quit(1)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capturas="): capturas = arg.trim_prefix("--capturas=")
	DirAccess.make_dir_recursive_absolute(capturas)
	var catalogo := preload("res://codigo/campanha/catalogo_campanha.gd").dados()
	verificar("catalogo da campanha valido", preload("res://codigo/campanha/catalogo_campanha.gd").validar(catalogo))
	var progresso := preload("res://codigo/campanha/progresso_campanha.gd").new()
	verificar("save isolado inicia", progresso.iniciar("user://percurso_primeira_raiz", "prototipo") == OK)
	for missao in ["sobreviver_queda", "estrada_interrompida", "acolhimento", "pomar_sulcos", "defesa_da_vila"]:
		for objetivo in catalogo.missoes[missao].objetivos:
			verificar("prepara requisito " + missao + ":" + objetivo.id, progresso.registrar_objetivo(missao, objetivo.id) == OK)
	progresso.recompensas = progresso._concluidas.duplicate()
	progresso.salvar_retorno("moinho", Vector2(-704, 420))
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = Vector2i(576, 324)
	root.size = Vector2i(1152, 648)
	set_meta("dicas_vistas", {"golpe": true, "rebento": true})
	set_meta("campanha_destino", "moinho")
	set_meta("campanha_nova_instancia", true)
	change_scene_to_file("res://cenas/campanha/percurso_prototipo.tscn")
	await quadros(60)
	cena = current_scene
	if not is_instance_valid(cena) or not is_instance_valid(cena.terreno):
		verificar("cena da Bacia carrega", false)
		quit(1)
		return
	var mapa: Node2D = cena.terreno
	var roteiro: Node = mapa.roteiro
	cena.jogador.invulneravel = true
	cena.jogador.set_physics_process(false)
	verificar("quarto estagio abre na Bacia", cena.regiao == "moinho" and is_instance_valid(roteiro))
	verificar("pontes e moinho preservam montagem modular atual", mapa._construcoes.pontes_3d.size()==2 and is_instance_valid(mapa._roda_moinho.modelo))
	var roda:Node2D=mapa._roda_moinho
	roda.instante_forcado=0.0;roda._process(0.0)
	var pivo:Vector3=roda.modelo._roda.position
	var raio_inicial:Vector3=roda.modelo._roda.to_global(Vector3(0,0,1))
	roda.instante_forcado=TAU/0.32;roda._process(0.0)
	verificar("roda gira sem deslocar eixo",roda.modelo._roda.position.distance_to(pivo)<0.001)
	verificar("giro da roda fecha o ciclo",roda.modelo._roda.to_global(Vector3(0,0,1)).distance_to(raio_inicial)<0.001)
	roda.instante_forcado = -1.0
	verificar("construcao antiga inteira foi substituida", not mapa._pecas.has("moinho") and not mapa._pecas.has("arco_entrada_dungeon"))
	verificar("transmissao nao avanca antes da pista", not roteiro.interagir("comporta_moinho").is_empty())
	verificar("pista da margem avanca", cena.controlador.interagir("investigar", "margem_secura") == OK)
	verificar("transmissao revela bloqueio interno", cena.controlador.interagir("investigar", "comporta_moinho") == OK)
	verificar("inspecao externa nao devolve agua", mapa._vazao_canais.z == 0)
	verificar("roda revela a entrada", cena.controlador.interagir("investigar", "roda_moinho") == OK)
	verificar("eixo examinado nao abre a comporta", not "dungeon" in roteiro.cumpridos() and mapa._vazao_canais.z == 0)
	var guia: Node = cena.get_children().filter(func(n): return n.has_method("_alvo_atual"))[0]
	var tutorial: Control = cena.hud.get_node_or_null("MiniTutorial")
	if is_instance_valid(tutorial) and tutorial.is_visible_in_tree():
		var para_guia: Transform2D = guia._desenho.get_global_transform_with_canvas().affine_inverse() * tutorial._painel.get_global_transform_with_canvas()
		var painel: Rect2 = para_guia * Rect2(Vector2.ZERO, tutorial._painel.size)
		verificar("seta respeita margem do painel de controles", guia._area_livre().end.x <= painel.position.x - 16.0)
	verificar("seta usa entrada central", guia._alvo_atual().get("base") == cena.alvos.entrada_dungeon.no.global_position)
	var sonda := CharacterBody2D.new()
	sonda.collision_layer = 2
	sonda.collision_mask = 64
	var forma := CollisionShape2D.new()
	var circulo := CircleShape2D.new()
	circulo.radius = 5
	forma.shape = circulo
	sonda.add_child(forma)
	cena.add_child(sonda)
	await quadros()
	for travessia in mapa._travessias:
		var vertical: bool = travessia.size.y > travessia.size.x
		sonda.position = travessia.get_center() - (Vector2(0, travessia.size.y * 0.5 - 6) if vertical else Vector2(travessia.size.x * 0.5 - 6, 0))
		var movimento := Vector2(0, travessia.size.y - 12) if vertical else Vector2(travessia.size.x - 12, 0)
		verificar("travessia completa sem colisao invisivel " + str(vertical), not sonda.test_move(sonda.global_transform, movimento))
	sonda.position = Vector2(-464, -280)
	verificar("fachada bloqueia passagem pelo moinho", sonda.test_move(sonda.global_transform, Vector2(0, -48)))
	verificar("objetivo do eixo permanece acessivel pela frente", not sonda.test_move(sonda.global_transform, Vector2(0, -8)))
	sonda.position = Vector2(80, -180)
	verificar("agua bloqueia personagem", sonda.test_move(sonda.global_transform, Vector2(0, -80)))
	sonda.queue_free()
	# As capturas de detalhe incluem um personagem para conferir a escala real.
	cena.jogador.position = Vector2(-448, -272)
	await quadros()
	for estacao in 4:
		mapa.definir_estacao(estacao)
		mapa._atlas_agua[estacao].get_image().save_png(capturas.path_join("atlas-agua-%d.png" % estacao))
		await quadros(3)
		await foto("moinho-estacao-%d" % estacao)
	mapa.definir_estacao(0)
	cena.jogador.position = cena.alvos.entrada_dungeon.no.position
	await quadros(1)
	verificar("interacao real com escadaria", cena.interagir_proximo() == OK)
	await quadros(10)
	verificar("escadaria entra em sala jogavel", roteiro.dentro and roteiro.sala.has_point(cena.jogador.position))
	while not roteiro.dungeon.pronta: await quadros(2)
	verificar("entrada usa gruta ampliada", roteiro.sala.size == Vector2(2784,1856))
	verificar("acampamentos usam objetos independentes com bases fisicas",roteiro.dungeon.objetos.size()>25 and roteiro.dungeon.objetos.all(func(o):return o.has_node("BaseFisica") and o.sprite.texture!=null))
	var barricadas:Array=roteiro.dungeon.objetos.filter(func(o):return o.tipo=="barricada")
	verificar("barricadas reutilizam a mesma textura",barricadas.size()>1 and barricadas[0].sprite.texture==barricadas[1].sprite.texture)
	verificar("portao solto retirado da dungeon",not roteiro.dungeon.objetos.any(func(o):return o.tipo=="comporta"))
	var fogueiras:Array=roteiro.dungeon.objetos.filter(func(o):return o.tipo=="fogueira_panela")
	verificar("cozinha tem fogueiras animadas e mesas com cadeiras",fogueiras.size()==4 and fogueiras.all(func(o):return o.sprite.hframes==4) and roteiro.dungeon.objetos.any(func(o):return o.tipo=="mesa") and roteiro.dungeon.objetos.any(func(o):return o.tipo=="cadeira"))
	verificar("seta acompanha camara final", guia._alvo_atual().get("base") == roteiro.dungeon.alvo_final())
	verificar("Lorde Goblin original protege a alavanca", is_instance_valid(roteiro.dungeon.guardiao) and roteiro.dungeon.guardiao.is_in_group("boss_lorde_goblin") and roteiro.dungeon.guardiao.aguardando_chegada)
	var adagas:=0
	var machados:=0
	for mob in roteiro.dungeon.inimigos:
		mob.set_physics_process(false)
		if mob.scene_file_path.ends_with("goblin_pomar.tscn"):adagas+=1
		elif mob.scene_file_path.ends_with("goblin_machado_fenda.tscn"):machados+=1
	verificar("galerias tem 60 goblins misturados e nenhum morcego", adagas==30 and machados==30)
	var profundidade_correta:=true
	for mob in roteiro.dungeon.inimigos:
		if mob.z_index!=mob.Profundidade.z_de(mob.global_position.y+mob.altura_pes):profundidade_correta=false
	verificar("goblins parados respeitam profundidade dos pes",profundidade_correta)
	# A antecipação do golpe também desviava do processamento da classe base.
	for caminho in ["res://cenas/inimigos/goblin_pomar.tscn","res://cenas/inimigos/goblin_machado_fenda.tscn"]:
		var ator:Node2D=load(caminho).instantiate();ator.ia_habilitada=false
		ator.position=Vector2(4096,400);roteiro.dungeon.add_child(ator)
		await process_frame;await physics_frame
		verificar("profundidade inicial em "+ator.name,ator.z_index==ator.Profundidade.z_de(ator.global_position.y))
		ator.position.y+=40;ator.iniciar_ataque(Vector2.DOWN);ator.ia_habilitada=true
		await physics_frame;await process_frame
		verificar("profundidade durante golpe em "+ator.name,ator.z_index==ator.Profundidade.z_de(ator.global_position.y))
		ator.queue_free()
	var cozinheiros:Array=roteiro.dungeon.inimigos.filter(func(m):return m.get_meta("atividade_acampamento")=="cozinhar")
	verificar("goblins ocupam cozinhas e vigiam passagens",cozinheiros.size()==8 and roteiro.dungeon.inimigos.any(func(m):return m.get_meta("atividade_acampamento")=="vigiar"))
	verificar("cozinheiro permanece voltado a atividade antes de alerta",not cozinheiros[0].ia_habilitada)
	cozinheiros[0].receber_dano(1,Vector2.ZERO)
	await quadros(2)
	verificar("goblin interrompe atividade quando atacado",cozinheiros[0].ia_habilitada)
	var separados:=true
	for mob in roteiro.dungeon.inimigos:
		for outro in roteiro.dungeon.inimigos:
			if mob!=outro and mob.global_position.distance_to(outro.global_position)<31:separados=false
	verificar("goblins espalhados preservam espaco entre si",separados)
	verificar("alavanca nao abre sem derrotar boss", not roteiro.dungeon.abrir() and not roteiro.interagir("entrada_dungeon").is_empty())
	verificar("agua permanece bloqueada na exploracao",mapa._vazao_canais.z==0)
	cena.interface._fechar_tela("introducao")
	var chefe:Node2D=roteiro.dungeon.guardiao
	cena.jogador.global_position=chefe.global_position+Vector2(-85,70)
	await quadros(4)
	verificar("entrada bloqueia combate e pausa mundo",chefe.em_apresentacao and paused)
	var cinema:Node=chefe._chegada
	await create_timer(.9,true).timeout
	await foto("lorde-chegada")
	for tentativa in 80:
		if cinema.fase=="dialogo":break
		await create_timer(.1,true).timeout
	verificar("Lorde chega com diálogo antes da luta",cinema.fase=="dialogo" and cinema.dialogo.visible and not chefe.em_combate)
	var vida_anterior:int=chefe.vida
	chefe.receber_dano(10)
	verificar("chefe protegido durante diálogo",chefe.vida==vida_anterior)
	for medida in [Vector2i(576,324),Vector2i(288,512),Vector2i(320,324)]:
		root.get_node("Controle").usando_toque=medida.x<360
		root.content_scale_size=medida;root.size=medida*2
		await quadros(5)
		cinema.dialogo._digitando.kill();cinema.dialogo._texto.visible_ratio=1.0
		var painel:PanelContainer=cinema.dialogo.painel
		var texto:Label=cinema.dialogo._texto
		verificar("diálogo respeita bordas "+str(medida),texto.get_global_rect().position.x>=painel.get_global_rect().position.x+8 and texto.get_global_rect().end.x<=painel.get_global_rect().end.x-8 and texto.get_line_count()<=texto.get_visible_line_count())
		await foto("lorde-dialogo-%dx%d"%[medida.x,medida.y])
		for pagina in range(1,cinema.dialogo._paginas.size()):
			cinema.dialogo._indice=pagina;cinema.dialogo._mostrar()
			cinema.dialogo._digitando.kill();cinema.dialogo._texto.visible_ratio=1.0
			await quadros(2)
			verificar("fala "+str(pagina+1)+" cabe "+str(medida),texto.get_line_count()<=texto.get_visible_line_count() and texto.get_global_rect().end.y<cinema.dialogo._avancar.get_global_rect().position.y)
			await foto("lorde-dialogo-pagina%d-%dx%d"%[pagina+1,medida.x,medida.y])
		cinema.dialogo._indice=0;cinema.dialogo._mostrar()
	root.content_scale_size=Vector2i(576,324);root.size=Vector2i(1152,648)
	root.get_node("Controle").usando_toque=false
	cinema.dialogo._fechar_fala()
	await create_timer(.6,true).timeout
	verificar("diálogo libera combate e restaura mundo",not paused and chefe.em_combate and not chefe.em_apresentacao)
	chefe._recarga=10.0
	var antes_andada:Vector2=chefe.position
	await create_timer(.65,true).timeout
	verificar("boss caminha ao perseguir no mapa",chefe.position.distance_to(antes_andada)>3 and chefe.sprite.andando)
	await foto("lorde-aproximacao")
	chefe.ia_habilitada=false
	chefe.sprite.definir_andando(false)
	verificar("marcador segue cabeca real do boss",guia._alvo_atual().get("p")==chefe.ponto_marcador() and guia._alvo_atual().get("base")==chefe.global_position)
	for direcao in {"baixo":Vector2.DOWN,"cima":Vector2.UP,"direita":Vector2.RIGHT,"esquerda":Vector2.LEFT}:
		var rumo:Vector2={"baixo":Vector2.DOWN,"cima":Vector2.UP,"direita":Vector2.RIGHT,"esquerda":Vector2.LEFT}[direcao]
		verificar("martelada do chefe inicia "+direcao,chefe.iniciar_ataque("martelada",chefe.global_position+rumo*50))
		verificar("boss usa a direcao2D "+direcao,chefe.sprite.direcao==direcao and chefe.sprite.flip_h==(direcao=="esquerda"))
		await create_timer(.69,true).timeout
		await foto("lorde-martelada-"+direcao)
		chefe.sprite.cancelar_ataque();chefe._fim_ataque()
	# Dissipar os escombros antes de examinar pés e ciclo da caminhada.
	await create_timer(1.0,true).timeout
	chefe.sprite.set_process(false)
	var centro_andada:Vector2=chefe.get_global_transform_with_canvas().origin
	var escala_captura:Vector2=Vector2(root.get_texture().get_size())/root.get_visible_rect().size
	var ficha_andada:=FileAccess.open(capturas.path_join("lorde-andada-enquadramento.json"),FileAccess.WRITE)
	ficha_andada.store_string(JSON.stringify({"centro":[centro_andada.x*escala_captura.x,centro_andada.y*escala_captura.y],"passo_ms":110}))
	ficha_andada.close()
	for direcao in {"baixo":Vector2.DOWN,"cima":Vector2.UP,"direita":Vector2.RIGHT,"esquerda":Vector2.LEFT}:
		var rumo:Vector2={"baixo":Vector2.DOWN,"cima":Vector2.UP,"direita":Vector2.RIGHT,"esquerda":Vector2.LEFT}[direcao]
		chefe.sprite.orientar(rumo);chefe.sprite.definir_andando(true)
		for i in 6:
			chefe.sprite._tempo_andada_ms=float(i*110)
			chefe.sprite._mostrar_andada(i)
			await quadros(1)
			await foto("lorde-andada-%s-%02d"%[direcao,i])
		chefe.sprite.definir_andando(false)
	chefe.sprite.set_process(true)
	await quadros(4)
	await foto("camara-comporta-fechada")
	var folhas:=[]
	for estacao in 4:
		roteiro.dungeon.terreno.get_node("Estacoes").definir_estacao(estacao,true)
		await quadros(3)
		folhas.append(roteiro.dungeon.alavanca.sprite.texture.resource_path)
		await foto("comporta-estacao-%d" % estacao)
	verificar("objetos trocam as quatro estacoes",folhas.size()==4 and folhas[0]!=folhas[1] and folhas[1]!=folhas[2] and folhas[2]!=folhas[3])
	var mapa_nav:=cena.get_world_2d().navigation_map
	var destino:Vector2=roteiro.dungeon.to_global(roteiro.dungeon.PONTO_ALAVANCA+Vector2(0,28))
	var caminho:=NavigationServer2D.map_get_path(mapa_nav,roteiro.dungeon.entrada(),destino,true,1)
	verificar("objetos deixam rota ate alavanca",not caminho.is_empty() and caminho[-1].distance_to(destino)<4)
	# Derrota real do guardião, com o próprio sinal usado pela dungeon.
	roteiro.dungeon.guardiao.liberar_combate()
	roteiro.dungeon.guardiao.receber_dano(100000)
	verificar("seta muda para alavanca apos guardiao",guia._alvo_atual().get("base")==destino)
	verificar("derrota ainda nao solta agua sem interacao",mapa._vazao_canais.z==0)
	verificar("alavanca liberada aceita interacao",roteiro.interagir("entrada_dungeon").is_empty())
	verificar("alavanca registra abertura",cena.controlador.interagir("reparar","entrada_dungeon")==OK)
	verificar("apenas alavanca interna libera corrente e roda",roteiro.dungeon.aberta and mapa._vazao_canais.z>0)
	await foto("camara-comporta-aberta-teste")
	verificar("seta de retorno aponta escada", guia._alvo_atual().get("base") == cena.alvos.saida_regiao.no.global_position)
	roteiro.interagir("saida_regiao")
	verificar("escada devolve jogador ao exterior", not roteiro.dentro and mapa.limites.has_point(cena.jogador.position))
	verificar("distancia e seta compartilham saida", guia._alvo_atual().get("base") == cena.alvos.saida_regiao.no.global_position and guia._distancia_metros(cena.alvos.saida_regiao.no.global_position) == roundi(cena.jogador.position.distance_to(cena.alvos.saida_regiao.no.position) / 16.0))
	# Conferir dois ciclos completos do atlas sob o mesmo relogio compartilhado.
	var camera: Camera2D = cena.jogador.get_node("Camera2D")
	cena.jogador.position = Vector2(80, -180)
	for i in 16:
		await create_timer(0.125).timeout
		await foto("agua-%02d" % i)
	cena.controlador.progresso.tempos_regioes.moinho = 61.0
	verificar("relato continua na vila", cena.controlador.objetivo_atual().id == "relato")
	for medida in [Vector2i(576, 324), Vector2i(288, 512), Vector2i(320, 324)]:
		root.get_node("Controle").usando_toque = medida.x < 360
		root.content_scale_size = medida
		root.size = medida * 2
		await quadros(5)
		verificar("guia conserva area util " + str(medida), guia._area_livre().size.x >= 80)
		await foto("guia-%dx%d" % [medida.x, medida.y])
	var carregamento := preload("res://codigo/campanha/carregamento_campanha.gd").new()
	cena.add_child(carregamento)
	root.content_scale_size = Vector2i(576, 324)
	root.size = Vector2i(1152, 648)
	root.get_node("Controle").usando_toque = false
	carregamento.mostrar("moinho")
	carregamento.definir_progresso(0.8, "PREPARANDO OS CANAIS")
	carregamento._revelar.kill();carregamento._historia.visible_ratio=1
	for medida in [Vector2i(576,324),Vector2i(288,512),Vector2i(320,324)]:
		root.content_scale_size=medida;root.size=medida*2
		await quadros(5)
		verificar("historia cabe no carregamento "+str(medida),carregamento._aviso.get_global_rect().end.y<=carregamento._raiz.get_global_rect().end.y-8 and carregamento._historia.get_line_count()<=carregamento._historia.get_visible_line_count())
		await foto("carregamento-moinho-%dx%d" % [medida.x,medida.y])
	verificar("carregamento usa historia da Bacia", carregamento._id == "moinho")
	carregamento.queue_free()
	print("Bacia: %d falhas" % falhas)
	quit(1 if falhas else 0)
