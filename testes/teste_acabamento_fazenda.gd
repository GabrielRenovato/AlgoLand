extends SceneTree
## Revisão gráfica e regressões de geometria, estações e isolamento das cercas.
const SAIDA := "res://arte/previas/fazenda/acabamento_detalhado/"
var falhas := 0
var camera: Camera2D

func _initialize() -> void: _rodar.call_deferred()
func quadros(n := 8) -> void:
	for i in n: await process_frame
func verificar(ok: bool, texto: String) -> void:
	if not ok:
		falhas += 1
		push_error(texto)
func foto(nome: String, centro: Vector2, zoom := 2.0) -> void:
	camera.position = centro
	camera.zoom = Vector2(zoom, zoom)
	await quadros()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(SAIDA + nome + ".png")

func _rodar() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"):
		quit(1)
		return
	await process_frame
	root.get_node("Saves").trocar("solo")
	root.get_node("Introducao").pular_prologo()
	root.get_node("Fazenda").apagar()
	root.get_node("Transicao").hora_salva = 12.0
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1728, 1152)
	root.content_scale_size = Vector2i(1152, 768)
	change_scene_to_file("res://cenas/fazenda.tscn")
	await quadros(24)
	var terreno := current_scene.get_node("Terrains")
	var estacoes := terreno.get_node("Estacoes")
	var objetos := terreno.get_node("Objetos3D")
	var casa := objetos.get_node("Casa")
	var fachada: Sprite2D = casa.get_node("Fachada")
	var posicoes := {}
	for no in objetos.get_children(): posicoes[no] = no.position
	var obstaculos := {}
	for no in terreno.get_node("Obstaculos").get_children():
		if no is CollisionPolygon2D: obstaculos[no] = no.polygon.duplicate()
	var detalhes: TileMapLayer = terreno.get_node("Detalhes")
	var celulas := detalhes.get_used_cells()
	var extracao := terreno.get_node("Extracao")
	var fazenda := root.get_node("Fazenda")
	var celula := Vector2i(17, 31)
	fazenda.entulho[celula] = "mato"
	fazenda.entulho_alterado.emit(celula)
	# Uma cerca de outro mundo não pode ser alterada pela estação desta fazenda.
	var alheia := Sprite2D.new()
	root.add_child(alheia)
	alheia.add_to_group("cerca")
	alheia.set_meta("peca", "horizontal")
	for hud in get_nodes_in_group("hud"): hud.hide()
	for no in current_scene.find_children("*", "CanvasLayer", true, false): no.hide()
	var jogador := current_scene.get_node("Jogador")
	jogador.set_physics_process(false)
	jogador.hide()
	var luz := current_scene.get_node("Iluminacao")
	luz.definir_hora(12.0)
	luz.set_process(false)
	luz._aplicar()
	camera = Camera2D.new()
	current_scene.add_child(camera)
	camera.make_current()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA))
	for e in 4:
		estacoes.definir_estacao(e, true)
		estacoes.meteorologia.definir_clima(0, true)
		await quadros()
		var nome: String = ["primavera", "verao", "outono", "inverno"][e]
		verificar(nome in fachada.texture.resource_path, "casa troca a estação")
		verificar((fachada.texture.get_size() * fachada.scale).is_equal_approx(Vector2(112, 90)), "casa conserva área lógica e porta")
		for no in posicoes: verificar(no.position == posicoes[no], "objetos conservam posição")
		for no in obstaculos: verificar(no.polygon == obstaculos[no], "colisões preservadas")
		verificar(detalhes.get_used_cells() == celulas, "vegetação conserva células")
		for cerca in objetos.get_children():
			if not cerca.is_in_group("cerca"): continue
			var arte: Texture2D = cerca.material.get_shader_parameter("arte")
			verificar(nome in arte.resource_path, "cerca sazonal integrada")
			verificar(arte.get_size() == cerca.texture.get_size() * 4, "cerca conserva pivô e tamanho físico")
		verificar(alheia.texture == null and alheia.material == null, "outro mundo não recebe a estação da fazenda")
		var mato: Sprite2D = extracao._entulho[celula].sprite
		verificar(nome in mato.material.get_shader_parameter("arte").resource_path, "entulho usa mato detalhado sazonal")
		for v in 2:
			var material: ShaderMaterial = detalhes.tile_set.get_source(0).get_tile_data(Vector2i(0, 8 + v), 0).material
			verificar(material != null and nome in material.get_shader_parameter("arte").resource_path, "vegetação fixa sazonal")
		for textura in terreno.get_node("ChaoFazenda")._flores.texturas.values():
			verificar(textura.get_size() == Vector2(64, 64) and nome in textura.resource_path, "flores baixas usam arte detalhada sazonal")
		await foto("geral_%d" % e, Vector2(576, 384), 1.0)
		await foto("casa_%d" % e, casa.position + Vector2(0, -30), 3.0)
		await foto("canto_%d" % e, Vector2(110, 630), 3.0)
		await foto("lateral_%d" % e, Vector2(1040, 270), 3.0)
		await foto("matos_%d" % e, Vector2(290, 500), 4.0)
	var comparacao := current_scene.get_node("ComparacaoTiny")
	comparacao.definir_ativo(true)
	await quadros()
	for cerca in objetos.get_children():
		if cerca.is_in_group("cerca"): verificar(cerca.material == null, "Tiny remove acabamento da cerca")
	verificar(extracao._entulho[celula].sprite.material == null, "Tiny remove acabamento do mato")
	comparacao.definir_ativo(false)
	await quadros()
	for cerca in objetos.get_children():
		if cerca.is_in_group("cerca"): verificar(cerca.material != null, "comparação restaura cerca")
	verificar(extracao._entulho[celula].sprite.material != null, "comparação restaura mato")
	alheia.queue_free()
	print("Acabamento fazenda: ", falhas, " falhas; quatro estações, geometria, entulho e comparação Tiny.")
	current_scene.queue_free()
	current_scene = null
	await quadros()
	quit.call_deferred(1 if falhas else 0)
