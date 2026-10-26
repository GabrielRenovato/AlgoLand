extends SceneTree
## Confere os campos digitáveis de preço e quantidade da aba VENDER do mercado e
## fotografa a tela. Save isolado obrigatório; servidor apontado para endereço morto
## (nenhuma chamada chega ao Supabase).
const SAIDA := "res://arte/previas/mercado/"
var falhas := 0
func conferir(ok: bool, texto: String) -> void:
	print(("OK   " if ok else "FALHA ") + texto)
	if not ok: falhas += 1
func _initialize():
	rodar.call_deferred()
func rodar():
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	root.get_node("Ranking").url_servico = "http://127.0.0.1:9"
	root.get_node("Introducao").pular_prologo()
	change_scene_to_file("res://cenas/fazenda.tscn")
	for i in 35: await process_frame
	root.get_node("Transicao").limpar()
	root.get_node("InventarioJogador").adicionar_coletavel("produto", "feno", 14)
	var camada := CanvasLayer.new()
	camada.layer = 50
	current_scene.add_child(camada)
	var tela: Control = load("res://codigo/mercado/tela_mercado.gd").new()
	camada.add_child(tela)
	await process_frame
	tela._trocar_aba(1)
	await process_frame
	var feno = null
	for item in root.get_node("InventarioJogador").mochila:
		if item != null and item.empilhavel() and item.quantidade >= 14:
			feno = item
	conferir(feno != null, "pilha de feno na mochila")
	tela._escolher_item(feno)
	await process_frame
	var preco: LineEdit = tela._preco_venda
	var quantidade: LineEdit = tela._rotulo_quantidade
	conferir(preco is LineEdit and quantidade is LineEdit, "preço e quantidade são campos digitáveis")
	# Digitação com letras misturadas: só os dígitos ficam.
	preco.grab_focus()
	preco.text = ""
	for letra in "2a5b0":
		var tecla := InputEventKey.new()
		tecla.pressed = true
		tecla.unicode = letra.unicode_at(0)
		tecla.keycode = OS.find_keycode_from_string(letra.to_upper())
		root.push_input(tecla)
		await process_frame
	await process_frame
	conferir(preco.text == "250", "filtra letras (%s)" % preco.text)
	preco.text_submitted.emit(preco.text)
	await process_frame
	conferir(tela._preco == 250, "Enter confirma o preço (%d)" % tela._preco)
	preco.grab_focus()
	preco.text = "999999"
	preco.release_focus()
	await process_frame
	conferir(tela._preco == int(tela._cliente.regras.get("preco_max", 9999)) and preco.text == str(tela._preco), "acima do máximo vira o máximo (%s)" % preco.text)
	preco.grab_focus()
	preco.text = "0"
	preco.text_submitted.emit(preco.text)
	await process_frame
	conferir(tela._preco == int(tela._cliente.regras.get("preco_min", 1)), "zero vira o mínimo (%d)" % tela._preco)
	preco.grab_focus()
	preco.text = "250"
	preco.text_submitted.emit(preco.text)
	tela._mudar_preco(10)
	conferir(tela._preco == 260 and preco.text == "260", "botões continuam somando ao valor digitado (%s)" % preco.text)
	quantidade.grab_focus()
	quantidade.text = "50"
	quantidade.text_submitted.emit(quantidade.text)
	await process_frame
	conferir(tela._quantidade == 14 and quantidade.text == "14", "quantidade limitada à pilha (%s)" % quantidade.text)
	quantidade.grab_focus()
	quantidade.text = "6"
	quantidade.text_submitted.emit(quantidade.text)
	await process_frame
	conferir(tela._quantidade == 6, "quantidade digitada (%d)" % tela._quantidade)
	conferir(tela._recebe_venda.text.contains("%d" % tela._cliente.liquido(260)), "valor líquido acompanha o preço digitado")
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA))
	root.get_texture().get_image().save_png(SAIDA+"vender_digitar_valor.png")
	print("MERCADO DIGITAR: %d falhas" % falhas)
	quit()
