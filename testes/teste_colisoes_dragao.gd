extends SceneTree

const Area := preload("res://codigo/efeitos/area_ataque_dragao.gd")
const Geometria := preload("res://codigo/efeitos/geometria_ataque_dragao.gd")
var falhas := 0

func _initialize() -> void:
	_rodar()

func verificar(nome: String, condicao: bool) -> void:
	print("OK " if condicao else "FALHA ", nome)
	if not condicao:
		falhas += 1

func _rodar() -> void:
	await process_frame
	var cena := Node2D.new()
	root.add_child(cena)
	current_scene = cena
	var alvo := Node2D.new()
	cena.add_child(alvo)
	var pes := CollisionShape2D.new()
	pes.name = "CollisionShape2D"
	pes.shape = CircleShape2D.new()
	pes.shape.radius = 5
	pes.position.y = 9
	alvo.add_child(pes)
	var area_dano := Area2D.new()
	area_dano.name = "AreaDano"
	alvo.add_child(area_dano)
	var corpo := CollisionShape2D.new()
	corpo.name = "CollisionShape2D"
	corpo.shape = CapsuleShape2D.new()
	corpo.shape.radius = 7
	corpo.shape.height = 24
	corpo.position.y = -1
	area_dano.add_child(corpo)
	for linha in 4:
		var area := Area.new()
		area.tipo = "sopro"
		area.origem = Geometria.boca(linha)
		area.direcao = [Vector2.DOWN, Vector2.UP, Vector2.RIGHT, Vector2.LEFT][linha]
		cena.add_child(area)
		alvo.position = area.origem + area.direcao * 90 - corpo.position
		area.atualizar(1, true, 0.36)
		verificar("fogo %d parte da mesma boca no visual e colisão" % linha, area._efeito.position == area.origem and area.atinge_alvo(alvo))
		alvo.position = area.origem - area.direcao * 40 - corpo.position
		verificar("fogo %d não atinge atrás da boca" % linha, not area.atinge_alvo(alvo))
		alvo.position = area.origem + area.direcao * 180 - corpo.position
		verificar("fogo %d não atinge além do efeito" % linha, not area.atinge_alvo(alvo))
		alvo.position = area.origem + area.direcao.rotated(PI / 3) * 100 - corpo.position
		verificar("fogo %d não atinge fora do cone" % linha, not area.atinge_alvo(alvo))
		area.queue_free()
	var sopro := Area.new()
	sopro.tipo = "sopro"
	sopro.direcao = Vector2.RIGHT
	sopro.position = Vector2(300, 300)
	sopro.scale = Vector2(2, 2)
	cena.add_child(sopro)
	alvo.global_position = sopro.to_global(Vector2(140, 0)) - corpo.position
	sopro.atualizar(1, true, 0.36)
	verificar("colisão acompanha a escala do chefe", sopro.atinge_alvo(alvo))
	sopro.atualizar(1, true, 0.17)
	verificar("fogo em crescimento não atinge a borda distante", not sopro.atinge_alvo(alvo))
	sopro.atualizar(1, true, 0.89)
	verificar("brasas finais não causam dano invisível", not sopro.atinge_alvo(alvo))
	sopro.atualizar(1, true, 0.36)
	alvo.global_position = sopro.to_global(Vector2(100, 0)) - corpo.position
	var parede := StaticBody2D.new()
	parede.collision_layer = 64
	parede.position = sopro.to_global(Vector2(50, 0))
	var bloqueio := CollisionShape2D.new()
	bloqueio.shape = RectangleShape2D.new()
	bloqueio.shape.size = Vector2(10, 200)
	parede.add_child(bloqueio)
	cena.add_child(parede)
	await physics_frame
	await physics_frame
	verificar("fogo não atravessa obstáculo da arena", not sopro.atinge_alvo(alvo))
	parede.queue_free()
	sopro.queue_free()
	await physics_frame
	for tipo in ["cauda", "asas"]:
		var area := Area.new()
		area.tipo = tipo
		area.alcance = 82 if tipo == "cauda" else 112
		cena.add_child(area)
		alvo.position = Vector2(area.alcance - 2, -9)
		area.atualizar(1, true, float(Geometria.DURACOES[tipo]) * 0.1)
		verificar(tipo + " não atinge o círculo inteiro na formação", not area.atinge_alvo(alvo))
		area.atualizar(1, true, float(Geometria.DURACOES[tipo]) * 0.4)
		verificar(tipo + " atinge os pés no impacto máximo", area.atinge_alvo(alvo))
		alvo.position.x = area.alcance + 3
		verificar(tipo + " considera a borda dos pés mesmo com o centro fora", area.atinge_alvo(alvo))
		alvo.position.x = area.alcance + 8
		verificar(tipo + " não atinge depois da borda", not area.atinge_alvo(alvo))
		alvo.position = Vector2(0, -9)
		area.atualizar(1, true, float(Geometria.DURACOES[tipo]) * 0.8)
		verificar(tipo + " não atinge quem entrou após o impacto", not area.atinge_alvo(alvo))
		verificar(tipo + " mantém o impacto ao cruzar o instante entre frames", area.atinge_alvo(alvo, float(Geometria.DURACOES[tipo]) * 0.4))
		area.queue_free()
	cena.queue_free()
	await process_frame
	print("Falhas: ", falhas)
	quit(falhas)
