extends SceneTree
const Gerador=preload("res://codigo/dados/gerador_npcs.gd")
const Elenco=preload("res://codigo/dados/moradores_primeira_raiz.gd")
const Catalogo=preload("res://codigo/dados/roupas_base_3d.gd")
var falhas:=0
var capturas:="res://capturas-gerador-npcs"
var figuras:Array[Image]=[]
var titulos:Array[String]=[]
func _initialize() -> void:rodar.call_deferred()
func verificar(nome: String,ok: bool) -> void:
	print("OK " if ok else "FALHA ",nome)
	if not ok:falhas+=1
func quadros(n:=3) -> void:
	for i in n:await process_frame
func foto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	verificar("captura "+nome,root.get_texture().get_image().save_png(capturas.path_join(nome+".png"))==OK)
func foto_modelo(h: Node,nome: String) -> Image:
	await RenderingServer.frame_post_draw
	var imagem:Image=h._vp.get_texture().get_image()
	verificar("figura "+nome,imagem.save_png(capturas.path_join(nome+".png"))==OK)
	return imagem
func rodar() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes") or DisplayServer.get_name()=="headless":quit(1);return
	root.get_node("Ranking").conexao_habilitada=false
	DirAccess.make_dir_recursive_absolute(capturas)
	verificar("semente reproduz ficha completa",Gerador.gerar(84,"ferreiro",3)==Gerador.gerar(84,"ferreiro",3))
	var ficha:=Gerador.gerar(42,"camponesa",2)
	verificar("corpete e saia são slots independentes",ficha.aparencia.roupas_3d.camisa=="corpete_camponesa" and ficha.aparencia.roupas_3d.calca=="saia_vinho_longa")
	verificar("salva ficha isolada",Gerador.salvar(ficha,"user://npc_teste.json")==OK)
	var lida:=Gerador.carregar("user://npc_teste.json")
	verificar("recarga preserva identidade e roupa",lida.id==ficha.id and lida.aparencia.roupas_3d==ficha.aparencia.roupas_3d)
	ficha.aparencia.roupas_3d.camisa="res://arquivo_arbitrario.gd"
	verificar("ficha não injeta caminhos",Gerador.normalizar(ficha).aparencia.roupas_3d.camisa==Catalogo.padrao().camisa)
	root.mode=Window.MODE_WINDOWED
	root.content_scale_size=Vector2i(576,324)
	root.size=Vector2i(1152,648)
	change_scene_to_file("res://cenas/npcs/oficina_npcs.tscn")
	await quadros(10)
	var oficina=current_scene
	verificar("oficina oferece os 15 moradores e geração livre",oficina._morador.item_count==16)
	for indice in range(1,oficina._morador.item_count):
		oficina._selecionar_morador(indice)
		await quadros(2)
		var id:String=oficina._morador.get_item_metadata(indice)
		var esperada:=Elenco.ficha(id)
		verificar("oficina carrega movimento da cidade "+id,oficina.visual.perfil_movimento==esperada.movimento and oficina._movimento.selected==(1 if esperada.movimento=="feminino" else 0))
		verificar("seleção preserva identidade da cidade "+id,oficina.ficha==esperada and oficina._nome.text==esperada.nome and int(oficina._semente.value)==esperada.semente and Gerador.PERFIS.keys()[oficina._perfil.selected]==esperada.perfil and (oficina.visual.traje_infantil==esperada.traje_infantil and oficina.visual.cabelo_infantil==esperada.cabelo_infantil if esperada.get("faixa_etaria","")=="crianca" else oficina.visual.heroi.roupas_3d==esperada.aparencia.roupas_3d))
		oficina._mudar_peca(0,"cabelo")
		verificar("edição da prévia preserva elenco "+id,Elenco.ficha(id)==esperada)
		if id=="noel":
			verificar("oficina veste o uniforme de Noel",oficina.visual.heroi._armaduras.mascara==15)
			oficina._alternar_corpo()
			verificar("ver corpo recolhe também a armadura",oficina.visual.heroi._armaduras.mascara==0 and oficina.visual.heroi.pecas_visiveis==0)
			oficina._alternar_corpo()
			verificar("vestir restaura as quatro peças",oficina.visual.heroi._armaduras.mascara==15)
	oficina._semente.value+=1
	oficina._movimento.select(1)
	oficina._movimento.item_selected.emit(1)
	verificar("movimento é editável sem mudar roupa",oficina.ficha.movimento=="feminino" and oficina.visual.perfil_movimento=="feminino")
	oficina._movimento.item_selected.emit(0)
	verificar("alterar semente retorna à geração livre",oficina._morador.selected==0 and oficina.ficha==Gerador.gerar(int(oficina._semente.value),oficina.ficha.perfil))
	for perfil in Gerador.PERFIS:
		oficina._perfil.select(Gerador.PERFIS.keys().find(perfil))
		oficina._semente.set_value_no_signal(101+Gerador.PERFIS.keys().find(perfil))
		oficina.gerar()
		await quadros(3)
		var h=oficina.visual.heroi
		verificar("prévia usa acabamento pixel art "+perfil,h.acabamento_pixel_art and h._vp.size==Vector2i(160,160) and h._vp.msaa_3d==Viewport.MSAA_DISABLED and h._sprite.texture_filter==CanvasItem.TEXTURE_FILTER_NEAREST and h._sprite.material.shader.resource_path=="res://codigo/jogador/contorno_pixel_base_3d.gdshader")
		var corpo:MeshInstance3D=h._modelo.find_child("CorpoBase",true,false)
		var original:=corpo.mesh.get_rid()
		var geometria:=hash(corpo.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX])
		for i in 4:
			var p:MeshInstance3D=h._pecas[i]
			verificar("peça separada do corpo %s/%d" % [perfil,i],p!=corpo and p.mesh!=corpo.mesh and p.skin==corpo.skin and p.skeleton==corpo.skeleton)
			if p.mesh.get_surface_count()==0:continue
			var a:=p.mesh.surface_get_arrays(0)
			var pesos:PackedFloat32Array=a[Mesh.ARRAY_WEIGHTS]
			var valido:=true
			for v in a[Mesh.ARRAY_VERTEX].size():
				var soma:=0.0
				for k in 4:soma+=pesos[v*4+k]
				valido=valido and absf(soma-1.0)<.001 and a[Mesh.ARRAY_VERTEX][v].is_finite()
			verificar("pesos finitos e normalizados %s/%d" % [perfil,i],valido)
		oficina._alternar_corpo()
		await quadros(2)
		verificar("despir preserva a geometria da base "+perfil,corpo.mesh.get_rid()==original and geometria==hash(corpo.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]))
		verificar("botão remove só as peças "+perfil,h._pecas.all(func(p):return not p.visible))
		oficina._alternar_corpo()
		oficina.set_process(false)
		for direcao in 4:
			oficina.visual.pose(false,direcao,0)
			await quadros(3)
			var imagem:=await foto_modelo(h,"roupa_%s_%d" % [perfil,direcao])
			if direcao==0:figuras.append(imagem);titulos.append(Gerador.PERFIS[perfil].nome)
		if perfil=="ferreiro":
			h.pecas_visiveis=7
			for direcao in 4:
				oficina.visual.pose(false,direcao,0)
				await quadros(2)
				await foto_modelo(h,"avental_sem_cabelo_%d" % direcao)
				for fase in 8:
					oficina.visual.pose(true,direcao,.733333333333*fase/8.0)
					await quadros(2)
					await foto_modelo(h,"andar_avental_%d_%02d" % [direcao,fase])
			h.pecas_visiveis=15
		if perfil=="camponesa":
			verificar("saia longa cobre pés e calçado",not h._pecas[2].visible and corpo.material_override.get_shader_parameter("cobertura_saia_longa"))
			h.pecas_visiveis=13
			verificar("tirar saia restaura calçado e pele",h._pecas[2].visible and not corpo.material_override.get_shader_parameter("cobertura_saia_longa"))
			h.pecas_visiveis=15
			var duracao:float=h._player.get_animation(h.ANIMACOES.correr).length
			for direcao in 4:
				for fase in 8:
					oficina.visual.pose(true,direcao,duracao*fase/8.0)
					await quadros(2)
					await foto_modelo(h,"andar_corpete_%d_%02d" % [direcao,fase])
				for fase in 3:
					oficina.visual.pose_acao("espada",fase,direcao,fase/3.0)
					await quadros(2)
					await foto_modelo(h,"acao_corpete_%d_%d" % [direcao,fase])
			for cabelo in Catalogo.MODELOS.cabelo:
				if cabelo.forma<7:continue
				var indice:int=Catalogo.MODELOS.cabelo.find(cabelo)
				oficina._mudar_peca(indice,"cabelo")
				verificar("trocar cabelo preserva corpo "+cabelo.id,corpo.mesh.get_rid()==original)
				for direcao in 4:
					oficina.visual.pose(false,direcao,0)
					await quadros(3)
					await foto_modelo(h,"%s_%d" % [cabelo.id,direcao])
		oficina.set_process(true)
	var npc:CharacterBody2D=load("res://cenas/npcs/npc_gerado.tscn").instantiate()
	npc.ficha=Gerador.gerar(84,"ferreiro")
	npc.position=Vector2(100,160)
	root.add_child(npc)
	await quadros(6)
	verificar("NPC instanciável usa a ficha e o rig real",npc.visual.heroi.roupas_3d.camisa=="avental_ferreiro" and npc.perfil=="ferreiro")
	verificar("NPC mantém o mesmo acabamento pixel art da oficina",npc.visual.heroi.acabamento_pixel_art and npc.visual.heroi._vp.size==Vector2i(160,160) and npc.visual.heroi._sprite.texture_filter==CanvasItem.TEXTURE_FILTER_NEAREST)
	var nome_npc:Label=npc.get_node("NomeNPC")
	verificar("nome permanece centralizado acima da cabeça",absf(nome_npc.position.x+nome_npc.size.x/2)<.1 and nome_npc.position.y+nome_npc.size.y<npc.visual.topo_aparente())
	npc.queue_free()
	await quadros(2)
	for indice in range(1,oficina._morador.item_count):
		if oficina._morador.get_item_text(indice)=="Noel":oficina._selecionar_morador(indice);break
	for tamanho in [Vector2i(576,324),Vector2i(288,512),Vector2i(320,324)]:
		root.content_scale_size=tamanho
		root.size=tamanho*2
		await quadros(8)
		var tela:=Rect2(Vector2.ZERO,Vector2(tamanho))
		verificar("oficina cabe em %s" % tamanho,tela.encloses(oficina._palco.get_global_rect()) and tela.encloses(oficina._estado.get_global_rect()))
		verificar("opções não forçam largura em %s" % tamanho,oficina._conteudo.size.x<oficina.size.x-24)
		await foto("oficina_%dx%d" % [tamanho.x,tamanho.y])
	await galeria(oficina)
	print("FALHAS: ",falhas)
	quit(falhas)
func galeria(oficina: Node) -> void:
	oficina.hide()
	root.content_scale_size=Vector2i(960,720)
	root.size=Vector2i(1440,1080)
	var fundo:=ColorRect.new()
	fundo.color=Color("d7c6a7")
	fundo.size=Vector2(960,720)
	root.add_child(fundo)
	var caixa:=Rect2i()
	for imagem in figuras:caixa=imagem.get_used_rect() if not caixa.has_area() else caixa.merge(imagem.get_used_rect())
	caixa=caixa.grow(12).intersection(Rect2i(0,0,figuras[0].get_width(),figuras[0].get_height()))
	for i in figuras.size():
		var textura:=TextureRect.new()
		textura.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		textura.texture=ImageTexture.create_from_image(figuras[i].get_region(caixa))
		textura.position=Vector2(12+(i%4)*236,12+(i/4)*344)
		textura.size=Vector2(224,304)
		textura.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		textura.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
		fundo.add_child(textura)
		var nome:=Label.new()
		nome.text=titulos[i]
		nome.position=textura.position+Vector2(0,306)
		nome.size=Vector2(224,24)
		nome.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		nome.add_theme_color_override("font_color",Color("352b30"))
		fundo.add_child(nome)
	await quadros(3)
	await foto("galeria_no_motor")
