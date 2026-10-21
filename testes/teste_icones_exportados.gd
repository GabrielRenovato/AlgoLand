extends SceneTree
## Executar também contra os recursos extraídos do APK: detecta preloads excluídos.
var falhas := 0
func _initialize() -> void: rodar.call_deferred()
func esperar(n := 10) -> void:
	for i in n: await process_frame
func conferir(ok: bool, texto: String) -> void:
	if not ok:
		falhas += 1
		push_error(texto)
func rodar() -> void:
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	var dados = load("res://codigo/modelos/dados_item.gd")
	var forja = load("res://codigo/dados/forja_armas.gd")
	var lista: Array = []
	for tipo in ["enxada", "regador", "machadinha", "picareta", "semente:cenoura"]:
		lista.append(dados.de_fazenda(tipo))
	for tipo in forja.receitas_ativas(): lista.append(forja.criar_item(tipo))
	for categoria in ["material", "receita", "colheita", "pocao", "produto"]:
		var conteudo: String = {"material":"madeira", "receita":"lanca_basica", "colheita":"cenoura", "pocao":"cura", "produto":"ovo"}[categoria]
		lista.append(dados.de_coletavel(categoria,conteudo))
	lista.append(dados.de_vara())
	lista.append(dados.de_peixe("sardinha"))
	var cena = load("res://cenas/ui/componentes/item_ui.tscn")
	var item_ui = cena.instantiate()
	root.add_child(item_ui)
	for item in lista:
		item_ui.exibir(item)
		var textura: Texture2D = item_ui.get_node("Icone").texture
		conferir(textura != null,"Ícone exportado: "+item.tipo)
		if textura != null:
			var imagem: Image = textura.get_image()
			conferir(imagem != null and imagem.get_used_rect().has_area(),"Ícone contém pixels: "+item.tipo)
	item_ui.queue_free()
	if falhas:
		print("ICONES EXPORTADOS: ",falhas," falhas")
		quit(1)
		return
	root.get_node("Introducao").pular_prologo()
	root.get_node("InventarioJogador").limpar()
	root.get_node("InventarioJogador").criar_itens_iniciais()
	root.get_node("Transicao").hora_salva = 12.0
	change_scene_to_file("res://cenas/fazenda.tscn")
	await esperar(35)
	current_scene.get_node("Jogador").set_physics_process(false)
	var interface = root.get_node("EventosJogo").interface_p1()
	interface._abrir_tela("inventario")
	await esperar()
	var exibidos := 0
	for no in root.find_children("*", "Control", true, false):
		if no.get_script() == null or no.get_script().resource_path != "res://codigo/ui/item_ui.gd" or no.dados == null: continue
		conferir(no.icone.texture != null,"Mochila e barra mantêm o ícone: "+no.dados.tipo)
		if no.is_visible_in_tree(): exibidos += 1
	conferir(exibidos >= 6,"Mochila e barra mostram os itens iniciais")
	if DisplayServer.get_name() != "headless":
		root.mode = Window.MODE_WINDOWED
		DirAccess.make_dir_recursive_absolute("/tmp/algoland-apk-icones-revisao")
		for tamanho in [Vector2i(576,324),Vector2i(720,324)]:
			root.content_scale_size = tamanho
			root.size = tamanho*2
			await esperar(12)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/algoland-apk-icones-revisao/%d.png" % tamanho.x)
	print("ICONES EXPORTADOS: ",falhas," falhas; ",lista.size()," itens conferidos; mochila e barra reais.")
	current_scene.queue_free()
	current_scene = null
	await esperar()
	quit(0 if falhas == 0 else 1)
