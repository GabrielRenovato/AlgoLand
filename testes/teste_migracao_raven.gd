extends SceneTree
## Regressão das ações que antes voltavam ao Mana Seed e das quatro peças Raven.
const Raven := preload("res://codigo/dados/aparencia_raven.gd")
var falhas := 0

func _initialize() -> void:
	rodar.call_deferred()

func verificar(ok: bool, mensagem: String) -> void:
	if not ok:
		falhas += 1
		push_error(mensagem)

func esperar(n: int) -> void:
	for i in n: await process_frame

func rodar() -> void:
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	assert(DisplayServer.get_name() != "headless")
	root.get_node("Introducao").pular_prologo()
	root.get_node("Transicao").hora_salva = 12.0
	change_scene_to_file("res://cenas/fazenda.tscn")
	await esperar(30)
	var jogador: Node2D = current_scene.get_node("Jogador")
	jogador.set_physics_process(false)
	jogador.aparencia_raven = {"versao":1,"pele":0,"cabelo":1,"roupa":1,"cor":[1,1,1,1]}
	jogador.roupa_atual = 0
	var visual: Sprite2D = jogador.get_node("HeroiRaven")
	visual.set_process(false)
	var vp := SubViewport.new()
	vp.size = Vector2i(1440,320)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(vp)
	var fundo := ColorRect.new()
	fundo.color = Color("37414b")
	fundo.size = vp.size
	vp.add_child(fundo)
	var direcoes := [Vector2.DOWN,Vector2.RIGHT,Vector2.UP,Vector2.LEFT]
	var acoes := ["plantar","colher","sentado","ferido","morrer"]
	var saida := ProjectSettings.globalize_path("res://arte/previas/migracao_raven")
	DirAccess.make_dir_recursive_absolute(saida)
	for conjunto in ["base","carrasco","cavaleiro_rubro","cavalheiro"]:
		var copias: Array[Sprite2D] = []
		for slot in ["cabeca","corpo","luvas","botas"]: jogador.inventario.equipados[slot]=null
		if conjunto != "base":
			for par in [["cabeca","elmo"],["corpo","peitoral"],["luvas","luvas"],["botas","botas"]]:
				jogador.inventario.equipados[par[0]] = preload("res://codigo/dados/forja_armas.gd").criar_item(par[1]+"_"+conjunto)
		for d in 4:
			for a in acoes.size():
				var acao: String = acoes[a]
				jogador._direcao_ataque = direcoes[d]
				jogador.velocity = Vector2.ZERO
				jogador.esta_sentado = acao=="sentado"
				jogador._frente_sentado = 1 if d==0 else (-1 if d==2 else 0)
				jogador._lado_sentado = -1 if d==3 else 1
				jogador.esta_forjando = acao=="forjar"
				jogador.caido = acao=="morrer"
				jogador.esta_em_acao_fazenda = acao in ["plantar","colher"]
				jogador.no_fazenda.parar()
				jogador.no_reacao.encerrar()
				if jogador.esta_em_acao_fazenda: jogador.no_fazenda.tocar(acao,direcoes[d])
				if acao=="ferido": jogador.no_reacao.tocar("ferido",direcoes[d],"espada","espada_basica",1,1,0.3)
				visual._process(0.0)
				verificar(visual._animacao==acao,"Ação exclusivamente Raven: "+acao)
				verificar(not jogador.get_node("CompositeSprites").visible,"Camadas antigas permanecem ocultas")
				for i in 4:
					var textura: AtlasTexture = visual._camadas[9+i].texture
					verificar(textura.atlas.resource_path.begins_with(Raven.RAIZ if conjunto=="base" else "res://assets/personagens/conjuntos/"+conjunto+"/"),"Peça com origem correta")
				for q in 4:
					visual.frame = d*4+q
					for camada in visual._camadas: camada.frame=visual.frame
					var copia: Sprite2D = visual.criar_rastro()
					copia.position = Vector2(a*240+q*60+30,d*80+56)
					vp.add_child(copia)
					copias.append(copia)
		await esperar(2)
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png(saida+"/"+conjunto+".png")
		for copia in copias: copia.free()
	# Retirar uma peça preserva as outras três; trocar prévia não concede itens.
	jogador.inventario.equipados.cabeca=null
	visual._process(0.0)
	verificar((visual._camadas[9].texture as AtlasTexture).atlas.resource_path==Raven.RAIZ+"camadas/vazio.png","Elmo independente")
	verificar((visual._camadas[10].texture as AtlasTexture).atlas.resource_path.ends_with("cavalheiro/raven_peitoral.png"),"Peitoral permanece equipado")
	for par in [["cabeca","cabeca_basica"],["corpo","armadura_basica"],["luvas","luvas_basicas"],["botas","botas_basicas"]]:
		jogador.inventario.equipados[par[0]] = preload("res://codigo/dados/forja_armas.gd").criar_item(par[1])
	visual._process(0.0)
	for i in 4:
		var atlas: Texture2D = (visual._camadas[9+i].texture as AtlasTexture).atlas
		verificar(not atlas.resource_path.ends_with("vazio.png"),"Equipamento básico também possui camada Raven")
	for slot in ["cabeca","corpo","luvas","botas"]: jogador.inventario.equipados[slot]=null
	visual._process(0.0)
	for i in 4:
		verificar((visual._camadas[9+i].texture as AtlasTexture).atlas.resource_path.ends_with("vazio.png"),"Desequipar retira apenas a peça correspondente")
	vp.free()
	change_scene_to_file("res://cenas/inicio_do_jogo.tscn")
	await esperar(20)
	var tela := current_scene
	var arquivo := FileAccess.open("user://previa_raven_teste.json",FileAccess.WRITE)
	arquivo.store_string(JSON.stringify({"aparencia_raven":{"pele":2,"cabelo":28,"roupa":8,"cor":[0.35,0.6,1,1]}}))
	arquivo.close()
	tela.caminho_save_personagem = "user://previa_raven_teste.json"
	tela._montar_personagem()
	verificar(tela.sprite_corpo.texture.resource_path.ends_with("paginas/corpo_2/andar.png"),"Menu respeita pele salva")
	verificar(tela.sprite_cabelo.texture.resource_path.ends_with("paginas/cabelo_28/andar.png"),"Menu respeita cabelo salvo")
	verificar(tela.sprite_cabelo.modulate.is_equal_approx(Color(0.35,0.6,1,1)),"Menu respeita tintura salva")
	root.size = Vector2i(1152,648)
	await esperar(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(saida+"/menu.png")
	print("MIGRACAO RAVEN: ",falhas," falhas; cinco ações, quatro direções, três conjuntos independentes e prévia salva.")
	quit(1 if falhas else 0)
