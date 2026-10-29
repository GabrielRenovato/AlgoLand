extends SceneTree
var falhas := 0
func _initialize(): rodar.call_deferred()
func conferir(ok: bool, nome: String):
	if not ok:
		falhas += 1
		push_error(nome)
func quadros(n := 4):
	for i in n: await process_frame
func rodar():
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	assert(DisplayServer.get_name() != "headless")
	await process_frame
	root.mode = Window.MODE_WINDOWED
	root.unresizable = false
	var sessao = load("res://codigo/coop_online/conexao_coop.gd").obter(self)
	for tamanho in [Vector2i(576,324),Vector2i(480,270),Vector2i(288,512),Vector2i(320,324),Vector2i(704,576)]:
		root.content_scale_size = tamanho
		root.size = tamanho * 2
		for em_sala in [false,true]:
			sessao.codigo = "ABCDEF012345" if em_sala else ""
			sessao.eu = "teste"
			sessao.dono = "teste"
			var tela = load("res://codigo/coop_online/tela_coop.gd").new()
			root.add_child(tela)
			if not em_sala:
				tela._mostrar_salas([
					{"codigo":"123456789ABC", "anfitriao":"ANFITRIAO COM NOME LONGO", "andar":1000, "jogadores":1},
					{"codigo":"123456789ABD", "anfitriao":"AMIGO", "andar":2, "jogadores":2},
					{"codigo":"123456789ABE", "anfitriao":"OUTRO AMIGO", "andar":3, "jogadores":2, "em_partida":true}])
				conferir(not tela._lista_salas.get_child(0).disabled, "sala aberta permite entrar")
				conferir(tela._lista_salas.get_child(1).disabled and tela._lista_salas.get_child(2).disabled, "salas ocupadas bloqueiam entrada")
			await quadros(8)
			var caixa: Control = tela._codigo.get_parent()
			conferir(caixa.get_global_rect().position.x >= 12, "margem esquerda")
			conferir(caixa.get_global_rect().end.x <= root.get_visible_rect().size.x - 12 + 0.1, "margem direita na area realmente renderizada")
			for botao in tela.find_children("*", "Button", true, false):
				if not botao.is_visible_in_tree(): continue
				var largura: float = botao.get_theme_font("font").get_string_size(botao.text, HORIZONTAL_ALIGNMENT_LEFT, -1, botao.get_theme_font_size("font_size")).x
				conferir(botao.autowrap_mode != TextServer.AUTOWRAP_OFF or largura + 12 <= botao.size.x, "texto do botao com margem: " + botao.text)
				conferir(botao.size.y >= 30, "altura de toque")
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/algoland-coop-online/tela_%dx%d_%s.png" % [tamanho.x,tamanho.y,"sala" if em_sala else "entrada"])
			tela.queue_free()
			await quadros()
	sessao.codigo = ""
	root.get_node("Introducao").pular_prologo()
	root.get_node("InventarioJogador").criar_itens_iniciais()
	var cena: Node = load("res://cenas/cidade.tscn").instantiate()
	root.add_child(cena)
	current_scene = cena
	await quadros(20)
	var portal: Control = cena.get_node("Interface")._telas["desafio_arena"]
	root.get_node("EventosJogo").abrir_tela.emit("desafio_arena")
	for tamanho in [Vector2i(576,324), Vector2i(288,512), Vector2i(320,324)]:
		root.content_scale_size = tamanho
		root.size = tamanho * 2
		await quadros(12)
		var mapa := portal.find_child("MapaJornada", true, false)
		conferir(mapa != null, "mapa dos andares renderizado")
		var salas: VBoxContainer = mapa.get_node("SalasOnline")
		conferir(salas.get_child_count() == 2, "mapa oferece criar e ver salas")
		conferir(mapa._grade.get_global_rect().end.y <= salas.get_global_rect().position.y, "grade nao sobrepoe botoes online")
		salas.get_child(1).grab_focus()
		await quadros(8)
		for botao in salas.get_children():
			conferir(botao.size.y >= 34, "toque nas opcoes do mapa")
			conferir(botao.get_global_rect().end.x <= portal.get_global_rect().end.x, "opcoes cabem no mapa %s: botao %s / interface %s" % [tamanho, botao.get_global_rect(), portal.get_global_rect()])
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/algoland-coop-online/mapa_salas_%dx%d.png" % [tamanho.x,tamanho.y])
	var mapa := portal.find_child("MapaJornada", true, false)
	mapa.get_node("SalasOnline").get_child(1).pressed.emit()
	await quadros(10)
	conferir(root.has_node("TelaCoopOnline"), "ver salas no mapa abre a tela online")
	if root.has_node("TelaCoopOnline"): root.get_node("TelaCoopOnline").queue_free()
	cena.queue_free()
	await quadros()
	print("TELA COOP: cinco resolucoes, duas vistas, ", falhas, " falhas")
	quit(1 if falhas else 0)
