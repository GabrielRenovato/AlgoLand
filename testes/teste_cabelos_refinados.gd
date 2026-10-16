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

func _rodar() -> void:
	if ProjectSettings.get_setting("application/config/name") != "AlgoLand testes Carrasco":
		push_error("Execute com saves isolados.")
		quit(1)
		return
	await process_frame
	var indice_cartola := -1
	var indice_elmo := -1
	for i in Aparencia.total_roupas():
		if Aparencia.roupas()[i]["id"] == "traje_cavalheiro": indice_cartola = i
		if Aparencia.roupas()[i]["id"] == "armadura_cavaleiro": indice_elmo = i
	for indice in Aparencia.total_cabelos():
		for pagina in Padrao.CORPOS:
			var sprite := Sprite2D.new()
			Aparencia.aplicar_cabelo(sprite,indice,pagina,2,0)
			_verificar("resolução/escala/nearest",sprite.texture.get_size() == Vector2(1024,1024) and sprite.scale == Vector2(0.5,0.5) and sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST)
			_verificar("molde nativo preservado",Aparencia.cabelo(indice,pagina,-1,0).get_width() == 512)
			_verificar("elmo oculta cabelo",Aparencia.cabelo_refinado(indice,pagina,indice_elmo,15).get_image().is_invisible())
			_verificar("sem elmo restaura penteado",Aparencia.cabelo_refinado(indice,pagina,indice_elmo,14) == sprite.texture)
			var nativo := Aparencia.cabelo(indice,pagina,indice_cartola,15).get_image()
			var sob_cartola := Aparencia.cabelo_refinado(indice,pagina,indice_cartola,15).get_image()
			var recorte := true
			for y in 512:
				for x in 512:
					if nativo.get_pixel(x,y).a != sob_cartola.get_pixel(x*2,y*2).a:
						recorte = false
			_verificar("cartola conserva recorte aprovado",recorte)
			sprite.free()
	var arena: Node = load("res://cenas/cenario.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	await process_frame
	var jogador: Node = arena.get_node("Jogador")
	jogador.definir_aparencia(4,2)
	jogador.no_reacao._familia = "um_mao"
	for sprite: Sprite2D in [jogador.sprite_cabelo,jogador.cabelo_ataque,jogador.cabelo_lanca_ataque,jogador.sprite_cabelo_forja]:
		_verificar("jogador real usa resolução dupla",sprite.texture.get_width() == 1024 and sprite.scale == Vector2(0.5,0.5))
	for componente: Node in [jogador.no_arco,jogador.no_reacao,jogador.no_fazenda]:
		componente._sincronizar_aparencia()
		_verificar("ação dinâmica usa resolução dupla",componente._cabelo.texture.get_width() == 1024 and componente._cabelo.scale == Vector2(0.5,0.5))
	jogador.definir_aparencia(1,indice_cartola)
	await process_frame
	var cartola: Sprite2D = jogador.get_node("CompositeSprites/BaseSprites/CartolaSobreCabelo")
	cartola.sincronizar()
	_verificar("cartola composta conserva tamanho",cartola.texture.get_width() == 1024 and cartola.scale == Vector2(0.5,0.5))
	_verificar("cartola segue quadro da roupa",cartola.frame == jogador.sprite_roupa.frame)
	_verificar("cabelo não duplica sobre chapéu",jogador.sprite_cabelo.self_modulate.a == 0)
	jogador.definir_aparencia(1,2)
	_verificar("tirar chapéu restaura cabelo",jogador.sprite_cabelo.self_modulate.a == 1 and jogador.sprite_cabelo.texture == Aparencia.cabelo_refinado(1,"andar",2,0))
	jogador.sentar(jogador.global_position,1,5)
	_verificar("sentado mantém cabelo e proporção",jogador.sprite_cabelo_forja.texture == Aparencia.cabelo_refinado(1,"sentado",2,0) and jogador.sprite_cabelo_forja.scale == Vector2(0.5,0.5))
	jogador.levantar(jogador.global_position)
	var tela: Node = load("res://cenas/criacao_personagem.tscn").instantiate()
	root.add_child(tela)
	await process_frame
	tela.cabelo = 6
	tela.roupa = 2
	tela._atualizar_previa()
	_verificar("prévia mantém proporção",tela._previa_cabelo.texture.get_width() == 1024 and tela._previa_cabelo.scale == Vector2(0.5,0.5))
	tela.queue_free()
	arena.queue_free()
	current_scene = null
	await process_frame
	print("Verificações: %d; falhas: %d" % [verificacoes,falhas])
	quit(falhas)
