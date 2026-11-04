extends SceneTree
const Gerador := preload("res://codigo/dados/gerador_npcs.gd")
const Acessorios := preload("res://codigo/npcs/acessorios_npc_3d.gd")
var falhas := 0
var pasta := "res://capturas-pelos-faciais"
func _initialize() -> void: rodar.call_deferred()
func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ",nome)
	if not ok: falhas+=1
func quadros(n := 3) -> void:
	for i in n: await process_frame; await physics_frame
func diferencas(a: Image,b: Image,alfa := false) -> int:
	var total := 0
	for y in a.get_height():
		for x in a.get_width():
			var ca := a.get_pixel(x,y)
			var cb := b.get_pixel(x,y)
			if (ca.a!=cb.a) if alfa else (ca!=cb): total+=1
	return total
func rodar() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes") or DisplayServer.get_name()=="headless":quit(1);return
	root.get_node("Ranking").conexao_habilitada=false
	root.mode=Window.MODE_WINDOWED
	root.content_scale_size=Vector2i(576,400);root.size=Vector2i(1152,800)
	DirAccess.make_dir_recursive_absolute(pasta)
	var antes := "--antes" in OS.get_cmdline_user_args()
	var folha := Image.create(8*192,6*192,false,Image.FORMAT_RGBA8)
	folha.fill(Color("8d9d96"))
	for cor in 2:
		var ficha := Gerador.gerar(84,"ferreiro")
		ficha.aparencia.cor=[0.20,0.11,0.065,1.0] if cor==0 else [0.81,0.78,0.73,1.0]
		ficha.variacao={"altura":1.0,"corpulencia":1.0,"postura":0.0,"cores":{},"acessorios":[]}
		var visual = load("res://codigo/jogador/representacao_heroi_3d.gd").new()
		visual.aparencia=ficha.aparencia
		visual.position=Vector2(288,220)
		root.add_child(visual)
		await quadros(4)
		var base: Array[Image] = []
		for estilo in 4:
			ficha.variacao.acessorios=[] if estilo in [0,3] else ["barba" if estilo==1 else "bigode"]
			Acessorios.aplicar(visual,ficha)
			for direcao in 8:
				visual.pose(false,0,0)
				visual.heroi._modelo.rotation.y=PI*direcao/4.0
				visual.heroi._cabeca_referencia.orientar(visual.heroi._modelo.rotation.y)
				await quadros(3)
				await RenderingServer.frame_post_draw
				var imagem: Image=visual.heroi._vp.get_texture().get_image()
				if estilo==0:base.append(imagem)
				elif not antes:
					verificar("silhueta preservada %d/%d/%d" % [cor,estilo,direcao],diferencas(base[direcao],imagem,true)==0)
					if estilo==3:verificar("remover pelos restaura rosto %d/%d" % [cor,direcao],diferencas(base[direcao],imagem)==0)
					elif direcao in [3,4,5]:verificar("nuca descoberta %d/%d/%d" % [cor,estilo,direcao],diferencas(base[direcao],imagem)==0)
					else:verificar("pelos visíveis %d/%d/%d" % [cor,estilo,direcao],diferencas(base[direcao],imagem)>(2 if direcao==0 else 0))
				if estilo==3:continue
				verificar("captura %d/%d/%d" % [cor,estilo,direcao],imagem.save_png(pasta.path_join("rosto_%d_%d_%d.png" % [cor,estilo,direcao]))==OK)
				var usado := imagem.get_used_rect()
				var centro := Vector2i(usado.get_center().x,usado.position.y+17)
				var recorte := imagem.get_region(Rect2i(centro-Vector2i(24,24),Vector2i(48,48)))
				recorte.resize(192,192,Image.INTERPOLATE_NEAREST)
				folha.blend_rect(recorte,Rect2i(Vector2i.ZERO,recorte.get_size()),Vector2i(direcao*192,(cor*3+estilo)*192))
		ficha.variacao.acessorios=["barba"]
		Acessorios.aplicar(visual,ficha)
		for direcao in 4:
			for fase in 8:
				visual.pose_caminhada(true,direcao,visual.duracao_caminhada()*fase/8.0)
				await quadros(2)
				await RenderingServer.frame_post_draw
				visual.heroi._vp.get_texture().get_image().save_png(pasta.path_join("andar_%d_%d_%d.png" % [cor,direcao,fase]))
		visual.queue_free()
		await quadros(2)
	verificar("folha comparativa",folha.save_png(pasta.path_join("comparacao.png"))==OK)
	await capturar_na_cidade()
	print("FALHAS: ",falhas)
	quit(1 if falhas else 0)

func capturar_na_cidade() -> void:
	var controlador = load("res://codigo/campanha/controlador_campanha.gd").new()
	verificar("fixture da cidade isolada",controlador.iniciar("user://percurso_primeira_raiz","prototipo")==OK)
	controlador.progresso.confirmar_conclusao("sobreviver_queda")
	controlador.progresso.confirmar_conclusao("estrada_interrompida")
	# A revisão dos rostos ocorre depois do relato, fora da abertura da cidade.
	controlador.progresso.registrar_objetivo("acolhimento","dara")
	controlador.progresso.registrar_objetivo("acolhimento","retorno")
	set_meta("campanha_destino","vila")
	change_scene_to_file("res://cenas/campanha/percurso_prototipo.tscn")
	await quadros(50)
	var cena = current_scene
	verificar("revisão usa a cidade real",cena.regiao=="vila")
	if cena.regiao!="vila":return
	cena.terreno.definir_estacao(0)
	cena.hud.hide();cena.interface.hide()
	cena.jogador.position=Vector2(0,425)
	var camera: Camera2D=cena.jogador.get_node("Camera2D")
	camera.reset_smoothing()
	for estilo in 3:
		var npc = load("res://cenas/npcs/npc_gerado.tscn").instantiate()
		npc.ficha=Gerador.gerar(84,"ferreiro")
		npc.ficha.nome=["Sem barba","Barba","Bigode"][estilo]
		npc.ficha.aparencia.cor=[0.20,0.11,0.065,1.0]
		npc.ficha.variacao={"altura":1.0,"corpulencia":1.0,"postura":0.0,"cores":{},"acessorios":[] if estilo==0 else ["barba" if estilo==1 else "bigode"]}
		npc.position=Vector2((estilo-1)*48,360)
		cena.add_child(npc)
		npc.set_physics_process(false)
		npc.visual.pose(false,0,0)
	await quadros(12)
	await RenderingServer.frame_post_draw
	verificar("captura no cenário",root.get_texture().get_image().save_png(pasta.path_join("cidade.png"))==OK)
