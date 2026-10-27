extends SceneTree
## Compara a grade completa com as texturas já ativas, usando o compositor real.
const SAIDA="res://arte/previas/personagens/base_3d/grade_pixel/"
var h: Node
var vp: SubViewport
var sprite: Sprite2D
func _initialize():rodar.call_deferred()
func esperar(n: int):
	for i in n:await process_frame
func foto(nome: String) -> Image:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img:=vp.get_texture().get_image()
	img.save_png(SAIDA+nome+".png")
	return img
func modo(pixel: bool,amostras: int):
	h.amostras_pixel_art=amostras
	h.acabamento_pixel_art=pixel
	vp.size=h._vp.size
	sprite.material=h._sprite.material
	sprite.texture_filter=h._sprite.texture_filter
func pose(acao: String,direcao: int,fracao:=0.0):
	h._modelo.rotation.y=direcao*TAU/8.0
	var nome: String=h._nome_animacao(acao)
	h._player.play(nome,0)
	h._player.pause()
	h._player.seek(h._player.get_animation(nome).length*fracao,true)
func rodar():
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	assert(DisplayServer.get_name()!="headless")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA))
	root.get_node("Ranking").conexao_habilitada=false
	root.get_node("Introducao").pular_prologo()
	root.get_node("Transicao").hora_salva=12.0
	change_scene_to_file("res://cenas/fazenda.tscn")
	await esperar(40)
	root.get_node("Transicao").limpar()
	var j=current_scene.get_node("Jogador")
	j.set_physics_process(false)
	j.no_fazenda.set_process(false)
	j.aparencia_raven={"pele":0,"cor":[1.0,1.0,1.0,1.0],"olhos":0}
	h=j.get_node("HeroiBase3D")
	assert(h.acabamento_pixel_art and h._vp.size==Vector2i(160,160),"Grade ativa por padrão no jogo")
	assert(h._vp.msaa_3d==Viewport.MSAA_DISABLED and h._sprite.texture_filter==CanvasItem.TEXTURE_FILTER_NEAREST,"Pixels sem suavização")
	var mochila: Array=j.inventario.fotografar_mochila()
	h.definir_roupas_3d(h.CATALOGO_ROUPAS.padrao())
	h._aplicar_cores()
	h.set_process(false)
	h._costas.visible=false
	h._mao.visible=false
	h._mao_esquerda.visible=false
	vp=SubViewport.new()
	vp.transparent_bg=true
	vp.world_2d=World2D.new()
	vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	sprite=Sprite2D.new()
	sprite.centered=false
	sprite.texture=h._vp.get_texture()
	vp.add_child(sprite)
	var contato:=Image.create(120*4,160*3,false,Image.FORMAT_RGBA8)
	contato.fill(Color("52624f"))
	for linha in 3:
		var pixel:=linha>0
		var amostras:=1 if linha==1 else 2
		modo(pixel,amostras)
		var fator: float=h._vp.size.x/640.0
		var corte:=Rect2i(Vector2i(Vector2(200,145)*fator),Vector2i(Vector2(240,320)*fator))
		for d in 4:
			pose("parado",d)
			var img:=await foto("%s_%d"%[["suave","grade80","grade160"][linha],d])
			var parte:=img.get_region(corte)
			parte.resize(120,160,Image.INTERPOLATE_NEAREST)
			contato.blend_rect(parte,Rect2i(0,0,120,160),Vector2i(d*120,linha*160))
	contato.resize(960,960,Image.INTERPOLATE_NEAREST)
	contato.save_png(SAIDA+"comparar_grades.png")
	print("GRADE: suave640, nativa80 e nativa160; quatro direções, mesmo modelo e pivô")
	if "--amostra" in OS.get_cmdline_user_args():
		quit()
		return
	modo(true,2)
	var tempos: Dictionary={}
	if "--repouso" in OS.get_cmdline_user_args():
		for q in 24:
			pose("parado",0,q/24.0)
			await foto("repouso_%02d"%q)
		print("GRADE REPOUSO: 24 fases reais da animação")
		quit()
		return
	for conjunto in 3:
		h.definir_roupas_3d([
			h.CATALOGO_ROUPAS.padrao(),
			{"camisa":"blusa_bufante","calca":"saia_pregas","calcado":"sapatilhas_vinho"},
			{"camisa":"jaqueta_viajante","calca":"calca_cargo","calcado":"botinas_trabalho"}][conjunto])
		for d in 8:
			pose("parado",d)
			await foto("parado_%d_%d"%[conjunto,d])
		if conjunto==0:
			for q in 24:
				pose("parado",0,q/24.0)
				await foto("repouso_%02d"%q)
		for acao in ["correr","espada"]:
			# A corrida do jogo acompanha a distância;114px/s é o passo normal.
			tempos[acao]=h.PASSADA/114.0 if acao=="correr" else h._duracoes_combo()[0]
			for d in [0,2,4,6]:
				for q in 12:
					pose(acao,d,q/12.0)
					await foto("%s_%d_%d_%02d"%[acao,conjunto,d,q])
	# A renderização de uma mesma pose é determinística e não muda o inventário.
	pose("parado",0)
	var a:=await foto("estavel_a")
	await esperar(8)
	var b:=await foto("estavel_b")
	assert(a.get_data()==b.get_data(),"Pose parada estável na grade")
	assert(j.inventario.fotografar_mochila()==mochila,"Inventário preservado")
	# Cena normal com o mesmo compositor, sem os recortes da comparação.
	h.definir_roupas_3d(h.CATALOGO_ROUPAS.padrao())
	h._acao=""
	h.set_process(true)
	await esperar(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(SAIDA+"no_mapa.png")
	FileAccess.open(SAIDA+"tempos.json",FileAccess.WRITE).store_string(JSON.stringify(tempos,"  "))
	print("GRADE: 24 vistas paradas,24 fases de repouso,288 quadros de movimento, pose estável e inventário preservado; contorno de um texel")
	quit()
