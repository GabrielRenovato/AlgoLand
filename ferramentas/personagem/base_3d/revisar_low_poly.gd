extends SceneTree
## Captura o compositor real no mapa e amostra as mesmas poses nos dois acabamentos.
var SAIDA := "res://arte/previas/personagens/base_3d/low_poly/"
var h: Node
func _initialize(): rodar.call_deferred()
func esperar(n: int):
	for i in n: await process_frame
func foto(nome: String) -> Image:
	await esperar(2)
	await RenderingServer.frame_post_draw
	var imagem: Image=h._vp.get_texture().get_image()
	imagem.save_png(SAIDA+nome+".png")
	return imagem
func pose(acao: String,d: int,fracao: float):
	h._acao=acao
	h._modelo.rotation.y=d*TAU/8.0
	if h._cabeca_referencia!=null:h._cabeca_referencia.orientar(h._modelo.rotation.y)
	var nome: String=h._nome_animacao(acao)
	h._player.play(nome,0)
	h._player.pause()
	h._player.seek(fracao*h._player.get_animation(nome).length,true)
	if h._cabeca_referencia!=null:h._cabeca_referencia.orientar(h._modelo.rotation.y)
func rodar():
	var pintura := "--pintura" in OS.get_cmdline_user_args()
	if pintura:SAIDA="res://arte/previas/personagens/base_3d/pintura_corpo/"
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
	h=j.get_node("HeroiBase3D")
	var corpo: MeshInstance3D=h._modelo.find_child("CorpoBase",true,false)
	assert(h.acabamento_low_poly and not h.acabamento_pixel_art)
	assert(h._vp.size==h.TAMANHO*h.NITIDEZ and h._sprite.material==null)
	var mochila: Array=j.inventario.fotografar_mochila()
	h.set_process(false)
	h.definir_roupas_3d(h.CATALOGO_ROUPAS.padrao())
	h._costas.visible=false
	h._mao.visible=false
	h._mao_esquerda.visible=false
	for modo in ["antes","low_poly"]:
		h.acabamento_low_poly=pintura or modo=="low_poly"
		h.acabamento_pixel_art=not pintura and modo=="antes"
		if pintura:corpo.material_override.set_shader_parameter("desenho_pixel_corpo",modo=="low_poly")
		h.roupas_pixel_art=true
		for d in 8:
			pose("parado",d,0.0)
			await foto("%s_%d"%[modo,d])
	if "--amostra" in OS.get_cmdline_user_args():
		quit()
		return
	var tempos: Dictionary={}
	var movimento_rosto: Dictionary={}
	for acao in ["correr","espada"]:
		tempos[acao]=h.PASSADA/114.0 if acao=="correr" else h._duracoes_combo()[0]
		for d in 8:
			movimento_rosto[acao+"_%d"%d]=[]
			for q in 16:
				pose(acao,d,q/16.0)
				await foto("%s_%d_%02d"%[acao,d,q])
				var cabeca: Node=h._cabeca_referencia
				movimento_rosto[acao+"_%d"%d].append({"quadro":q,"flexao":rad_to_deg(cabeca.flexao),"giro":rad_to_deg(cabeca.giro_rosto),"peso_pintura":cabeca.material.get_shader_parameter("flexao"),"vista":cabeca._direcao})
	# Regressão do rosto travado nas mesmas poses reais, em todas as direções.
	for chave in movimento_rosto:
		var minimo:=1.0
		var maximo:=-1.0
		for amostra in movimento_rosto[chave]:
			minimo=minf(minimo,amostra.peso_pintura)
			maximo=maxf(maximo,amostra.peso_pintura)
		assert(maximo-minimo>.1,"Rosto precisa mudar de inclinação: "+chave)
	# Reproduz os clipes com relógio real: a ligação ao esqueleto deve funcionar
	# sem seek por quadro nem chamadas manuais à cabeça durante a reprodução.
	for acao in ["correr","espada"]:
		h._acao=acao
		h._modelo.rotation.y=PI*.25
		h._cabeca_referencia.orientar(PI*.25)
		var nome: String=h._nome_animacao(acao)
		var duracao: float=tempos[acao]
		h._player.speed_scale=h._player.get_animation(nome).length/duracao
		h._player.play(nome,0)
		var inicio:=Time.get_ticks_msec()
		var minimo:=1.0
		var maximo:=-1.0
		while Time.get_ticks_msec()-inicio<duracao*1000.0:
			await process_frame
			var peso: float=h._cabeca_referencia.material.get_shader_parameter("flexao")
			minimo=minf(minimo,peso)
			maximo=maxf(maximo,peso)
		assert(maximo-minimo>.1,"Cabeça deve acompanhar reprodução real: "+acao)
		h._player.pause()
	h._player.speed_scale=1.0
	assert(j.inventario.fotografar_mochila()==mochila,"Inventário preservado")
	h._costas.visible=true
	h._mao.visible=true
	h._mao_esquerda.visible=true
	h._acao=""
	h.set_process(true)
	await esperar(5)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(SAIDA+"no_mapa.png")
	FileAccess.open(SAIDA+"movimento_rosto.json",FileAccess.WRITE).store_string(JSON.stringify(movimento_rosto,"  "))
	FileAccess.open(SAIDA+"tempos.json",FileAccess.WRITE).store_string(JSON.stringify(tempos,"  "))
	print("LOW POLY: 16 vistas comparativas e 256 poses reais de corrida/ataque; inventário preservado")
	quit()
