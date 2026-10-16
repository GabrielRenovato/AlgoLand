extends SceneTree
const Aparencia := preload("res://codigo/dados/aparencia.gd")
const Padrao := preload("res://codigo/dados/padrao_armadura.gd")
var falhas := 0
var verificacoes := 0

func _initialize() -> void:
	_rodar()

func _verificar(nome: String, condicao: bool) -> void:
	verificacoes += 1
	if not condicao:
		falhas += 1
		print("FALHA ",nome)

func _mesma_cobertura(nativa: Image, refinada: Image) -> bool:
	var antiga := nativa.get_data()
	var nova := refinada.get_data()
	for y in 512:
		for x in 512:
			if antiga[(y*512+x)*4+3] != nova[(y*2*1024+x*2)*4+3]:
				return false
	return true

func _rodar() -> void:
	if ProjectSettings.get_setting("application/config/name") != "AlgoLand testes Carrasco":
		push_error("Execute com saves isolados.")
		quit(1)
		return
	await process_frame
	var conjuntos := []
	for indice in Aparencia.total_roupas():
		var raiz := Aparencia.raiz_armadura_visual(indice)
		var pecas := 0 if raiz.is_empty() else 15
		if not raiz.is_empty(): conjuntos.append(indice)
		for pagina in Padrao.CORPOS:
			var sprite := Sprite2D.new()
			Aparencia.aplicar_roupa(sprite,indice,pagina,pecas)
			_verificar("resolução/escala/nearest",sprite.texture.get_width() == 1024 and sprite.scale == Vector2(0.5,0.5) and sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST)
			_verificar("molde preservado",Aparencia.roupa(indice,pagina,pecas).get_width() == 512)
			sprite.free()
		Aparencia._cache_roupas_refinadas.clear()
	for indice in conjuntos:
		for mascara in [1,2,4,8,7,14,15]:
			var antiga := Aparencia.roupa(indice,"andar",mascara).get_image()
			var nova := Aparencia.roupa_refinada(indice,"andar",mascara).get_image()
			_verificar("peça isolada/combinação conserva cobertura",_mesma_cobertura(antiga,nova))
		Aparencia._cache_roupas_refinadas.clear()
	var raizes := {"elmo":Aparencia.raiz_armadura_visual(conjuntos[1]),"peitoral":Aparencia.raiz_armadura_visual(conjuntos[0]),"luvas":Aparencia.raiz_armadura_visual(conjuntos[2])}
	for pagina in Padrao.CORPOS:
		_verificar("mistura de conjuntos conserva encaixe",_mesma_cobertura(Aparencia.roupa(7,pagina,0,raizes).get_image(),Aparencia.roupa_refinada(7,pagina,0,raizes).get_image()))
	var arena: Node = load("res://cenas/cenario.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	await process_frame
	var jogador: Node = arena.get_node("Jogador")
	var inventario: Node = root.get_node("InventarioJogador")
	var equipado: Dictionary = inventario.equipados.duplicate()
	for indice in [7]+conjuntos:
		jogador.definir_aparencia(1,indice)
		jogador.no_reacao._familia = "lanca"
		for componente: Node in [jogador.no_arco,jogador.no_reacao,jogador.no_fazenda]:
			componente._sincronizar_aparencia()
			_verificar("ação dinâmica usa roupa refinada",componente._roupa.texture.get_width() == 1024 and componente._roupa.scale == Vector2(0.5,0.5))
		for sprite: Sprite2D in [jogador.sprite_roupa,jogador.roupa_ataque,jogador.roupa_lanca_ataque,jogador.sprite_roupa_forja]:
			_verificar("jogador usa roupa refinada",sprite.texture.get_width() == 1024 and sprite.scale == Vector2(0.5,0.5))
		if Aparencia.roupas()[indice]["id"] == "traje_cavalheiro":
			var cartola: Sprite2D = jogador.get_node("CompositeSprites/BaseSprites/CartolaSobreCabelo")
			cartola.sincronizar()
			_verificar("cartola acompanha escala da roupa",cartola.scale == Vector2(0.5,0.5) and cartola.texture.get_width() == 1024)
		_verificar("prévia não altera itens reais",inventario.equipados == equipado)
	jogador.definir_aparencia(1,2)
	jogador.sentar(jogador.global_position,1,5)
	_verificar("sentado mantém escala",jogador.sprite_roupa_forja.scale == Vector2(0.5,0.5))
	jogador.levantar(jogador.global_position)
	arena.queue_free()
	current_scene = null
	await process_frame
	print("Verificações: %d; falhas: %d" % [verificacoes,falhas])
	quit(falhas)
