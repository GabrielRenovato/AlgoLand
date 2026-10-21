extends SceneTree

## Queda real, para os dois lados e nas quatro estações, com save isolado.
var falhas := 0
var registros: Array = []

func _initialize() -> void:
	_rodar()

func verificar(ok: bool, mensagem: String) -> void:
	if not ok:
		falhas += 1
		print("FALHA ", mensagem)

func quadros(n := 8) -> void:
	for i in n:
		await process_frame

func _rodar() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"):
		push_error("Use save isolado para conferir a queda.")
		quit(1)
		return
	await process_frame
	var capturar := "--capturar" in OS.get_cmdline_user_args()
	var fazenda: Node = root.get_node("Fazenda")
	var calendario: Node = root.get_node("Calendario")
	fazenda.removidos.clear()
	root.get_node("Transicao").hora_salva = 12.0
	var cena: Node = load("res://cenas/fazenda.tscn").instantiate()
	root.add_child(cena)
	current_scene = cena
	await quadros(16)
	var terreno: Node = cena.get_node("Terrains")
	var extracao: Node = terreno.get_node("Extracao")
	var recurso: Dictionary = extracao.recursos[0]
	var original: Sprite2D = terreno.get_node(recurso.no)
	var obstaculo: CollisionPolygon2D = terreno.get_node(recurso.obstaculo)
	var jogador: Node = cena.get_node("Jogador")
	jogador.set_physics_process(false)
	jogador.camera.position_smoothing_enabled = false
	jogador.camera.set_as_top_level(true)
	jogador.camera.global_position = recurso.pos - Vector2(0, 40)
	DirAccess.make_dir_recursive_absolute("/tmp/algoland-queda-carvalho")
	for estacao in 4:
		calendario.dia = 1 + estacao * 30
		terreno.get_node("Estacoes").definir_estacao(estacao, true)
		terreno.get_node("Estacoes").meteorologia.definir_clima(0, true)
		for lado in [1, -1]:
			fazenda.removidos.erase(recurso.chave)
			extracao._sincronizar_arvore(recurso)
			# Também confere cópia da escala na copa e no toco.
			original.scale = Vector2(0.75, 0.75) if estacao == 3 else Vector2.ONE
			await quadros()
			var golpe: Vector2 = terreno.to_global(recurso.pos - Vector2(lado * 12, 0))
			extracao.impacto("machado", golpe, 3)
			await create_timer(0.20).timeout
			extracao.impacto("machado", golpe)
			var tronco: Sprite2D = extracao.get_node_or_null("Queda_" + String(recurso.chave))
			verificar(tronco != null, "gera a copa caindo")
			if tronco == null:
				continue
			verificar(not original.visible and fazenda.tem_toco(recurso.chave), "corte troca adulta pelo toco")
			verificar(tronco.scale == original.scale and extracao._tocos[recurso.chave].scale == original.scale, "copa e toco conservam a escala")
			var origem: Vector2 = tronco.position + tronco.offset * tronco.scale
			verificar(origem.distance_to(recurso.pos + original.offset * original.scale) < 0.01, "primeiro quadro não salta ao recortar")
			var pivo: Vector2 = tronco.position
			var tempo := 0.0
			var proxima_captura := 0.0
			var indice := 0
			var chegou_ao_chao := false
			var angulo_anterior := 0.0
			while is_instance_valid(tronco) and tempo < 2.5:
				verificar(tronco.position.distance_to(pivo) < 0.01, "base não desliza durante a queda")
				verificar(tronco.rotation * lado >= -0.001, "cai para o lado oposto ao golpe")
				var angulo: float = tronco.rotation * lado
				if tempo < 0.95:
					verificar(angulo >= angulo_anterior - 0.001, "inclinação contínua antes do impacto")
				angulo_anterior = angulo
				chegou_ao_chao = chegou_ao_chao or angulo >= deg_to_rad(89.5)
				if tempo >= proxima_captura:
					registros.append({"estacao":estacao,"lado":lado,"quadro":indice,"tempo":tempo,"angulo":tronco.rotation,"pivo":[pivo.x,pivo.y],"alfa":tronco.modulate.a})
					if capturar and (estacao == 0 or indice % 6 == 0):
						await RenderingServer.frame_post_draw
						root.get_texture().get_image().save_png("/tmp/algoland-queda-carvalho/%d_%d_%03d.png" % [estacao,lado,indice])
					indice += 1
					proxima_captura += 1.0 / 24.0
				await process_frame
				tempo += extracao.get_process_delta_time()
			verificar(chegou_ao_chao, "copa chega ao chão")
			verificar(not is_instance_valid(tronco), "copa é liberada ao terminar")
			verificar(not obstaculo.disabled and extracao._tocos.has(recurso.chave), "toco continua sólido depois da queda")
			if capturar:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("/tmp/algoland-queda-carvalho/%d_%d_fim.png" % [estacao,lado])
			print("OK queda estação ", estacao, " lado ", lado)
	original.scale = Vector2.ONE
	FileAccess.open("/tmp/algoland-queda-carvalho/trajetoria.json", FileAccess.WRITE).store_string(JSON.stringify(registros,"\t"))
	print("RESULTADO: ", falhas, " falhas")
	cena.queue_free()
	await quadros()
	quit(1 if falhas else 0)
