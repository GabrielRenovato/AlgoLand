extends SceneTree
var falhas := 0
var cena: Node2D
var capturas := "res://capturas-campanha"
func _initialize() -> void: rodar.call_deferred()
func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ", nome)
	if not ok: falhas += 1
func quadros(n := 8) -> void:
	for i in n:
		await process_frame
		await physics_frame
func foto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	verificar("captura " + nome, root.get_texture().get_image().save_png(capturas.path_join(nome+".png")) == OK)

func validar_cinema_cidade() -> void:
	verificar("chegada à vila inicia cinema e bloqueia interação",cena.cinema_cidade_ativa() and not cena.jogador.movimento_habilitado and cena.interagir_proximo()==ERR_BUSY)
	verificar("cinema preserva objetivo até terminar relato",cena.controlador.objetivo_atual().id=="dara")
	cena.interface._abrir_tela("inventario")
	verificar("mochila não interrompe cinema",cena.interface._telas_abertas.is_empty())
	cena.cinema_cidade.cancelar()
	await quadros(3)
	verificar("cancelamento restaura jogo sem cumprir relato",not cena.cinema_cidade_ativa() and cena.jogador.movimento_habilitado and cena.hud.visible and cena.interface.visible and cena.controlador.objetivo_atual().id=="dara")
	verificar("chegada interrompida pode ser retomada",cena.abrir_regiao("vila",false)==OK)
	for i in 900:
		await quadros(1)
		if cena.cinema_cidade_ativa() and cena.cinema_cidade.fase=="apresentacao":break
	verificar("cinema aguarda mapa e rig de Dara",cena.cinema_cidade_ativa() and cena.cinema_cidade.fase=="apresentacao")
	if not cena.cinema_cidade_ativa():return
	await create_timer(1.2).timeout
	await foto("02-cinema-vila-apresentacao")
	for i in 900:
		await quadros(1)
		if not cena.cinema_cidade_ativa() or cena.cinema_cidade.fase=="dialogo":break
	verificar("plano da cidade chega naturalmente à conversa",cena.cinema_cidade_ativa() and cena.cinema_cidade.fase=="dialogo")
	if not cena.cinema_cidade_ativa():return
	var cinema:Node=cena.cinema_cidade
	await quadros(35)
	verificar("Dara olha para jogador e mantém posição durante fala",cena.moradores.dara.conversando and cena.jogador.velocity==Vector2.ZERO)
	var posicao_dara:Vector2=cena.moradores.dara.global_position
	var tamanho_antes:=root.size
	var escala_antes:=root.content_scale_size
	var toque_antes:bool=root.get_node("Controle").usando_toque
	for indice in cinema.FALAS.size():
		verificar("fala cinematográfica na ordem %d" % indice,cinema.indice==indice)
		if cinema._digitando != null and cinema._digitando.is_valid():cinema._digitando.kill()
		cinema._texto.visible_ratio=1.0
		for medida in [Vector2i(576,324),Vector2i(288,512),Vector2i(320,324)]:
			root.content_scale_size=medida;root.size=medida*2
			root.get_node("Controle").usando_toque=medida.x<360
			cinema._organizar()
			await quadros(8)
			var area:=Rect2(Vector2.ZERO,Vector2(medida))
			verificar("cinema cabe na tela %d %s" % [indice,medida],area.encloses(cinema._painel.get_global_rect()) and area.encloses(cinema._pular.get_global_rect()))
			for controle in [cinema._nome,cinema._texto,cinema._contador,cinema._continuar]:
				verificar("margens internas do cinema %d %s %s" % [indice,medida,controle.name],cinema._painel.get_global_rect().grow(-10).encloses(controle.get_global_rect()))
			verificar("fala sem corte %d %s" % [indice,medida],cinema._texto.size.y>=cinema._texto.get_line_height()*cinema._texto.get_line_count())
			verificar("fala e botão não se sobrepõem %d %s" % [indice,medida],not cinema._texto.get_global_rect().intersects(cinema._continuar.get_global_rect()))
			var quadro_cena:=Rect2(0,cinema._topo.size.y,medida.x,cinema._painel.position.y-cinema._topo.size.y-8)
			for ator in [cena.jogador,cena.moradores.dara]:
				var corpo:Rect2=cena.get_viewport().get_canvas_transform()*Rect2(ator.global_position-Vector2(12,42),Vector2(24,50))
				verificar("atores acima da legenda %d %s %s" % [indice,medida,ator.name],quadro_cena.encloses(corpo))
			await foto("02-cinema-dara-%d-%dx%d" % [indice,medida.x,medida.y])
		cinema._espera=0
		cinema.avancar()
		await quadros(2)
	root.content_scale_size=escala_antes;root.size=tamanho_antes
	root.get_node("Controle").usando_toque=toque_antes
	await quadros(30)
	verificar("relato conclui encontro e aponta Lia",not cena.cinema_cidade_ativa() and cena.controlador.objetivo_atual().id=="lia" and "retorno" in cena.controlador.progresso.objetivos_cumpridos("acolhimento"))
	verificar("fim restaura câmera, HUD e controles",cena.jogador.get_node("Camera2D").is_current() and cena.hud.visible and cena.interface.visible and cena.jogador.movimento_habilitado and not get_meta("cinema_ativo",false))
	verificar("Dara não atravessa a entrada durante o diálogo",cena.moradores.dara.global_position.distance_to(posicao_dara)<2)
	var progresso:RefCounted=cena.Controlador.Progresso.new()
	verificar("relato persiste ao reabrir save",progresso.iniciar("user://percurso_primeira_raiz","prototipo")==OK and "retorno" in progresso.objetivos_cumpridos("acolhimento"))
	verificar("restaurar fixture da vila depois do relato não repete cena",cena.abrir_regiao("vila",false)==OK and not cena.cinema_cidade_ativa())
	await quadros(35)
	# Pular também precisa limpar a câmera temporária e devolver todos os controles.
	var pulavel:Node=load("res://codigo/campanha/chegada_cidade.gd").new()
	pulavel.cena=cena
	pulavel.concluida.connect(pulavel.queue_free)
	cena.add_child(pulavel)
	cena.cinema_cidade=pulavel
	pulavel.iniciar()
	for i in 900:
		await quadros(1)
		if pulavel._preparada:break
	pulavel.pular()
	await quadros(30)
	verificar("pular cena restaura controles sem repetir objetivos",not cena.cinema_cidade_ativa() and cena.jogador.movimento_habilitado and cena.jogador.get_node("Camera2D").is_current() and cena.controlador.objetivo_atual().id=="lia")

func testar_treino_dara() -> void:
	cena.jogador.usando_espada=true
	cena.jogador.usando_escudo=true
	cena._iniciar_treino()
	await quadros(4)
	var treino = cena._treino
	verificar("treino de Dara cria o boneco",is_instance_valid(treino) and is_instance_valid(treino.boneco) and treino.boneco.is_in_group("enemy"))
	var vida_antes: int = treino.boneco.vida
	var golpes := [0]
	treino.boneco.golpeado.connect(func():golpes[0]+=1)
	cena.jogador.position=treino.boneco.position+Vector2(-20,0)
	cena.jogador.aplicar_golpe(treino.boneco,Vector2.RIGHT)
	await quadros(2)
	verificar("golpe do jogador chega ao boneco sem tirar vida",golpes[0]==1 and treino.boneco.vida==vida_antes)
	verificar("boneco não dá maestria",treino.boneco.get_meta("sem_maestria",false))
	cena.jogador.invulneravel=false
	cena.jogador.temporizador_invul=0.0
	var hp_antes: int = int(cena.jogador.hp_atual)
	treino._espera=0.0
	treino._aviso=0.01
	await quadros(8)
	verificar("golpe do boneco sem defesa tira vida do jogador",int(cena.jogador.hp_atual)<hp_antes)
	verificar("falha no bloqueio não avança a fase",treino.fase==0 and treino.acertos==0)
	var boneco = treino.boneco
	treino.encerrar(false)
	await quadros(3)
	verificar("encerrar o treino remove o boneco",not is_instance_valid(boneco) and not is_instance_valid(cena._treino))
	cena.jogador.hp_atual=int(cena.jogador.estatisticas.hp_maximo)
func interagir(id: String) -> void:
	cena.jogador.position = cena.alvos[id].no.position
	cena.jogador.velocity = Vector2.ZERO
	await quadros(2)
	if cena.regiao!="chegada": cena.controlador.contar_tempo(60)
	if cena.regiao=="vila":
		var guias := cena.get_children().filter(func(no):return no.has_method("_alvo_atual"))
		var base: Vector2 = guias[0]._alvo_atual().get("base",Vector2.INF) if not guias.is_empty() else Vector2.INF
		verificar("seta da cidade acompanha objetivo "+id,base.distance_to(cena.alvos[id].no.global_position)<1)
		if base.is_finite():
			verificar("distância da cidade usa mesmo alvo "+id,guias[0]._distancia_metros(base)==roundi(cena.jogador.global_position.distance_to(base)/16.0))
	verificar("interação próxima " + id, cena.interagir_proximo() == OK)
	if cena.interface._telas.introducao.visible:
		var conclusao: bool = not cena._destino_apos_conclusao.is_empty()
		await quadros(25)
		if conclusao:
			cena.interface._telas.introducao.avancar()
			await quadros(2)
			await foto("07-conclusao-"+id)
		if id == "dara":
			cena.interface._telas.introducao.avancar()
			await quadros(2)
			await foto("02-dialogo-dara")
		if id in ["dara","saida_regiao"]:
			var escala_anterior := root.content_scale_size
			var tamanho_anterior := root.size
			var fase: String = str(cena.controlador.objetivo_atual().get("id","fim"))
			for tamanho in [Vector2i(576,324),Vector2i(288,512),Vector2i(320,324)]:
				root.content_scale_size=tamanho;root.size=tamanho*2
				await quadros(4)
				var dialogo = cena.interface._telas.introducao
				var caixa: Rect2 = dialogo.painel.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,dialogo.painel.size)
				var texto: Rect2 = dialogo._texto.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,dialogo._texto.size)
				verificar("transição cabe na tela %s %s" % [id,tamanho],Rect2(Vector2.ZERO,Vector2(tamanho)).encloses(caixa))
				verificar("transição preserva margens %s %s" % [id,tamanho],caixa.grow(-6).encloses(texto))
				await foto("08-transicao-%s-%s-%dx%d" % [id,fase,tamanho.x,tamanho.y])
			root.content_scale_size=escala_anterior;root.size=tamanho_anterior
			await quadros(3)
		if id=="bancada_ivo":
			var dialogo = cena.interface._telas.introducao
			verificar("bancada oferece duas ligações",dialogo._opcoes.size()==2)
			dialogo._fechar_fala()
			await quadros(30)
			verificar("fechar a fala não dispensa a escolha",dialogo.visible and dialogo._caixa_opcoes.visible and not dialogo._avancar.visible)
			dialogo._caixa_opcoes.get_child(0).pressed.emit()
			await quadros(6)
			verificar("escolha grava a ligação e conclui o ofício",cena.controlador.progresso.preparo=="ligacao_ferro" and "oficio" in cena.controlador.progresso.objetivos_cumpridos("acolhimento"))
			verificar("fala de Ivo confirma a ligação",dialogo.visible and "ferro" in dialogo._texto.text.to_lower())
		cena.interface._telas.introducao._fechar_fala()
		await quadros(12)
		if conclusao:
			verificar("resultado final abre antes do mapa",cena.interface._telas.resultado.visible)
			cena.interface._telas.resultado.mapa.emit()
			await quadros(12)
			cena = null
func rodar() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes") or DisplayServer.get_name() == "headless":
		quit(1); return
	for argumento in OS.get_cmdline_user_args():
		if argumento.begins_with("--capturas="): capturas = argumento.trim_prefix("--capturas=")
	DirAccess.make_dir_recursive_absolute(capturas)
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = Vector2i(576,324)
	root.size = Vector2i(1152,648)
	set_meta("campanha_nova_instancia",false)
	change_scene_to_file("res://cenas/campanha/percurso_prototipo.tscn")
	await quadros(50)
	cena = current_scene
	verificar("cenário de protótipo inicia", cena.controlador.regiao == "chegada" and is_instance_valid(cena.jogador))
	verificar("região bloqueada não abre", cena.abrir_regiao("pomar",false) == ERR_UNAUTHORIZED)
	verificar("chega sem espada ou escudo", cena.jogador.inventario.buscar_por_tipo("espada_basica") == null and cena.jogador.inventario.buscar_por_tipo("escudo_basico") == null)
	verificar("chão regional preserva composição própria", cena.terreno.modo_modular and cena.terreno.chao.get_used_cells().size()==6144 and cena.terreno._atlas.get_tiles_count()==256)
	var modular=cena.terreno
	var antes_objetos: int=modular._pecas.size()
	var antes_colisoes: int=modular.obstaculos.size()
	verificar("tronco é peça removível com colisão própria",modular.remover_objeto("tronco_atalho")==OK and modular._pecas.size()==antes_objetos-1 and modular.obstaculos.size()==antes_colisoes-1)
	var celula := Vector2i((cena.jogador.position/16).floor())
	verificar("terreno admite mudança local de material",modular.alterar_terreno(celula,modular.PEDRA)==OK and modular._tipo_canto(celula)==modular.PEDRA)
	verificar("mudança atualiza tiles vizinhos",modular.chao.get_cell_atlas_coords(celula)==Vector2i(10,10))
	modular.alterar_terreno(celula,modular.TERRA)
	await quadros(3)
	verificar("criatura espera preparação", not is_instance_valid(cena.inimigo))
	var chegada_antes: Vector2=cena.jogador.position
	for id in ["sulcos_chegada","kit_resgate","raizes_despertas"]:
		cena.jogador.position=cena.alvos[id].no.position
		verificar("ponto de missão indisponível não oferece F "+id,cena.alvo_proximo()!=id and not cena.alvos[id].no.pode_interagir())
	cena.jogador.position=chegada_antes
	verificar("baú fechado oferece abrir, sem equipamentos soltos",modular.estado_bau==modular.EstadoBau.FECHADO and cena.alvos.espada_inicial.nome=="Abrir baú" and not modular._pecas.has("equipamento_espada"))
	verificar("raízes com seiva foram retiradas do cenário",not modular._pecas.has("nucleo_raizes") and not modular._pecas.has("broto_raizes_0"))
	var posicao_entrada: Vector2=cena.jogador.position
	for id in ["painel_ruinas","arco_estrada","arvore_1"]:
		var registro: Dictionary=modular._pecas[id]
		for lado in ["frente","atras"]:
			cena.jogador.position=registro.ponto+Vector2(0,12 if lado=="frente" else -48)
			cena.jogador.velocity=Vector2.ZERO
			cena.jogador.get_node("Camera2D").reset_smoothing()
			await quadros(3)
			verificar("profundidade do jogador "+lado+" de "+id,cena.jogador.z_index>registro.sprite.z_index if lado=="frente" else cena.jogador.z_index<registro.sprite.z_index)
			await foto("00-profundidade-"+id+"-"+lado)
	cena.jogador.position=posicao_entrada
	cena.jogador.get_node("Camera2D").reset_smoothing()
	for estacao in 4:
		cena.terreno.definir_estacao(estacao)
		await quadros(4)
		verificar("entrada livre na estação %d" % estacao,cena.terreno.ponto_seguro(cena.jogador.position))
		await foto("01-chegada-estacao-%d" % estacao)
	var mapa := cena.get_world_2d().navigation_map
	for id in cena.alvos:
		var caminho := NavigationServer2D.map_get_path(mapa,cena.jogador.position,cena.alvos[id].no.position,true)
		verificar("caminho da chegada até " + id, not caminho.is_empty() and caminho[-1].distance_to(cena.alvos[id].no.position)<2)
	for local in ["sulcos_chegada","kit_resgate","raizes_despertas"]:
		cena.jogador.position=cena.alvos[local].no.position+Vector2(0,-10)
		cena.jogador.get_node("Camera2D").reset_smoothing()
		for estacao in 4:
			cena.terreno.definir_estacao(estacao)
			await quadros(4)
			await foto("01-"+local+"-estacao-"+str(estacao))
	cena.jogador.position=Vector2(cena.terreno.dados.entrada[0],cena.terreno.dados.entrada[1])
	cena.terreno.definir_estacao(0)
	await foto("01-chegada")
	cena.jogador.position = cena.alvos.espada_inicial.no.position
	cena.jogador.velocity = Vector2.ZERO
	await quadros(2)
	await foto("00-bau-fechado-abrir")
	verificar("primeira interação só abre o baú",cena.interagir_proximo()==OK and cena.terreno.estado_bau==cena.terreno.EstadoBau.ABRINDO and cena.equipamentos_encontrados().is_empty())
	verificar("não coleta durante abertura",cena.interagir_proximo()!=OK and cena.equipamentos_encontrados().is_empty())
	for quadro in 4:
		cena.terreno.set_process(false)
		cena.terreno._process(.16)
		await quadros(2)
		await foto("00-bau-abrindo-quadro-"+str(quadro))
	cena.terreno.set_process(true)
	verificar("baú abre e salva sem conceder itens",cena.terreno.estado_bau==cena.terreno.EstadoBau.ABERTO and cena.controlador.progresso.bau_resgate_aberto and cena.equipamentos_encontrados().is_empty())
	# Restauração interna da fixture; entradas reais e derrota são testadas separadamente.
	set_meta("campanha_nova_instancia",false)
	reload_current_scene()
	await quadros(40)
	cena=current_scene
	verificar("retomada conserva baú aberto ainda com os dois itens",cena.terreno.estado_bau==cena.terreno.EstadoBau.ABERTO and cena.equipamentos_encontrados().is_empty())
	cena.jogador.position=cena.alvos.espada_inicial.no.position
	await quadros(2)
	await foto("00-bau-aberto-pegar-espada")
	var tecla := InputEventAction.new()
	tecla.action = "open_menu"
	tecla.pressed = true
	Input.parse_input_event(tecla)
	await quadros(2)
	tecla = InputEventAction.new()
	tecla.action = "open_menu"
	Input.parse_input_event(tecla)
	verificar("ação padrão F aciona coleta no cenário", "espada" in cena.controlador.progresso.objetivos_cumpridos("sobreviver_queda"))
	verificar("coletar espada passa a oferecer escudo no baú",not cena.alvos.espada_inicial.no.visible and cena.alvos.escudo_inicial.no.visible and cena.alvos.escudo_inicial.nome=="Pegar escudo")
	verificar("espada está equipada de verdade", cena.jogador.inventario.equipados.arma != null and cena.jogador.inventario.equipados.arma.tipo == "espada_basica")
	verificar("checkpoint da coleta", cena.salvar_retorno() == OK)
	var antes: Vector2 = cena.jogador.position
	# Restauração interna da fixture; entradas reais e derrota são testadas separadamente.
	set_meta("campanha_nova_instancia",false)
	reload_current_scene()
	await quadros(40)
	cena = current_scene
	verificar("retomada conserva espada sem antecipar escudo", cena.jogador.inventario.equipados.arma != null and cena.jogador.inventario.buscar_por_tipo("escudo_basico") == null)
	verificar("retomada conserva posição segura", cena.jogador.position.distance_to(antes)<2)
	await interagir("escudo_inicial")
	await interagir("kit_resgate")
	verificar("escudo equipado e combate disponível", cena.jogador.inventario.equipados.escudo != null and is_instance_valid(cena.inimigo))
	verificar("dez rebentos extras distribuídos",cena.rebentos_espalhados.size()==10)
	var posicoes: Array[Vector2]=[]
	for rebento in cena.rebentos_espalhados:
		posicoes.append(rebento.position)
		verificar("rebento nasce em chão seguro longe do baú",cena.terreno.ponto_seguro(rebento.position) and rebento.position.distance_to(Vector2(-378,324))>200)
		verificar("rebento distante não persegue a chegada",rebento.obter_jogador()==null)
	cena._preparar_criatura()
	verificar("coletas não duplicam rebentos",cena.rebentos_espalhados.size()==10)
	var camera_rebentos: Camera2D=cena.jogador.get_node("Camera2D")
	root.content_scale_size=Vector2i(1536,1024);root.size=Vector2i(1536,1024)
	camera_rebentos.position=-cena.jogador.position
	camera_rebentos.reset_smoothing()
	await quadros(3)
	await foto("01-rebentos-distribuidos")
	camera_rebentos.position=Vector2.ZERO
	root.content_scale_size=Vector2i(576,324);root.size=Vector2i(1152,648)
	camera_rebentos.reset_smoothing()
	cena.jogador.morrer()
	await quadros(40)
	cena = current_scene
	verificar("derrota retoma com vida e equipamentos", not cena.jogador.estaMorto and cena.jogador.hp_atual>0 and cena.jogador.inventario.equipados.arma != null and cena.jogador.inventario.equipados.escudo != null)
	verificar("derrota não conclui combate", not "combate" in cena.controlador.progresso.objetivos_cumpridos("sobreviver_queda"))
	verificar("derrota reinicia objetivos e baú",cena.controlador.progresso.objetivos_cumpridos("sobreviver_queda").is_empty() and not cena.controlador.progresso.bau_resgate_aberto)
	for no in cena.get_children():
		if no.has_method("pular") and no.get("ativa"):no.pular()
	await quadros(3)
	await interagir("espada_inicial")
	for quadro in 90:
		if cena.terreno.estado_bau==cena.terreno.EstadoBau.ABERTO:break
		await quadros(1)
	verificar("reinicio aguarda animacao do bau",cena.terreno.estado_bau==cena.terreno.EstadoBau.ABERTO)
	await interagir("espada_inicial")
	await interagir("escudo_inicial")
	await interagir("kit_resgate")
	var criatura = cena.inimigo
	var vida_inicial: int = criatura.vida
	for tentativa in 20:
		if not is_instance_valid(criatura) or criatura.esta_morto: break
		cena.jogador.position = criatura.position+Vector2(0,-20)
		cena.jogador.virar_para(Vector2.DOWN)
		cena.jogador._sem_acao_ate_ms = 0
		var ataque := InputEventAction.new()
		ataque.action = "attack"
		ataque.pressed = true
		Input.parse_input_event(ataque)
		await quadros(2)
		ataque = InputEventAction.new()
		ataque.action = "attack"
		Input.parse_input_event(ataque)
		await quadros(30)
	verificar("ataque real causa dano à criatura", not is_instance_valid(criatura) or criatura.vida < vida_inicial)
	await quadros(65)
	verificar("morte do inimigo registra combate", "combate" in cena.controlador.progresso.objetivos_cumpridos("sobreviver_queda"))
	await interagir("sulcos_chegada")
	await interagir("raizes_despertas")
	cena.jogador.position=cena.alvos.raizes_despertas.no.position+Vector2(0,12)
	cena.jogador.get_node("Camera2D").reset_smoothing()
	for onda in 3:
		cena.encontro._process(12.1)
		await quadros(2)
		await foto("01-vigilia-onda-"+str(onda))
		for criatura_vigilia in cena.encontro.criaturas:
			criatura_vigilia.receber_dano(9999)
		await quadros(12)
	cena.encontro._process(cena.encontro.PAUSA_CHEFE+0.1)
	verificar("vitória dos rebentos inicia chefe sem liberar saída",is_instance_valid(cena.encontro.chefe) and not "vigilia" in cena.controlador.progresso.objetivos_cumpridos("sobreviver_queda"))
	if not is_instance_valid(cena.encontro.chefe):quit(1);return
	var chefe=cena.encontro.chefe
	chefe.set_physics_process(false)
	cena.jogador.position=chefe.position+Vector2(100,30)
	chefe._physics_process(2.3)
	await quadros(2)
	await foto("01-cerne-chegada")
	chefe._physics_process(4.3)
	chefe.receber_dano(250)
	await quadros(2)
	await foto("01-cerne-fase2")
	chefe.receber_dano(9999)
	chefe._physics_process(2.1)
	chefe.receber_dano(9999)
	chefe._physics_process(3.1)
	await quadros(2)
	verificar("morte do chefe libera objetivo da vigília","vigilia" in cena.controlador.progresso.objetivos_cumpridos("sobreviver_queda"))
	cena.controlador.contar_tempo(60)
	await interagir("marco_estrada")
	verificar("clareira concluída retorna ao mapa", current_scene is Control and current_scene.tela == "regioes" and current_scene.controlador.progresso.missao_concluida("sobreviver_queda"))
	verificar("conclusão indica a estrada como próximo destino", current_scene.selecionado == "estrada" and not current_scene._entrar.disabled)
	verificar("cidade ainda bloqueada no mapa", not current_scene.controlador.progresso.acesso_liberado("vila"))
	await foto("07-proximo-destino-estrada")
	current_scene.selecionar("chegada")
	verificar("mapa identifica clareira concluída", current_scene._entrar.text == "Rejogar" and "concluída" in current_scene._descricao.text)
	current_scene.entrar_selecionado()
	await quadros(2)
	current_scene.dialogo_salas.jogar_solo()
	await quadros(45)
	cena = current_scene
	verificar("reentrada reinicia objetivos e baú",cena.controlador.progresso.objetivos_cumpridos("sobreviver_queda").is_empty() and not cena.controlador.progresso.bau_resgate_aberto)
	for no in cena.get_children():
		if no.has_method("pular") and no.get("ativa"):no.pular()
	await quadros(3)
	cena.voltar_ao_mapa()
	await quadros(15)
	verificar("mapa continua acessível na nova tentativa",current_scene is Control)
	current_scene.selecionar("estrada")
	current_scene.entrar_selecionado()
	await quadros(2)
	current_scene.dialogo_salas.jogar_solo()
	await quadros(45)
	cena = current_scene
	verificar("continuar pelo mapa abre estrada", cena.regiao == "estrada")
	verificar("cidade recusa entrada antes do resgate", cena.abrir_regiao("vila",false) == ERR_UNAUTHORIZED)
	cena.jogador.position=cena.alvos.saida_regiao.no.position
	await quadros(2)
	cena.controlador.contar_tempo(60)
	verificar("saída da estrada não pula investigação e resgate",cena.interagir_proximo()==ERR_UNAVAILABLE)
	for estacao in 4:
		cena.terreno.definir_estacao(estacao)
		await quadros(6)
		await foto("02-estrada-estacao-%d" % estacao)
	await interagir("carreto")
	await interagir("trabalhador")
	verificar("resgate conclui segundo estágio", cena.controlador.progresso.missao_concluida("estrada_interrompida"))
	cena.jogador.position=cena.alvos.saida_regiao.no.position
	await quadros(2)
	verificar("saída da estrada exige derrotar os rebentos", cena.interagir_proximo()==ERR_BUSY)
	for rebento in cena.terreno.roteiro.rebentos:
		if is_instance_valid(rebento): rebento.queue_free()
	await quadros(2)
	await interagir("saida_regiao")
	verificar("estrada indica cidade no mapa", current_scene is Control and current_scene.selecionado == "vila" and not current_scene._entrar.disabled)
	await foto("07-proximo-destino-vila")
	current_scene.entrar_selecionado()
	await quadros(45)
	cena = current_scene
	verificar("continuar pelo mapa abre vila", cena.regiao == "vila")
	await validar_cinema_cidade()
	await quadros()
	verificar("vila tem cenário próprio", cena.terreno.regiao == "vila" and cena.terreno.dados.has("casas"))
	verificar("cidade segue dez edifícios e seis setores da referência",cena.terreno.dados.casas.size()==10 and cena.terreno.setores.size()==6 and cena.terreno.limites.size==Vector2(1536,1024))
	var modelo_casa = load("res://codigo/campanha/casa_vila_3d.gd")
	var casas_3d: Array = cena.terreno.get_children().filter(func(no): return no.get_script()==modelo_casa)
	verificar("dez edifícios usam modelos 3D completos",casas_3d.size()==10 and casas_3d.all(func(no):return no.modelo is Node3D and no.visor.size==Vector2i(256,256)))
	verificar("edifícios, árvore e torres têm quatro estações integradas",cena.terreno._pecas_referencia.size()+cena.terreno._fachadas_familias.size()+casas_3d.size()==13 and cena.terreno._pecas_referencia.all(func(p): return p.quadros.size()==4) and cena.terreno._fachadas_familias.all(func(p):return p.ficha.texturas.size()==4) and casas_3d.all(func(no):return cena.terreno.estacao_mudou.is_connected(no.definir_estacao)))
	var mapa_vila := cena.get_world_2d().navigation_map
	for id in cena.alvos:
		var destino: Vector2 = cena.alvos[id].no.position
		var rota := NavigationServer2D.map_get_path(mapa_vila,cena.jogador.position,destino,true)
		verificar("ruas ligam entrada até " + id,not rota.is_empty() and rota[-1].distance_to(destino)<2)
	for casa in cena.terreno.dados.casas:
		var porta := Vector2(casa[1][0],casa[1][1])+Vector2(0,32)
		var rota := NavigationServer2D.map_get_path(mapa_vila,cena.jogador.position,porta,true)
		verificar("acesso livre à fachada %s %s" % [casa[0],casa[1]],cena.terreno.ponto_seguro(porta) and not rota.is_empty() and rota[-1].distance_to(porta)<2)
	var camera_vila: Camera2D = cena.jogador.get_node("Camera2D")
	var zoom_antes := camera_vila.zoom
	var posicao_antes: Vector2 = cena.jogador.position
	# Visão geral da composição real, além das capturas normais com HUD.
	root.content_scale_size=Vector2i(1536,1024)
	root.size=Vector2i(1536,1024)
	cena.jogador.position=Vector2.ZERO
	camera_vila.zoom=Vector2.ONE
	camera_vila.reset_smoothing()
	for estacao in 4:
		cena.terreno.definir_estacao(estacao)
		await quadros(6)
		verificar("dez casas 3D acompanham a estação %d" % estacao,casas_3d.all(func(no):return no._estacao==estacao))
		await foto("02-vila-geral-estacao-%d" % estacao)
	root.content_scale_size=Vector2i(576,324)
	root.size=Vector2i(1152,648)
	camera_vila.zoom=zoom_antes
	for setor in cena.terreno.setores:
		cena.jogador.position=cena.terreno.setores[setor]
		camera_vila.reset_smoothing()
		await quadros(5)
		await foto("02-vila-setor-"+setor)
	cena.jogador.position=posicao_antes
	camera_vila.reset_smoothing()
	for estacao in 4:
		cena.terreno.definir_estacao(estacao)
		await quadros(6)
		await foto("02-vila-estacao-%d" % estacao)
	await interagir("lia")
	await interagir("estela")
	await interagir("bancada_ivo")
	await testar_treino_dara()
	await interagir("tomas")
	await foto("02-vila")
	cena.abrir_regiao("pomar",false)
	await quadros()
	for id in ["cerca_pomar","raiz_pomar","sulco_pomar","barreira_pomar","canal_pomar"]:
		await interagir(id)
		if id == "barreira_pomar": await foto("03-pomar-barreira")
	for estacao in 4:
		cena.terreno.definir_estacao(estacao)
		await quadros(4)
		await foto("03-pomar-estacao-%d" % estacao)
	verificar("reparo altera a cerca", cena.terreno._reparo.visible)
	await foto("03-pomar")
	cena.abrir_regiao("vila",false)
	await quadros()
	await interagir("tomas")
	verificar("fim do percurso volta ao mapa com progresso salvo", current_scene is Control and current_scene.tela == "regioes" and current_scene.controlador.progresso.missao_concluida("pomar_sulcos"))
	root.get_node("Controle").usando_toque = true
	current_scene.selecionar("vila")
	current_scene.entrar_selecionado()
	await quadros(45)
	cena = current_scene
	for i in 180:
		if not cena.cinema_cidade_ativa() or cena.cinema_cidade._preparada:break
		await quadros(1)
	if cena.cinema_cidade_ativa():cena.cinema_cidade.pular()
	await quadros(30)
	for tamanho in [Vector2i(576,324),Vector2i(288,512),Vector2i(320,324)]:
		root.content_scale_size = tamanho
		root.size = tamanho*2
		await quadros(12)
		var objetivo: Control = cena.hud.get_node("ObjetivoPrincipal")
		var area := objetivo.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,objetivo.size)
		verificar("missão padrão cabe em %s" % tamanho, Rect2(Vector2.ZERO,Vector2(tamanho)).encloses(area))
		verificar("vida padrão visível em %s" % tamanho,cena.hud.barra_vida.is_visible_in_tree())
		verificar("missão mantém largura compacta em %s" % tamanho, area.size.x <= 148 and area.size.x < tamanho.x*0.55)
		for controle in cena.interface.get_children():
			if not controle.is_in_group("controles_toque"): continue
			for botao in controle._botoes:
				if not botao.visivel: continue
				var area_botao := Rect2(botao.centro-Vector2.ONE*botao.raio,Vector2.ONE*botao.raio*2)
				verificar("toque livre da missão %s %s" % [botao.acao,tamanho],not area_botao.intersects(area))
		await foto("04-mapa-%dx%d" % [tamanho.x,tamanho.y])
		cena._resposta("lia",OK)
		await quadros(25)
		var dialogo = cena.interface._telas.introducao
		dialogo.avancar()
		await quadros(2)
		var caixa: Rect2 = dialogo.painel.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,dialogo.painel.size)
		var texto: Rect2 = dialogo._texto.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,dialogo._texto.size)
		verificar("diálogo padrão cabe em %s" % tamanho, Rect2(Vector2.ZERO,Vector2(tamanho)).encloses(caixa))
		verificar("texto respeita margens do diálogo %s" % tamanho, caixa.grow(-6).encloses(texto))
		await foto("06-dialogo-%dx%d" % [tamanho.x,tamanho.y])
		dialogo._fechar_fala()
		await quadros(3)
	await foto("05-percurso-concluido")
	var progresso = cena.controlador.progresso
	var novo = load("res://codigo/campanha/controlador_campanha.gd").new()
	verificar("percurso persiste na reabertura", novo.iniciar("user://percurso_primeira_raiz","prototipo") == OK and novo.progresso.missao_concluida("pomar_sulcos"))
	verificar("protótipo não concede relíquia nem chefe", not progresso.possui_reliquia("reliquia_primeira_raiz"))
	verificar("atalho de mapa padrão existe", is_instance_valid(cena.hud._botao_mapa_toque))
	cena.hud._botao_mapa_toque.pressed.emit()
	await quadros(15)
	verificar("mapa padrão retorna às regiões do andar", current_scene is Control and current_scene.tela == "regioes")
	if is_instance_valid(cena): cena.queue_free()
	if is_instance_valid(current_scene): current_scene.queue_free()
	current_scene = null
	cena = null
	await quadros(10)
	print("FALHAS: ", falhas)
	quit(falhas)
