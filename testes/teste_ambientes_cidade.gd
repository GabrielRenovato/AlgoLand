extends SceneTree

## Exercita estações, quadros reais, obstáculos sazonais e assentos com saves isolados.
var falhas := 0

func _initialize() -> void:
	_rodar()

func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ", nome)
	if not ok:
		falhas += 1

func quadros(n := 8) -> void:
	for i in n:
		await process_frame

func carregar(caminho: String) -> Node2D:
	if current_scene != null:
		current_scene.queue_free()
		current_scene = null
		await quadros()
	root.get_node("Transicao").hora_salva = 12.0
	var cena: Node2D = load(caminho).instantiate()
	root.add_child(cena)
	current_scene = cena
	await quadros()
	cena.get_node("Iluminacao").set_process(false)
	return cena

func por_prefixo(pai: Node, prefixo: String) -> Node2D:
	for filho in pai.get_children():
		if filho.name.begins_with(prefixo):
			return filho
	return null

func quadros_distintos(sprite: Sprite2D) -> bool:
	var im := sprite.texture.get_image()
	var w := im.get_width() / sprite.hframes
	var a := im.get_region(Rect2i(0, 0, w, im.get_height())).get_data()
	for q in range(1, sprite.hframes):
		if im.get_region(Rect2i(q * w, 0, w, im.get_height())).get_data() != a:
			return true
	return false

func _rodar() -> void:
	if ProjectSettings.get_setting("application/config/name") != "AlgoLand testes Carrasco":
		push_error("Execute com saves isolados.")
		quit(1)
		return
	await process_frame
	root.get_node("Calendario").dia = 1
	# Regressão visual: preservar a densidade dos arquivos originais, sem
	# redimensionar nem quantizar os móveis ao gerar as folhas sazonais.
	var manifesto: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/cenario/cidade/ambientes/manifesto.json"))
	for nome in ["banco", "mesa_piquenique", "banco_piquenique_esquerdo", "banco_piquenique_direito", "cerca", "feno", "lenha", "horta", "canteiro"]:
		var preparado: Dictionary = manifesto["externo/" + nome]
		var textura: Texture2D = load(preparado.get("fonte", "res://assets/cenario/cidade/decoracao/mobiliario/" + nome + ".png"))
		var usado := textura.get_image().get_used_rect()
		verificar("resolução original preservada: " + nome, Vector2i(preparado["usado"][2], preparado["usado"][3]) == usado.size and preparado["escala_origem"] == 1.0)
	var vila := await carregar("res://cenas/cidade.tscn")
	var decoracao := vila.get_node("Decoracao")
	var horta := por_prefixo(decoracao, "horta_")
	var feno := por_prefixo(decoracao, "feno_")
	var lenha := por_prefixo(decoracao, "lenha_")
	var mesa := por_prefixo(decoracao, "mesa_piquenique_")
	var bancos := [por_prefixo(decoracao, "banco_piquenique_esquerdo_"), por_prefixo(decoracao, "banco_piquenique_direito_")]
	verificar("mesa sem assento embutido", mesa.get_node_or_null("Assento") == null)
	for banco in bancos:
		verificar("banco independente da mesa: " + banco.name, banco.get_parent() == decoracao and banco.position.distance_to(mesa.position) >= 36)
		verificar("cada banco tem sua colisão: " + banco.name, decoracao.has_node("Obstaculos/" + banco.name))
	var galinha := por_prefixo(decoracao, "galinha_")
	verificar("galinha tem quadros de bicar, não apenas luz pulsando", quadros_distintos(galinha.get_node("Imagem")))
	var imagens_horta: Array[PackedByteArray] = []
	for estacao in 4:
		vila.get_node("Terrains/Estacoes").definir_estacao(estacao, true)
		await quadros(40)
		verificar("horta segue o F3 na estação " + str(estacao), horta.get_node("DetalheAmbiente").estacao == estacao)
		imagens_horta.append(horta.get_node("Imagem").texture.get_image().get_data())
		verificar("feno só aparece na colheita: " + str(estacao), feno.visible == (estacao == 2))
		verificar("colisão do feno acompanha a estação: " + str(estacao), decoracao.get_node("Obstaculos/" + feno.name).disabled == (estacao != 2))
		verificar("lenha reservada ao período frio: " + str(estacao), lenha.visible == (estacao in [2, 3]))
		verificar("piquenique recolhido no inverno: " + str(estacao), mesa.visible == (estacao != 3))
		verificar("galinha recolhida no inverno: " + str(estacao), galinha.visible == (estacao != 3))
		for banco in bancos:
			verificar("banco acompanha estação: %s/%d" % [banco.name, estacao], banco.visible == (estacao != 3) and banco.get_node("Assento").is_processing() == (estacao != 3))
	for a in 4:
		for b in range(a + 1, 4):
			verificar("cultivo diferente entre estações %d e %d" % [a, b], imagens_horta[a] != imagens_horta[b])
	vila.get_node("Terrains/Estacoes").definir_estacao(0, true)
	await quadros(40)
	var jogador: Node2D = vila.get_node("Jogador")
	var consulta := PhysicsShapeQueryParameters2D.new()
	consulta.shape = jogador.get_node("CollisionShape2D").shape
	consulta.collision_mask = 64
	for objeto in decoracao.get_children():
		var cadeira := objeto.get_node_or_null("Assento")
		if cadeira == null:
			continue
		cadeira.abrir_tela()
		verificar("jogador senta com sua própria roupa: " + objeto.name, jogador.esta_sentado)
		cadeira._levantar()
		await physics_frame
		consulta.transform = Transform2D(0, jogador.position + Vector2(0, 9))
		verificar("saída do assento sem obstáculo: " + objeto.name, vila.get_world_2d().direct_space_state.intersect_shape(consulta).is_empty())
		verificar("saída dentro da cidade: " + objeto.name, Rect2(14, 14, 676, 536).has_point(jogador.position + Vector2(0, 9)))
	for id in ["venda", "sede", "enfermaria", "pousada", "mistica", "casa_bento"]:
		var cena := await carregar("res://cenas/cidade/" + id + ".tscn")
		var interior := cena.get_node("Interior")
		var sala := interior.get_node("Sala")
		verificar("sala em perspectiva ortogonal, sem fundo frontal: " + id, sala.get_script().resource_path == "res://codigo/cidade/sala_topdown.gd" and sala.scale == Vector2.ONE)
		verificar("sala usa materiais pintados compartilhados: " + id, sala.FOLHA.resource_path.begins_with("res://assets/cenario/cidade/interiores_detalhados/materiais/"))
		var detalhes := interior.find_children("DetalheAmbiente", "Node", true, false)
		verificar("móveis detalhados integrados: " + id, not detalhes.is_empty())
		for estacao in 4:
			root.get_node("Calendario").dia = estacao * 30 + 1
			await quadros()
			var corretos := true
			for detalhe in detalhes:
				corretos = corretos and detalhe.estacao == estacao and detalhe.imagem.scale == Vector2(0.25, 0.25) and detalhe.imagem.texture.resource_path.begins_with("res://assets/cenario/cidade/interiores_detalhados/")
			verificar("interior segue calendário com arte4× e escala lógica preservada: %s/%d" % [id, estacao], corretos)
		var origem: Vector2 = cena.get_node("Chegada_entrada").position
		var dados: Dictionary = interior.dados()["casas"][id]
		for chave in dados["pontos"]:
			var ponto := Vector2(dados["pontos"][chave][0], dados["pontos"][chave][1])
			verificar("rota interna preservada: " + id + "/" + chave, not cena.caminho_entre(origem, ponto).is_empty())
		var lareira := interior.get_node_or_null("Lareira/Imagem")
		if lareira != null:
			verificar("chamas têm quadros distintos: " + id, quadros_distintos(lareira))
			var detalhe := lareira.get_parent().get_node_or_null("DetalheAmbiente")
			if detalhe != null and detalhe.dados.get("calor_sazonal", false):
				root.get_node("Calendario").dia = 31
				await quadros()
				var apagada := true
				for filho in lareira.get_parent().get_children():
					if filho is PointLight2D:
						apagada = apagada and not filho.visible
				verificar("aquecimento apagado no verão: " + id, apagada)
	print("Ambientes: %d falhas" % falhas)
	current_scene.queue_free()
	current_scene = null
	await quadros()
	quit(1 if falhas else 0)
