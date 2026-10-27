extends SceneTree
## Prévia 3D independente e encaixe da mochila nas três proporções suportadas.
var falhas := 0
func _initialize() -> void: rodar.call_deferred()
func esperar(n := 8) -> void:
	for i in n: await process_frame
func verificar(ok: bool, texto: String) -> void:
	if not ok: falhas += 1; push_error(texto)
func rodar() -> void:
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	assert(DisplayServer.get_name()!="headless")
	root.mode = Window.MODE_WINDOWED
	root.get_node("Ranking").conexao_habilitada = false
	root.get_node("Introducao").pular_prologo()
	change_scene_to_file("res://cenas/casa.tscn")
	await esperar(30)
	var jogador = current_scene.get_node("Jogador")
	jogador.set_physics_process(false)
	jogador.aparencia_raven = {"pele":2,"olhos":4,"cor":[.35,.6,1,1]}
	var visual = jogador.get_node("HeroiBase3D")
	visual.set_process(false)
	visual._player.active = false
	var animacao: String = visual._player.assigned_animation
	var quadro: float = visual._player.current_animation_position
	var ui = root.get_node("EventosJogo").interface_p1()
	ui._abrir_tela("inventario")
	await esperar()
	var tela = ui._telas.inventario
	for cabelo in ["cabelo_curto","cabelo_longo","cabelo_cacheado"]:
		var roupas: Dictionary = visual.roupas_3d.duplicate()
		roupas.cabelo = cabelo
		visual.definir_roupas_3d(roupas)
		tela._atualizar_boneco()
		await esperar()
		verificar(tela._previa.heroi.roupas_3d==roupas and tela._previa.aparencia_raven.olhos==4,"Mochila preserva cabelo, roupa e olhos")
		verificar(visual._player.assigned_animation==animacao and visual._player.current_animation_position==quadro,"Mochila preserva animação do jogador")
		verificar(not tela._boneco.get_node("Corpo").visible,"Corpo antigo oculto")
		for tamanho in [Vector2i(576,324),Vector2i(288,512),Vector2i(320,324)]:
			root.content_scale_size = tamanho
			root.size = tamanho*2
			await esperar()
			var previa: Node2D = tela._previa
			var desenho: Rect2 = previa.global_transform*previa.retangulo_aparente()
			for slot in tela._slots_equipamento.values():
				verificar(not desenho.grow(2).intersects(slot.get_global_rect()),"Margem dos slots "+str(tamanho))
	print("PREVIA INVENTARIO 3D: ",falhas," falhas")
	quit(1 if falhas else 0)
