extends SceneTree
## Contrato comportamental do cenário modular; revisão visual continua obrigatória.
var falhas := 0
var capturas := "res://capturas-mapas-modulares"
var mapa: Node2D
var camera: Camera2D
func _initialize() -> void: rodar.call_deferred()
func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ",nome)
	if not ok: falhas+=1
func quadros(n := 5) -> void:
	for i in n: await process_frame
func imagem() -> Image:
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func foto(nome: String) -> void:
	var foto := await imagem()
	verificar("captura "+nome,foto.save_png(capturas.path_join(nome+".png"))==OK)
func diferencas(a: Image,b: Image) -> int:
	var total := 0
	for y in range(0,a.get_height(),3):
		for x in range(0,a.get_width(),3):
			var ca:=a.get_pixel(x,y)
			var cb:=b.get_pixel(x,y)
			if absf(ca.r-cb.r)+absf(ca.g-cb.g)+absf(ca.b-cb.b)>.08: total+=1
	return total
func rodar() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes") or DisplayServer.get_name()=="headless": quit(1);return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capturas="):capturas=arg.trim_prefix("--capturas=")
	verificar_pesos_grama()
	DirAccess.make_dir_recursive_absolute(capturas)
	root.content_scale_size=Vector2i(576,324)
	root.size=Vector2i(1152,648)
	await quadros(10)
	var memoria_base: float=Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)
	var cena := Node2D.new()
	root.add_child(cena);current_scene=cena
	mapa=load("res://cenas/campanha/terreno_chegada.tscn").instantiate()
	cena.add_child(mapa)
	camera=Camera2D.new();cena.add_child(camera)
	await quadros(10)
	var utilizadas: Array=mapa.chao.get_used_cells()
	var fonte: TileSetAtlasSource=mapa.chao.tile_set.get_source(0)
	verificar("atlas reutiliza combinações em vez de um tile exclusivo por posição",utilizadas.size()>fonte.get_tiles_count()*8)
	verificar("objetos são instâncias separadas do chão",mapa._pecas.size()>20 and mapa._pecas.has("tronco_atalho"))
	verificar("referência tem painel, suprimentos e ponte própria",mapa._pecas.has("painel_ruinas") and mapa._pecas.has("suprimentos_resgate") and mapa._pecas.ponte_tronco.tipo=="ponte")
	verificar("baú inicia fechado e equipamentos não ficam no chão",mapa.estado_bau==mapa.EstadoBau.FECHADO and not mapa._pecas.has("equipamento_espada") and not mapa._pecas.has("equipamento_escudo"))
	verificar("baú inicia animação sem abrir instantaneamente",mapa.abrir_bau()==OK and mapa.estado_bau==mapa.EstadoBau.ABRINDO and mapa.quadro_bau==0)
	verificar("baú recusa reentrada durante animação",mapa.abrir_bau()==ERR_BUSY)
	mapa.set_process(false)
	for quadro in 4:
		mapa._process(.16)
		verificar("avanço do quadro do baú "+str(quadro),mapa.quadro_bau==mini(quadro+1,3))
	verificar("abertura conclui sem repetir",mapa.estado_bau==mapa.EstadoBau.ABERTO and mapa.abrir_bau()==ERR_ALREADY_IN_USE)
	mapa._process(2)
	verificar("animação mantém último quadro",mapa.quadro_bau==3)
	mapa.set_process(true)
	await physics_frame
	for p in [Vector2(350,80),Vector2(350,180),Vector2(300,400),Vector2(120,440)]:
		var ponto: Vector2=mapa._da_imagem(p)
		var consulta:=PhysicsPointQueryParameters2D.new()
		consulta.position=ponto;consulta.collision_mask=64
		verificar("água visível bloqueia fisicamente "+str(p),mapa.peso_agua(ponto)>.6 and not mapa.get_world_2d().direct_space_state.intersect_point(consulta).is_empty())
	verificar("raízes com seiva não são decoração",not mapa._pecas.has("nucleo_raizes") and not mapa._pecas.has("broto_raizes_0"))
	for t in [.2,.5,.8]:
		var ponto: Vector2=mapa._da_imagem(Vector2(241,428).lerp(Vector2(325,513),t))
		var consulta:=PhysicsPointQueryParameters2D.new()
		consulta.position=ponto;consulta.collision_mask=64
		verificar("ponte mantém corredor físico livre "+str(t),mapa.get_world_2d().direct_space_state.intersect_point(consulta).is_empty())
	var sonda:=CharacterBody2D.new()
	sonda.collision_layer=2;sonda.collision_mask=64
	var forma:=CollisionShape2D.new()
	var circulo:=CircleShape2D.new();circulo.radius=5
	forma.shape=circulo;sonda.add_child(forma);cena.add_child(sonda)
	await physics_frame
	sonda.position=mapa._da_imagem(Vector2(241,428).lerp(Vector2(325,513),.2))
	verificar("pés do jogador atravessam a ponte sem bater nas margens",not sonda.test_move(sonda.global_transform,Vector2(84,85)*.6))
	sonda.position=mapa._da_imagem(Vector2(215,402))
	verificar("acesso completo da margem noroeste à ponte",not sonda.test_move(sonda.global_transform,Vector2(26,26)))
	sonda.position=mapa._da_imagem(Vector2(241,428))
	verificar("travessia completa inclui as duas cabeceiras",not sonda.test_move(sonda.global_transform,Vector2(84,85)))
	sonda.position=mapa._da_imagem(Vector2(325,513))
	# O riacho continua para sudeste; desembarcar na terra a leste do tronco.
	verificar("saída da ponte alcança a margem leste",not sonda.test_move(sonda.global_transform,Vector2(30,-5)))
	sonda.position=mapa._pecas.painel_ruinas.ponto+Vector2(0,18)
	verificar("movimento real não atravessa base da ruína",sonda.test_move(sonda.global_transform,Vector2(0,-55)))
	for lado in [-1,1]:
		sonda.position=mapa._pecas.painel_ruinas.ponto+Vector2(lado*49,-25)
		verificar("pilar lateral bloqueia entrada na pedra "+str(lado),sonda.test_move(sonda.global_transform,Vector2(-lado*23,0)))
		sonda.position=mapa._pecas.painel_ruinas.ponto+Vector2(lado*49,-8)
		verificar("contorno externo da ruína continua livre "+str(lado),not sonda.test_move(sonda.global_transform,Vector2(0,28)))
	var ator=load("res://cenas/jogador.tscn").instantiate()
	cena.add_child(ator)
	ator.set_physics_process(false)
	ator.set_process(false)
	ator.get_node("Camera2D").enabled=false
	camera.position=mapa._pecas.painel_ruinas.ponto+Vector2(0,-32)
	camera.zoom=Vector2.ONE*2
	for lado in [-1,1]:
		ator.position=mapa._pecas.painel_ruinas.ponto+Vector2(lado*47,-23)
		ator.z_index=mapa.Profundidade.z_de(ator.position.y+11)
		verificar("personagem à frente do pilar usa profundidade dos pés "+str(lado),ator.z_index>mapa._pecas.painel_ruinas.sprite.z_index)
		await quadros()
		await foto("13-ruina-lateral-"+str(lado))
	ator.queue_free()
	sonda.position=mapa._da_imagem(Vector2(420,80))
	verificar("movimento real da margem ao rio é bloqueado",sonda.test_move(sonda.global_transform,Vector2(-75,0)))
	sonda.position=mapa._da_imagem(Vector2(1340,263))
	verificar("abertura do arco permite seguir a direção da estrada",not sonda.test_move(sonda.global_transform,Vector2(70,-85)))
	for base in [Vector2(-44,-27),Vector2(43,-11)]:
		var consulta:=PhysicsPointQueryParameters2D.new()
		consulta.position=mapa._pecas.arco_estrada.ponto+base;consulta.collision_mask=64
		verificar("pilar do arco tem colisão na base desenhada "+str(base),not mapa.get_world_2d().direct_space_state.intersect_point(consulta).is_empty())
	var arvore: Sprite2D=mapa._pecas.arvore_1.sprite
	sonda.position=mapa._pecas.arvore_1.ponto-Vector2(0,48)
	sonda.z_index=mapa.Profundidade.z_de(sonda.position.y+11)
	mapa.atualizar_oclusao(sonda,1)
	verificar("copa atenua quando encobre o personagem",arvore.modulate.a<.5)
	sonda.position=Vector2(3000,3000)
	mapa.atualizar_oclusao(sonda,1)
	verificar("copa recupera opacidade ao sair",is_equal_approx(arvore.modulate.a,1))
	sonda.queue_free()
	for nome in ["grama","terra_raizes","pedra","agua"]:
		var variantes: Dictionary=mapa._fichas[nome].variantes
		verificar("material "+nome+" tem quatro estações",variantes.size()==4)
	for registro in mapa._pecas.values():
		var ficha: Dictionary=mapa._fichas[registro.tipo]
		verificar("variantes próprias "+registro.id,ficha.variantes.size()==4)
		verificar("densidade nativa desktop "+registro.id,float(ficha.variantes.primavera.largura_visivel)/float(registro.largura)>=2.0)
	camera.position=mapa._pecas.tronco_atalho.ponto-Vector2(0,20)
	await quadros()
	var antes := await imagem()
	await foto("01-tronco-presente")
	var colisoes: int=mapa.obstaculos.size()
	verificar("remoção opera sobre peça e colisão",mapa.remover_objeto("tronco_atalho")==OK and mapa.obstaculos.size()<colisoes)
	await quadros()
	var depois := await imagem()
	verificar("remover peça revela chão sem a mesma pintura no fundo",diferencas(antes,depois)>60)
	await foto("02-tronco-removido")
	var celula:=Vector2i(-30,20)
	camera.position=Vector2(celula*16)
	await quadros()
	antes=await imagem()
	var atlas_antes: Dictionary={}
	for c in utilizadas:atlas_antes[c]=mapa.chao.get_cell_atlas_coords(c)
	verificar("solo admite alteração local",mapa.alterar_terreno(celula,mapa.PEDRA)==OK)
	var alteradas:=0
	for c in utilizadas:
		if mapa.chao.get_cell_atlas_coords(c)!=atlas_antes[c]:alteradas+=1
	verificar("edição recompõe apenas os tiles vizinhos",alteradas>0 and alteradas<=9)
	await quadros()
	depois=await imagem()
	verificar("a alteração aparece na renderização real",diferencas(antes,depois)>30)
	await foto("03-solo-alterado")
	for estacao in 4:
		mapa.definir_estacao(estacao)
		camera.position=mapa._pecas.bau_resgate.ponto-Vector2(0,16);camera.zoom=Vector2.ONE*2
		for quadro in 4:
			mapa.quadro_bau=quadro
			mapa._aplicar_quadro_bau()
			await quadros(2)
			await foto("12-bau-estacao-%d-quadro-%d" % [estacao,quadro])
		verificar("arco mantém orientação na estação "+str(estacao),mapa._pecas.arco_estrada.sprite.scale.x<0)
		camera.position=mapa._da_imagem(Vector2(1375,220));camera.zoom=Vector2.ONE*1.5
		await quadros()
		await foto("11-arco-estacao-"+str(estacao))
		camera.position=Vector2.ZERO;camera.zoom=Vector2.ONE*.31
		await quadros(8)
		await foto("04-geral-estacao-"+str(estacao))
		camera.position=Vector2(-410,320);camera.zoom=Vector2.ONE
		await quadros()
		await foto("05-detalhe-estacao-"+str(estacao))
	mapa.definir_estacao(0)
	for par in [["07-resgate",Vector2(350,830)],["08-ponte",Vector2(280,470)],["09-raizes",Vector2(855,235)],["10-ruinas",Vector2(160,280)]]:
		camera.position=mapa._da_imagem(par[1]);camera.zoom=Vector2.ONE*1.5
		await quadros()
		await foto(par[0])
	for tamanho in [Vector2i(1920,1080),Vector2i(2560,1440)]:
		camera.zoom=Vector2.ONE
		root.size=tamanho
		camera.position=Vector2(80,-210)
		await quadros(10)
		await foto("06-desktop-%dx%d" % [tamanho.x,tamanho.y])
	# Capturar PNG é trabalho de revisão; medir somente quadros estáveis sem captura.
	await quadros(20)
	var tempos: Array[float]=[]
	for i in 30:
		await process_frame
		tempos.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.0)
	tempos.sort()
	var metricas := {"tiles":utilizadas.size(),"combinacoes":fonte.get_tiles_count(),"objetos":mapa._pecas.size(),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"memoria_texturas":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),"incremento_texturas":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)-memoria_base,"processamento_mediano_ms":tempos[15]}
	print("METRICAS ",JSON.stringify(metricas))
	FileAccess.open(capturas.path_join("metricas.json"),FileAccess.WRITE).store_string(JSON.stringify(metricas,"\t"))
	cena.queue_free();current_scene=null
	await quadros()
	print("FALHAS: ",falhas)
	quit(falhas)

func verificar_pesos_grama() -> void:
	var grama = load("res://codigo/cenario/grama_3d_no_mapa.gd")
	var iguais := true
	for combinacao in 256:
		var tipos := [combinacao%4,(combinacao/4)%4,(combinacao/16)%4,(combinacao/64)%4]
		var consultar := func(c: Vector2i) -> int: return tipos[posmod(c.x,2)+2*posmod(c.y,2)]
		for uv in [Vector2.ZERO,Vector2(.001,.999),Vector2(.2,.7),Vector2(.5,.5),Vector2(.99,.01)]:
			var pesos := [(1.-uv.x)*(1.-uv.y),uv.x*(1.-uv.y),(1.-uv.x)*uv.y,uv.x*uv.y]
			var acumulado := [0.0,0.0,0.0,0.0]
			for i in 4: acumulado[tipos[i]] += pesos[i]
			var total := 0.0
			for i in 4:
				acumulado[i] = pow(maxf(float(acumulado[i])-.18,0.0),2.0)
				total += float(acumulado[i])
			var esperado := float(acumulado[0])/maxf(total,.001)
			for origem in [Vector2.ZERO,Vector2(-32,-64)]:
				iguais = iguais and is_equal_approx(grama.peso_modular(origem+uv*16.0,consultar),esperado)
	verificar("atalho da grama preserva 256 combinações, transições e coordenadas negativas",iguais)
