extends SceneTree
## A franja não pode deslocar a armadura quando a cabeça permanece no lugar.
const Gerador = preload("res://ferramentas/armaduras/gerar_conjunto.gd")

func _initialize() -> void:
	var corpo := Image.load_from_file("res://assets/personagens/raven_fantasy/camadas/corpo_0.png")
	var cabelo := Image.load_from_file("res://assets/personagens/raven_fantasy/camadas/cabelo_1.png")
	for d in 4:
		var regiao := Rect2i(8, 320 + d * 80 + 4, 64, 64)
		var pele := corpo.get_region(regiao)
		var limite := cabelo.get_region(regiao).get_used_rect()
		assert(Gerador.ancora_cabeca_raven(pele, limite) == Vector2i(32, 25), "Centro anatômico no repouso: direção %d" % d)
		# Mesmo crânio com mais volume de cabelo à esquerda/direita e abaixo.
		var volumoso := Rect2i(limite.position - Vector2i(2, 0), limite.size + Vector2i(5, 3))
		assert(Gerador.ancora_cabeca_raven(pele, volumoso) == Vector2i(32, 25), "Volume do cabelo não altera o encaixe")
		var movido := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		movido.blit_rect(pele, Rect2i(0, 0, 64, 64), Vector2i(1, -2))
		limite.position += Vector2i(1, -2)
		assert(Gerador.ancora_cabeca_raven(movido, limite) == Vector2i(33, 23), "Armadura acompanha o balanço da cabeça")
	print("ALINHAMENTO RAVEN: 12 verificações, quatro direções; centro, cabelo assimétrico e movimento")
	quit()
