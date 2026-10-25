extends SceneTree

## Regressão: composição final, bases físicas e corredores em todos os mapas.
var falhas := 0
func _initialize() -> void: rodar.call_deferred()
func quadros(n := 5) -> void:
	for i in n:
		await physics_frame
		await process_frame
func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ",nome)
	if not ok: falhas += 1
func rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name","")).begins_with("AlgoLand testes"):
		quit(1)
		return
	await process_frame
	var catalogo = load("res://codigo/fendas/catalogo_andares.gd")
	root.get_node("Introducao").pular_prologo()
	root.get_node("Progresso").iniciar_partida()
	for andar in range(1,22):
		var transicao: Node = root.get_node("Transicao")
		transicao.retornando = true
		transicao.estado = {"onda_atual":andar}
		transicao.iniciar_onda_ao_chegar = false
		change_scene_to_file(catalogo.cena(andar))
		await quadros(12)
		var terreno: Node2D = current_scene.get_node("Terrains")
		var jogador: CharacterBody2D = current_scene.get_node("Jogador")
		jogador.set_physics_process(false)
		jogador.collision_mask = 64
		var sprites := terreno.get_node("Objetos3D")
		var fontes := {}
		var correspondencia := true
		var contato := true
		var quantidade := 0
		var espaco := terreno.get_world_2d().direct_space_state
		for forma in terreno.get_node("Obstaculos").get_children():
			if not forma.has_meta("sprite_colisao"): continue
			quantidade += 1
			var nome: String = forma.get_meta("sprite_colisao")
			var sprite := sprites.get_node_or_null(NodePath(nome)) as Sprite2D
			if sprite == null or fontes.has(nome):
				correspondencia = false
				continue
			fontes[nome] = forma
			# Toda base fica nos pés; altura do desenho não vira parede.
			var centro := Vector2.ZERO
			for ponto in forma.polygon:
				centro += ponto
				var local: Vector2 = ponto-sprite.position
				if local.y < -12 or local.y > 1 or absf(local.x)>32:
					correspondencia = false
			centro = forma.to_global(centro/forma.polygon.size())
			var consulta := PhysicsPointQueryParameters2D.new()
			consulta.position = centro
			consulta.collision_mask = 64
			if espaco.intersect_point(consulta).is_empty(): contato = false
			# Chegar ao centro da base com o corpo real precisa encontrar um sólido.
			var pes: Vector2 = jogador.get_node("CollisionShape2D").position
			for direcao in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
				var inicio: Vector2 = centro-pes+direcao*40
				if not jogador.test_move(Transform2D(0,inicio),-direcao*40): contato = false
		for sprite in sprites.get_children():
			# A regressão original eram arbustos removidos ou com a base antiga.
			if sprite is Sprite2D and str(sprite.name).begins_with("ArbustoMargem") and not fontes.has(str(sprite.name)):
				correspondencia = false
		verificar("bases correspondem aos sprites finais / andar %d (%d bases)" % [andar,quantidade],correspondencia and quantidade>0)
		verificar("jogador encontra a base por quatro lados / andar %d" % andar,contato)
		var mapa := terreno.get_world_2d().navigation_map
		var entrada: Vector2 = terreno.get_node("Chegada_portal").global_position
		var passagens := true
		for setor in terreno.get_node("Setores").get_children():
			var rota := NavigationServer2D.map_get_path(mapa,entrada,setor.global_position,true,1)
			if rota.is_empty() or rota[-1].distance_to(setor.global_position)>4:
				print("ROTA_DIAG ",andar," ",setor.name," destino ",setor.global_position," fim ",rota[-1] if not rota.is_empty() else Vector2.INF," proximo ",NavigationServer2D.map_get_closest_point(mapa,setor.global_position))
				passagens = false
			for i in range(1,rota.size()):
				var a := rota[i-1]
				var b := rota[i]
				var passos := maxi(ceili(a.distance_to(b)/8),1)
				for j in passos:
					var inicio := a.lerp(b,float(j)/passos)
					var fim := a.lerp(b,float(j+1)/passos)
					if jogador.test_move(Transform2D(0,inicio),fim-inicio):
						print("BLOQUEIO ",andar," ",setor.name," ",inicio)
						passagens = false
		verificar("jogador percorre todas as salas / andar %d" % andar,passagens)
		var bordas := true
		var contorno: PackedVector2Array = terreno.get_node("LimiteArena/Contorno").polygon
		var deslocamento_pes: Vector2 = jogador.get_node("CollisionShape2D").position
		# Cruzar segmentos da parede nos dois sentidos: nenhuma fresta física.
		for i in range(0,contorno.size(),maxi(contorno.size()/60,1)):
			var a: Vector2 = terreno.to_global(contorno[i])
			var b: Vector2 = terreno.to_global(contorno[(i+1)%contorno.size()])
			if a.distance_to(b)<1: continue
			var meio := (a+b)*.5
			var normal := (b-a).normalized().orthogonal()
			for sentido in [-1,1]:
				if not jogador.test_move(Transform2D(0,meio+normal*12*sentido-deslocamento_pes),-normal*24*sentido): bordas=false
		verificar("paredes fechadas com o corpo real / andar %d" % andar,bordas)
		# Trocar a estação conserva exatamente as mesmas formas físicas.
		var antes: Array = []
		for forma in terreno.get_node("Obstaculos").get_children(): antes.append(forma.polygon.duplicate())
		for estacao in 4:
			terreno.get_node("Estacoes").definir_estacao(estacao,true)
			var depois: Array = []
			for forma in terreno.get_node("Obstaculos").get_children(): depois.append(forma.polygon)
			if antes != depois: correspondencia=false
		verificar("bases conservadas nas quatro estacoes / andar %d" % andar,correspondencia)
		current_scene.get_node("enemySpawner/GerenciadorOndas").parar_ondas()
		await quadros(2)
	quit(1 if falhas else 0)
