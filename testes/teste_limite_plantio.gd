extends SceneTree

## Reproduz canteiros antigos na borda e golpes da enxada nos tiles mistos. Só com saves isolados.
const Solo := preload("res://codigo/cenario/solo_arado.gd")
const Limite := preload("res://codigo/cenario/limite_plantio.gd")
var falhas := 0

func _initialize() -> void:
	_rodar()

func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ", nome)
	if not ok:
		falhas += 1

func quadros() -> void:
	for i in 4:
		await process_frame

func _rodar() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"):
		quit(1)
		return
	await process_frame
	for estacao in range(4):
		for molhado in [false, true]:
			var sem_grama := true
			var terra_visivel := true
			for atlas in [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(1, 1), Vector2i(3, 1), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2)]:
				# Conexões completas são o caso que mais encobria a grama nos canteiros antigos.
				var textura := Solo.textura(estacao, molhado, Vector2i(6, 21), 255, 255, atlas).get_image()
				for y in 16:
					for x in 16:
						var terra := Limite.cobre_pixel(estacao, atlas, x, y)
						sem_grama = sem_grama and (terra or textura.get_pixel(x, y).a == 0.0)
						terra_visivel = terra_visivel and (not terra or textura.get_pixel(x, y).a == 1.0)
			verificar("estação %d / molhado %s: grama preservada e terra arada visível" % [estacao, molhado], sem_grama and terra_visivel)
	var fazenda: Node = root.get_node("Fazenda")
	root.get_node("Calendario").dia = 1
	fazenda.solo.clear()
	fazenda.entulho.clear()
	fazenda.entulho_iniciado = true
	var cena: Node = load("res://cenas/fazenda.tscn").instantiate()
	root.add_child(cena)
	current_scene = cena
	await quadros()
	cena.get_node("Terrains/Estacoes").definir_estacao(0, true)
	var plantio: Node = cena.get_node("Terrains/Plantio")
	var terra: TileMapLayer = cena.get_node("Terrains/Terra")
	var fora := Vector2i(6, 21)
	var dentro := Vector2i(7, 22)
	verificar("reprodução usa o canto misto real da fazenda", plantio._atlas_da_terra(terra, fora) == Vector2i(1, 0))
	# A borda atual tem terra no centro; testa a recusa com um centro realmente
	# coberto de grama, sem depender do recorte de um pacote antigo.
	var id_original := terra.get_cell_source_id(fora)
	var atlas_visual := terra.get_cell_atlas_coords(fora)
	var alternativa := terra.get_cell_alternative_tile(fora)
	terra.set_cell(fora,0,Vector2i(0,1))
	verificar("enxada recusa centro com grama", plantio.avaliar_terreno("enxada", fora) == fazenda.MSG_FORA)
	plantio._ao_impacto("enxada", Vector2(fora) * 16 + Vector2(8, 8))
	verificar("impacto inválido não altera o solo", not fazenda.solo.has(fora))
	verificar("enxada aceita terra pura", plantio.avaliar_terreno("enxada", dentro) == "")
	plantio._ao_impacto("enxada", Vector2(dentro) * 16 + Vector2(8, 8))
	verificar("impacto válido ara uma única célula", fazenda.solo.size() == 1 and fazenda.solo.has(dentro))
	terra.set_cell(fora,id_original,atlas_visual,alternativa)
	# Um save antigo pode ter canteiro na borda: corrigir só o desenho, sem apagar solo ou colheita.
	fazenda.solo[fora] = {"molhado": false, "planta": "", "dias": 0, "murcha": false}
	verificar("canteiro antigo continua regável", plantio.avaliar_terreno("regar", fora) == "")
	fazenda.entulho[Vector2i(37, 36)] = "mato"
	verificar("limpar mato da borda continua permitido", plantio.avaliar_terreno("enxada", Vector2i(37, 36)) == "")
	verificar("limite externo continua bloqueado", plantio.avaliar_terreno("enxada", Vector2i(5, 21)) == fazenda.MSG_FORA)
	cena.queue_free()
	current_scene = null
	await quadros()
	print("FALHAS: ", falhas)
	quit(falhas)
