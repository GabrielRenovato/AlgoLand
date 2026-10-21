extends SceneTree
const Raven := preload("res://codigo/dados/aparencia_raven.gd")
const Cores := preload("res://codigo/dados/cores_armas_raven.gd")
const Icones := preload("res://codigo/ui/icones_itens.gd")
const Receitas := preload("res://codigo/dados/forja_armas.gd")
const Paleta := preload("res://codigo/dados/paleta_raven.gd")
const TIPOS := ["espada_basica","espada_gemea","machado","lanca_basica","arco_curto","escudo_basico"]
const ACOES := ["espada","espada_dupla","machado","lanca","arco","bloquear"]
const TONS := ["c9be9f","c47c4c","6eacd2","dfad42","a477db"]
var falhas := 0
func _initialize() -> void: rodar.call_deferred()
func esperar(n: int) -> void:
	for i in n: await process_frame
func verificar(ok: bool, mensagem: String) -> void:
	if not ok:
		falhas+=1
		push_error(mensagem)

func rodar() -> void:
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	assert(DisplayServer.get_name()!="headless")
	root.get_node("Introducao").pular_prologo()
	root.get_node("Transicao").hora_salva=12.0
	change_scene_to_file("res://cenas/fazenda.tscn")
	await esperar(30)
	var jogador: Node2D = current_scene.get_node("Jogador")
	jogador.set_physics_process(false)
	var visual: Sprite2D = jogador.get_node("HeroiRaven")
	visual.set_process(false)
	jogador.aparencia_raven={"pele":0,"cabelo":1,"roupa":1,"cor":[1,1,1,1]}
	jogador.esta_em_acao_fazenda=false
	var vp := SubViewport.new()
	vp.size=Vector2i(800,504)
	vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(vp)
	var fundo := ColorRect.new()
	fundo.size=vp.size
	fundo.color=Color("34414b")
	fundo.z_index=-100
	vp.add_child(fundo)
	var prova := SubViewport.new()
	prova.size=Vector2i(80,80)
	prova.transparent_bg=true
	prova.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(prova)
	var ferramenta := Sprite2D.new()
	ferramenta.centered=false
	ferramenta.hframes=4
	ferramenta.vframes=4
	ferramenta.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	prova.add_child(ferramenta)
	var saida := ProjectSettings.globalize_path("res://arte/previas/cores_armas_raven")
	DirAccess.make_dir_recursive_absolute(saida)
	for d in 4:
		var copias: Array[Node] = []
		for t in TIPOS.size():
			var tipo: String=TIPOS[t]
			for nivel in range(1,6):
				var item=Receitas.criar_item(tipo)
				item.nivel=nivel
				jogador.inventario.equipados.arma=null if tipo=="escudo_basico" else item
				jogador.inventario.equipados.escudo=item if tipo=="escudo_basico" else null
				visual._direcao=d
				visual._escudo_ativo=tipo=="escudo_basico"
				visual._aplicar_aparencia(ACOES[t])
				visual.frame=d*4+2
				for camada in visual._camadas: camada.frame=visual.frame
				var camada: Sprite2D=visual._camadas[8 if tipo=="escudo_basico" else 5]
				verificar(camada.material==Cores.material(tipo,nivel),"Cor do equipamento no personagem: "+tipo+str(nivel))
				verificar(visual.material==Raven.material_pose(false,false,d),"Melhoria não tinge a pele")
				var copia: Sprite2D = visual.criar_rastro()
				copia.position=Vector2((nivel-1)*160+65,24+t*80+58)
				vp.add_child(copia)
				copias.append(copia)
				var icone := Sprite2D.new()
				icone.texture=Icones.obter(item,self)
				icone.position=Vector2((nivel-1)*160+122,24+t*80+40)
				icone.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
				vp.add_child(icone)
				copias.append(icone)
				var legenda := Label.new()
				legenda.text="%s / %d" % [tipo,nivel]
				legenda.add_theme_font_size_override("font_size",9)
				legenda.position=Vector2((nivel-1)*160+4,24+t*80+2)
				vp.add_child(legenda)
				copias.append(legenda)
				ferramenta.texture=camada.texture
				ferramenta.frame=camada.frame
				ferramenta.material=camada.material
				await esperar(2)
				await RenderingServer.frame_post_draw
				var render := prova.get_texture().get_image()
				var origem := ferramenta.texture.get_image().get_region(Rect2i(160,d*80,80,80))
				var esperado: Dictionary=Paleta.CORES.duplicate()
				esperado.merge(Cores.paleta(tipo,nivel),true)
				var erros := 0
				for y in 80:
					for x in 80:
						var pixel := origem.get_pixel(x,y)
						var atual := render.get_pixel(x,y)
						if absf(pixel.a-atual.a)>0.01: erros+=1
						if pixel.a<0.5: continue
						var cor := Color.html(esperado.get(pixel.to_html(false),pixel.to_html(false)))
						if maxf(absf(cor.r-atual.r),maxf(absf(cor.g-atual.g),absf(cor.b-atual.b)))>0.012: erros+=1
				verificar(erros==0,"GPU preserva silhueta e aplica a paleta: "+tipo+str(nivel)+" direção "+str(d))
				var cor_base := "745c42" if tipo=="arco_curto" else ("7b6554" if tipo=="escudo_basico" else "c9be9f")
				var nativos: Image=load(Raven.RAIZ+"icones/"+tipo+".png").get_image()
				var novo := icone.texture.get_image()
				for y in nativos.get_height():
					for x in nativos.get_width():
						var pixel := nativos.get_pixel(x,y)
						verificar(pixel.a==novo.get_pixel(x,y).a,"Ícone preserva transparência")
						if pixel.a>0 and pixel.to_html(false)==cor_base:
							var tom: String = cor_base if nivel==1 else TONS[nivel-1]
							verificar(novo.get_pixel(x,y).is_equal_approx(Color.html(tom)),"Tom visível do nível no ícone")
		await esperar(2)
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png(saida+"/direcao-%d.png" % d)
		for copia in copias: copia.free()
	# A arma equipada governa a cor, mesmo com outra igual de nível maior na bolsa.
	var reserva=Receitas.criar_item("espada_basica")
	reserva.nivel=5
	jogador.inventario.mochila[0]=reserva
	var arma=Receitas.criar_item("espada_basica")
	jogador.inventario.equipados.arma=arma
	visual._aplicar_aparencia("espada")
	verificar(visual._camadas[5].material==Cores.material("espada_basica",1),"Instâncias iguais têm cores independentes")
	jogador.iniciar_forja(arma)
	visual._aplicar_aparencia("espada")
	verificar(arma.nivel==2 and visual._camadas[5].material==Cores.material("espada_basica",2),"Refino atualiza a cor sem trocar a arma")
	verificar(reserva.nivel==5,"Refino preserva a outra instância")
	var ui = root.get_node("EventosJogo").interface_p1()
	ui._abrir_tela("inventario")
	jogador.inventario.item_alterado.emit(reserva)
	await esperar(5)
	var tela = ui._telas["inventario"]
	verificar(tela._slots_mochila[0].item_ui().icone.texture==Cores.icone("espada_basica",5),"Mochila exibe a cor da instância armazenada")
	var hud = get_first_node_in_group("hud_p1")
	var barra = hud.barra_armas
	var exibido = jogador.inventario.item_na_celula(barra._celula(0))
	verificar(barra._casas[0].get_node("Conteudo/Slot").item_ui().icone.texture==Icones.obter(exibido,self),"Barra acompanha a cor do item após o sinal de melhoria")
	root.mode=Window.MODE_WINDOWED
	for tamanho in [Vector2i(576,324),Vector2i(288,512)]:
		root.content_scale_size=tamanho
		root.size=tamanho*2
		await esperar(5)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(saida+"/inventario-%dx%d.png" % [tamanho.x,tamanho.y])
	jogador.esta_em_acao_fazenda=true
	visual._aplicar_aparencia("machado")
	verificar(visual._camadas[5].material==Raven.material_pose(false,false,visual._direcao),"Machadinha de fazenda mantém a própria aparência")
	prova.free()
	vp.free()
	print("CORES ARMAS RAVEN: ",falhas," falhas; seis equipamentos, cinco níveis, quatro direções, ícones, alfa e refino real.")
	quit(1 if falhas else 0)
