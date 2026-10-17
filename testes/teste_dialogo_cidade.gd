extends SceneTree

var falhas := 0

func _initialize() -> void:
	_rodar()

func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ", nome)
	if not ok:
		falhas += 1

func quadros() -> void:
	for i in range(6):
		await process_frame

func conferir(tela: Control, nome: String) -> void:
	var painel: Rect2 = tela.painel.get_global_rect()
	verificar(nome + ": painel compacto e dentro da tela", painel.size.y <= tela.size.y * 0.75 and Rect2(Vector2.ZERO, tela.size).encloses(painel))
	verificar(nome + ": texto cabe sem cortar linhas", not tela._fala.visible or (tela._fala.size.y >= tela._fala.get_minimum_size().y and painel.encloses(tela._fala.get_global_rect())))
	var menu: Rect2 = tela._menu_assuntos.get_global_rect()
	verificar(nome + ": respostas dentro do mesmo balão",not tela._menu_assuntos.visible or painel.encloses(menu))
	verificar(nome + ": lista de respostas rolável",tela._rolagem != null and tela._rolagem.follow_focus)

func _rodar() -> void:
	if ProjectSettings.get_setting("application/config/name") != "AlgoLand testes Carrasco":
		push_error("Execute em copia de testes com saves isolados.")
		quit(1)
		return
	await process_frame
	var cidade: Node = root.get_node("Cidade")
	cidade.caminho_save = "user://teste_dialogo_cidade.json"
	cidade.apagar()
	var vila: Node = load("res://cenas/cidade.tscn").instantiate()
	root.add_child(vila)
	current_scene = vila
	await quadros()
	vila.get_node("Iluminacao").definir_hora(12.0)
	vila.get_node("Iluminacao").set_process(false)
	var interface: Node = vila.get_node("Interface")
	var tela: Control = interface._telas["conversa_cidade"]
	var dados: GDScript = load("res://codigo/cidade/dados_cidade.gd")
	for tamanho in [Vector2i(576,324), Vector2i(480,270), Vector2i(704,576)]:
		root.content_scale_size = tamanho
		root.size = tamanho * 2
		await quadros()
		for id in dados.MORADORES:
			cidade.conversar(id)
			await quadros()
			conferir(tela, str(tamanho) + "/" + id)
			verificar("retrato e nome correspondem: " + id, tela._retrato.texture != null and tela._titulo.text == dados.MORADORES[id]["nome"])
			tela._assunto("papo")
			await quadros()
			conferir(tela, "assunto de conversa/" + id)
			for pedido in dados.MISSOES:
				if dados.MISSOES[pedido]["dono"] == id:
					tela._abrir_pedido(pedido)
					await quadros()
					conferir(tela, "pedido/" + pedido)
			interface._fechar_tela("conversa_cidade")
	cidade.conversar("bento")
	await quadros()
	tela._abrir_pedido("horta")
	tela._botoes[0].pressed.emit()
	await quadros()
	verificar("aceite continua funcional", cidade.missoes["horta"]["estado"] == "aceita")
	verificar("pedido incompleto impede entrega", tela._botoes[0].disabled)
	interface._fechar_tela("conversa_cidade")
	cidade.conversar("curandeira")
	await quadros()
	var pocoes: Button = tela._botoes.filter(func(b): return b.text == "POCOES")[0]
	pocoes.pressed.emit()
	await quadros()
	verificar("Rosa abre preparo de poções", interface._telas_abertas.has("caldeirao") and not interface._telas_abertas.has("conversa_cidade"))
	interface._fechar_tela("caldeirao")
	cidade.conversar("mercador")
	await quadros()
	var sementes: Button = tela._botoes.filter(func(b): return b.text == "SEMENTES")[0]
	sementes.pressed.emit()
	await quadros()
	verificar("negociar abre loja e inventario", interface._telas_abertas.has("mercante") and interface._telas_abertas.has("inventario") and not interface._telas_abertas.has("conversa_cidade"))
	interface._fechar_tela("mercante")
	verificar("fechar libera o jogador", vila.get_node("Jogador").movimento_habilitado)
	current_scene.queue_free()
	current_scene = null
	await quadros()
	cidade.apagar()
	print("FALHAS: ", falhas)
	quit(falhas)
