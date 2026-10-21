extends SceneTree

## Integração e capturas reais, com gravações exclusivamente no projeto isolado.
var falhas := 0
var verificacoes := 0
const SAIDA := "res://arte/previas/fazenda/tiny/"

func _initialize() -> void:
	_rodar.call_deferred()

func _conferir(condicao: bool, descricao: String) -> void:
	verificacoes += 1
	if not condicao:
		falhas += 1
		push_error(descricao)

func _quadros(n := 5) -> void:
	for i in n:
		await process_frame

func _foto(nome: String) -> void:
	await _quadros()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(SAIDA + nome + ".png")

func _rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes fazenda tiny"):
		push_error("Execute em projeto de testes com saves isolados da fazenda Tiny.")
		quit(1)
		return
	root.get_node("Saves").trocar("solo")
	root.get_node("Introducao").pular_prologo()
	root.get_node("Fazenda").apagar()
	root.get_node("Transicao").hora_salva = 12.0
	root.get_node("Fazenda").definir_clima_hoje(0)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1152, 768)
	root.content_scale_size = Vector2i(1152, 768)
	change_scene_to_file("res://cenas/fazenda.tscn")
	await _quadros(20)
	var terreno := current_scene.get_node("Terrains")
	var troca := current_scene.get_node("ComparacaoTiny")
	var estacoes := terreno.get_node("Estacoes")
	var jogador := current_scene.get_node("Jogador")
	jogador.set_physics_process(false)
	jogador.position = Vector2(376, 256)
	jogador.add_child(load("res://codigo/jogador/heroi_tiny.gd").new())
	for hud in get_nodes_in_group("hud"):
		hud.hide()
	for n in current_scene.find_children("*", "CanvasLayer", true, false):
		if n.name == "Vinheta":
			n.hide()
	var luz := current_scene.get_node("Iluminacao")
	luz.definir_hora(12.0)
	luz.set_process(false)
	luz._aplicar()
	var camera := Camera2D.new()
	camera.position = Vector2(576, 384)
	current_scene.add_child(camera)
	camera.make_current()
	var posicoes := {}
	for objeto in terreno.get_node("Objetos3D").get_children():
		posicoes[objeto] = objeto.position
	var extracao := terreno.get_node("Extracao")
	# Canteiro de teste só no save isolado, para inspecionar solo seco, regado e suas junções.
	for y in range(24, 27):
		for x in range(12, 19):
			root.get_node("Fazenda").entulho.erase(Vector2i(x, y))
			root.get_node("Fazenda").solo[Vector2i(x, y)] = {"molhado": x >= 15, "planta": "", "dias": 0, "murcha": false}
	root.get_node("Fazenda").entulho_alterado.emit(Vector2i.ZERO)
	var entulho_antes: Dictionary = root.get_node("Fazenda").entulho.duplicate()
	terreno.get_node("Plantio").queue_redraw()
	var solo_antes: Dictionary = root.get_node("Fazenda").solo.duplicate(true)
	var colisao_antes: PackedVector2Array = terreno.get_node("Obstaculos/Obstaculo1").polygon.duplicate()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA))
	estacoes.definir_estacao(0, true)
	await _foto("original_geral")
	# O canteiro de teste atualiza o mapa no redraw; comparar só depois
	# dessa preparação, para medir exclusivamente a alternância visual.
	var celulas: Array[Vector2i] = terreno.get_node("Terra").get_used_cells()
	# Exercita a própria ação do F3, sem mudar o calendário nem gravar a opção.
	var painel: Node = root.get_node("PainelDebug")
	painel._alternar_fazenda_tiny()
	_conferir(troca.ativo, "Ação do F3 ativa a comparação")
	for indice in 4:
		estacoes.definir_estacao(indice, true)
		await _quadros()
		var pasta: String = troca.PASTA + troca.NOMES[indice] + "/"
		_conferir(terreno.get_node("Chao").tile_set.get_source(0).texture.resource_path == pasta + "terreno.png", "Terreno sazonal Tiny %d" % indice)
		for objeto in posicoes:
			_conferir(objeto.position == posicoes[objeto], "Planta preservada: " + objeto.name)
			if objeto is Sprite2D:
				_conferir(objeto.texture.resource_path.begins_with(pasta), "Sprite sazonal Tiny: " + objeto.name)
		# A comparação troca os índices gráficos dos atlas contínuos pelos
		# índices Tiny; as posições e os dados de plantio precisam permanecer.
		var atuais: Array[Vector2i] = terreno.get_node("Terra").get_used_cells()
		_conferir(atuais.size()==celulas.size() and celulas.all(func(c): return atuais.has(c)), "Células de plantio intactas")
		_conferir(root.get_node("Fazenda").entulho == entulho_antes, "Entulho persistido intacto")
		_conferir(root.get_node("Fazenda").solo == solo_antes, "Plantio e rega preservados pela troca")
		for registro in extracao._entulho.values():
			_conferir(registro["sprite"].texture.resource_path.begins_with(pasta), "Entulho sazonal integrado")
		_conferir(terreno.get_node("Lago")._textura_agua.resource_path == pasta + "agua.png", "Água sazonal integrada")
		_conferir(terreno.get_node("Objetos3D/Casa/Fachada").texture.resource_path == pasta + "casa.png", "Casa Tiny permanece aplicada após atualização da estação")
		await _foto(troca.NOMES[indice] + "_geral")
		root.size = Vector2i(1152, 648)
		root.content_scale_size = Vector2i(384, 216)
		camera.position = Vector2(380, 250)
		await _foto(troca.NOMES[indice] + "_casa")
		camera.position = Vector2(720, 480)
		await _foto(troca.NOMES[indice] + "_lago")
		camera.position = Vector2(256, 408)
		await _foto(troca.NOMES[indice] + "_horta")
		root.size = Vector2i(1152, 768)
		root.content_scale_size = Vector2i(1152, 768)
		camera.position = Vector2(576, 384)
	painel._alternar_fazenda_tiny()
	_conferir(not troca.ativo, "F3 restaura original")
	_conferir(terreno.get_node("Obstaculos/Obstaculo1").polygon == colisao_antes, "Colisão da casa restaurada")
	for objeto in troca._originais:
		if objeto.has_meta("peca"):
			_conferir(objeto.texture.resource_path.begins_with("res://assets/cenario/fazenda/cerca/inverno/"), "Cerca original segue estação ao restaurar")
		elif objeto.name == "Fachada" and troca._detalhe_casa != null:
			_conferir(objeto.texture == troca._detalhe_casa._texturas[3], "Fachada original sazonal restaurada")
		else:
			_conferir(objeto.texture == troca._originais[objeto]["texture"], "Textura original restaurada: " + objeto.name)
		_conferir(objeto.offset == troca._originais[objeto]["offset"], "Pivô original restaurado: " + objeto.name)
		_conferir(objeto.scale == troca._originais[objeto]["scale"] and objeto.texture_filter == troca._originais[objeto]["texture_filter"], "Escala e filtro originais restaurados: " + objeto.name)
	estacoes.definir_estacao(0, true)
	await _foto("original_restaurado")
	# A cidade herda fazenda.gd para configurar a câmera, mas não possui a casa deste mapa.
	change_scene_to_file("res://cenas/cidade.tscn")
	await _quadros(20)
	_conferir(current_scene.scene_file_path == "res://cenas/cidade.tscn", "Cidade carrega após sair da fazenda")
	_conferir(not current_scene.comparar_visual_fazenda, "Cidade não habilita comparação da fazenda")
	_conferir(not current_scene.has_node("ComparacaoTiny"), "Cidade não monta controlador exclusivo da fazenda")
	painel._alternar_fazenda_tiny()
	_conferir(not current_scene.has_node("ComparacaoTiny"), "Ação do F3 na cidade não cria comparação indevida")
	print("FAZENDA TINY: %d verificações, %d falhas" % [verificacoes, falhas])
	quit(1 if falhas else 0)
