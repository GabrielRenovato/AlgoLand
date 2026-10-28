extends SceneTree
## RGB pelos controles reais, persistência, avatar público e margens responsivas.
const CORES:=preload("res://codigo/dados/cores_pele.gd")
const VISUAL:=preload("res://codigo/dados/visual_ranking.gd")
var falhas:=0
var verificacoes:=0
func _initialize(): rodar.call_deferred()
func conferir(ok: bool, texto: String):
	verificacoes+=1
	if not ok: falhas+=1; push_error(texto)
func esperar(n:=4):
	for i in n: await process_frame
func cor_aplicada(h: Node, cor: Color):
	var corpo=h._modelo.find_child("CorpoBase",true,false)
	conferir(corpo.material_override.get_shader_parameter("pele_base").is_equal_approx(cor),"Cor RGB aplicada ao corpo")
	conferir(h._cabeca_referencia.material.get_shader_parameter("tom_pele").is_equal_approx(cor),"Cabeça e corpo usam o mesmo RGB")
func rodar():
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	assert(DisplayServer.get_name()!="headless")
	root.get_node("Ranking").conexao_habilitada=false
	root.get_node("Introducao").pular_prologo()
	root.mode=Window.MODE_WINDOWED
	root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_IGNORE
	DirAccess.make_dir_recursive_absolute("/tmp/algoland-rgb-pele")
	for invalido in [null,[],[1,2],[1,2,3,4],["x",0,0],[NAN,0,0]]:
		conferir(CORES.normalizar_rgb(invalido).is_empty(),"RGB inválido usa tom legado")
	conferir(CORES.normalizar_rgb([-1.,.5,3.])==[0.,.5,1.],"RGB limitado a canais válidos")
	var tela=load("res://cenas/criacao_personagem.tscn").instantiate()
	tela.trocar_cena=false
	tela.caminho_save="user://configuracao_jogador.json"
	root.add_child(tela)
	await esperar(10)
	var h=tela._previa_3d.heroi
	h._player.pause()
	var cor:=Color8(173,112,83)
	for tamanho in [Vector2i(576,324),Vector2i(480,270),Vector2i(288,216),Vector2i(288,512),Vector2i(320,324)]:
		root.size=tamanho*2
		root.content_scale_size=tamanho
		tela._abrir_aba(tela.Aba.CABELO)
		await esperar(6)
		tela._botao_rgb_pele.pressed.emit()
		await esperar()
		var editor=tela.get_node("EditorRGBPele")
		conferir(editor.z_index>h.z_index,"Janela RGB fica à frente da prévia do personagem")
		for i in 3: editor.controles[i].value=[173,112,83][i]
		await esperar()
		cor_aplicada(h,cor)
		var painel: Rect2=editor.painel.get_global_rect()
		conferir(Rect2(Vector2.ZERO,Vector2(tamanho)).encloses(painel),"Painel RGB cabe na resolução %s"%tamanho)
		for controle in editor.painel.find_children("*","Control",true,false):
			if controle is Label or controle is SpinBox or controle is Button:
				conferir(painel.grow(-10).encloses(controle.get_global_rect()),"Controle com margem interna: "+controle.get_class())
				if controle is Label:
					var texto: Vector2=controle.get_theme_font("font").get_string_size(controle.text,HORIZONTAL_ALIGNMENT_LEFT,-1,controle.get_theme_font_size("font_size"))
					conferir(texto.x<=controle.size.x+1,"Texto RGB cabe no controle")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/algoland-rgb-pele/interface_%dx%d.png"%[tamanho.x,tamanho.y])
		editor.queue_free()
		await esperar()
	conferir(tela.dados_do_personagem().aparencia_raven.cor_pele.size()==3,"RGB incluído no save")
	tela.confirmar()
	var dados: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(tela.caminho_save))
	conferir(CORES.obter(dados.aparencia_raven).is_equal_approx(cor),"RGB sobrevive ao JSON")
	var publico:=VISUAL.normalizar(dados.aparencia_raven)
	conferir(CORES.obter(publico).is_equal_approx(cor),"RGB preservado no lobby e ranking")
	var avatar=load("res://codigo/jogador/representacao_heroi_3d.gd").new()
	avatar.aparencia=publico
	root.add_child(avatar)
	await esperar()
	cor_aplicada(avatar.heroi,cor)
	avatar.queue_free()
	tela.queue_free()
	await esperar()
	root.get_node("Transicao").hora_salva=12.
	change_scene_to_file("res://cenas/fazenda.tscn")
	await esperar(45)
	var j=current_scene.get_node("Jogador")
	j.set_physics_process(false)
	j.no_fazenda.set_process(false)
	h=j.get_node("HeroiBase3D")
	h.set_process(false)
	cor_aplicada(h,cor)
	var editor=load("res://codigo/ui/editor_visual.gd").abrir(j)
	root.add_child(editor)
	await esperar()
	conferir(CORES.obter(editor._tela.dados_do_personagem().aparencia_raven).is_equal_approx(cor),"Editor reabre na cor salva")
	editor._tela._abrir_rgb_pele()
	await esperar()
	editor._tela.get_node("EditorRGBPele").controles[0].value=200
	cor=Color8(200,112,83)
	editor._tela.confirmar()
	await esperar()
	cor_aplicada(h,cor)
	for pele in 3:
		var e=load("res://codigo/ui/editor_visual.gd").abrir(j)
		root.add_child(e)
		await esperar()
		e._tela._botoes_pele[pele].pressed.emit()
		conferir(not e._tela.dados_do_personagem().aparencia_raven.has("cor_pele"),"Tom pronto remove RGB personalizado")
		e._tela.confirmar()
		await esperar()
		cor_aplicada(h,CORES.TONS[pele])
	print("COR DE PELE RGB: ",verificacoes," verificações; ",falhas," falhas")
	quit(1 if falhas else 0)
