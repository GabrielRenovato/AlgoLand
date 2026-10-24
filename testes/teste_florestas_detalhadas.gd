extends SceneTree
## Regressão: chão efetivamente substituído, materiais sazonais e geometrias preservadas.
var falhas := 0
func _initialize() -> void: rodar.call_deferred()
func verificar(ok: bool, mensagem: String) -> void:
	if not ok:
		falhas += 1
		push_error(mensagem)
func quadros() -> void:
	for i in 5: await process_frame
func rodar() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"):
		quit(1)
		return
	await process_frame
	for andar in [1, 2, 5, 8]:
		var terreno: Node2D = load("res://cenas/fendas/terreno_%02d.tscn" % andar).instantiate()
		root.add_child(terreno)
		# O instalador é adiado; captura a geometria original já inicializada.
		var celulas := {}
		for nome in ["Chao", "Terra", "Agua", "Detalhes", "Penhasco"]:
			celulas[nome] = terreno.get_node(nome).get_used_cells()
		var bases := {}
		for objeto in terreno.get_node("Objetos3D").get_children():
			if objeto is Sprite2D: bases[objeto] = [objeto.position, objeto.scale, objeto.offset, objeto.texture, objeto.visible]
		var colisoes := {}
		for forma in terreno.get_node("Obstaculos").get_children():
			if forma is CollisionPolygon2D: colisoes[forma] = forma.polygon.duplicate()
		await quadros()
		var arte := terreno.get_node("FlorestaDetalhada")
		var estacoes := terreno.get_node("Estacoes")
		for e in [0, 1, 2, 3, 0]:
			estacoes.definir_estacao(e, true)
			await quadros()
			verificar(arte.estacao == e, "estação da floresta %d" % andar)
			verificar(arte.visible and not terreno.get_node("Chao").visible and not terreno.get_node("Terra").visible, "grama e terra antigas escondidas")
			var grama: Texture2D = arte._solo.get_shader_parameter("grama")
			var terra: Texture2D = arte._solo.get_shader_parameter("terra")
			verificar(grama.resource_path.ends_with("grama_%s.png" % arte.NOMES[e]), "grama detalhada sazonal")
			verificar(terra.resource_path.ends_with("%s/terra.png" % arte.NOMES[e]), "terra detalhada sazonal")
			var mascara: Image = arte._solo.get_shader_parameter("distribuicao").get_image()
			var centro_terra := false
			for celula in celulas.Terra:
				if estacoes._terra_continua.atlas_original(celula) in arte.Limite.CENTROS:
					verificar(mascara.get_pixelv(celula * 16 + Vector2i(8, 8) - Vector2i(arte.area.position)).b > 0.99, "trilha mantém cobertura de terra")
					centro_terra = true
					break
			verificar(centro_terra, "mapa contém trilha de terra")
			for nome in celulas: verificar(terreno.get_node(nome).get_used_cells() == celulas[nome], "células preservadas: " + nome)
			for objeto in bases: verificar(bases[objeto] == [objeto.position, objeto.scale, objeto.offset, objeto.texture, objeto.visible], "pivô, escala e profundidade física preservados")
			for forma in colisoes: verificar(forma.polygon == colisoes[forma], "colisões preservadas")
			for dados in arte._artes:
				var textura: Texture2D = dados.material.get_shader_parameter("arte")
				verificar(arte.NOMES[e] in textura.resource_path, "árvores/pedras sazonais")
				var recorte: Vector4 = dados.material.get_shader_parameter("recorte")
				verificar(recorte.z > 0 and recorte.w > 0, "recorte visível da arte; sem divisão inteira")
			for topo in terreno.get_node("RelevoOriginal")._topos: verificar(topo.material.get_shader_parameter("arte") == grama, "platô compartilha grama e fase do chão")
		print("Floresta ", andar, ": quatro estações, retorno e geometria conferidos")
		terreno.queue_free()
		await quadros()
	print("FALHAS FLORESTAS DETALHADAS: ", falhas)
	quit(1 if falhas else 0)
