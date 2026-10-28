extends SceneTree
## Exercita os botões reais, confirmação e reabertura sem alterar a partida do usuário.
var falhas := 0
var verificacoes := 0
const SAIDA := "/tmp/algoland-pele-detalhes/"
func _initialize(): rodar.call_deferred()
func conferir(ok: bool, texto: String):
	verificacoes += 1
	if not ok:
		falhas += 1
		push_error(texto)
func esperar(n := 3):
	for i in n: await process_frame
func foto(h: Node, nome: String) -> Image:
	await esperar()
	await RenderingServer.frame_post_draw
	var imagem: Image = h._vp.get_texture().get_image()
	imagem.save_png(SAIDA+nome+".png")
	return imagem
func iguais(a: Image, b: Image) -> bool:
	return a.get_size()==b.get_size() and a.get_data()==b.get_data()
func rodar():
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	assert(DisplayServer.get_name()!="headless")
	DirAccess.make_dir_recursive_absolute(SAIDA)
	root.get_node("Ranking").conexao_habilitada=false
	root.get_node("Introducao").pular_prologo()
	var tela=load("res://cenas/criacao_personagem.tscn").instantiate()
	tela.trocar_cena=false
	tela.caminho_save="user://configuracao_jogador.json"
	root.add_child(tela)
	await esperar(8)
	var h=tela._previa_3d.heroi
	h._player.pause()
	# Uma cor escolhida deve conservar os mesmos detalhes ao percorrer as peles.
	for olho in [0,1,3]:
		tela._botoes_olhos[olho].pressed.emit()
		tela._botoes_pele[0].pressed.emit()
		var antes:=await foto(h,"criacao_olho_%d_pele_0"%olho)
		for pele in [1,2,0]:
			tela._botoes_pele[pele].pressed.emit()
			var imagem:=await foto(h,"criacao_olho_%d_pele_%d"%[olho,pele])
			conferir(tela.olhos==olho,"Trocar pele conserva seleção dos olhos")
			conferir(h._cabeca_referencia.visible,"Cabeça da referência continua ativa")
			if olho==0:
				# Centros da íris na pose frontal congelada, na grade nativa de 160.
				for ponto in [Vector2i(75,62),Vector2i(81,62)]:
					var cor:=imagem.get_pixelv(ponto)
					conferir(maxf(cor.r,maxf(cor.g,cor.b))<.45,"Íris castanha mantém pigmento e não estoura para branco, pele %d"%pele)
			if pele==0: conferir(iguais(antes,imagem),"Voltar ao tom original restaura todos os pixels do rosto")
	# Save legado: entrar no editor e trocar só a pele não pode inventar tinturas.
	tela.carregar_dados({"aparencia_raven":{"pele":0,"cor":[1.,1.,1.,1.]},"roupas_3d":h.CATALOGO_ROUPAS.padrao()})
	tela._atualizar_tudo()
	await esperar()
	conferir(not h._cabeca_referencia.material.get_shader_parameter("tingir_olhos"),"Prévia preserva olhos originais sem tintura salva")
	tela.confirmar()
	var salvo: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(tela.caminho_save))
	conferir(not salvo.aparencia_raven.has("olhos"),"Criação preserva ausência de tintura dos olhos")
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
	h._player.pause()
	h._modelo.rotation.y=0
	var mochila: Array=j.inventario.fotografar_mochila()
	var original:=await foto(h,"jogo_original")
	for pele in [1,2,0]:
		var editor=load("res://codigo/ui/editor_visual.gd").abrir(j)
		root.add_child(editor)
		await esperar(5)
		editor._tela._previa_3d.heroi._player.pause()
		editor._tela._botoes_pele[pele].pressed.emit()
		await foto(editor._tela._previa_3d.heroi,"editor_pele_%d"%pele)
		editor._tela.confirmar()
		await esperar()
		var imagem:=await foto(h,"jogo_pele_%d"%pele)
		conferir(not j.aparencia_raven.has("olhos"),"Editor não aplica cor de olhos ao trocar pele")
		conferir(not j.aparencia_raven.cor_cabelo_personalizada,"Editor preserva pintura original do cabelo")
		conferir(not h._cabeca_referencia.material.get_shader_parameter("tingir_olhos"),"Jogo conserva olhos originais")
		if pele==0: conferir(iguais(original,imagem),"Editor restaura exatamente os detalhes originais ao retornar à pele inicial")
	# Escolher castanho explicitamente após o caso legado precisa invalidar o cache.
	var editor=load("res://codigo/ui/editor_visual.gd").abrir(j)
	root.add_child(editor)
	await esperar(5)
	editor._tela._botoes_olhos[0].pressed.emit()
	editor._tela.confirmar()
	await esperar()
	conferir(h._cabeca_referencia.material.get_shader_parameter("tingir_olhos"),"Escolha explícita de castanho atualiza o material")
	conferir(j.inventario.fotografar_mochila()==mochila,"Inventário preservado")
	print("PELE E DETALHES DO ROSTO: ",verificacoes," verificações, ",falhas," falhas")
	current_scene.queue_free()
	await esperar(5)
	quit(1 if falhas else 0)
