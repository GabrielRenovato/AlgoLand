extends SceneTree

const Chuva := preload("res://codigo/efeitos/chuva_fogo_dragao.gd")
var falhas := 0

class JogadorTeste extends Node2D:
	var estaMorto := false
	var invulneravel := true
	var mortes := 0
	func receber_hitkill_dragao() -> void:
		mortes += 1
		estaMorto = true

func _initialize() -> void:
	_rodar()

func verificar(nome: String, condicao: bool) -> void:
	print("OK " if condicao else "FALHA ", nome)
	if not condicao:
		falhas += 1

func _rodar() -> void:
	await process_frame
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"):
		push_error("Teste requer saves isolados.")
		quit(1)
		return
	var cena := Node2D.new()
	root.add_child(cena)
	current_scene = cena
	var terreno = load("res://cenas/terreno.tscn").instantiate()
	var poligono: PackedVector2Array = terreno.get_node("LimiteArena/Contorno").polygon
	terreno.free()
	var mapa := Node2D.new()
	mapa.name = "Terrains"
	cena.add_child(mapa)
	var limite := StaticBody2D.new()
	limite.name = "LimiteArena"
	limite.collision_layer = 0
	mapa.add_child(limite)
	var contorno := CollisionPolygon2D.new()
	contorno.name = "Contorno"
	contorno.build_mode = CollisionPolygon2D.BUILD_SEGMENTS
	contorno.polygon = poligono
	limite.add_child(contorno)
	for vertical in [true, false]:
		for menor in [true, false]:
			var metade := Chuva.metade_mapa(poligono, vertical, menor)
			verificar("especial ocupa exatamente metade do contorno %s/%s" % [vertical, menor], absf(Chuva.area_poligono(metade) / Chuva.area_poligono(poligono) - 0.5) < 0.00001)
	for centro in [Vector2(100, 100), Vector2(350, 200), Vector2(680, 300), Vector2(0, -100)]:
		var circular := Chuva.zona_centrada(poligono, centro)
		var limitado := true
		for ponto in circular: limitado = limitado and ponto.distance_to(centro) <= Chuva.RAIO_ZONA + 0.1
		verificar("zona em %s contém jogador e respeita raio de fuga" % centro, limitado and Geometry2D.is_point_in_polygon(centro,circular))
	# Aumentar muito o contorno não aumenta a zona, nem o caminho até sair dela.
	var gigante := PackedVector2Array([Vector2(-5000,-5000),Vector2(5000,-5000),Vector2(5000,5000),Vector2(-5000,5000)])
	var zona_grande := Chuva.zona_centrada(gigante,Vector2.ZERO)
	verificar("caverna gigante mantém zona local",Chuva.limites_poligono(zona_grande).size.x <= Chuva.RAIO_ZONA * 2 + 0.1)
	verificar("aviso permite fuga andando a 50 pixels por segundo",Chuva.RAIO_ZONA + 16 < 50 * Chuva.AVISO)
	var jogador := JogadorTeste.new()
	jogador.name = "Jogador"
	jogador.position = Vector2(100, 100)
	cena.add_child(jogador)
	var chefe = load("res://cenas/inimigos/dragao_vermelho.tscn").instantiate()
	cena.add_child(chefe)
	chefe.set_physics_process(false)
	chefe.vida_maxima = 1000
	chefe.vida = 500
	chefe._registrar_especiais()
	verificar("50% exatos ainda não dispararam a primeira marca", chefe._especiais_pendentes == 0)
	chefe.vida = 499
	chefe._registrar_especiais()
	chefe._registrar_especiais()
	verificar("abaixo de 50% enfileira somente um especial", chefe._especiais_pendentes == 1)
	verificar("especial começa com decolagem", chefe._iniciar_especial() and chefe.estado == chefe.Estado.SUBINDO)
	verificar("decolagem não revela a metade escolhida", not chefe._chuva.visible)
	await process_frame
	verificar("dragão não recebe ataques durante o voo", not chefe._area_dano.monitorable)
	var vida_antes: int = chefe.vida
	chefe.receber_dano(100)
	verificar("dragão aéreo é invulnerável", chefe.vida == vida_antes)
	chefe._physics_process(1.3)
	verificar("dragão desaparece no céu", not chefe.sprite.visible and chefe.estado == chefe.Estado.CHUVA)
	verificar("aviso de três segundos aparece somente após desaparecer", chefe._chuva.visible and Chuva.AVISO == 3.0)
	verificar("aviso centrado na posição capturada do jogador", chefe._chuva.centro_aviso == jogador.position and Geometry2D.is_point_in_polygon(jogador.position, chefe._chuva.zona))
	var zona_fixa: PackedVector2Array = chefe._chuva.zona.duplicate()
	var meio := Vector2.ZERO
	for ponto in chefe._chuva.zona:
		meio += ponto
	meio /= chefe._chuva.zona.size()
	jogador.position = meio
	chefe._physics_process(Chuva.AVISO - 0.1)
	verificar("aviso não causa morte", jogador.mortes == 0 and not chefe._chuva.ativo)
	chefe._physics_process(0.2)
	verificar("chuva mata mesmo com invulnerabilidade", jogador.mortes == 1 and chefe._chuva.ativo)
	jogador.estaMorto = false
	jogador.position = Vector2(2000, 2000)
	chefe._physics_process(0.2)
	verificar("metade segura não causa dano", jogador.mortes == 1)
	verificar("aviso não segue o jogador depois de marcado", chefe._chuva.zona == zona_fixa)
	chefe._physics_process(Chuva.DURACAO)
	verificar("fim da chuva inicia pouso e remove zona", chefe.estado == chefe.Estado.DESCENDO and chefe._chuva == null)
	chefe._physics_process(1.3)
	await process_frame
	verificar("pouso restaura sprite e área de acerto", chefe.estado == chefe.Estado.LIVRE and chefe.sprite.visible and chefe._area_dano.monitorable and chefe.sprite.position == Vector2(0, -46))
	chefe.vida = 100
	chefe._registrar_especiais()
	chefe._registrar_especiais()
	verificar("10% dispara somente o segundo especial", chefe._especiais_pendentes == 1 and chefe._marcas_especial == [true, true])
	chefe._iniciar_especial()
	var chuva = chefe._chuva
	chefe.queue_free()
	await process_frame
	await process_frame
	verificar("troca de onda remove chuva pendente", not is_instance_valid(chuva))
	cena.queue_free()
	await process_frame
	var arena = load("res://cenas/cenario.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	for i in 4:
		await process_frame
	arena.get_node("enemySpawner/GerenciadorOndas").parar_ondas()
	var real = arena.get_node("Jogador")
	real.set_physics_process(false)
	real.invulneravel = true
	real.defesa.estado = real.defesa.Estado.GUARDA
	var progresso := root.get_node("Progresso")
	progresso.partida_ativa = true
	progresso.moradores["curandeira"] = true
	progresso.reviveu_na_partida = false
	real.receber_hitkill_dragao()
	verificar("hit kill real ignora HP, invulnerabilidade, guarda e reviver", real.estaMorto and real.hp_atual == 0 and not progresso.reviveu_na_partida)
	arena.queue_free()
	await process_frame
	print("Falhas: ", falhas)
	quit(falhas)
