extends SceneTree

const Aparencia := preload("res://codigo/dados/aparencia.gd")

func _initialize() -> void:
	_rodar.call_deferred()

func _rodar() -> void:
	if ProjectSettings.get_setting("application/config/name") != "AlgoLand testes Carrasco":
		push_error("Execute com saves isolados.")
		quit(1)
		return
	for pagina in Aparencia.PAGINAS_ANDAR + Aparencia.PAGINAS_COMBATE:
		var sprite := Sprite2D.new()
		Aparencia.aplicar_corpo(sprite,pagina,0,0)
		assert(sprite.texture.resource_path == Aparencia.RAIZ_CORPO_REFINADO+pagina+".png")
		assert(sprite.texture.get_size() == Vector2(1024,1024))
		assert(sprite.scale == Vector2(0.5,0.5))
		sprite.free()
	var cena := Node2D.new()
	root.add_child(cena)
	current_scene = cena
	var jogador = load("res://cenas/jogador.tscn").instantiate()
	cena.add_child(jogador)
	jogador.set_physics_process(false)
	jogador._arvore_animacao.active = false
	assert(jogador.get_node_or_null("CompositeSprites/CorridaBaseNova") == null)
	var opcoes: Array = root.get_node("PainelDebug")._opcoes["PERSONAGEM"]
	var base: Array = []
	for opcao in opcoes:
		if opcao[0] == "MANA SEED REFINADO":
			base = opcao
	assert(not base.is_empty(), "F3 deve manter a opção da base refinada")
	var roupa: int = jogador.roupa_atual
	var cabelo: int = jogador.cabelo_atual
	var inventario: Node = root.get_node("InventarioJogador")
	var equipados: Dictionary = inventario.equipados.duplicate()
	base[1].call()
	assert(jogador.roupa_atual == roupa and jogador.cabelo_atual == cabelo)
	assert(inventario.equipados == equipados)
	for sprite in [jogador.sprite_corpo,jogador.corpo_espada_escudo_ataque,jogador.corpo_lanca_escudo_ataque]:
		assert(sprite.texture.get_width() == 1024 and sprite.scale == Vector2(0.5,0.5))
	for animacao in ["idle_down","run_right","sword_slash_1_right","sword_slash_2_right","sword_slash_3_right"]:
		assert(jogador.reprodutor_anim.has_animation(animacao))
		jogador.reprodutor_anim.play(animacao)
		jogador.reprodutor_anim.advance(0.07)
	var tela = load("res://cenas/ui/tela_inventario.tscn").instantiate()
	cena.add_child(tela)
	await process_frame
	for camada in [tela._corpo,tela._roupa,tela._cabelo]:
		assert(camada.texture.region == Rect2(0,0,128,128),"Inventário recortou apenas parte do quadro refinado")
		assert(camada.size == Vector2(64,64),"Textura aumentou a área da prévia")
		assert(camada.position == tela._corpo.position,"Camadas do personagem desalinhadas")
	var quadro_legado = tela._quadro(load("res://assets/personagens/Body/body_1.png"),0)
	assert(quadro_legado.region == Rect2(0,0,64,64))
	print("Inventário: recorte completo de 128 px exibido em 64 px, camadas alinhadas; grade legada preservada.")
	print("Mana Seed refinado: 11 páginas, escala, F3 único, aparência, equipamentos e animações conferidos.")
	cena.queue_free()
	await process_frame
	quit()
