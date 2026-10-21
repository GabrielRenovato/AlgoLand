extends SceneTree
const Raven := preload("res://codigo/dados/aparencia_raven.gd")
var falhas := 0
func _initialize() -> void: rodar.call_deferred()
func verificar(ok: bool, mensagem: String) -> void:
	if not ok:
		falhas += 1
		push_error(mensagem)
func quadros(n: int) -> void:
	for i in n: await process_frame
func rodar() -> void:
	assert(str(ProjectSettings.get_setting("application/config/custom_user_dir_name","")).begins_with("AlgoLand testes"))
	assert(DisplayServer.get_name() != "headless")
	DirAccess.make_dir_recursive_absolute("/tmp/algoland-raven-personalizacao")
	var dados := {}
	for tamanho in [Vector2i(576,324),Vector2i(720,324),Vector2i(288,512),Vector2i(320,324)]:
		var vp := SubViewport.new()
		vp.size = tamanho
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(vp)
		var tela: Control = load("res://cenas/criacao_personagem.tscn").instantiate()
		tela.trocar_cena = false
		tela.caminho_save = "user://teste_raven_personagem.json"
		vp.add_child(tela)
		await quadros(8)
		verificar(tela._casas_cabelo.size() == 29 and tela._casas_roupa.size() == 9,"Catálogo Raven: 28 arquivos de cabelo + sem cabelo, oito roupas + corpo base")
		tela._casas_cabelo[28].botao.pressed.emit()
		tela._casas_roupa[8].botao.pressed.emit()
		tela._botoes_pele[2].pressed.emit()
		tela._casas_cor[10].pressed.emit()
		tela._campo_nome.text = "AVENTUREIRA"
		tela._ao_nome_alterado(tela._campo_nome.text)
		verificar(tela.cabelo == 28 and tela.roupa == 8 and tela.pele == 2,"Escolha por botões reais")
		verificar(tela._previa_corpo.texture == Raven.corpo("andar",2),"Tom de pele aplicado na prévia")
		verificar(tela._previa_cabelo.texture == Raven.cabelo(28,"andar"),"Cabelo escolhido na prévia")
		for aba in 3:
			tela._abrir_aba(aba)
			await quadros(4)
			# A rolagem vertical é intencional no celular; nenhuma borda horizontal pode escapar.
			for controle in [tela._rotulo_cabelo,tela._rotulo_roupa,tela._botao_confirmar,tela._campo_nome] + tela._botoes_aba + tela._botoes_pele + (tela._casas_cor if aba == 2 else []):
				var r: Rect2 = controle.get_global_rect()
				verificar(r.position.x >= -0.5 and r.end.x <= tamanho.x+0.5,"Encaixe horizontal %s: %s %s" % [tamanho,controle.name,r])
			if aba == 2:
				verificar(tela._campo_nome.get_global_rect().position.y >= tela._slider_brilho.get_global_rect().end.y+4,"Cor sem sobreposição do nome em "+str(tamanho))
			verificar(tela._previa_corpo.scale == Vector2.ONE,"Prévia preserva a escala nativa das camadas")
			await RenderingServer.frame_post_draw
			vp.get_texture().get_image().save_png("/tmp/algoland-raven-personalizacao/%dx%d-aba%d.png" % [tamanho.x,tamanho.y,aba])
		if tamanho.x < 420:
			var rolagem := tela._colunas.get_parent() as ScrollContainer
			rolagem.scroll_vertical = 10000
			await quadros(5)
			verificar(Rect2(Vector2.ZERO,Vector2(tamanho)).encloses(tela._botao_confirmar.get_global_rect()),"Rodapé acessível pela rolagem em "+str(tamanho))
			await RenderingServer.frame_post_draw
			vp.get_texture().get_image().save_png("/tmp/algoland-raven-personalizacao/%dx%d-rodape.png" % [tamanho.x,tamanho.y])
		tela.confirmar()
		dados = JSON.parse_string(FileAccess.get_file_as_string(tela.caminho_save))
		verificar(dados.aparencia_raven.pele == 2 and dados.aparencia_raven.cabelo == 28 and dados.aparencia_raven.roupa == 8,"Salvar opções Raven sem reutilizar IDs antigos")
		verificar(dados.cabelo_atual == 0 and dados.roupa_atual == 2,"Compatibilidade dos IDs antigos")
		vp.queue_free()
		await quadros(3)
	# O jogador lê os mesmos dados e usa as mesmas camadas em ações diferentes.
	var jogador: Node2D = load("res://cenas/jogador.tscn").instantiate()
	root.add_child(jogador)
	jogador.set_physics_process(false)
	jogador.aplicar_dados_carregados(dados)
	await quadros(3)
	var visual: Sprite2D = jogador.get_node("HeroiRaven")
	for acao in ["parado","correr","espada","picareta","pescar","lanca"]:
		visual._aplicar_aparencia(acao)
		verificar(visual.texture == Raven.folha("corpo_2",acao),"Pele no jogo: "+acao)
		verificar(visual._camadas[6].texture == Raven.folha("cabelo_28",acao),"Cabelo no jogo: "+acao)
		verificar(visual._camadas[4].texture == Raven.folha("capa",acao),"Roupa no jogo: "+acao)
	jogador.queue_free()
	await quadros(5)
	for id in Node.get_orphan_node_ids():
		var orfao = instance_from_id(id)
		if is_instance_valid(orfao) and orfao is Node: orfao.free()
	print("PERSONALIZACAO RAVEN: ",falhas," falhas; prévia, seleções, save, jogador e quatro tamanhos.")
	quit.call_deferred(1 if falhas else 0)
