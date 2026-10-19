extends SceneTree

## Mostra as quatro ferramentas nas quatro direções usando a animação real do personagem.
## Saves isolados; o material não altera geometria, alcance, quadros ou o corpo.
var falhas := 0
func _initialize() -> void: rodar.call_deferred()
func quadros(n := 8) -> void:
	for i in n:
		await physics_frame
		await process_frame
func rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name","")).begins_with("AlgoLand testes") or DisplayServer.get_name()=="headless":
		quit(1)
		return
	await process_frame
	root.get_node("Introducao").pular_prologo()
	root.get_node("Cooperativo").sair()
	change_scene_to_file("res://cenas/fazenda.tscn")
	await quadros(20)
	var jogador: Node=current_scene.get_node("Jogador")
	jogador.set_physics_process(false)
	var madeira=load("res://codigo/dados/ferramentas_madeira.gd")
	var viewport:=SubViewport.new()
	viewport.disable_3d=true
	viewport.world_2d=World2D.new()
	viewport.size=Vector2i(640,512)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(viewport)
	var fundo:=ColorRect.new()
	fundo.size=viewport.size
	fundo.color=Color("364d34")
	viewport.add_child(fundo)
	var acoes: Array[String]=["enxada","machado","picareta","regar"]
	var tipos: Array[String]=["enxada","machadinha","picareta","regador"]
	var direcoes: Array[Vector2]=[Vector2.DOWN,Vector2.UP,Vector2.RIGHT,Vector2.LEFT]
	var nomes: Array[String]=["FRENTE","COSTAS","DIREITA","ESQUERDA"]
	var animacao=load("res://codigo/jogador/fazenda_jogador.gd")
	var icones=load("res://codigo/ui/icones_fazenda.gd")
	for linha in 4:
		for coluna in 4:
			var ator=animacao.new()
			ator.jogador=jogador
			ator.position=Vector2(80+coluna*160,80+linha*128)
			ator.scale=Vector2(2,2)
			viewport.add_child(ator)
			ator.tocar(acoes[linha],direcoes[coluna])
			ator.set_process(false)
			ator._indice=2
			ator._aplicar_quadro()
			var texto:=Label.new()
			texto.position=Vector2(coluna*160+8,linha*128+5)
			texto.text=tipos[linha].to_upper()+" / "+nomes[coluna]
			texto.add_theme_font_size_override("font_size",10)
			viewport.add_child(texto)
			var icone:=TextureRect.new()
			icone.texture=icones.da_ferramenta(tipos[linha])
			icone.material=madeira.material()
			icone.position=Vector2(coluna*160+8,linha*128+27)
			icone.size=Vector2(32,32)
			icone.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
			viewport.add_child(icone)
	await quadros()
	await RenderingServer.frame_post_draw
	var pasta:="res://arte/previas/ferramentas/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(pasta))
	viewport.get_texture().get_image().save_png(pasta+"madeira_no_godot.png")
	viewport.queue_free()
	await quadros(2)
	# Compara duas renderizações reais para preservar alfa e efeitos em todos os quadros.
	for arquivo in ["ferramenta_fazenda.png","ferramenta_machado.png","ferramenta_picareta.png"]:
		var teste:=SubViewport.new()
		teste.disable_3d=true
		teste.world_2d=World2D.new()
		teste.transparent_bg=true
		teste.size=Vector2i(1024,512)
		teste.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		teste.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		root.add_child(teste)
		for lado in 2:
			var original:=TextureRect.new()
			original.position.x=lado*512
			original.texture=load("res://assets/personagens/Fazenda/"+arquivo)
			original.material=madeira.material() if lado else null
			teste.add_child(original)
		await quadros(3)
		await RenderingServer.frame_post_draw
		var imagem:=teste.get_texture().get_image()
		var iguais:=true
		var efeitos:=true
		var alterados:=0
		for y in 512:
			for x in 512:
				var a:=imagem.get_pixel(x,y)
				var b:=imagem.get_pixel(x+512,y)
				if not is_equal_approx(a.a,b.a): iguais=false
				if a.a<0.5:continue
				if (minf(a.r,minf(a.g,a.b))>0.94 or (a.g>a.r+0.10 and a.b>a.r+0.10)) and not a.is_equal_approx(b): efeitos=false
				if not a.is_equal_approx(b): alterados+=1
		print("OK " if iguais and efeitos and alterados>100 else "FALHA ",arquivo," alfa estável, efeitos preservados, madeira em ",alterados," pixels")
		if not iguais or not efeitos or alterados<=100: falhas+=1
		teste.queue_free()
		await quadros(2)
	quit(0 if falhas==0 else 1)
