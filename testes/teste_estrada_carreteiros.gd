extends SceneTree

var falhas := 0
var capturas := "res://capturas-estrada-carreteiros"
var cena: Node2D
var mapa: Node2D
var camera: Camera2D

func _initialize() -> void: rodar.call_deferred()
func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ",nome)
	if not ok:falhas+=1
func quadros(n := 5) -> void:
	for i in n:await process_frame;await physics_frame
func foto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	verificar("captura "+nome,root.get_texture().get_image().save_png(capturas.path_join(nome+".png"))==OK)
func olhar(p: Vector2, zoom := 1.0) -> void:
	camera.position = p
	camera.zoom = Vector2.ONE*zoom
	camera.reset_smoothing()
	await quadros(4)
func fechar_fala() -> void:
	if cena.interface._telas.introducao.visible:cena.interface._telas.introducao._fechar_fala()
	await quadros(3)
func rodar() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes") or DisplayServer.get_name()=="headless":quit(1);return
	auto_accept_quit=false
	root.mode=Window.MODE_WINDOWED
	root.content_scale_size=Vector2i(576,324);root.size=Vector2i(1152,648)
	DirAccess.make_dir_recursive_absolute(capturas)
	# Fixture no diretório descartável do runner: não visita nem modifica a chegada.
	var controlador := preload("res://codigo/campanha/controlador_campanha.gd").new()
	verificar("fixture isolada",controlador.iniciar("user://percurso_primeira_raiz","prototipo")==OK)
	for objetivo in controlador.Catalogo.dados().missoes.sobreviver_queda.objetivos:
		verificar("preparar acesso "+str(objetivo.id),controlador.progresso.registrar_objetivo("sobreviver_queda",objetivo.id)==OK)
	set_meta("campanha_destino","estrada")
	set_meta("campanha_nova_instancia",false)
	change_scene_to_file("res://cenas/campanha/percurso_prototipo.tscn")
	await quadros(35)
	cena=current_scene
	mapa=cena.terreno
	verificar("segundo estágio integrado",cena.regiao=="estrada" and mapa.modo_modular)
	verificar("cidade bloqueada na entrada da estrada",not cena.controlador.progresso.acesso_liberado("vila"))
	if cena.regiao!="estrada":quit(1);return
	var guia: Node
	for no in cena.get_children():
		if no.has_method("_alvo_atual"):
			guia=no
			break
	verificar("seta começa apontando para o carreto",is_instance_valid(guia) and guia._alvo_atual().get("base",Vector2.INF).distance_to(cena.alvos.carreto.no.global_position)<1.0)
	if is_instance_valid(guia):
		var base_carreto: Vector2=cena.alvos.carreto.no.global_position
		verificar("distância usa o alvo do carreto",guia._distancia_metros(base_carreto)==roundi(cena.jogador.global_position.distance_to(base_carreto)/16.0))
	verificar("mapa ampliado e tiles reutilizáveis",mapa.chao.get_used_cells().size()==10240 and mapa._atlas.get_tiles_count()==256)
	verificar("carreto é carroça própria, sem lenha substituta",mapa._pecas.carreto_atacado.tipo=="carreto" and not mapa.dados.alvos.carreto.has("prop"))
	verificar("abrigo e carga independentes",mapa._pecas.abrigo_trabalhador.tipo=="abrigo" and mapa._pecas.has("carga_caida"))
	var quantidade_prevista := 0
	for grupo in mapa.dados.encontros: quantidade_prevista += grupo.pontos.size()
	verificar("13 inimigos distribuídos com percepção local",quantidade_prevista==13 and mapa.roteiro.rebentos.size()==quantidade_prevista and mapa.roteiro.rebentos.all(func(r):return r.raio_percepcao==110))
	var indice := 0
	for grupo in mapa.dados.encontros:
		for previsto in grupo.pontos:
			var ponto_previsto := Vector2(previsto[0],previsto[1])
			var ponto_resolvido: Vector2 = ponto_previsto if mapa.ponto_seguro(ponto_previsto) else mapa.ponto_livre(ponto_previsto)
			verificar("inimigo no ponto previsto ou ajuste seguro "+str(indice),mapa.roteiro.rebentos[indice].position.distance_to(ponto_resolvido)<12 and mapa.ponto_seguro(mapa.roteiro.rebentos[indice].position))
			indice+=1
	for inimigo in mapa.roteiro.rebentos:inimigo.set_physics_process(false)
	cena.jogador.get_node("Camera2D").enabled=false
	camera=Camera2D.new();cena.add_child(camera)
	camera.position=Vector2.ZERO
	# Ocultar HUD só nas vistas técnicas, sem alterar o cenário.
	cena.hud.hide();cena.interface.hide()
	for estacao in 4:
		mapa.definir_estacao(estacao)
		await olhar(Vector2.ZERO,.28)
		await foto("01-geral-"+str(estacao))
		await olhar(Vector2(-285,-35))
		await foto("02-carreto-"+str(estacao))
		await olhar(Vector2(135,290))
		await foto("03-refugio-"+str(estacao))
		verificar("variante sazonal carregada "+str(estacao),str(mapa._pecas.carreto_atacado.sprite.texture.resource_path).contains(mapa.NOMES[estacao]))
	mapa.definir_estacao(0)
	var sonda:=CharacterBody2D.new()
	sonda.collision_layer=2;sonda.collision_mask=64
	var forma:=CollisionShape2D.new()
	var circulo:=CircleShape2D.new();circulo.radius=6
	forma.shape=circulo;sonda.add_child(forma);cena.add_child(sonda)
	await physics_frame
	for rota in [mapa.dados.rota_principal,mapa.dados.rota_refugio]:
		for i in rota.size()-1:
			var a:=Vector2(rota[i][0],rota[i][1])
			var b:=Vector2(rota[i+1][0],rota[i+1][1])
			sonda.position=a
			verificar("passagem real de "+str(a)+" até "+str(b),not sonda.test_move(sonda.global_transform,b-a))
	for id in mapa.dados.alvos:
		var p: Array=mapa.dados.alvos[id].p
		verificar("interação acessível "+id,mapa.ponto_seguro(Vector2(p[0],p[1])))
	sonda.position=Vector2(-300,10)
	verificar("carroça bloqueia apenas a base",sonda.test_move(sonda.global_transform,Vector2(0,-65)))
	sonda.position=Vector2(135,345)
	verificar("frente do abrigo aberta",not sonda.test_move(sonda.global_transform,Vector2(0,-40)))
	var ponto: Vector2=cena.alvos.trabalhador.no.position
	var trabalhador: Node=mapa.roteiro.trabalhador
	verificar("trabalhador usa roupa agrícola de serviço",trabalhador.scene_file_path=="res://cenas/npcs/npc_gerado.tscn" and trabalhador.ficha.aparencia.roupas_3d.camisa=="colete_agricultor" and trabalhador.ficha.aparencia.roupas_3d.calca=="calca_cargo" and trabalhador.ficha.aparencia.roupas_3d.calcado=="botinas_trabalho" and trabalhador.ficha.aparencia.roupas_3d.cabelo=="cabelo_cacheado")
	verificar("nenhum sprite antigo do mercador",not cena.alvos.trabalhador.no.get_children().any(func(no):return no is Sprite2D and no!=cena.alvos.trabalhador.no._aviso))
	verificar("nome único centralizado sobre a cabeça",not trabalhador.get_node("NomeNPC").visible and absf(cena.alvos.trabalhador.rotulo.position.x+cena.alvos.trabalhador.rotulo.size.x/2)<.1)
	cena.hud.show();cena.interface.show()
	cena.jogador.position=cena.alvos.carreto.no.position
	cena.jogador.velocity=Vector2.ZERO
	await olhar(Vector2(-265,-20))
	verificar("investigar rastros registra primeiro passo",mapa.roteiro.interagir("carreto")==OK and "carreto" in cena.controlador.progresso.objetivos_cumpridos("estrada_interrompida"))
	verificar("investigação libera busca do trabalhador",cena.controlador.objetivos_disponiveis().any(func(o):return o.missao=="estrada_interrompida" and o.id=="trabalhador" and o.regiao=="estrada"))
	await quadros(24);await foto("04-pista-do-carreto");await fechar_fala()
	verificar("seta acompanha o trabalhador",guia._alvo_atual().get("base",Vector2.INF).distance_to(cena.alvos.trabalhador.no.global_position)<1.0)
	cena.jogador.position=ponto+Vector2(0,24)
	cena.jogador.velocity=Vector2.ZERO
	await olhar(Vector2(135,295))
	var nome: Label=cena.alvos.trabalhador.rotulo
	verificar("nome acompanha silhueta visível",mapa.roteiro._nome_medido and absf(nome.position.y+nome.size.y+6-trabalhador.visual.topo_aparente())<4)
	cena.controlador.contar_tempo(60)
	verificar("resgate não exige matar todos",mapa.roteiro.interagir("trabalhador")==OK and "trabalhador" in cena.controlador.progresso.objetivos_cumpridos("estrada_interrompida") and mapa.roteiro.rebentos.size()==quantidade_prevista)
	verificar("resgate conclui estrada e libera cidade",cena.controlador.progresso.missao_concluida("estrada_interrompida") and cena.controlador.progresso.acesso_liberado("vila"))
	verificar("resgate libera conversa com Dara na vila",cena.controlador.objetivos_disponiveis().any(func(o):return o.missao=="acolhimento" and o.id=="dara" and o.regiao=="vila"))
	verificar("NPC usa pose de conversa do gerador",trabalhador.conversando)
	await quadros(24);await foto("05-trabalhador-encontrado");await fechar_fala()
	verificar("seta aponta à saída quando Dara está na vila",guia._alvo_atual().get("base",Vector2.INF).distance_to(cena.alvos.saida_regiao.no.global_position)<1.0)
	# Conferir UI existente, controles e âncoras na região nova em telas pequenas.
	for tamanho in [Vector2i(320,324),Vector2i(288,512),Vector2i(960,540),Vector2i(1280,720)]:
		root.content_scale_size=tamanho;root.size=tamanho*2
		await olhar(Vector2(135,295))
		await foto("06-tela-"+str(tamanho.x)+"x"+str(tamanho.y))
	verificar("Dara pede o relato no primeiro encontro",cena._fala("dara").contains("Diga o que viu."))
	verificar("registrar primeira conversa com Dara",cena.controlador.progresso.registrar_objetivo("acolhimento","dara")==OK)
	verificar("fala de Dara não antecipa a entrega",cena._fala("dara").contains("Diga o que viu."))
	verificar("registrar entrega a Dara",cena.controlador.progresso.registrar_objetivo("acolhimento","retorno")==OK)
	verificar("Dara reconhece o relato depois da entrega",cena._fala("dara").contains("Você o encontrou com vida"))
	root.content_scale_size=Vector2i(576,324);root.size=Vector2i(1152,648)
	cena.jogador.position=cena.alvos.saida_regiao.no.position
	await quadros(2)
	cena.controlador.progresso.tempos_regioes["estrada"]=0
	verificar("saída respeita minuto mínimo",mapa.roteiro.interagir("saida_regiao")==ERR_BUSY)
	await quadros(2)
	var original: int=mapa.chao.get_cell_source_id(Vector2i(-18,-1))
	var total: int=mapa._pecas.size()
	verificar("remoção revela piso de verdade",mapa.remover_objeto("carreto_atacado")==OK and mapa._pecas.size()==total-1 and mapa.chao.get_cell_source_id(Vector2i(-18,-1))==original)
	verificar("alteração local de solo",mapa.alterar_terreno(Vector2i(-15,0),mapa.PEDRA)==OK and mapa._tipo_canto(Vector2i(-15,0))==mapa.PEDRA)
	# IA deve caminhar no mapa real, usando a camada de navegação da estrada.
	var criatura: Node2D=mapa.roteiro.rebentos[0]
	criatura.position=Vector2(-600,350)
	cena.jogador.position=Vector2(-520,325)
	var inicio: Vector2=criatura.position
	criatura.set_physics_process(true)
	await create_timer(1.1).timeout
	criatura.set_physics_process(false)
	verificar("rebento persegue pela estrada real",criatura.position.distance_to(inicio)>10)
	print("FALHAS: ",falhas)
	quit(1 if falhas else 0)
