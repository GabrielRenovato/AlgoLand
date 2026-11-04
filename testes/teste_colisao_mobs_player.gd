extends SceneTree
## Usa os corpos reais dos mobs e a forma física definida na cena do jogador.
const MOBS := ["arraia_junco","besouro_barranco","caranguejo","cerne_partido","cogumelo","dragao_vermelho","esqueleto_arqueiro","esqueleto_guerreiro","esqueleto_mago","falcao","flor","goblin_machado_fenda","goblin_maromba","goblin_pomar","golem","gremlin","lorde_goblin","medusa","mimico","minotauro","morcego","rebento_raizes","slime","valvula_errante","vespa"]
var falhas := 0
func _initialize() -> void: rodar.call_deferred()
func verificar(nome: String, condicao: bool) -> void:
	print("OK " if condicao else "FALHA ",nome)
	if not condicao: falhas += 1
func sincronizar() -> void:
	for i in 3:
		await process_frame
		await physics_frame
func rodar() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"):
		quit(1)
		return
	var mundo := Node2D.new()
	root.add_child(mundo)
	current_scene = mundo
	var modelo = load("res://cenas/jogador.tscn").instantiate()
	var player := CharacterBody2D.new()
	player.collision_layer = modelo.collision_layer
	player.collision_mask = modelo.collision_mask
	var pes: CollisionShape2D = modelo.get_node("CollisionShape2D").duplicate()
	player.add_child(pes)
	mundo.add_child(player)
	modelo.free()
	for nome in MOBS:
		var mob = load("res://cenas/inimigos/"+nome+".tscn").instantiate()
		mob.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
		mob.process_mode = Node.PROCESS_MODE_DISABLED
		mundo.add_child(mob)
		var corpo: CollisionShape2D = mob.get_node("colision_body")
		var centro := Vector2(500,500)
		var distancia: float = maxf(100.0,corpo.shape.get_rect().size.length()*mob.scale.length()+40.0)
		verificar(nome+" detecta player e conserva camada atingivel",bool(mob.collision_mask & 2) and bool(mob.collision_layer & 32))
		if nome in ["vespa","morcego","falcao"]:
			verificar(nome+" continua sem navegacao terrestre",mob._agente == null and not bool(mob.collision_mask & 64))
		for rumo in [Vector2.RIGHT,Vector2.DOWN,Vector2.UP,Vector2.LEFT]:
			player.global_position = centro-pes.position
			mob.global_position = centro+rumo*distancia-corpo.position*mob.scale
			await sincronizar()
			var choque: KinematicCollision2D = mob.move_and_collide(-rumo*distancia*2.0)
			verificar(nome+" bloqueado pelo player "+str(rumo),choque!=null and choque.get_collider()==player)
			mob.global_position = centro+rumo*distancia-corpo.position*mob.scale
			player.global_position = centro-pes.position
			await sincronizar()
			choque = player.move_and_collide(rumo*distancia*2.0)
			verificar(nome+" bloqueia o player "+str(rumo),choque!=null and choque.get_collider()==mob)
		mob.esta_morto = true
		await sincronizar()
		verificar(nome+" morto deixa de bloquear o player",not bool(mob.collision_layer & 32) and not bool(mob.collision_mask & 2))
		mob.queue_free()
		await sincronizar()
	print("FALHAS: ",falhas)
	quit(1 if falhas else 0)
