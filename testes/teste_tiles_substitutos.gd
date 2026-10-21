extends SceneTree

## Verifica os mapas reais nas quatro estações e permite revisão gráfica isolada.
var falhas := 0
var capturar := false

func _initialize() -> void:
	_rodar()

func quadros(n := 8) -> void:
	for i in n:
		await process_frame

func verificar(ok: bool, mensagem: String) -> void:
	if not ok:
		falhas += 1
		print("FALHA ", mensagem)

func _rodar() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"):
		push_error("Use save isolado.")
		quit(1)
		return
	capturar = "--capturar" in OS.get_cmdline_user_args()
	await process_frame
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1152, 768)
	root.content_scale_size = Vector2i(576, 384)
	var calendario: Node = root.get_node("Calendario")
	var transicao: Node = root.get_node("Transicao")
	DirAccess.make_dir_recursive_absolute("/tmp/algoland-tiles-capturas")
	var locais := ["fazenda", "cidade", "casa", "praia", "cenario", "terreno", "terreno_fenda"]
	for andar in range(1,12): locais.append("fendas/terreno_%02d" % andar)
	for local in locais:
		var filtro := ""
		for argumento in OS.get_cmdline_user_args():
			if argumento.begins_with("--local="):
				filtro = argumento.trim_prefix("--local=")
		if not filtro.is_empty() and local != filtro:
			continue
		for estacao in 4:
			if current_scene != null:
				current_scene.queue_free()
				await quadros()
			calendario.dia = 1 + estacao * calendario.DIAS_POR_ESTACAO
			transicao.hora_salva = 12.0
			var cena: Node = load("res://cenas/" + local + ".tscn").instantiate()
			if local == "fazenda" and "--detalhe-terra" in OS.get_cmdline_user_args():
				var fazenda: Node = root.get_node("Fazenda")
				fazenda.solo.clear()
				for y in range(24,27):
					for x in range(13,18):
						var pos := Vector2i(x,y)
						fazenda.entulho.erase(pos)
						fazenda.solo[pos] = {"molhado":x>=16,"planta":"","dias":0,"murcha":false}
			root.add_child(cena)
			current_scene = cena
			await quadros(12)
			var terreno := cena.get_node_or_null("Terrains")
			if cena.has_node("Estacoes"):
				terreno = cena
			if terreno and terreno.has_node("Estacoes"):
				terreno.get_node("Estacoes").definir_estacao(estacao, true)
				if "--clima-limpo" in OS.get_cmdline_user_args():
					var meteorologia: Node = terreno.get_node("Estacoes").meteorologia
					meteorologia.definir_clima(meteorologia.Estado.LIMPO, true)
			if cena.has_node("Iluminacao"):
				cena.get_node("Iluminacao").set_process(false)
				cena.get_node("Iluminacao")._aplicar()
			var jugador := cena.get_node_or_null("Jogador")
			if jugador:
				jugador.set_physics_process(false)
				jugador.camera.position_smoothing_enabled = false
				jugador.camera.set_as_top_level(true)
				var centros := {"fazenda": Vector2(544,340), "cidade": Vector2(352,288), "casa": Vector2(128,80), "praia": Vector2(480,240), "cenario": Vector2(332,137)}
				if local == "fazenda" and "--detalhe-terra" in OS.get_cmdline_user_args():
					centros[local] = Vector2(240,372)
					jugador.camera.zoom = Vector2(2,2)
				if local == "cidade" and "--detalhe-arvores" in OS.get_cmdline_user_args():
					centros[local] = Vector2(816,80)
					jugador.camera.limit_top = -1000
					jugador.camera.limit_bottom = 10000
					jugador.camera.zoom = Vector2(2,2)
				if local == "fazenda" and "--detalhe-arvores" in OS.get_cmdline_user_args():
					centros[local] = Vector2(640,215)
				if local == "fazenda" and "--detalhe-penhasco" in OS.get_cmdline_user_args():
					centros[local] = Vector2(544,56)
					jugador.camera.limit_top = -1000
					jugador.camera.limit_bottom = 10000
					jugador.camera.zoom = Vector2(2,2)
				if local == "fazenda" and "--comparar-especies" in OS.get_cmdline_user_args():
					var extracao: Node = terreno.get_node("Extracao")
					var recurso: Dictionary = extracao.recursos.filter(func(r): return r.tipo == "arvore")[0]
					root.get_node("Fazenda").removidos.erase(recurso.chave)
					extracao._sincronizar_arvore(recurso)
					var adulta: Sprite2D = terreno.get_node(recurso.no)
					for objeto in terreno.get_node("Objetos3D").get_children():
						if objeto is Sprite2D and objeto != adulta and objeto.texture is AtlasTexture and objeto.texture.resource_name in ["arvore","arvore_var"]:
							objeto.visible = false
					jugador.global_position = adulta.global_position + Vector2(45,5)
					var pinheiro := Sprite2D.new()
					pinheiro.texture = terreno.get_node("Estacoes").ARVORES_VARIACAO[estacao]
					pinheiro.offset = adulta.offset
					pinheiro.centered = adulta.centered
					pinheiro.scale = adulta.scale
					pinheiro.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
					pinheiro.position = adulta.position + Vector2(90,0)
					pinheiro.z_index = adulta.z_index
					adulta.get_parent().add_child(pinheiro)
					centros[local] = adulta.global_position + Vector2(45,-48)
					jugador.camera.zoom = Vector2(2,2)
					jugador.camera.limit_top = -1000
					jugador.camera.limit_bottom = 10000
					jugador.camera.limit_left = -1000
					jugador.camera.limit_right = 10000
				jugador.camera.global_position = centros[local]
			else:
				var camera := Camera2D.new()
				camera.position = Vector2(332, 137) if local == "terreno" else Vector2.ZERO
				cena.add_child(camera)
			for sprite: Sprite2D in cena.find_children("*", "Sprite2D", true, false):
				if sprite.texture is AtlasTexture:
					var atlas := sprite.texture as AtlasTexture
					if atlas.atlas and "substitutos" in atlas.atlas.resource_path:
						verificar(not atlas.region in [Rect2(16,128,16,32), Rect2(32,128,32,32)], local + ": arbusto rejeitado ainda no mapa: " + str(sprite.get_path()))
						verificar(Rect2(Vector2.ZERO, atlas.atlas.get_size()).encloses(atlas.region), local + ": recorte fora do atlas: " + str(sprite.get_path()))
						if atlas.resource_name in ["arvore", "arvore_var"]:
							var nomes := ["spring", "summer", "autumn", "winter"]
							var prefixo := "arvore_var_" if atlas.resource_name == "arvore_var" else "arvore_"
							verificar(atlas.atlas.resource_path.ends_with(prefixo + nomes[estacao] + ".png"), local + ": árvore na estação errada: " + str(sprite.get_path()) + " " + atlas.atlas.resource_path)
			for camada: TileMapLayer in cena.find_children("*", "TileMapLayer", true, false):
				if not camada.tile_set: continue
				for celula in camada.get_used_cells():
					var fonte := camada.tile_set.get_source(camada.get_cell_source_id(celula)) as TileSetAtlasSource
					verificar(fonte != null and fonte.has_tile(camada.get_cell_atlas_coords(celula)), local + ": célula sem tile")
					if fonte:
						var caminho := fonte.texture.resource_path
						verificar(not ("Seasonal Forest" in caminho or "Starter Pack" in caminho or "terreno/mana_seed" in caminho or "gentle_forest" in caminho), local + ": tile legado: " + caminho)
			if terreno and terreno.has_node("Estacoes"):
				var terra = terreno.get_node("Estacoes")._terra_continua
				if local in ["fazenda", "terreno", "fendas/terreno_06", "fendas/terreno_10"]:
					verificar(terra._fonte != null, local + ": terra contínua configurada")
				if local in ["fendas/terreno_01","fendas/terreno_02","fendas/terreno_05","fendas/terreno_08"]:
					verificar(terra._fonte != null and terra._mascarada == null, local + ": floresta com terra própria contínua")
				if terra._fonte != null:
					verificar(terra._fonte.texture == terra.FOLHAS[estacao], local + ": estação da terra")
					for dados in terra._celulas:
						var pos: Vector2i = dados.celula
						verificar(terra.atlas_original(pos) == dados.atlas, local + ": plantio preserva máscara original")
						verificar(terra._camada.get_cell_source_id(pos) == terra._id and terra._camada.get_cell_atlas_coords(pos) == Vector2i(posmod(pos.x,8),posmod(pos.y,8)+dados.banco*8), local + ": terra contínua entre centro e bordas")
					var quantidade: int = terra._camada.get_used_cells().size()
					terra.aplicar(estacao,false)
					for dados in terra._celulas:
						verificar(terra._camada.get_cell_source_id(dados.celula) == dados.id and terra._camada.get_cell_atlas_coords(dados.celula) == dados.atlas and terra._camada.get_cell_alternative_tile(dados.celula) == dados.alternativa, local + ": restauração da terra para comparação Tiny")
					terra.aplicar(estacao,true)
					verificar(terra._camada.get_used_cells().size() == quantidade, local + ": posições da terra preservadas")
				var grama = terreno.get_node("Estacoes")._grama_continua
				if local in ["fazenda", "terreno", "fendas/terreno_06", "fendas/terreno_10"]:
					verificar(grama._fonte != null, local + ": chão contínuo configurado")
				if grama._fonte != null:
					verificar(grama._fonte.texture == grama.FOLHAS[estacao], local + ": estação da grama")
					for dados in grama._celulas:
						var camada: TileMapLayer = dados.camada
						var pos: Vector2i = dados.celula
						verificar(camada.get_cell_source_id(pos) == grama._id and camada.get_cell_atlas_coords(pos) == Vector2i(posmod(pos.x,8),posmod(pos.y,8)+dados.banco*8), local + ": fase contínua da grama")
					var quantidade: int = grama._camada.get_used_cells().size()
					grama.aplicar(estacao,false)
					for dados in grama._celulas:
						var camada: TileMapLayer = dados.camada
						verificar(camada.get_cell_source_id(dados.celula) == dados.id and camada.get_cell_atlas_coords(dados.celula) == dados.atlas and camada.get_cell_alternative_tile(dados.celula) == dados.alternativa, local + ": restauração da grama para comparação Tiny")
					grama.aplicar(estacao,true)
					verificar(grama._camada.get_used_cells().size() == quantidade, local + ": células do chão preservadas")
			if local == "cidade":
				verificar(cena._terra_mascarada._fontes.size() == 2,"Cidade: terra aplicada nos dois pares Wang")
			if local == "fazenda":
				verificar(not root.get_node("Fazenda").entulho.values().has("arbusto"), "Fazenda: arbusto no entulho")
				var estacoes: Node = terreno.get_node("Estacoes")
				verificar(not estacoes._atlas_arvores.is_empty() and not estacoes._atlas_variacao.is_empty(),"Fazenda: duas espécies reais no mapa")
				var paredao = estacoes._penhasco_original
				verificar(paredao._fonte != null,"Fazenda: face rochosa usa seis colunas de variação")
				if paredao._fonte != null:
					var celulas: Array[Vector2i] = paredao._camada.get_used_cells()
					verificar(paredao._fonte.texture.resource_path.ends_with(["spring","summer","autumn","winter"][estacao]+".png"),"Fazenda: estação do penhasco")
					paredao.aplicar(estacao,false)
					for dados in paredao._celulas:
						verificar(paredao._camada.get_cell_source_id(dados.celula)==dados.id and paredao._camada.get_cell_atlas_coords(dados.celula)==dados.atlas,"Fazenda: comparação Tiny restaura tiles originais")
					paredao.aplicar(estacao,true)
					verificar(paredao._camada.get_used_cells()==celulas,"Fazenda: troca visual preserva todas as células")
			await quadros()
			if capturar:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("/tmp/algoland-tiles-capturas/%s_%d.png" % [local.replace("/", "_"), estacao])
			print("OK mapa ", local, " estação ", estacao)
	print("RESULTADO: ", falhas, " falhas")
	if current_scene != null:
		current_scene.queue_free()
		await quadros()
	quit(1 if falhas else 0)
